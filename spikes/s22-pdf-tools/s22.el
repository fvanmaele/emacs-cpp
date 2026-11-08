;;; s22.el --- spike S22: pdf-tools 1.3.0's viewer on a long PDF  -*- lexical-binding: t; -*-

;; Run in a graphical `emacs -Q -l s22.el' (RUN.md).  Every step runs from a timer, so
;; Emacs's own command loop redisplays between steps, as with a person at the keys.
;; Criteria 1 - 4 of RUN.md; the log goes to S22_LOG (default arch-run1.log).

(require 'cl-lib)

(defvar s22-dir (file-name-directory (or load-file-name buffer-file-name)))
(defvar s22-log (expand-file-name (or (getenv "S22_LOG") "arch-run1.log") s22-dir))
(defvar s22-src (expand-file-name "src/" s22-dir))
(defvar s22-pdf (expand-file-name "test.pdf" s22-src))
(defvar s22-buffer nil)
(defvar s22-steps nil "Scroll samples: (page vscroll pages-in-window).")
(defvar s22-failures 0)

(defun s22-log (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (append-to-file (concat line "\n") nil s22-log)))

(defun s22-check (criterion ok fmt &rest args)
  (unless ok (cl-incf s22-failures))
  (s22-log "%s %s: %s" (if ok "PASS" "FAIL") criterion (apply #'format fmt args)))

(add-to-list 'load-path (expand-file-name "pdf-tools/lisp" s22-src))
(add-to-list 'load-path (expand-file-name "tablist" s22-src))
(setq pdf-info-epdfinfo-program (expand-file-name "pdf-tools/server/epdfinfo" s22-src))
(require 'pdf-tools)
(require 'pdf-roll)

(defun s22-pages-in-window ()
  "Pages whose image is at least partly visible in the selected window."
  (let ((start (window-start)) (end (window-end nil t)) pages)
    (dolist (ov (overlays-in start end))
      (when (and (eq (overlay-get ov 'window) (selected-window))
                 (overlay-get ov 'display)
                 (cl-oddp (overlay-start ov))
                 (pos-visible-in-window-p (overlay-start ov) nil t))
        (push (/ (+ (overlay-start ov) 3) 4) pages)))
    (sort (delete-dups pages) #'<)))

(defun s22-page-width (&optional page)
  "Displayed pixel width of PAGE's image in roll mode (default: the current page)."
  (let* ((ov (pdf-roll-page-overlay (or page (pdf-view-current-page))))
         (spec (and ov (overlay-get ov 'display))))
    (and spec (car (image-size (if (eq (car-safe spec) 'image) spec (car (last spec))) t)))))

(defun s22-width-ok (label)
  (let ((page (s22-page-width)) (body (window-body-width nil t)))
    (s22-check "3 fit-width" (and page (<= (abs (- page body)) (* 0.02 body)))
               "%s: page %s px, window body %s px" label page body)))

(defun s22-start ()
  (s22-log "S22 run %s, Emacs %s, epdfinfo %s" (format-time-string "%F %T")
           emacs-version pdf-info-epdfinfo-program)
  ;; 1: the server answers.
  (condition-case err
      (progn (pdf-info-check-epdfinfo)
             (s22-check "1 epdfinfo" t "pdf-info-check-epdfinfo succeeded"))
    (error (s22-check "1 epdfinfo" nil "%S" err)))
  (delete-other-windows)
  (copy-file (expand-file-name "test-orig.pdf" s22-src) s22-pdf t)
  (setq s22-buffer (find-file s22-pdf))
  (unless (derived-mode-p 'pdf-view-mode) (pdf-view-mode))
  (setq-local pdf-view-display-size 'fit-width)
  (pdf-view-roll-minor-mode 1)
  (s22-log "pages %d, frame %sx%s px" (pdf-info-number-of-pages)
           (frame-pixel-width) (frame-pixel-height))
  (run-at-time 1 nil #'s22-fit))

(defun s22-fit ()
  (with-current-buffer s22-buffer
    (s22-width-ok "one window")
    (split-window-right)
    (run-at-time 1 nil
                 (lambda ()
                   (with-current-buffer s22-buffer
                     (s22-width-ok "after split-window-right")
                     (delete-other-windows)
                     (run-at-time 1 nil
                                  (lambda ()
                                    (with-current-buffer s22-buffer
                                      (s22-width-ok "after delete-other-windows")
                                      (pdf-roll-goto-page 1)
                                      (setq s22-steps nil)
                                      (run-at-time 0.5 nil #'s22-scroll)))))))))

(defun s22-scroll ()
  "One C-n per tick until the last page's end or 3000 ticks."
  (with-current-buffer s22-buffer
    (execute-kbd-macro (kbd "C-n"))
    (redisplay t)
    (push (list (pdf-view-current-page) (window-vscroll nil t) (s22-pages-in-window))
          s22-steps)
    (let* ((last (pdf-info-number-of-pages))
           (now (car s22-steps)) (before (cadr s22-steps))
           (stuck (and before (equal (butlast now) (butlast before)))))
      (if (or (and stuck (= (car now) last)) (>= (length s22-steps) 3000))
          (s22-scrolled last)
        (run-at-time 0.01 nil #'s22-scroll)))))

(defun s22-scrolled (last)
  (let* ((steps (reverse s22-steps))
         (pages (delete-dups (mapcar #'car steps)))
         (two (cl-remove-if-not (lambda (s) (>= (length (nth 2 s)) 2)) steps))
         ;; A stop: the same page and vscroll twice in a row before the last page.
         (stops (cl-loop for (a b) on steps while b
                         when (and (equal (butlast a) (butlast b)) (< (car a) last))
                         collect a)))
    (s22-check "2 roll: reaches the end" (equal pages (number-sequence 1 last))
               "%d C-n, pages passed %S of %d" (length steps) pages last)
    (s22-check "2 roll: two pages at a break" (> (length two) 0)
               "%d of %d samples show two pages, e.g. %S" (length two) (length steps)
               (car two))
    (s22-check "2 roll: no stop before the end" (null stops)
               "%d stops %S" (length stops) (seq-take stops 3)))
  (run-at-time 0.5 nil #'s22-revert))

(defun s22-revert ()
  (condition-case err (s22-revert-1)
    (error (s22-check "4 re-export" nil "revert signalled %S" err)
           (s22-log "S22 done: %d failures" s22-failures)
           (kill-emacs 4))))

(defun s22-revert-1 ()
  ;; 4: the file rewritten on disk (5 pages, 1 cm margins), reverted as the export does.
  (let ((start (float-time)))
    (copy-file (expand-file-name "test-new.pdf" s22-src) s22-pdf t)
    (with-current-buffer s22-buffer
      (revert-buffer t t)
      (run-at-time 1 nil
                   (lambda ()
                     (condition-case err
                     (with-current-buffer s22-buffer
                       (redisplay t)
                       (s22-check "4 re-export" (and (= (pdf-info-number-of-pages) 5)
                                                     pdf-view-roll-minor-mode
                                                     (s22-pages-in-window))
                                  "%.2f s: pages %d, roll %s, shown %S"
                                  (- (float-time) start) (pdf-info-number-of-pages)
                                  pdf-view-roll-minor-mode (s22-pages-in-window))
                       (s22-width-ok "after the revert")
                       (s22-log "S22 done: %d failures" s22-failures)
                       (kill-emacs 0))
                     (error (s22-check "4 re-export" nil "after the revert: %S" err)
                            (kill-emacs 4))))))))

(run-at-time 1 nil #'s22-start)
;; Watchdog: a step that fails or hangs ends the run instead of leaving Emacs open.
(run-at-time 240 nil (lambda () (s22-log "S22 watchdog: stopped after 240 s") (kill-emacs 3)))
;;; s22.el ends here
