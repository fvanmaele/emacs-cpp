;;; ready.el --- loaded before s20-run.el: when the module's fswatch starts  -*- lexical-binding: t; -*-
;; Spike code, never promoted (S20, 0120).
(defvar rd-out (getenv "TR_OUT"))
(defvar rd-start nil)
(advice-add 'emacs-cpp-reverter--start :after
            (lambda (&rest _) (unless rd-start (setq rd-start (float-time)))))
(advice-add 's20--emit :before
            (lambda (fmt &rest _)
              (when (and rd-start (string-prefix-p "ready:" fmt))
                (write-region (format "fswatch started %.2f s before the ready line\n"
                                      (- (float-time) rd-start))
                              nil rd-out t 'silent))))
