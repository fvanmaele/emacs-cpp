;;; navtime.el --- S8: first M-. after restart, stock vs patched clangd  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S8_ROOT (configured copy), S8_OUT (log), CLANGD (program), FLAGS.
;; Session 1 builds the index (waits for it); session 2, a fresh server with the
;; index on disk, times the first M-. and the first M-? on a library name.
(require 'init-test)
(init-test--load)
(require 'eglot)
(defvar root (file-name-as-directory (getenv "S8_ROOT")))
(defvar out (getenv "S8_OUT"))
(defvar program (getenv "CLANGD"))
(defvar flags (split-string (or (getenv "FLAGS") "") " " t))
(advice-add 'emacs-cpp-presets-clangd-contact :filter-return
            (lambda (contact) (append (list program) (cdr contact) flags)))
(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (round (* 1000 (float-time (time-subtract (current-time) t0)))))
(defun settle (s) (let ((e (+ (float-time) s))) (while (< (float-time) e) (accept-process-output nil 0.5))))
(defun at-library-name ()
  (goto-char (point-min))
  (unless (re-search-forward "\\_<\\(?:dealii\\|std\\)::\\([A-Za-z_]+\\)" nil t)
    (error "no dealii:: or std:: name"))
  (goto-char (match-beginning 1)))
(defun session (n)
  (let* ((t0 (current-time))
         (buffer (find-file-noselect (expand-file-name "src/main.cc" root))))
    (with-current-buffer buffer
      (run-hooks 'post-command-hook)
      (at-library-name)
      (let* ((t1 (current-time))
             (defs (xref-backend-definitions 'eglot (xref-backend-identifier-at-point 'eglot)))
             (d (ms t1))
             (t2 (current-time))
             (refs (xref-backend-references 'eglot (xref-backend-identifier-at-point 'eglot)))
             (r (ms t2)))
        (let ((locations (sort (delete-dups
                                (mapcar (lambda (ref)
                                          (let ((loc (xref-item-location ref)))
                                            (format "%s:%s" (file-relative-name
                                                             (xref-location-group loc) root)
                                                    (xref-location-line loc))))
                                        refs))
                               #'string<)))
          (say "%s %s session %d: first M-. %d ms -> %s; then M-? %d ms (%d refs, %d distinct); %d ms after open"
               (file-name-nondirectory program) (or flags "") n d
               (and defs (file-name-nondirectory (xref-location-group (xref-item-location (car defs)))))
               r (length refs) (length locations) (ms t0))
          (when (= n 2)
            (dolist (location locations) (say "  ref %s" location)))))
      ;; Session 1: let the background index finish before shutting down.
      (when (= n 1) (settle (string-to-number (or (getenv "S8_SETTLE") "120"))))
      (eglot-shutdown (eglot-current-server)))
    (kill-buffer buffer)))
(let ((emacs-cpp-presets-state-file (expand-file-name "s8-state.eld" (file-name-directory out))))
  (session 1)
  (session 2))
