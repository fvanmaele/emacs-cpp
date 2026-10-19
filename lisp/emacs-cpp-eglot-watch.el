;;; emacs-cpp-eglot-watch.el --- eglot's file watches for macOS  -*- lexical-binding: t; -*-

;;; Commentary:

;; macOS watches files with kqueue, one file descriptor per directory, and Emacs
;; refuses watches beyond 975.  pyright and texlab register
;; `workspace/didChangeWatchedFiles'; pyright does so three times, and exits about
;; 0.1 s after eglot answers a registration with an error, which Emacs 31.1's eglot
;; (1.24.31) does when `eglot-max-file-watches' is reached or a watch is refused;
;; eglot then reconnects in a loop (RESEARCH_platform_differences 3.8, 3.14).
;; pyright does not watch files itself when the client offers no watching
;; (RESEARCH_eglot_fork 3), so turning watching off is no way out.
;;
;; Two changes, the former eglot patches 0001 and 0002 written as advice on the
;; built-in eglot (D-121, owner's exception to D-069; loaded on macOS only, by
;; init-lsp):
;; - At the cap, or when the system refuses a watch, the watches made so far stay,
;;   one warning says so, and the registration succeeds.
;; - One watch per directory, shared by all of a server's registrations, so the
;;   cap counts directories.  A watch the system ends (its directory deleted) is
;;   forgotten and replaced when the directory comes back; an error in one
;;   registration's handler is warned about and does not keep the event from the
;;   others.
;;
;; The advice replaces eglot internals (`eglot--watch-globs',
;; `eglot--count-file-watches') and wraps `eglot-unregister-capability' and
;; `eglot--on-shutdown', so it is tied to one eglot: enabling refuses any other
;; version, loudly.  `emacs-cpp-eglot-watch-disable' takes it all back (the tests
;; run it on Arch too).

;;; Code:

