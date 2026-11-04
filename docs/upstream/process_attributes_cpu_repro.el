;;; process_attributes_cpu_repro.el --- process-attributes CPU times on Apple silicon  -*- lexical-binding: t; -*-
;; emacs -Q --batch -l process_attributes_cpu_repro.el
;; One second of busy work, timed by `current-cpu-time' (clock) and by the `time'
;; (utime + stime) of `process-attributes' for this Emacs.
(let* ((attributes (lambda ()
                     (float-time (alist-get 'time (process-attributes (emacs-pid))))))
       (clock (lambda ()
                (let ((cpu (current-cpu-time))) (/ (float (car cpu)) (cdr cpu)))))
       (attributes0 (funcall attributes))
       (clock0 (funcall clock))
       (end (+ (float-time) 1.0)))
  (while (< (float-time) end))
  (let ((by-clock (- (funcall clock) clock0))
        (by-attributes (- (funcall attributes) attributes0)))
    (message "%s, %s" (car (split-string (emacs-version) "\n")) system-configuration)
    (message "1 s of busy work: current-cpu-time %.3f s, process-attributes %.3f s, ratio %.1f"
             by-clock by-attributes (/ by-clock by-attributes))))
