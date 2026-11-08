;;; init-writing-gui-test.el --- PDFs in pdf-tools, drawn  -*- lexical-binding: t; -*-

;;; Commentary:

;; `make test-gui' (D-199), in the shipped profile: batch Emacs draws nothing, so whether
;; a page is on the screen can be asked only here.  Roll mode reports a drawing failure
;; through `with-demoted-errors', a line in *Messages*, so each test reads those too.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)
(require 'init-writing-test)

(defun init-writing-gui--settle (&optional seconds)
  "Redisplay and let timers and processes run for SECONDS (default 0.5)."
  (let ((deadline (+ (float-time) (or seconds 0.5))))
    (while (< (float-time) deadline)
      (redisplay t)
      (accept-process-output nil 0.05))))

(defun init-writing-gui--image-spec (overlay)
  "Return OVERLAY's image specification, or nil when it draws none."
  (let* ((display (overlay-get overlay 'display))
         (spec (if (eq (car-safe display) 'image) display (car (last display)))))
    (and (eq (car-safe spec) 'image) spec)))

(defun init-writing-gui--drawn-pages (window)
  "Return the pages whose image WINDOW shows, at least partly, in order."
  (with-current-buffer (window-buffer window)
    (let (pages)
      (dolist (overlay (overlays-in (point-min) (point-max)))
        (when (and (eq (overlay-get overlay 'window) window)
                   (init-writing-gui--image-spec overlay)
                   ;; Partly: a page is usually taller than the window.
                   (pos-visible-in-window-p (overlay-start overlay) window t))
          (push (/ (+ (overlay-start overlay) 3) 4) pages)))
      (sort pages #'<))))

(defun init-writing-gui--page-width (window page)
  "Return the pixel width of PAGE's image in WINDOW."
  (with-selected-window window
    (car (image-size (init-writing-gui--image-spec (pdf-roll-page-overlay page window))
                     t))))

(defmacro init-writing-gui--with-pdf (pages &rest body)
  "Run BODY with `pdf' a file of PAGES pages and only a text buffer shown; clean up.
Fails when roll mode logged a drawing error meanwhile."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory
                 (file-truename (make-temp-file "emacs-cpp-gui" t))))
          (pdf (expand-file-name "doc.pdf" root))
          (text (generate-new-buffer "*init-writing-gui*"))
          (before (buffer-list))
          (log-start (with-current-buffer (messages-buffer) (point-max))))
     (ignore pdf)
     (unwind-protect
         (progn
           (init-test--load)
           (init-writing-test--write-pdf pdf ,pages)
           (delete-other-windows)
           (set-window-buffer nil text)
           (select-window (frame-first-window))
           ,@body
           (should-not
            (with-current-buffer (messages-buffer)
              (save-excursion
                (goto-char log-start)
                (and (search-forward "Error in image roll" nil t)
                     (buffer-substring (line-beginning-position)
                                       (line-end-position)))))))
       (delete-other-windows)
       (set-window-buffer nil text)
       (init-writing-test--kill-new-buffers before)
       (kill-buffer text)
       (delete-directory root t))))

(defun init-writing-gui--show (pdf)
  "Visit PDF and show it as the export does: another window, this one stays selected."
  (let ((window (display-buffer (find-file-noselect pdf)
                                '(nil (inhibit-same-window . t)))))
    (init-writing-gui--settle)
    window))

(defun init-writing-gui--goto (window page)
  "Show PAGE in WINDOW as a key there would."
  (with-selected-window window
    (pdf-view-goto-page page window))
  (init-writing-gui--settle))

(ert-deftest init-writing-gui-opens-as-agreed ()
  "A PDF opens in another window in roll mode, drawn at the window's width."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (with-current-buffer (window-buffer window)
        (should (eq major-mode 'pdf-view-mode))
        (should pdf-view-roll-minor-mode)
        (should pdf-links-minor-mode)
        (should pdf-isearch-minor-mode)
        (should (eq pdf-view-display-size 'fit-width)))
      (should (equal (car (init-writing-gui--drawn-pages window)) 1))
      (should (= (init-writing-gui--page-width window 1)
                 (window-body-width window t))))))

(ert-deftest init-writing-gui-refits-on-resize ()
  "Pages follow the window's width when the window is resized (D-199)."
  (init-writing-gui--with-pdf 6
    (let* ((window (init-writing-gui--show pdf))
           (before (window-body-width window t)))
      (with-selected-window window (split-window-right))
      (init-writing-gui--settle)
      (should (< (window-body-width window t) before))
      (should (= (init-writing-gui--page-width window 1)
                 (window-body-width window t))))))

(ert-deftest init-writing-gui-scrolls-across-pages ()
  "`C-n' goes from page 1 into page 2, both shown at the break."
  (init-writing-gui--with-pdf 3
    (let ((window (init-writing-gui--show pdf))
          (both nil))
      (with-selected-window window
        (dotimes (_ 200)
          (unless both
            (execute-kbd-macro (kbd "C-n"))
            (redisplay t)
            (setq both (equal (init-writing-gui--drawn-pages window) '(1 2))))))
      (should both))))

(defun init-writing-gui--scroll-steps (window from command steps redraw)
  "Run COMMAND STEPS times in WINDOW from the top of page FROM; return (PAGE VSCROLL).
REDRAW non-nil: a redraw after each step; nil: none until the last, as when
trackpad events queue under load and Emacs skips redraws while input waits."
  (init-writing-gui--goto window from)
  (with-selected-window window
    (dotimes (_ steps)
      (funcall command 3 window)
      (when redraw (redisplay t))))
  (redisplay t)
  (with-current-buffer (window-buffer window)
    (list (pdf-view-current-page window) (window-vscroll window t))))

(ert-deftest init-writing-gui-scroll-steps-without-redraw ()
  "Steps without a redraw between them end where the same steps with redraws end,
across page breaks, forward and backward (D-200, pdf-tools patch 0001)."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (dolist (case '((1 pdf-roll-scroll-forward) (4 pdf-roll-scroll-backward)))
        (let ((with (init-writing-gui--scroll-steps window (car case) (cadr case) 40 t))
              (without (init-writing-gui--scroll-steps window (car case) (cadr case) 40 nil)))
          ;; 40 steps of 3 lines cross at least one page break.
          (should-not (= (car with) (car case)))
          (should (equal without with)))))))

(defun init-writing-gui--shorten-and-check (pdf window selected revert)
  "PDF, 6 pages, with page 6 in WINDOW, becomes 5 pages; REVERT must leave a page drawn.
SELECTED non-nil: WINDOW is the selected window during the revert."
  (init-writing-gui--goto window 6)
  (should (member 6 (init-writing-gui--drawn-pages window)))
  (init-writing-test--write-pdf pdf 5)
  (with-current-buffer (window-buffer window)
    (if selected
        (with-selected-window window (funcall revert))
      (funcall revert))
    (init-writing-gui--settle 1)
    (should (= (pdf-info-number-of-pages) 5))
    (should pdf-view-roll-minor-mode))
  (should (equal (init-writing-gui--drawn-pages window) '(5))))

(ert-deftest init-writing-gui-clamp-unselected-window ()
  "A shortened PDF in a window not selected keeps a page drawn: the export's case."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (init-writing-gui--shorten-and-check pdf window nil (lambda () (revert-buffer t t))))))

(ert-deftest init-writing-gui-clamp-selected-window ()
  "A shortened PDF in the selected window keeps a page drawn: S22's case."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (init-writing-gui--shorten-and-check pdf window t (lambda () (revert-buffer t t))))))

(ert-deftest init-writing-gui-clamp-as-the-reverter-reverts ()
  "The project reverter's call, modes preserved, keeps a page drawn (D-162)."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (init-writing-gui--shorten-and-check pdf window nil
                                           (lambda () (revert-buffer t t t))))))

(ert-deftest init-writing-gui-clamp-two-windows ()
  "Two windows on the last page both keep a page drawn."
  (init-writing-gui--with-pdf 6
    (let* ((window (init-writing-gui--show pdf))
           (second (with-selected-window window (split-window-below))))
      (init-writing-gui--settle)
      (should (eq (window-buffer second) (window-buffer window)))
      (init-writing-gui--goto second 6)
      (init-writing-gui--shorten-and-check pdf window nil (lambda () (revert-buffer t t)))
      (should (equal (init-writing-gui--drawn-pages second) '(5))))))

(ert-deftest init-writing-gui-clamp-buried-then-shown ()
  "A window that left the PDF on its last page shows a page when it comes back."
  (init-writing-gui--with-pdf 6
    (let* ((window (init-writing-gui--show pdf))
           (buffer (window-buffer window))
           (other (generate-new-buffer "*init-writing-gui-other*")))
      (init-writing-gui--goto window 6)
      (set-window-buffer window other)
      (init-writing-gui--settle)
      (init-writing-test--write-pdf pdf 5)
      (with-current-buffer buffer (revert-buffer t t))
      (set-window-buffer window buffer)
      (init-writing-gui--settle 1)
      (should (equal (init-writing-gui--drawn-pages window) '(5))))))

(ert-deftest init-writing-gui-defect-without-the-clamp ()
  "Without the clamp the window stays blank: when this fails, pdf-tools fixed its
defect and D-192's clamp can go."
  (init-writing-gui--with-pdf 6
    (let ((window (init-writing-gui--show pdf)))
      (init-writing-gui--goto window 6)
      (init-writing-test--write-pdf pdf 5)
      (with-current-buffer (window-buffer window)
        (remove-hook 'after-revert-hook #'emacs-cpp-pdf--clamp-page t)
        (with-selected-window window (revert-buffer t t))
        (init-writing-gui--settle 1))
      (should (null (init-writing-gui--drawn-pages window)))
      ;; The drawing errors are this defect's: not the macro's to fail on here.
      (setq log-start (with-current-buffer (messages-buffer) (point-max))))))

(ert-deftest init-writing-gui-export-shortened ()
  "`C-c C-c x' twice, the second PDF shorter, its last page shown: a page stays drawn."
  (init-test--load)
  (skip-unless (init-writing-test--tools-p))
  (init-writing-test--with-file "A\n\n\\newpage\n\nB\n\n\\newpage\n\nC\n"
    (let ((pdf (expand-file-name "doc.pdf" default-directory)))
      (delete-other-windows)
      (set-window-buffer nil (current-buffer))
      (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf))))
      (init-writing-gui--settle)
      (let* ((buffer (find-buffer-visiting pdf))
             (window (get-buffer-window buffer)))
        (should window)
        (should-not (eq window (selected-window)))
        (with-current-buffer buffer
          (should (eq major-mode 'pdf-view-mode))
          (should pdf-view-roll-minor-mode)
          (should (= (pdf-info-number-of-pages) 3)))
        (init-writing-gui--goto window 3)
        (should (member 3 (init-writing-gui--drawn-pages window)))
        (erase-buffer)
        (insert "A\n\n\\newpage\n\nB\n")
        (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf))))
        (init-writing-gui--settle 1)
        (with-current-buffer buffer
          (should (= (pdf-info-number-of-pages) 2)))
        (should (equal (init-writing-gui--drawn-pages window) '(2)))))))

(provide 'init-writing-gui-test)
;;; init-writing-gui-test.el ends here
