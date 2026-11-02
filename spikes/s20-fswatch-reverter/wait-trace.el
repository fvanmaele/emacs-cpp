;;; wait-trace.el --- what runs inside S20's slowest accept-process-output calls  -*- lexical-binding: t -*-
;; Spike code (S20 follow-up, O-78), never promoted. Loads s20-run.el unchanged after
;; advising it; writes the 8 slowest waits to TRACE_OUT. S20's environment as run.sh:
;;   S20_ROOT=$TMPDIR/s20-repo S20_MODE=fswatch-queued \
;;   S20_FSWATCH=$HOME/opt/fswatch-no-loss/bin/fswatch S20_OUT=/tmp/out TRACE_OUT=/tmp/trace \
;;   S20_EL=$PWD/spikes/s20-fswatch-reverter/s20-run.el emacs -Q --batch \
;;     -l spikes/s20-fswatch-reverter/wait-trace.el </dev/null
(defvar tw-cur nil "Counters of the current wait: plist.")
(defvar tw-waits nil "Entries (SECONDS PLIST).")
(defun tw--add (key n) (when tw-cur (setq tw-cur (plist-put tw-cur key (+ n (or (plist-get tw-cur key) 0))))))
(advice-add 'accept-process-output :around
            (lambda (fn &rest args)
              (let ((tw-cur (list :timers 0)) (start (float-time)) (gcs gcs-done))
                (prog1 (apply fn args)
                  (push (list (- (float-time) start)
                              (append tw-cur (list :gcs (- gcs-done gcs))))
                        tw-waits)))))
(advice-add 'timer-event-handler :around
            (lambda (fn &rest args)
              (let ((start (float-time)))
                (prog1 (apply fn args)
                  (tw--add :timers 1)
                  (tw--add :timer-s (- (float-time) start))))))
(advice-add 'vc-refresh-state :around
            (lambda (fn &rest args)
              (let ((start (float-time)))
                (prog1 (apply fn args)
                  (tw--add :vc 1)
                  (tw--add :vc-s (- (float-time) start))))))
(advice-add 's20--revert :around
            (lambda (fn &rest args)
              (let ((start (float-time)))
                (prog1 (apply fn args)
                  (tw--add :reverts 1)
                  (tw--add :revert-s (- (float-time) start))))))
(add-hook 'kill-emacs-hook
          (lambda ()
            (let ((s (seq-take (sort (copy-sequence tw-waits) (lambda (x y) (> (car x) (car y)))) 8)))
              (write-region
               (mapconcat (lambda (e)
                            (format "%.3f s %S" (car e)
                                    (mapcar (lambda (v) (if (floatp v) (/ (round (* 1000 v)) 1000.0) v))
                                            (cadr e))))
                          s "\n")
               nil (getenv "TRACE_OUT") nil 'silent))))
(load (getenv "S20_EL") nil t)
