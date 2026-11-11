;;; emacs-cpp-eglot-fswatch.el --- eglot's file watches through the patched fswatch  -*- lexical-binding: t; -*-

;;; Commentary:

;; Language servers ask the client to watch files (`workspace/didChangeWatchedFiles':
;; ty, pyright, clangd).  Emacs's own watches take one kqueue descriptor per
;; directory on the Mac (refused beyond 975) and one inotify watch per directory on
;; Arch, where eglot stops at `eglot-max-file-watches' and then fails the whole
;; registration, which makes pyright exit (RESEARCH_platform_differences 3.1, 3.3,
;; 3.14).  Here each registration gets one patched fswatch (D-109) watching the
;; project root recursively, whatever its size (D-127; DESIGN 7.1; S18 PASS on both
;; machines).
;;
;; An `:around' method on `eglot-register-capability' and on
;; `eglot-unregister-capability' for that method takes the registration over, so
;; eglot's own method (and `file-notify') is not used for it; advice before
;; `eglot--on-shutdown' ends a server's processes.  Records become changes in the
;; shape S18 measured: a filter call's records merged per path (inotify writes three
;; for a written file), the URI built from the root's (not `eglot-path-to-uri', whose
;; `file-truename' was most of the cost), each glob one regexp, one notification per
;; filter call.  Overflows and an fswatch that dies are warned about, never hidden.
;; The program, `emacs-cpp-default-fswatch-program', is checked at startup by
;; init-lsp (`emacs-cpp-fswatch-program-check').

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'eglot)
(require 'url-util)

(defvar emacs-cpp-default-fswatch-program)

;; eglot internals used below; another eglot without them fails here, not at the
;; first change (`advice-add' would accept a function that does not exist).
(dolist (internal '(eglot--on-shutdown eglot--project eglot--uri-path-allowed-chars))
  (unless (or (fboundp internal) (boundp internal))
    (error "emacs-cpp: this eglot lacks %s, which lisp/emacs-cpp-eglot-fswatch.el \
uses; update the backend (D-127)" internal)))

(defconst emacs-cpp-eglot-fswatch-latency 0.1
  "Seconds fswatch gathers events before it writes them (its -l).")

(defconst emacs-cpp-eglot-fswatch-exclude '("/\\.git/")
  "Regexps of paths fswatch does not report (its -e): git's own churn.")

(defconst emacs-cpp-eglot-fswatch--created 1 "LSP FileChangeType Created.")
(defconst emacs-cpp-eglot-fswatch--changed 2 "LSP FileChangeType Changed.")
(defconst emacs-cpp-eglot-fswatch--deleted 3 "LSP FileChangeType Deleted.")
(defconst emacs-cpp-eglot-fswatch--all-kinds 7
  "LSP WatchKind Create | Change | Delete (1 | 2 | 4), a watcher's default.")

(defvar emacs-cpp-eglot-fswatch--processes (make-hash-table :test #'eq :weakness 'key)
  "Server -> alist (REGISTRATION-ID . PROCESS).")

(defvar emacs-cpp-eglot-fswatch--root-uris (make-hash-table :test #'equal)
  "True-name root -> its file URI, without the trailing slash.")

;;;; Globs

(defun emacs-cpp-eglot-fswatch--braces (glob start)
  "Return (ALTERNATIVES . END) for the `{a,b}' at START in GLOB; END is its `}'.
Nested braces are counted; each alternative is a glob itself."
  (let ((depth 0) (j start) (from (1+ start)) alternatives)
    (while (progn
             (pcase (aref glob j)
               (?{ (cl-incf depth))
               (?} (cl-decf depth)
                   (when (= depth 0)
                     (push (substring glob from j) alternatives)))
               (?, (when (= depth 1)
                     (push (substring glob from j) alternatives)
                     (setq from (1+ j)))))
             (and (> depth 0) (< (cl-incf j) (length glob)))))
    (unless (= depth 0) (error "emacs-cpp: unclosed { in glob %S" glob))
    (cons (nreverse alternatives) j)))

(defun emacs-cpp-eglot-fswatch--bracket (content)
  "Return the regexp class for the CONTENT of a glob's `[...]'; `[!...]' negates."
  (if (string-prefix-p "!" content)
      (concat "[^" (substring content 1) "]")
    (concat "[" content "]")))

(defun emacs-cpp-eglot-fswatch--glob-body (glob)
  "Return a regexp, unanchored, for LSP GLOB: `*', `**', `?', `{a,b}', `[...]'."
  (let ((i 0) (n (length glob)) (parts nil))
    (cl-flet ((at (offset char)         ; GLOB has CHAR at I + OFFSET
                (and (< (+ i offset) n) (eq (aref glob (+ i offset)) char)))
              (emit (regexp width)      ; REGEXP stands for the next WIDTH chars
                (push regexp parts)
                (cl-incf i width)))
      (while (< i n)
        (cond
         ;; `**/': any directories, or none; `**': anything; `*': within one name.
         ((and (at 0 ?*) (at 1 ?*) (at 2 ?/)) (emit "\\(?:.*/\\)?" 3))
         ((and (at 0 ?*) (at 1 ?*)) (emit ".*" 2))
         ((at 0 ?*) (emit "[^/]*" 1))
         ((at 0 ??) (emit "[^/]" 1))
         ((at 0 ?{)
          (pcase-let ((`(,alternatives . ,end)
                       (emacs-cpp-eglot-fswatch--braces glob i)))
            (emit (concat "\\(?:"
                          (mapconcat #'emacs-cpp-eglot-fswatch--glob-body
                                     alternatives "\\|")
                          "\\)")
                  (- (1+ end) i))))
         ((at 0 ?\[)
          (let ((end (or (cl-position ?\] glob :start (1+ i))
                         (error "emacs-cpp: unclosed [ in glob %S" glob))))
            (emit (emacs-cpp-eglot-fswatch--bracket (substring glob (1+ i) end))
                  (- (1+ end) i))))
         (t (emit (regexp-quote (string (aref glob i))) 1)))))
    (apply #'concat (nreverse parts))))

(defun emacs-cpp-eglot-fswatch-glob-regexp (glob &optional prefix)
  "Return an anchored regexp matching root-relative file names for GLOB.
PREFIX, a directory relative to the root (\"\" or ending in /), is where the
watcher's base lies; GLOB is relative to it."
  (concat "\\`" (regexp-quote (or prefix "")) (emacs-cpp-eglot-fswatch--glob-body glob)
          "\\'"))

(defun emacs-cpp-eglot-fswatch--watcher-base (pattern)
  "Return the directory a relative glob PATTERN is based on; nil for a plain glob."
  (when-let* ((base-uri (and (consp pattern) (plist-get pattern :baseUri))))
    (eglot-uri-to-path (if (stringp base-uri) base-uri (plist-get base-uri :uri)))))

(defun emacs-cpp-eglot-fswatch--prefix (base root)
  "Return BASE relative to ROOT: \"\" for ROOT itself, else ending in /."
  (let ((rel (file-relative-name base root)))
    (if (equal rel ".") "" (file-name-as-directory rel))))

(defun emacs-cpp-eglot-fswatch--matchers (watchers root)
  "Return (REGEXP . KIND) for the WATCHERS of a registration; ROOT is the project.
Watchers based outside ROOT are left out (D-121)."
  (cl-loop
   for watcher across watchers
   for pattern = (plist-get watcher :globPattern)
   for glob = (if (consp pattern) (plist-get pattern :pattern) pattern)
   for base = (emacs-cpp-eglot-fswatch--watcher-base pattern)
   when (or (null base) (file-in-directory-p base root))
   collect (cons (emacs-cpp-eglot-fswatch-glob-regexp
                  glob (and base (emacs-cpp-eglot-fswatch--prefix base root)))
                 (or (plist-get watcher :kind) emacs-cpp-eglot-fswatch--all-kinds))))

;;;; Records to changes

(defun emacs-cpp-eglot-fswatch--root-uri (real-root)
  "Return REAL-ROOT's URI without its trailing slash, computed once."
  (or (gethash real-root emacs-cpp-eglot-fswatch--root-uris)
      (puthash real-root (eglot-path-to-uri (directory-file-name real-root) :truenamep t)
               emacs-cpp-eglot-fswatch--root-uris)))

(defun emacs-cpp-eglot-fswatch-merge (records)
  "Return RECORDS (\"PATH FLAGS\") as (PATH . FLAGS), one per path, first-seen order.
The flags of a path's records are joined with commas."
  (let ((flags (make-hash-table :test #'equal)) order)
    (dolist (record records)
      (unless (string-empty-p record)
        (let* ((space (or (cl-position ?\s record :from-end t)
                          (error "emacs-cpp: fswatch record without flags: %S" record)))
               (path (substring record 0 space))
               (old (gethash path flags)))
          (unless old (push path order))
          (puthash path (if old (concat old "," (substring record (1+ space)))
                          (substring record (1+ space)))
                   flags))))
    (mapcar (lambda (path) (cons path (gethash path flags))) (nreverse order))))

(defun emacs-cpp-eglot-fswatch--change-type (path flags)
  "Return PATH's LSP FileChangeType: gone, created (fswatch's FLAGS) or changed."
  (cond ((not (file-exists-p path)) emacs-cpp-eglot-fswatch--deleted)
        ((string-search "Created" flags) emacs-cpp-eglot-fswatch--created)
        (t emacs-cpp-eglot-fswatch--changed)))

(defun emacs-cpp-eglot-fswatch--matching (matchers rel)
  "Return those of MATCHERS whose glob matches REL, whatever their kinds."
  (let ((case-fold-search nil))
    (cl-loop for matcher in matchers
             when (string-match-p (car matcher) rel) collect matcher)))

(defun emacs-cpp-eglot-fswatch--wanted-p (matchers rel type)
  "Non-nil if one of MATCHERS whose kind includes change TYPE matches REL."
  (let ((bit (ash 1 (1- type)))         ; WatchKind bit of a FileChangeType
        (case-fold-search nil))
    (cl-loop for (regexp . kind) in matchers
             thereis (and (> (logand kind bit) 0) (string-match-p regexp rel)))))

(defun emacs-cpp-eglot-fswatch--server-has-text-p (server file)
  "Non-nil if a buffer of SERVER visits FILE: the server has its text already."
  (when-let* ((buffer (get-file-buffer file)))
    (eq server (with-current-buffer buffer (eglot-current-server)))))

(defun emacs-cpp-eglot-fswatch-changes (server merged real-root root matchers)
  "Return the LSP changes of MERGED, (PATH . FLAGS) under REAL-ROOT, for MATCHERS.
ROOT is the root as eglot spells it, for buffers; a file a buffer of SERVER's
visits is left out, as eglot does (the server has its text)."
  (let ((root-uri (emacs-cpp-eglot-fswatch--root-uri real-root))
        changes)
    (pcase-dolist (`(,path . ,flags) merged)
      (when (string-prefix-p real-root path)
        ;; The globs first: the change's type asks the file system, and most
        ;; records of a build match no glob.
        (when-let* ((rel (substring path (length real-root)))
                    (matching (emacs-cpp-eglot-fswatch--matching matchers rel))
                    (type (emacs-cpp-eglot-fswatch--change-type path flags))
                    ((emacs-cpp-eglot-fswatch--wanted-p matching rel type))
                    ((not (emacs-cpp-eglot-fswatch--server-has-text-p
                           server (concat root rel)))))
          (push (list :uri (concat root-uri "/" (url-hexify-string
                                                 rel eglot--uri-path-allowed-chars))
                      :type type)
                changes))))
    (nreverse changes)))

;;;; Processes

(defun emacs-cpp-eglot-fswatch--overflow-p (record)
  "Non-nil when RECORD's flags include `Overflow': fswatch lost changes."
  (when-let* ((space (cl-position ?\s record :from-end t)))
    ;; A regexp from the last space on, no list of the flags per record.
    (let ((case-fold-search nil))
      (string-match-p "[ ,]Overflow\\(?:,\\|\\'\\)" record space))))

(defun emacs-cpp-eglot-fswatch--warn-overflow (root)
  (display-warning
   'emacs-cpp
   (format "fswatch for %s overflowed: changes were lost; `M-x \
eglot-reconnect' lets the server see the files again" root)
   :warning))

(defun emacs-cpp-eglot-fswatch--filter (server real-root root matchers)
  "Return the process filter turning fswatch's records into notifications."
  (let ((pending "")
        (overflow-warned 0))
    (lambda (_process output)
      ;; Records end in NUL; the last piece is the start of a record still coming.
      (let* ((pieces (split-string (concat pending output) "\0"))
             (records (butlast pieces)))
        (setq pending (car (last pieces)))
        (when (cl-some #'emacs-cpp-eglot-fswatch--overflow-p records)
          (when (> (- (float-time) overflow-warned) 60) ; at most once a minute
            (setq overflow-warned (float-time))
            (emacs-cpp-eglot-fswatch--warn-overflow root))
          (setq records (cl-remove-if #'emacs-cpp-eglot-fswatch--overflow-p records)))
        (when-let* ((changes (emacs-cpp-eglot-fswatch-changes
                              server (emacs-cpp-eglot-fswatch-merge records)
                              real-root root matchers)))
          (jsonrpc-notify server :workspace/didChangeWatchedFiles
                          `(:changes ,(vconcat changes))))))))

(defun emacs-cpp-eglot-fswatch--command (real-root)
  "Return the fswatch command line watching REAL-ROOT."
  `(,emacs-cpp-default-fswatch-program
    "-0" "-r" "-x" "--event-flag-separator=," ; NUL-ended records, recursive, flags
    "-l" ,(number-to-string emacs-cpp-eglot-fswatch-latency)
    "--allow-overflow"                  ; report lost changes, not exit
    ,@(cl-loop for regexp in emacs-cpp-eglot-fswatch-exclude
               append (list "-e" regexp))
    ,(directory-file-name real-root)))

(defun emacs-cpp-eglot-fswatch--sentinel (root stderr)
  "Return the sentinel of ROOT's fswatch.
It warns when fswatch ends unasked, then kills the STDERR buffer."
  (lambda (process event)
    (unless (process-live-p process)
      (unless (process-get process 'emacs-cpp-stopping)
        (let ((text (with-current-buffer stderr (string-trim (buffer-string)))))
          (display-warning
           'emacs-cpp
           (format "fswatch for %s ended (%s)%s; its changes are no longer \
reported; `M-x eglot-reconnect' starts it again"
                   root (string-trim event)
                   (if (string-empty-p text) "" (format ": %s" text)))
           :warning)))
      (when (buffer-live-p stderr) (kill-buffer stderr)))))

(defun emacs-cpp-eglot-fswatch--start (server id matchers)
  "Start SERVER's fswatch for registration ID, its globs MATCHERS; return it."
  (let* ((root (file-name-as-directory
                (expand-file-name (project-root (eglot--project server)))))
         (real-root (file-name-as-directory (file-truename root)))
         (stderr (generate-new-buffer (format " *emacs-cpp-fswatch %s stderr*" id)))
         (process (make-process
                   :name (format "emacs-cpp-fswatch %s" id)
                   :command (emacs-cpp-eglot-fswatch--command real-root)
                   :connection-type 'pipe :noquery t :coding 'utf-8-unix
                   :stderr stderr
                   :filter (emacs-cpp-eglot-fswatch--filter
                            server real-root root matchers)
                   :sentinel (emacs-cpp-eglot-fswatch--sentinel root stderr))))
    (process-put process 'emacs-cpp-stderr stderr)
    process))

(defun emacs-cpp-eglot-fswatch--stop (server &optional id)
  "Stop SERVER's fswatch of registration ID, or all of SERVER's."
  (let ((alist (gethash server emacs-cpp-eglot-fswatch--processes)))
    (pcase-dolist (`(,key . ,process) alist)
      (when (or (null id) (equal key id))
        (process-put process 'emacs-cpp-stopping t)
        (when (process-live-p process) (delete-process process))))
    (puthash server (if id (cl-remove id alist :key #'car :test #'equal) nil)
             emacs-cpp-eglot-fswatch--processes)))

(defun emacs-cpp-eglot-fswatch-processes (&optional server)
  "Return the live fswatch processes of SERVER, or of every server."
  (let (live)
    (maphash (lambda (s alist)
               (when (or (null server) (eq s server))
                 (pcase-dolist (`(,_ . ,process) alist)
                   (when (process-live-p process) (push process live)))))
             emacs-cpp-eglot-fswatch--processes)
    live))

;;;; eglot

(cl-defmethod eglot-register-capability :around
  (server (_method (eql workspace/didChangeWatchedFiles)) id &key watchers
          &allow-other-keys)
  "Watch the files of registration ID with one patched fswatch (D-127)."
  (emacs-cpp-eglot-fswatch--stop server id)
  (let* ((root (expand-file-name (project-root (eglot--project server))))
         (matchers (emacs-cpp-eglot-fswatch--matchers watchers root)))
    ;; A registration can be handled after the server exited: jsonrpc runs a
    ;; request from a timer, and a server shut down right after it connected
    ;; (ty registers at once) has its request run while `jsonrpc-shutdown' waits,
    ;; possibly after `eglot--on-shutdown', which would then leave this fswatch
    ;; running for the session.
    (when (and matchers (jsonrpc-running-p server))
      (push (cons id (emacs-cpp-eglot-fswatch--start server id matchers))
            (gethash server emacs-cpp-eglot-fswatch--processes))))
  (list t "OK"))

(cl-defmethod eglot-unregister-capability :around
  (server (_method (eql workspace/didChangeWatchedFiles)) id)
  "End the fswatch of registration ID."
  (emacs-cpp-eglot-fswatch--stop server id)
  (list t "OK"))

(defun emacs-cpp-eglot-fswatch--on-shutdown (server)
  "Before `eglot--on-shutdown': end SERVER's fswatch processes."
  (emacs-cpp-eglot-fswatch--stop server))

(advice-add 'eglot--on-shutdown :before #'emacs-cpp-eglot-fswatch--on-shutdown)

(provide 'emacs-cpp-eglot-fswatch)
;;; emacs-cpp-eglot-fswatch.el ends here
