;;; gui-test-run.el --- Run test/gui/ in this graphical Emacs  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by `make test-gui' (D-199): runs the ERT tests of this directory, which need
;; pages drawn, writes *Messages* to EMACS_CPP_GUI_TEST_LOG and exits: 0 when all pass, 1
;; when one fails, 2 when the run could not start, 3 on the watchdog.  An error here must
;; not leave a graphical Emacs open and idle, with make waiting on it.

;;; Code:

(require 'ert)

(setq message-log-max t)

(defun gui-test-run--finish (code)
  "Write *Messages* to the log and exit Emacs with CODE."
  (with-current-buffer (messages-buffer)
    (write-region nil nil (getenv "EMACS_CPP_GUI_TEST_LOG") nil 'no-message))
  (kill-emacs code))

(defun gui-test-run ()
  "Run the tests of test/gui/ and exit."
  (condition-case err
      (progn
        (unless (display-graphic-p)
          (error "make test-gui: this Emacs is not graphical"))
        (when (file-equal-p "~" (concat "~" (user-login-name)))
          (error "make test-gui: HOME is the real home, %s (D-104)"
                 (expand-file-name "~")))
        (dolist (file (directory-files (expand-file-name "test/gui") t "-test\\.el\\'"))
          (load file nil t))
        ;; Only these: the batch tests are loaded too, for their helpers.
        (let ((stats (ert-run-tests-batch "-gui-")))
          (gui-test-run--finish (if (zerop (ert-stats-completed-unexpected stats)) 0 1))))
    (error (message "make test-gui: %s" (error-message-string err))
           (gui-test-run--finish 2))))

(run-at-time 300 nil (lambda ()
                       (message "make test-gui: watchdog, stopped after 300 s")
                       (gui-test-run--finish 3)))
;; From a timer: the frame is up and Emacs is in its command loop.
(run-at-time 0.5 nil #'gui-test-run)

(provide 'gui-test-run)
;;; gui-test-run.el ends here
