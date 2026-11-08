;;; init-writing.el --- Markdown and the org journal  -*- lexical-binding: t; -*-

;;; Commentary:

;; The owner's existing packages, carried over (DESIGN 12).  Markdown buffers export to
;; PDF through pandoc and a LaTeX engine on `C-c C-c x' (D-184, DESIGN 12.1).  Math drawn
;; in the buffer is deferred (T-136).  Code spans use a monospace font with Greek and math
;; symbols, and characters LaTeX drops are a warning (D-185); the page margin is 3 cm
;; (D-189).  Every PDF opens in pdf-tools, scrolling continuously, its pages at the
;; window's width (D-199); its server is `make epdfinfo', and without it no PDF opens.

;;; Code:

(require 'cl-lib)

(defvar pdf-info-epdfinfo-program)
(defvar image-mode-winprops-alist)
(defvar pdf-view-roll-minor-mode)
(declare-function image-mode-window-get "image-mode" (prop &optional winprops))
(declare-function image-mode-window-put "image-mode" (prop val &optional winprops))
(declare-function pdf-info-check-epdfinfo "pdf-info" (&optional interactive-p))
(declare-function pdf-info-number-of-pages "pdf-info" (&optional file-or-buffer))
(declare-function pdf-roll-goto-page "pdf-roll" (page &optional window))
(declare-function pdf-tools-enable-minor-modes "pdf-tools" (&optional modes))
(declare-function pdf-view-goto-page "pdf-view" (page &optional window))
(declare-function pdf-view-mode "pdf-view" ())

(defcustom emacs-cpp-markdown-pdf-engine "xelatex"
  "LaTeX engine pandoc uses for `emacs-cpp-markdown-pdf' (D-184).
Passed as pandoc's --pdf-engine; xelatex reads Unicode text and system fonts."
  :type 'string
  :safe #'stringp
  :group 'tools)

(defcustom emacs-cpp-markdown-pdf-monofont "DejaVuSansMono.ttf"
  "Monospace font of code spans and blocks in `emacs-cpp-markdown-pdf' (D-185).
Passed as pandoc's `-V monofont='; nil leaves pandoc's default, Latin Modern
Mono, which has no Greek letters or math symbols: formulas written in code
spans (rho_I = Sigma p_i, in Unicode) lose those characters.  DejaVu Sans
Mono ships with TeX Live; a name with .ttf is looked up as a file there."
  :type '(choice (const :tag "pandoc's default" nil) string)
  :safe (lambda (value) (or (null value) (stringp value)))
  :group 'tools)

(defcustom emacs-cpp-markdown-pdf-margin "3cm"
  "Page margin, all four sides, of `emacs-cpp-markdown-pdf' (D-189).
A TeX length, passed as pandoc's `-V geometry:margin='; nil leaves pandoc's
default (LaTeX's own margins, wider on the sides).  A bad length is a LaTeX
error: the export shows pandoc's output and signals."
  :type '(choice (const :tag "pandoc's default" nil) string)
  :safe (lambda (value) (or (null value) (stringp value)))
  :group 'tools)

(defconst emacs-cpp-markdown--pdf-output "*emacs-cpp-markdown-pdf*"
  "Buffer holding pandoc's output of the last export.")

(defun emacs-cpp-markdown--pdf-file (file)
  "Return the PDF file `emacs-cpp-markdown-pdf' writes for FILE."
  (concat (file-name-sans-extension file) ".pdf"))

(defun emacs-cpp-markdown--pdf-command (file engine monofont margin)
  "Return the pandoc command line writing FILE's PDF with ENGINE, MONOFONT, MARGIN.
MONOFONT nil: pandoc's default monospace font; MARGIN nil: its default margins."
  (append (list "pandoc" (file-name-nondirectory file)
                "-o" (file-name-nondirectory (emacs-cpp-markdown--pdf-file file))
                (concat "--pdf-engine=" engine))
          (and monofont (list "-V" (concat "monofont=" monofont)))
          (and margin (list "-V" (concat "geometry:margin=" margin)))))

(defun emacs-cpp-markdown--missing-characters (output)
  "Return the distinct characters LaTeX reported missing in OUTPUT, in order."
  (let ((start 0)
        found)
    (while (string-match "Missing character: There is no \\(.\\)" output start)
      (setq start (match-end 0))
      (cl-pushnew (match-string 1 output) found :test #'equal))
    (nreverse found)))

(defvar emacs-cpp-pdf--server-checked nil
  "The `pdf-info-epdfinfo-program' that passed the check in this session, or nil.")

(defun emacs-cpp-pdf--check-server ()
  "Signal an error naming `make epdfinfo' unless pdf-tools' server runs (D-199).
Not built, or built against a poppler library since replaced: both only show when
it runs.  A pass holds for the session; a failure is checked again next time, so
that no restart is needed after the build."
  (require 'pdf-info)
  (unless (equal emacs-cpp-pdf--server-checked pdf-info-epdfinfo-program)
    (condition-case err
        (pdf-info-check-epdfinfo)
      (error
       (error "emacs-cpp: pdf-tools' server does not run: %s; run `make epdfinfo' in %s (D-199)"
              (error-message-string err) emacs-cpp-root)))
    (setq emacs-cpp-pdf--server-checked pdf-info-epdfinfo-program)))

(defun emacs-cpp-pdf-view-mode ()
  "`pdf-view-mode' with its server checked first: the mode of every PDF (D-199).
An error here reaches the owner through `normal-mode' as a message over the raw
file, which names the fix."
  (emacs-cpp-pdf--check-server)
  (require 'pdf-tools)
  (pdf-view-mode))

(defun emacs-cpp-pdf--clamp-page ()
  "Move each window past this PDF's new end to its last page (D-192).
After a revert that shortens the document, roll mode draws nothing in a window on
a page that no longer exists until the next key.  Every window that has shown the
buffer counts: it may be the export's window, not selected, or come back later.
Its record of pages drawn goes too: `pdf-roll-initialize' clears only the selected
window's, and undrawing a page that no longer exists stops the redraw."
  (let ((last (pdf-info-number-of-pages)))
    (dolist (window (mapcar #'car image-mode-winprops-alist))
      (when (and (window-live-p window)
                 (> (or (image-mode-window-get 'page window) 1) last))
        (image-mode-window-put 'displayed-pages nil window)
        (if pdf-view-roll-minor-mode
            (pdf-roll-goto-page last window)
          (pdf-view-goto-page last window))))))

(defun emacs-cpp-pdf--setup ()
  "Turn on `pdf-tools-enabled-modes' and the clamp in this PDF buffer (D-192, D-199)."
  (pdf-tools-enable-minor-modes)
  (add-hook 'after-revert-hook #'emacs-cpp-pdf--clamp-page nil t))

(defun emacs-cpp-markdown--check-tools (engine)
  "Signal an error naming the fix when something the export needs is missing:
pandoc and ENGINE, with the install command, or pdf-tools' server, which shows the
PDF, before LaTeX has run (D-199)."
  (dolist (program (list "pandoc" engine))
    (unless (executable-find program)
      (error "emacs-cpp: %s is not on exec-path; install: %s (D-184)"
             program emacs-cpp-default-markdown-pdf-install)))
  (emacs-cpp-pdf--check-server))

(defun emacs-cpp-markdown--show-pdf (pdf)
  "Show PDF in another window, reverting its buffer when it has one.  Return it."
  (let ((buffer (find-buffer-visiting pdf)))
    (if buffer
        (with-current-buffer buffer
          (revert-buffer t t))
      (setq buffer (find-file-noselect pdf)))
    (display-buffer buffer '(nil (inhibit-same-window . t)))
    buffer))

(defun emacs-cpp-markdown-pdf ()
  "Write this Markdown file's PDF through pandoc and show it in pdf-tools (D-184, D-199).
The PDF goes beside the file, named as it with .pdf; the engine is
`emacs-cpp-markdown-pdf-engine'.  Return the pandoc process."
  (interactive)
  (let* ((file (or buffer-file-name
                   (user-error "emacs-cpp: this buffer visits no file")))
         (engine emacs-cpp-markdown-pdf-engine)
         (monofont emacs-cpp-markdown-pdf-monofont)
         (margin emacs-cpp-markdown-pdf-margin)
         (pdf (emacs-cpp-markdown--pdf-file file))
         (output (get-buffer-create emacs-cpp-markdown--pdf-output))
         (default-directory (file-name-directory file)))
    (emacs-cpp-markdown--check-tools engine)
    (save-buffer)
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (message "emacs-cpp: pandoc writing %s ..." (file-name-nondirectory pdf))
    (make-process
     :name "emacs-cpp-markdown-pdf"
     :buffer output
     :command (emacs-cpp-markdown--pdf-command file engine monofont margin)
     :noquery t
     :sentinel (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (emacs-cpp-markdown--pdf-finished
                    (process-exit-status process) file pdf))))))

(defun emacs-cpp-markdown--pdf-finished (status file pdf)
  "Show PDF when pandoc exited with STATUS 0 on FILE; else show its output, signal.
Characters LaTeX dropped for want of a glyph are a warning naming them (D-185):
pandoc exits 0 and the PDF silently lacks them."
  (if (eql 0 status)
      (let ((missing (emacs-cpp-markdown--missing-characters
                      (with-current-buffer
                          (get-buffer-create emacs-cpp-markdown--pdf-output)
                        (buffer-string)))))
        (prog1 (emacs-cpp-markdown--show-pdf pdf)
          (if (null missing)
              (message "emacs-cpp: wrote %s" pdf)
            (display-warning
             'emacs-cpp
             (format "%s lacks %d characters its fonts have no glyph for: %s; \
see %s, and `emacs-cpp-markdown-pdf-monofont' (D-185)"
                     pdf (length missing) (string-join missing " ")
                     emacs-cpp-markdown--pdf-output)))))
    (display-buffer (get-buffer-create emacs-cpp-markdown--pdf-output))
    (error "emacs-cpp: pandoc failed (exit %s) on %s; its output is in %s"
           status file emacs-cpp-markdown--pdf-output)))

(use-package markdown-mode
  :config
  (keymap-set markdown-mode-command-map "x" #'emacs-cpp-markdown-pdf))

;; Not `pdf-tools-install': it rebuilds the server, installs system packages and can fail
;; silently (D-199).  Dark themes add `pdf-view-dark-minor-mode' to the list by themselves.
(use-package pdf-tools
  :mode ("\\.[pP][dD][fF]\\'" . emacs-cpp-pdf-view-mode)
  :magic ("%PDF" . emacs-cpp-pdf-view-mode)
  :hook (pdf-view-mode . emacs-cpp-pdf--setup)
  :custom
  (pdf-info-epdfinfo-program (expand-file-name "lib/pdf-tools/server/epdfinfo" emacs-cpp-root))
  (pdf-view-display-size 'fit-width)
  (pdf-tools-enabled-modes '(pdf-view-roll-minor-mode pdf-links-minor-mode
                             pdf-isearch-minor-mode)))

(use-package org-journal)

(provide 'init-writing)
;;; init-writing.el ends here
