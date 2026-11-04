;;; refresh-first.el --- loaded before s20-run.el: shown refresh ahead of reverts  -*- lexical-binding: t; -*-
;; Spike code, never promoted (S20, D-168 revisited).  The module's step with one
;; change: a queued shown buffer's VC state and marks run before the remaining
;; reverts.  Still one kind of work per step, one timer; every step 0.01 s apart.
(defvar emacs-cpp-reverter--timer)
(defvar emacs-cpp-reverter--busy)
(defvar emacs-cpp-reverter--queue)
(defvar emacs-cpp-reverter--reverts)
(defvar emacs-cpp-reverter-pause)
(defvar emacs-cpp-reverter-step)
(defun rf-step ()
  (setq emacs-cpp-reverter--timer nil)
  (if emacs-cpp-reverter--busy
      (setq emacs-cpp-reverter--timer
            (run-with-timer emacs-cpp-reverter-step nil #'emacs-cpp-reverter--step))
    (unwind-protect
        (let ((emacs-cpp-reverter--busy t))
          (if emacs-cpp-reverter--queue
              (let ((next (car (last emacs-cpp-reverter--queue))))
                (setq emacs-cpp-reverter--queue (butlast emacs-cpp-reverter--queue))
                (when (buffer-live-p next) (emacs-cpp-reverter--refresh next)))
            (when emacs-cpp-reverter--reverts (emacs-cpp-reverter--revert-step))))
      (when (or emacs-cpp-reverter--queue emacs-cpp-reverter--reverts)
        (emacs-cpp-reverter--arm emacs-cpp-reverter-pause)))))
(advice-add 'emacs-cpp-reverter--step :override #'rf-step)
