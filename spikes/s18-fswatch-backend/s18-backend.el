;;; s18-backend.el --- S18: eglot's watches through one fswatch per root  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-127).  Replaces Emacs 31.1's `eglot--watch-globs'
;; (eglot 1.24.31) by one patched fswatch (D-109) per registration and root; records
;; are read by a process filter, matched against the registration's globs and sent in
;; one `workspace/didChangeWatchedFiles' per filter call.  `s18-matcher': `eglot'
;; uses eglot's compiled glob predicates, `regexp' one regexp per glob (from the glob
;; text, kept by advice on `eglot--glob-compile').

(require 'cl-lib)
(require 'eglot)

(defvar s18-fswatch-program
  (or (getenv "S18_FSWATCH")
      (if (eq system-type 'darwin)
          (expand-file-name "~/opt/fswatch-no-loss/bin/fswatch")
        "/opt/fswatch-no-loss/bin/fswatch"))
  "The patched fswatch.")

(defvar s18-matcher 'regexp "Glob matching: `eglot' or `regexp'.")

(defvar s18-stats nil "Plist: :records :sent :overflow :skipped.")

(defvar s18--processes (make-hash-table :test #'eq)
  "Server -> alist (ID . PROCESSES).")

(defvar s18--glob-text (make-hash-table :test #'eq :weakness 'key)
  "Compiled glob predicate -> its glob text.")

(defun s18--stat (key &optional n)
  (setq s18-stats (plist-put s18-stats key (+ (or (plist-get s18-stats key) 0) (or n 1)))))

(defun s18--remember-glob (fn glob &rest args)
  "Around `eglot--glob-compile': remember GLOB for the predicate FN returns."
  (let ((pred (apply fn glob args)))
    (puthash pred glob s18--glob-text)
    pred))

(defun s18-glob-to-regexp (glob)
  "An anchored regexp for LSP GLOB (`**', `*', `?', `{a,b}', `[...]')."
  (let ((i 0) (n (length glob)) (out "\\`"))
    (while (< i n)
      (let ((c (aref glob i)))
        (cond
         ((and (eq c ?*) (< (1+ i) n) (eq (aref glob (1+ i)) ?*))
          (if (and (< (+ i 2) n) (eq (aref glob (+ i 2)) ?/))
              (setq out (concat out "\\(?:.*/\\)?") i (+ i 3))
            (setq out (concat out ".*") i (+ i 2))))
         ((eq c ?*) (setq out (concat out "[^/]*") i (1+ i)))
         ((eq c ??) (setq out (concat out "[^/]") i (1+ i)))
         ((eq c ?{)
          (let ((end (or (cl-position ?} glob :start i) (error "s18: bad glob %s" glob))))
            (setq out (concat out "\\(?:"
                              (mapconcat #'regexp-quote
                                         (split-string (substring glob (1+ i) end) ",")
                                         "\\|")
                              "\\)")
                  i (1+ end))))
         ((eq c ?\[)
          (let ((end (or (cl-position ?\] glob :start i) (error "s18: bad glob %s" glob))))
            (setq out (concat out (replace-regexp-in-string
                                   "\\`\\[!" "[^" (substring glob i (1+ end))))
                  i (1+ end))))
         (t (setq out (concat out (regexp-quote (string c))) i (1+ i))))))
    (concat out "\\'")))

(defun s18--matchers (globs)
  "GLOBS, (PREDICATE . KIND) pairs, as (MATCH . KIND): MATCH a regexp or function."
  (mapcar (lambda (g)
            (cons (if (eq s18-matcher 'regexp)
                      (s18-glob-to-regexp
                       (or (gethash (car g) s18--glob-text)
                           (error "s18: no glob text for a predicate")))
                    (car g))
                  (cdr g)))
          globs))

(defun s18--handle (server root real-root matchers record changes)
  "Push RECORD's change onto CHANGES if it matches; return CHANGES."
  (let* ((space (or (cl-position ?\s record :from-end t) (error "s18: record %S" record)))
         (path (substring record 0 space))
         (flags (substring record (1+ space))))
    (s18--stat :records)
    (cond
     ((string-search "Overflow" flags)
      (s18--stat :overflow)
      (message "s18: fswatch reported an overflow at %s" path)
      changes)
     (t
      (when (and real-root (string-prefix-p real-root path))
        (setq path (concat root (substring path (length real-root)))))
      (if (not (string-prefix-p root path))
          (progn (s18--stat :skipped) changes)
        (let* ((rel (substring path (length root)))
               (exists (file-exists-p path))
               (type (cond ((not exists) 3)
                           ((string-search "Created" flags) 1)
                           (t 2)))
               (bit (ash 1 (1- type)))
               (buffer (get-file-buffer path)))
          (if (and (cl-loop for (match . kind) in matchers
                            thereis (and (> (logand kind bit) 0)
                                         (if (stringp match)
                                             (string-match-p match rel)
                                           (funcall match rel))))
                   (not (and buffer (with-current-buffer buffer (eglot-managed-p)))))
              (cons `(:uri ,(eglot-path-to-uri path) :type ,type) changes)
            (s18--stat :skipped)
            changes)))))))

(defun s18--filter (server root real-root matchers)
  "A process filter splitting fswatch's NUL-separated records."
  (let ((pending ""))
    (lambda (_proc string)
      (let* ((text (concat pending string))
             (records (split-string text "\0"))
             changes)
        (setq pending (car (last records)))
        (dolist (r (butlast records))
          (unless (string-empty-p r)
            (setq changes (s18--handle server root real-root matchers r changes))))
        (when changes
          (s18--stat :sent (length changes))
          (jsonrpc-notify server :workspace/didChangeWatchedFiles
                          `(:changes ,(vconcat (nreverse changes)))))))))

(defun s18--watch-globs (server id globs dir _in-root)
  "Override of `eglot--watch-globs': one fswatch for DIR (or the project root)."
  (let* ((root (file-name-as-directory
                (expand-file-name (or dir (project-root (eglot--project server))))))
         (real (file-name-as-directory (file-truename root)))
         (proc (make-process
                :name (format "s18-fswatch %s" id)
                :command (list s18-fswatch-program "-0" "-r" "-x"
                               "--event-flag-separator=," "-l" "0.1"
                               "--allow-overflow" "-e" "/\\.git/" (directory-file-name real))
                :connection-type 'pipe :noquery t :coding 'utf-8-unix
                :stderr (get-buffer-create " *s18-fswatch stderr*")
                :filter (s18--filter server root (unless (equal real root) real)
                                     (s18--matchers globs))
                :sentinel (lambda (p event)
                            (unless (process-get p 's18-stopping)
                              (message "s18: fswatch for %s ended: %s" root
                                       (string-trim event)))))))
    (push proc (alist-get id (gethash server s18--processes)))
    t))

(defun s18--stop (server &optional id)
  "Stop SERVER's fswatch processes, of registration ID or all."
  (let ((alist (gethash server s18--processes)))
    (dolist (entry alist)
      (when (or (null id) (equal (car entry) id))
        (dolist (p (cdr entry))
          (process-put p 's18-stopping t)
          (when (process-live-p p) (delete-process p)))))
    (puthash server (if id (cl-remove id alist :key #'car :test #'equal) nil)
             s18--processes)))

(defun s18--before-unregister (server method id &rest _)
  (when (eq method 'workspace/didChangeWatchedFiles)
    (s18--stop server id)))

(defun s18--before-shutdown (server &rest _)
  (s18--stop server))

(defun s18-live-processes ()
  "The fswatch processes still alive."
  (cl-loop for p in (process-list)
           when (and (string-prefix-p "s18-fswatch" (process-name p)) (process-live-p p))
           collect p))

(defun s18-enable ()
  (advice-add 'eglot--glob-compile :around #'s18--remember-glob)
  (advice-add 'eglot--watch-globs :override #'s18--watch-globs)
  (advice-add 'eglot-unregister-capability :before #'s18--before-unregister)
  (advice-add 'eglot--on-shutdown :before #'s18--before-shutdown))

(provide 's18-backend)
;;; s18-backend.el ends here
