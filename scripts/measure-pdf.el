;;; measure-pdf.el --- Time pdf-tools on a long PDF  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by scripts/measure-pdf.sh (T-142, D-199) in a graphical Emacs: the shipped
;; profile opens MEASURE_PDF in another window, as the export does, and times the first
;; page drawn, `C-n' line by line, a jump to the middle and a revert.  Each step runs in
;; Emacs with redisplay forced, so a time includes the drawing it caused.  Exit 0, or 2
;; on an error, 3 on the watchdog: never a graphical Emacs left open.

;;; Code:

(require 'cl-lib)
(require 'init-test)

(defun measure-pdf--log (format-string &rest args)
  "Append a line made of FORMAT-STRING and ARGS to MEASURE_LOG."
  (append-to-file (concat (apply #'format format-string args) "\n") nil
                  (getenv "MEASURE_LOG")))

(defun measure-pdf--time (function)
  "Call FUNCTION, redisplay, and return the milliseconds taken."
  (let ((start (float-time)))
    (funcall function)
    (redisplay t)
    (* 1000 (- (float-time) start))))

(defun measure-pdf--drawn-p (window page)
  "Non-nil when PAGE's image is drawn in WINDOW."
  (with-current-buffer (window-buffer window)
    (let* ((overlay (pdf-roll-page-overlay page window))
           (display (and overlay (overlay-get overlay 'display))))
      (eq (car-safe (if (eq (car-safe display) 'image) display (car (last display))))
          'image))))

(defun measure-pdf--wait-drawn (window page)
  "Redisplay until PAGE is drawn in WINDOW, at most 30 s; signal when it is not."
  (let ((deadline (+ (float-time) 30)))
    (while (and (not (measure-pdf--drawn-p window page)) (< (float-time) deadline))
      (redisplay t)
      (accept-process-output nil 0.005))
    (unless (measure-pdf--drawn-p window page)
      (error "Page %d not drawn after 30 s" page))))

(defun measure-pdf--run ()
  "Run the measurements and exit."
  (condition-case err
      (let* ((pdf (getenv "MEASURE_PDF"))
             (text (generate-new-buffer "*measure-pdf*"))
             buffer window)
        (init-test--load)
        (measure-pdf--log "measure-pdf %s, Emacs %s, %s, frame %sx%s px"
                          (format-time-string "%F %T") emacs-version system-type
                          (frame-pixel-width) (frame-pixel-height))
        (delete-other-windows)
        (set-window-buffer nil text)
        (let ((start (float-time)))
          (setq buffer (find-file-noselect pdf))
          (measure-pdf--log "visit (loads pdf-tools, checks the server): %.0f ms"
                            (* 1000 (- (float-time) start)))
          (setq window (display-buffer buffer '(nil (inhibit-same-window . t))))
          (measure-pdf--wait-drawn window 1)
          (measure-pdf--log "first page drawn, from the visit's start: %.0f ms"
                            (* 1000 (- (float-time) start))))
        (with-current-buffer buffer
          (measure-pdf--log "pages %d, buffer %d characters, %d overlays"
                            (pdf-info-number-of-pages) (buffer-size)
                            (length (overlays-in (point-min) (point-max)))))
        (with-selected-window window
          (let ((times (cl-loop repeat 300
                                collect (measure-pdf--time
                                         (lambda () (execute-kbd-macro (kbd "C-n")))))))
            (measure-pdf--log "300 C-n: mean %.1f ms, median %.1f ms, slowest %.1f ms, reached page %d"
                              (/ (apply #'+ times) (length times))
                              (nth 150 (sort (copy-sequence times) #'<))
                              (apply #'max times)
                              (image-mode-window-get 'page window)))
          (measure-pdf--log "jump to page 500: %.0f ms"
                            (measure-pdf--time
                             (lambda ()
                               (pdf-view-goto-page 500 window)
                               (measure-pdf--wait-drawn window 500)))))
        (with-current-buffer buffer
          (let ((start (float-time)))
            (revert-buffer t t)
            (measure-pdf--wait-drawn window 500)
            (measure-pdf--log "revert, page 500 drawn again: %.0f ms"
                              (* 1000 (- (float-time) start)))))
        (kill-emacs 0))
    (error (measure-pdf--log "measure-pdf error: %s" (error-message-string err))
           (kill-emacs 2))))

(run-at-time 240 nil (lambda ()
                       (measure-pdf--log "measure-pdf: watchdog, stopped after 240 s")
                       (kill-emacs 3)))
(run-at-time 0.5 nil #'measure-pdf--run)

(provide 'measure-pdf)
;;; measure-pdf.el ends here