(require 'cl-lib)
(require 'eglot)
(require 'filenotify)
(require 'lisp-mnt)

(defconst emacs-cpp-eglot-watch-eglot-version "1.24.31"
  "The eglot version this advice was written against (Emacs 31.1's).")

(defvar emacs-cpp-eglot-watch--table (make-hash-table :test #'eq :weakness 'key)
  "Server -> hash table DIRECTORY -> (DESCRIPTOR . HANDLERS).
HANDLERS is an alist (ID . FUNCTION) of the registrations using the watch.")

(defun emacs-cpp-eglot-watch--eglot-version ()
  "Return the Version header of the eglot library Emacs loads."
  (with-temp-buffer
    (insert-file-contents (find-library-name "eglot"))
    (lm-version)))

(defun emacs-cpp-eglot-watch--directories (server)
  "Return SERVER's table of watched directories."
  (or (gethash server emacs-cpp-eglot-watch--table)
      (puthash server (make-hash-table :test #'equal) emacs-cpp-eglot-watch--table)))

(defun emacs-cpp-eglot-watch--forget (server key)
  "Stop and forget SERVER's watch of directory KEY, for every registration."
  (let ((table (emacs-cpp-eglot-watch--directories server)))
    (when-let* ((entry (gethash key table)))
      ;; The system may have ended it already (`stopped').
      (when (file-notify-valid-p (car entry))
        (file-notify-rm-watch (car entry)))
      (pcase-dolist (`(,id . ,_) (cdr entry))
        (setf (gethash id (eglot--file-watches server))
              (delete key (gethash id (eglot--file-watches server)))))
      (remhash key table))))

(defun emacs-cpp-eglot-watch--dispatch (server key event)
  "Pass file EVENT of SERVER's watched directory KEY to every registration on it.
A `stopped' event (the directory was deleted) forgets the watch."
  (pcase-dolist (`(,id . ,handler)
                 (cdr (gethash key (emacs-cpp-eglot-watch--directories server))))
    (condition-case err
        (funcall handler event)
      (error (eglot--warn "File watch of registration %s on %s: %s"
                          id key (error-message-string err)))))
  (when (eq (nth 1 event) 'stopped)
    (emacs-cpp-eglot-watch--forget server key)))

(defun emacs-cpp-eglot-watch--count ()
  "Count the watched directories of all eglot servers.
Replaces `eglot--count-file-watches'."
  (let ((count 0))
    (maphash (lambda (_project servers)
               (dolist (server servers)
                 (cl-incf count (hash-table-count
                                 (emacs-cpp-eglot-watch--directories server)))))
             eglot--servers-by-project)
    count))

(cl-defun emacs-cpp-eglot-watch--watch-globs
    (server id globs dir in-root
            &aux (project (eglot--project server)) success full
            (watch-count (emacs-cpp-eglot-watch--count)))
  "Watch the files matching GLOBS under DIR for SERVER's registration ID.
Replaces `eglot--watch-globs', whose arguments it takes: GLOBS is a list of
\(COMPILED-GLOB . KIND); DIR nil means the whole project; IN-ROOT says whether
DIR is inside the project root."
  (cl-labels
      ((subdirs-using-project ()
         (delete-dups
          (mapcar #'file-name-directory
                  (project-files project (and dir (list dir))))))
       (subdirs-using-find ()
         (with-temp-buffer
           (call-process find-program nil t nil dir "-type" "d" "-print0")
           (cl-loop initially (goto-char (point-min))
                    for start = (point) while (search-forward "\0" nil t)
                    collect (expand-file-name
                             (buffer-substring-no-properties start (1- (point)))
                             dir))))
       (handle-event (event)
         (pcase-let* ((`(,desc ,action ,file ,file1) event)
                      (action-type (cl-case action
                                     (created 1) (changed 2) (deleted 3)))
                      (action-bit (when action-type
                                    (ash 1 (1- action-type))))
                      (candidate (if dir (file-relative-name file dir) file)))
           (cond
            ((and (memq action '(created changed deleted))
                  (not (eglot--find-buffer-visiting server file))
                  (cl-loop for (compiled . kind) in globs
                           thereis (and (> (logand kind action-bit) 0)
                                        (funcall compiled candidate))))
             (jsonrpc-notify
              server :workspace/didChangeWatchedFiles
              `(:changes ,(vector `(:uri ,(eglot-path-to-uri file)
                                         :type ,action-type))))
             (when (and (eq action 'created) (file-directory-p file))
               (add-watch file)))
            ((eq action 'renamed)
             (handle-event `(,desc deleted ,file))
             (handle-event `(,desc created ,file1))))))
       (add-watch (subdir)
         (let* ((table (emacs-cpp-eglot-watch--directories server))
                (key (directory-file-name subdir))
                (entry (gethash key table)))
           ;; A watch the system ended (its directory deleted) is replaced.
           (when (and entry (not (file-notify-valid-p (car entry))))
             (emacs-cpp-eglot-watch--forget server key)
             (setq entry nil))
           (cond ((or full (not (file-readable-p subdir))))
                 (entry
                  ;; Watched already for another registration: share it.
                  (unless (assoc id (cdr entry))
                    (push (cons id #'handle-event) (cdr entry))
                    (push key (gethash id (eglot--file-watches server)))))
                 ((and eglot-max-file-watches
                       (>= watch-count eglot-max-file-watches))
                  (setq full t)
                  (eglot--warn "Reached `eglot-max-file-watches' limit of %d, \
not watching some directories" eglot-max-file-watches))
                 (t
                  (condition-case err
                      (let ((desc (file-notify-add-watch
                                   subdir '(change)
                                   (lambda (event)
                                     (emacs-cpp-eglot-watch--dispatch
                                      server key event)))))
                        (puthash key (list desc (cons id #'handle-event)) table)
                        (push key (gethash id (eglot--file-watches server)))
                        (cl-incf watch-count))
                    (file-notify-error
                     (setq full t)
                     (eglot--warn "Cannot watch %s: %s, not watching some directories"
                                  subdir (error-message-string err)))))))))
    (let ((subdirs (if (or (null dir) in-root)
                       (subdirs-using-project)
                     (condition-case _ (subdirs-using-find)
                       (error (subdirs-using-project))))))
      (unwind-protect
          (cl-loop for subdir in subdirs do (add-watch subdir)
                   finally (setq success t))
        (unless success
          (eglot-unregister-capability
           server 'workspace/didChangeWatchedFiles id))))))

(defun emacs-cpp-eglot-watch--unregister (unregister server method id &rest args)
  "Around `eglot-unregister-capability' (UNREGISTER with SERVER, METHOD, ID, ARGS).
For file watches: drop registration ID from each directory it shares, and stop
a directory's watch when its last registration goes."
  (if (not (eq method 'workspace/didChangeWatchedFiles))
      (apply unregister server method id args)
    (let ((table (emacs-cpp-eglot-watch--directories server)))
      (dolist (key (gethash id (eglot--file-watches server)))
        (when-let* ((entry (gethash key table)))
          (setcdr entry (assoc-delete-all id (cdr entry)))
          (unless (cdr entry)
            (file-notify-rm-watch (car entry))
            (remhash key table)))))
    (remhash id (eglot--file-watches server))
    (list t "OK")))

(defun emacs-cpp-eglot-watch--on-shutdown (server)
  "Before `eglot--on-shutdown': stop SERVER's watches.
Its own loop then finds no descriptors to remove (the table holds directories)."
  (maphash (lambda (_directory entry)
             (when (file-notify-valid-p (car entry))
               (file-notify-rm-watch (car entry))))
           (emacs-cpp-eglot-watch--directories server))
  (remhash server emacs-cpp-eglot-watch--table)
  (clrhash (eglot--file-watches server)))

(defun emacs-cpp-eglot-watch-enable ()
  "Install the file-watch changes on eglot (D-121).
Signal an error unless eglot is the version they were written against."
  (let ((version (emacs-cpp-eglot-watch--eglot-version)))
    (unless (equal version emacs-cpp-eglot-watch-eglot-version)
      (error "emacs-cpp: lisp/emacs-cpp-eglot-watch.el was written for eglot %s, \
but eglot %s is loaded; check its watch code and update the advice (D-121)"
             emacs-cpp-eglot-watch-eglot-version version)))
  (advice-add 'eglot--watch-globs :override #'emacs-cpp-eglot-watch--watch-globs)
  (advice-add 'eglot--count-file-watches :override #'emacs-cpp-eglot-watch--count)
  (advice-add 'eglot-unregister-capability :around #'emacs-cpp-eglot-watch--unregister)
  (advice-add 'eglot--on-shutdown :before #'emacs-cpp-eglot-watch--on-shutdown))

(defun emacs-cpp-eglot-watch-disable ()
  "Remove the file-watch changes from eglot."
  (advice-remove 'eglot--watch-globs #'emacs-cpp-eglot-watch--watch-globs)
  (advice-remove 'eglot--count-file-watches #'emacs-cpp-eglot-watch--count)
  (advice-remove 'eglot-unregister-capability #'emacs-cpp-eglot-watch--unregister)
  (advice-remove 'eglot--on-shutdown #'emacs-cpp-eglot-watch--on-shutdown))

(provide 'emacs-cpp-eglot-watch)
;;; emacs-cpp-eglot-watch.el ends here
