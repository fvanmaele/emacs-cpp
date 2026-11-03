;;; wiring.el --- S20: window change functions on show  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-153, criterion 7).  Runs in a terminal Emacs
;; (`wiring.sh'): batch Emacs runs no window change functions.  Each action runs from
;; a timer and is checked from the next one, so the command loop redisplays in
;; between, as after a command.  Writes one line per action to S20_OUT, then exits.

(require 'cl-lib)
(require 'xref)

(defvar wiring-out (or (getenv "S20_OUT") (error "wiring: S20_OUT is not set")))
(defvar wiring-seen nil "Frames `window-buffer-change-functions' ran for since the action.")
(defvar wiring-files
  (let ((dir (make-temp-file "s20-wiring" t)))
    (mapcar (lambda (n)
              (let ((file (expand-file-name (format "f%d.cc" n) dir)))
                (write-region (format "// wiring %d\n" n) nil file nil 'silent)
                file))
            '(1 2 3 4))))
(defvar wiring-buffers (mapcar #'find-file-noselect wiring-files))

(defun wiring--emit (fmt &rest args)
  (write-region (concat (apply #'format fmt args) "\n") nil wiring-out t 'silent))

(defvar wiring-actions
  (list
   (cons "(control, expect NOT RUN) a message, no window change"
         (lambda () (message "wiring")))
   (cons "switch-to-buffer"
         (lambda () (switch-to-buffer (nth 0 wiring-buffers))))
   (cons "pop-to-buffer into another window"
         (lambda () (pop-to-buffer (nth 1 wiring-buffers) t)))
   (cons "xref-pop-to-location"
         (lambda ()
           (xref-pop-to-location
            (xref-make "wiring" (xref-make-file-location (nth 2 wiring-files) 1 0)))))
   (cons "(setup, not judged) tab-bar-new-tab showing another buffer"
         (lambda ()
           (tab-bar-mode 1)
           (tab-bar-new-tab)
           (switch-to-buffer (nth 3 wiring-buffers))))
   (cons "tab-bar-switch-to-tab"
         (lambda ()
           (tab-bar-switch-to-tab
            (alist-get 'name (car (funcall tab-bar-tabs-function))))))))

(defun wiring--step (actions)
  "Run the first of ACTIONS; check it and run the rest from later timers."
  (if (null actions)
      (kill-emacs 0)
    (setq wiring-seen nil)
    (condition-case err
        (funcall (cdar actions))
      ;; A timer's error only reaches the echo area; record it, then exit.
      (error (wiring--emit "%s: error %S" (caar actions) err) (kill-emacs 3)))
    (run-with-timer
     0.3 nil
     (lambda ()
       (wiring--emit "%s: %s" (caar actions) (if wiring-seen "runs" "NOT RUN"))
       (wiring--step (cdr actions))))))

(add-hook 'window-buffer-change-functions (lambda (frame) (push frame wiring-seen)))
;; Never wait forever on a prompt (C-11).
(run-with-timer 20 nil (lambda () (wiring--emit "timeout") (kill-emacs 2)))
(run-with-timer 0.5 nil #'wiring--step wiring-actions)

;;; wiring.el ends here
