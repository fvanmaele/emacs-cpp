;;; s22-revert-probe.el --- S22 criterion 4 alone: the window after a revert  -*- lexical-binding: t; -*-
(load (expand-file-name "s22.el" (file-name-directory load-file-name)) nil t)
(cancel-function-timers #'s22-start)
(defun s22p-state (tag)
  (with-current-buffer s22-buffer
    (let ((ovs (cl-remove-if-not (lambda (o) (overlay-get o 'display)) (overlays-in (point-min) (point-max)))))
      (s22-log "%s: mode %s roll %s point %d start %d size %d overlays-with-display %d (window %s) shown %S vscroll %s"
               tag major-mode pdf-view-roll-minor-mode (point) (window-start) (buffer-size)
               (length ovs) (and ovs (overlay-get (car ovs) 'window)) (s22-pages-in-window)
               (window-vscroll nil t)))))
(run-at-time 1 nil
  (lambda ()
    (setq s22-log (expand-file-name (or (getenv "S22_PROBE_LOG") "arch-revert-probe.log") s22-dir))
    (copy-file (expand-file-name "test-orig.pdf" s22-src) s22-pdf t)
    (setq s22-buffer (find-file s22-pdf))
    (unless (derived-mode-p (quote pdf-view-mode)) (pdf-view-mode))
    (setq-local pdf-view-display-size 'fit-width)
    (pdf-view-roll-minor-mode 1)
    (run-at-time 1 nil
      (lambda ()
        (with-current-buffer s22-buffer (pdf-roll-goto-page (string-to-number (or (getenv "S22_PAGE") "1"))))
        (redisplay t)
        (s22p-state "before revert")
        (copy-file (expand-file-name "test-new.pdf" s22-src) s22-pdf t)
        (with-current-buffer s22-buffer
          (when (getenv "S22_CLAMP")
            (add-hook 'after-revert-hook
                      (lambda ()
                        (let ((last (pdf-info-number-of-pages)))
                          (when (> (pdf-view-current-page) last)
                            (pdf-roll-goto-page last))))
                      nil t))
          (revert-buffer t t))
        (run-at-time 1 nil (lambda () (s22p-state "revert +1 s")))
        (run-at-time 3 nil (lambda () (s22p-state "revert +3 s")
                             (with-current-buffer s22-buffer (execute-kbd-macro (kbd "C-p")))))
        (run-at-time 4 nil (lambda () (s22p-state "after one C-p")))
        (run-at-time 6 nil (lambda () (s22p-state "revert +6 s") (kill-emacs 0)))))))
