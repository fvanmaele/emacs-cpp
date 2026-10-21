;;; emacs-cpp-eglot-fswatch.el --- eglot's file watches through the patched fswatch  -*- lexical-binding: t; -*-

;;; Commentary:

;; Language servers ask the client to watch files (`workspace/didChangeWatchedFiles':
;; ty, pyright, texlab, clangd).  Emacs's own watches take one kqueue descriptor per
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

(defvar emacs-cpp-eglot-fswatch--processes (make-hash-table :test #'eq :weakness 'key)
  "Server -> alist (REGISTRATION-ID . PROCESS).")

(defvar emacs-cpp-eglot-fswatch--root-uris (make-hash-table :test #'equal)
  "True-name root -> its file URI, without the trailing slash.")

;;;; Globs

(defun emacs-cpp-eglot-fswatch--glob-body (glob)
  "Return a regexp, unanchored, for LSP GLOB: `*', `**', `?', `{a,b}', `[...]'."
  (let ((i 0) (n (length glob)) (parts nil))
    (while (< i n)
      (let ((c (aref glob i)))
        (cond
         ((and (eq c ?*) (< (1+ i) n) (eq (aref glob (1+ i)) ?*))
          (cond ((and (< (+ i 2) n) (eq (aref glob (+ i 2)) ?/))
                 (push "\\(?:.*/\\)?" parts) (setq i (+ i 3)))
                (t (push ".*" parts) (setq i (+ i 2)))))
         ((eq c ?*) (push "[^/]*" parts) (setq i (1+ i)))
         ((eq c ??) (push "[^/]" parts) (setq i (1+ i)))
         ((eq c ?{)
          ;; Alternatives, each a glob itself; nested braces are counted.
          (let ((depth 0) (j i) (start (1+ i)) alternatives)
            (while (progn
                     (pcase (aref glob j)
                       (?{ (cl-incf depth))
                       (?} (cl-decf depth)
                           (when (= depth 0)
                             (push (substring glob start j) alternatives)))
                       (?, (when (= depth 1)
                             (push (substring glob start j) alternatives)
                             (setq start (1+ j)))))
                     (and (> depth 0) (< (cl-incf j) n))))
            (unless (= depth 0) (error "emacs-cpp: unclosed { in glob %S" glob))
            (push (concat "\\(?:"
                          (mapconcat #'emacs-cpp-eglot-fswatch--glob-body
                                     (nreverse alternatives) "\\|")
                          "\\)")
                  parts)
            (setq i (1+ j))))
         ((eq c ?\[)
          (let ((end (or (cl-position ?\] glob :start (1+ i))
                         (error "emacs-cpp: unclosed [ in glob %S" glob))))
            (push (concat "[" (if (eq (aref glob (1+ i)) ?!)
                                  (concat "^" (substring glob (+ i 2) end))
                                (substring glob (1+ i) end))
                          "]")
                  parts)
            (setq i (1+ end))))
         (t (push (regexp-quote (string c)) parts) (setq i (1+ i))))))
    (apply #'concat (nreverse parts))))

(defun emacs-cpp-eglot-fswatch-glob-regexp (glob &optional prefix)
  "Return an anchored regexp matching root-relative file names for GLOB.
PREFIX, a directory relative to the root (\"\" or ending in /), is where the
watcher's base lies; GLOB is relative to it."
  (concat "\\`" (regexp-quote (or prefix "")) (emacs-cpp-eglot-fswatch--glob-body glob)
          "\\'"))

(defun emacs-cpp-eglot-fswatch--matchers (watchers root)
  "Return (REGEXP . KIND) for the WATCHERS of a registration; ROOT is the project.
Watchers based outside ROOT are left out (D-121)."
  (cl-loop
   for watcher across watchers
   for pattern = (plist-get watcher :globPattern)
   for base-uri = (and (consp pattern) (plist-get pattern :baseUri))
   for base = (and base-uri (eglot-uri-to-path (if (stringp base-uri) base-uri
                                                  (plist-get base-uri :uri))))
   for glob = (if (consp pattern) (plist-get pattern :pattern) pattern)
   when (or (null base) (file-in-directory-p base root))
   collect (cons (emacs-cpp-eglot-fswatch-glob-regexp
                  glob (and base (let ((rel (file-relative-name base root)))
                                   (if (equal rel ".") "" (file-name-as-directory rel)))))
                 (or (plist-get watcher :kind) 7))))

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

(defun emacs-cpp-eglot-fswatch-changes (server merged real-root root matchers)
  "Return the LSP changes of MERGED, (PATH . FLAGS) under REAL-ROOT, for MATCHERS.
ROOT is the root as eglot spells it, for buffers; a file a buffer of SERVER's
visits is left out, as eglot does (the server has its text)."
  (let ((root-uri (emacs-cpp-eglot-fswatch--root-uri real-root))
        changes)
    (pcase-dolist (`(,path . ,flags) merged)
      (when (string-prefix-p real-root path)
        (let* ((rel (substring path (length real-root)))
               (type (cond ((not (file-exists-p path)) 3)
                           ((string-search "Created" flags) 1)
                           (t 2)))
               (bit (ash 1 (1- type)))
               (buffer (get-file-buffer (concat root rel))))
          (when (and (cl-loop for (regexp . kind) in matchers
                              thereis (and (> (logand kind bit) 0)
                                           (let ((case-fold-search nil))
                                             (string-match-p regexp rel))))
                     (not (and buffer
                               (eq server (with-current-buffer buffer
                                            (eglot-current-server))))))
            (push `(:uri ,(concat root-uri "/" (url-hexify-string
                                                rel eglot--uri-path-allowed-chars))
                         :type ,type)
                  changes)))))
    (nreverse changes)))

;;;; Processes

(defun emacs-cpp-eglot-fswatch--overflow-p (record)
  "Non-nil when RECORD's flags include `Overflow': fswatch lost changes."
  (when-let* ((space (cl-position ?\s record :from-end t)))
    (member "Overflow" (split-string (substring record (1+ space)) ","))))

(defun emacs-cpp-eglot-fswatch--filter (server real-root root matchers)
  "Return the process filter turning fswatch's records into notifications."
  (let ((pending "")
        (overflow-warned 0))
    (lambda (_process output)
      (let* ((records (split-string (concat pending output) "\0"))
             (complete (butlast records)))
        (setq pending (car (last records)))
        (when (cl-some #'emacs-cpp-eglot-fswatch--overflow-p complete)
          (when (> (- (float-time) overflow-warned) 60)
            (setq overflow-warned (float-time))
            (display-warning
             'emacs-cpp
             (format "fswatch for %s overflowed: changes were lost; `M-x \
eglot-reconnect' lets the server see the files again" root)
             :warning))
          (setq complete (cl-remove-if #'emacs-cpp-eglot-fswatch--overflow-p complete)))
        (when-let* ((changes (emacs-cpp-eglot-fswatch-changes
                              server (emacs-cpp-eglot-fswatch-merge complete)
                              real-root root matchers)))
          (jsonrpc-notify server :workspace/didChangeWatchedFiles
                          `(:changes ,(vconcat changes))))))))

(defun emacs-cpp-eglot-fswatch--start (server id matchers)
  "Start SERVER's fswatch for registration ID, its globs MATCHERS; return it."
  (let* ((root (file-name-as-directory
                (expand-file-name (project-root (eglot--project server)))))
         (real-root (file-name-as-directory (file-truename root)))
         (stderr (generate-new-buffer (format " *emacs-cpp-fswatch %s stderr*" id)))
         (process
          (make-process
           :name (format "emacs-cpp-fswatch %s" id)
           :command `(,emacs-cpp-default-fswatch-program
                      "-0" "-r" "-x" "--event-flag-separator=,"
                      "-l" ,(number-to-string emacs-cpp-eglot-fswatch-latency)
                      "--allow-overflow"
                      ,@(cl-loop for regexp in emacs-cpp-eglot-fswatch-exclude
                                 append (list "-e" regexp))
                      ,(directory-file-name real-root))
           :connection-type 'pipe :noquery t :coding 'utf-8-unix
           :stderr stderr
           :filter (emacs-cpp-eglot-fswatch--filter server real-root root matchers)
           :sentinel
           (lambda (process event)
             (unless (or (process-get process 'emacs-cpp-stopping)
                         (process-live-p process))
               (display-warning
                'emacs-cpp
                (format "fswatch for %s ended (%s)%s; its changes are no longer \
reported; `M-x eglot-reconnect' starts it again"
                        root (string-trim event)
                        (let ((text (with-current-buffer stderr
                                      (string-trim (buffer-string)))))
                          (if (string-empty-p text) "" (format ": %s" text))))
                :warning))
             (unless (process-live-p process)
               (when (buffer-live-p stderr) (kill-buffer stderr)))))))
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
    (when matchers
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
