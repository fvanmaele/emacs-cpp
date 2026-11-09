;;; init-go-to-anything-gui-test.el --- M-o's PDF preview, drawn  -*- lexical-binding: t; -*-

;;; Commentary:

;; `make test-gui' (D-199): `M-o' previews a PDF in a side window on the right (D-201).
;; The prompt runs for real: keys reach it from timers, as typed, and each step records
;; the windows while the prompt is open.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)
(require 'init-writing-test)
(require 'init-go-to-anything-test)
(require 'init-writing-gui-test)

(defvar recentf-list)

(defun init-go-gui--layout ()
  "Return the frame's windows as (BUFFER-NAME SIDE PREVIEW-P), left to right.
consult names a previewed file's buffer \" Preview:FILE\"; the prefix is dropped."
  (mapcar (lambda (window)
            (list (string-remove-prefix " Preview:" (buffer-name (window-buffer window)))
                  (window-parameter window 'window-side)
                  (and (window-parameter window 'emacs-cpp-go-pdf-preview) t)))
          (window-list nil 'nomini (frame-first-window))))

(defun init-go-gui--pdf-fits (window)
  "Non-nil when WINDOW shows a PDF page drawn at its width.
The image at the window's start: roll mode's page overlay, or the single page of
a preview, where consult delays the mode hooks that turn roll mode on.  Within
2 px: pdf-view fits a single page 1 px under the window's width."
  (with-current-buffer (window-buffer window)
    (and (eq major-mode 'pdf-view-mode)
         (let ((display (get-char-property (window-start window) 'display window)))
           (and (eq (car-safe display) 'image)
                (<= (abs (- (car (image-size display t (window-frame window)))
                            (window-body-width window t)))
                    2))))))

(defun init-go-gui--run (steps)
  "Open `M-o' and run STEPS 1.2 s apart while it is open; return the records.
A step is a key string, typed into the prompt, or a function, whose value is
recorded.  The prompt's `C-g' quit is caught."
  (let ((records nil)
        (pending steps))
    (cl-labels ((next ()
                  (run-at-time
                   1.2 nil
                   (lambda ()
                     (let ((step (pop pending)))
                       (if (stringp step)
                           (setq unread-command-events
                                 (append unread-command-events
                                         (listify-key-sequence (kbd step))))
                         (push (funcall step) records)))
                     (when pending (next))))))
      (next)
      (condition-case nil
          (call-interactively #'emacs-cpp-go-to-anything)
        (quit nil)))
    (nreverse records)))

(defmacro init-go-gui--with-project (&rest body)
  "Run BODY with `pdf' a 3-page PDF and notes.txt in a temporary git project,
a.cc shown alone in the frame."
  (declare (indent 0))
  `(progn
     (init-test--load)
     (init-go-to-anything-test--with-project
       (let ((pdf (expand-file-name "doc.pdf" root))
             (before (buffer-list))
             ;; Earlier tests' files, gone now, would come first under "Recent File".
             (recentf-list nil))
         (init-writing-test--write-pdf pdf 3)
         (write-region "notes\n" nil (expand-file-name "notes.txt" root))
         (delete-other-windows)
         (switch-to-buffer (current-buffer))
         (unwind-protect
             (progn ,@body)
           (delete-other-windows)
           (init-writing-test--kill-new-buffers before))))))

(ert-deftest init-go-to-anything-gui-pdf-preview-side-window ()
  "A PDF previews on the right, a.cc stays; another candidate and `C-g' remove it."
  (init-go-gui--with-project
    (let* ((side (lambda ()
                   (let ((window (emacs-cpp-go--pdf-side-window)))
                     (list (init-go-gui--layout)
                           (and window (init-go-gui--pdf-fits window))

                           (and window (/ (float (window-total-width window))
                                          (frame-width)))))))
           (records (init-go-gui--run
                     (list "d o c . p d f" side
                           "C-a C-k n o t e s" side
                           "C-a C-k d o c . p d f" side
                           "C-g"))))
      (pcase-let ((`(,pdf-1 ,notes ,pdf-2) records))
        (should (equal (car pdf-1) '(("a.cc" nil nil) ("doc.pdf" right t))))
        (should (cadr pdf-1))
        (should (< 0.35 (nth 2 pdf-1) 0.45))
        (should (equal (car notes) '(("notes.txt" nil nil))))
        ;; The window M-o started from shows a.cc again, not the last text preview.
        (should (equal (car pdf-2) '(("a.cc" nil nil) ("doc.pdf" right t))))
        (should (cadr pdf-2)))
      (should (equal (init-go-gui--layout) '(("a.cc" nil nil)))))))

(ert-deftest init-go-to-anything-gui-pdf-return-opens-as-before ()
  "`RET' on a previewed PDF opens it in the window M-o started from, as without D-201."
  (init-go-gui--with-project
    (init-go-gui--run (list "d o c . p d f" #'ignore "RET"))
    (should (equal (init-go-gui--layout) '(("doc.pdf" nil nil))))
    (let ((window (frame-first-window)))
      (with-current-buffer (window-buffer window)
        (should pdf-view-roll-minor-mode)
        (should (equal buffer-file-name pdf)))
      (init-writing-gui--settle)
      (should (init-go-gui--pdf-fits window)))
    ;; Outside the prompt the rules do nothing.
    (should-not (emacs-cpp-go--pdf-preview-p (current-buffer) nil))
    (should-not (emacs-cpp-go--other-preview-p (current-buffer) nil))))

(ert-deftest init-go-to-anything-gui-pdf-buffer-preview ()
  "An open PDF buffer previews on the right too; after `C-g' it stays open, unshown."
  (init-go-gui--with-project
    (let* ((buffer (find-file-noselect pdf))
           (records (init-go-gui--run (list "d o c . p d f" #'init-go-gui--layout "C-g"))))
      (should (equal (car records) '(("a.cc" nil nil) ("doc.pdf" right t))))
      (should (buffer-live-p buffer))
      (should (equal (init-go-gui--layout) '(("a.cc" nil nil)))))))

(provide 'init-go-to-anything-gui-test)
;;; init-go-to-anything-gui-test.el ends here
