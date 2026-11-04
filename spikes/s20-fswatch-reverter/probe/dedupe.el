;;; dedupe.el --- loaded before s20-run.el: one record per path into --handle  -*- lexical-binding: t; -*-
;; Spike code, never promoted (S20, 0120).
(advice-add 'emacs-cpp-reverter--handle :filter-args
            (lambda (args)
              (let ((seen (make-hash-table :test #'equal)) out)
                (dolist (r (nth 2 args))
                  (let ((path (substring r 0 (cl-position ?\s r :from-end t))))
                    (unless (gethash path seen) (puthash path t seen) (push r out))))
                (list (nth 0 args) (nth 1 args) (nreverse out) (nth 3 args)))))
