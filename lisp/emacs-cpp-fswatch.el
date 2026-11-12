;;; emacs-cpp-fswatch.el --- The patched fswatch as a process of Emacs  -*- lexical-binding: t; -*-

;;; Commentary:

;; What the two users of the patched fswatch (D-109) share: the reverter
;; (lisp/emacs-cpp-reverter.el, one process per project root) and eglot's file
;; watches (lisp/emacs-cpp-eglot-fswatch.el, one per registration).  The command
;; line, the records of a filter call (NUL-ended `PATH FLAGS', an `Overflow' record
;; when fswatch lost changes), and the end of a process: one that ends unasked is a
;; warning with its status and stderr, never hidden, and nothing restarts it behind
;; the user's back.  Which processes run, and what a record means, stay with the
;; two users.  The program, `emacs-cpp-default-fswatch-program', is checked at
;; startup by init-lsp (`emacs-cpp-fswatch-program-check').

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar emacs-cpp-default-fswatch-program)

(defun emacs-cpp-fswatch-command (real-root latency excludes)
  "Return the fswatch command line watching REAL-ROOT, a true name.
LATENCY: the seconds fswatch gathers events before it writes them (its -l).
EXCLUDES: regexps of paths it does not report (its -e)."
  `(,emacs-cpp-default-fswatch-program
    "-0" "-r" "-x" "--event-flag-separator=," ; NUL-ended records, recursive, flags
    "-l" ,(number-to-string latency)
    "--allow-overflow"                  ; report lost changes, not exit
    ,@(cl-loop for regexp in excludes append (list "-e" regexp))
    ,(directory-file-name real-root)))

(defun emacs-cpp-fswatch-overflow-p (record)
  "Non-nil when RECORD's flags include `Overflow': fswatch lost changes."
  (when-let* ((space (cl-position ?\s record :from-end t)))
    ;; A regexp from the last space on, no list of the flags per record.
    (let ((case-fold-search nil))
      (string-match-p "[ ,]Overflow\\(?:,\\|\\'\\)" record space))))

(defun emacs-cpp-fswatch-filter (handler warn-overflow)
  "Return a process filter that calls HANDLER with each call's records.
HANDLER takes (RECORDS OVERFLOWED): the complete records of the output so far,
without the `Overflow' ones, and whether there was one.  WARN-OVERFLOW is called
without arguments before HANDLER, at most once a minute."
  (let ((pending "")
        (overflow-warned 0))
    (lambda (_process output)
      ;; Records end in NUL; the last piece is the start of one still coming.
      (let* ((pieces (split-string (concat pending output) "\0"))
             (all (butlast pieces))
             (records (cl-remove-if #'emacs-cpp-fswatch-overflow-p all))
             (overflowed (/= (length records) (length all))))
        (setq pending (car (last pieces)))
        (when (and overflowed (> (- (float-time) overflow-warned) 60))
          (setq overflow-warned (float-time))
          (funcall warn-overflow))
        (funcall handler records overflowed)))))

(defun emacs-cpp-fswatch--sentinel (root stderr consequence)
  "Return the sentinel of ROOT's fswatch.
It warns when fswatch ends unasked, naming CONSEQUENCE (what no longer happens and
the command that starts it again), then kills the STDERR buffer."
  (lambda (process event)
    (unless (process-live-p process)
      (unless (process-get process 'emacs-cpp-stopping)
        (let ((text (with-current-buffer stderr (string-trim (buffer-string)))))
          (display-warning
           'emacs-cpp
           (format "fswatch for %s ended (%s)%s; %s"
                   root (string-trim event)
                   (if (string-empty-p text) "" (format ": %s" text))
                   consequence)
           :warning)))
      (when (buffer-live-p stderr) (kill-buffer stderr)))))

(defun emacs-cpp-fswatch-start (name root command filter consequence)
  "Start COMMAND, an fswatch watching ROOT, as the process NAME; return it.
FILTER as `emacs-cpp-fswatch-filter' returns it; CONSEQUENCE for the warning when
it ends unasked.  Its stderr goes to a hidden buffer named after NAME."
  (let ((stderr (generate-new-buffer (format " *%s stderr*" name))))
    (make-process
     :name name
     :command command
     :connection-type 'pipe :noquery t :coding 'utf-8-unix
     :stderr stderr
     :filter filter
     :sentinel (emacs-cpp-fswatch--sentinel root stderr consequence))))

(defun emacs-cpp-fswatch-stop (process)
  "End PROCESS, an fswatch of `emacs-cpp-fswatch-start', without its warning."
  (process-put process 'emacs-cpp-stopping t)
  (when (process-live-p process) (delete-process process)))

(provide 'emacs-cpp-fswatch)
;;; emacs-cpp-fswatch.el ends here
