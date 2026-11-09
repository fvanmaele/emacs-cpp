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

(defun emacs-cpp-markdown--mainfont-p (value)
  "Non-nil when VALUE is a valid `emacs-cpp-markdown-pdf-mainfont'."
  (or (null value) (stringp value)
      (and (proper-list-p value) (= (length value) 4) (seq-every-p #'stringp value))))

(defcustom emacs-cpp-markdown-pdf-mainfont
  '("DejaVuSerif.ttf" "DejaVuSerif-Bold.ttf" "DejaVuSerif-Italic.ttf"
    "DejaVuSerif-BoldItalic.ttf")
  "Main font of `emacs-cpp-markdown-pdf''s text and tables (D-205).
nil: pandoc's default, Latin Modern Roman, which has no Greek letters: rho, theta
in plain text are dropped (a warning names them, D-185).  A string: a font name,
passed as pandoc's `-V mainfont='; an installed family finds its bold and italic
by itself.  A list of four files, regular, bold, italic, bold italic: font files
name no family, so each style is named (`-V mainfontoptions=BoldFont=...'), else
LaTeX substitutes the regular face without a message.  DejaVu Serif ships with
TeX Live, as DejaVu Sans Mono does (D-185)."
  :type '(choice (const :tag "pandoc's default" nil)
                 (string :tag "Font name")
                 (list :tag "Font files" (string :tag "Regular") (string :tag "Bold")
                       (string :tag "Italic") (string :tag "Bold italic")))
  :safe #'emacs-cpp-markdown--mainfont-p
  :group 'tools)

(defun emacs-cpp-markdown--mainfont-args (mainfont)
  "Return pandoc's arguments for MAINFONT, an `emacs-cpp-markdown-pdf-mainfont'."
  (unless (emacs-cpp-markdown--mainfont-p mainfont)
    (error "emacs-cpp: `emacs-cpp-markdown-pdf-mainfont' is %S: nil, a font name \
or four font files (D-205)" mainfont))
  (pcase mainfont
    ('nil nil)
    ((pred stringp) (list "-V" (concat "mainfont=" mainfont)))
    (`(,regular ,bold ,italic ,bold-italic)
     (list "-V" (concat "mainfont=" regular)
           "-V" (concat "mainfontoptions=BoldFont=" bold)
           "-V" (concat "mainfontoptions=ItalicFont=" italic)
           "-V" (concat "mainfontoptions=BoldItalicFont=" bold-italic)))))

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

(defconst emacs-cpp-markdown--pandoc-reader '("-f" "markdown+autolink_bare_uris")
  "How pandoc reads Markdown for the HTML and the PDF: bare URIs become links (D-204).")

(defun emacs-cpp-markdown--check-pandoc ()
  "Signal an error naming the install command when pandoc is not on `exec-path'."
  (unless (executable-find "pandoc")
    (error "emacs-cpp: pandoc is not on exec-path; install: %s (D-184, D-204)"
           emacs-cpp-default-markdown-pdf-install)))

(defun emacs-cpp-markdown--html (begin end buffer)
  "Write the HTML of BEGIN..END into BUFFER through pandoc: `markdown-command' (D-204).
Bare URIs become links; pandoc missing or failing is an error, no other program."
  (emacs-cpp-markdown--check-pandoc)
  (let* ((coding-system-for-write 'utf-8)
         (coding-system-for-read 'utf-8)
         (status (apply #'call-process-region begin end "pandoc" nil (list buffer nil) nil
                        emacs-cpp-markdown--pandoc-reader)))
    (unless (eql 0 status)
      (error "emacs-cpp: pandoc failed (exit %s) writing the HTML (D-204)" status))))

(defun emacs-cpp-markdown--pdf-command (file engine monofont margin &optional mainfont)
  "Return the pandoc command line writing FILE's PDF with ENGINE, MONOFONT, MARGIN,
MAINFONT.  MONOFONT nil: pandoc's default monospace font; MARGIN nil: its default
margins; MAINFONT: see `emacs-cpp-markdown-pdf-mainfont', nil its default."
  (append (list "pandoc" (file-name-nondirectory file))
          emacs-cpp-markdown--pandoc-reader
          (list "-o" (file-name-nondirectory (emacs-cpp-markdown--pdf-file file))
                (concat "--pdf-engine=" engine))
          (and monofont (list "-V" (concat "monofont=" monofont)))
          (and margin (list "-V" (concat "geometry:margin=" margin)))
          (emacs-cpp-markdown--mainfont-args mainfont)))

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

(defun emacs-cpp-markdown--check-tools (engine &optional opener)
  "Signal an error naming the fix when something the export needs is missing:
pandoc and ENGINE, with the install command; then OPENER, the program that opens
the PDF outside Emacs (D-202), or, when OPENER is nil, pdf-tools' server, which
shows it (D-199); all before LaTeX has run."
  (emacs-cpp-markdown--check-pandoc)
  (unless (executable-find engine)
    (error "emacs-cpp: %s is not on exec-path; install: %s (D-184)"
           engine emacs-cpp-default-markdown-pdf-install))
  (if (null opener)
      (emacs-cpp-pdf--check-server)
    (unless (executable-find opener)
      (error "emacs-cpp: %s, which opens the PDF outside Emacs, is not on exec-path \
\(`emacs-cpp-default-pdf-open-command', D-202)" opener))))

(defun emacs-cpp-markdown--show-pdf (pdf)
  "Show PDF in another window, reverting its buffer when it has one.  Return it."
  (let ((buffer (find-buffer-visiting pdf)))
    (if buffer
        (with-current-buffer buffer
          (revert-buffer t t))
      (setq buffer (find-file-noselect pdf)))
    (display-buffer buffer '(nil (inhibit-same-window . t)))
    buffer))

(defun emacs-cpp-markdown--open-pdf (opener pdf)
  "Open PDF with OPENER, outside Emacs (D-202).
Return the opener's process; a non-zero exit is an error-level warning."
  (make-process
   :name "emacs-cpp-pdf-open"
   :buffer nil
   :command (list opener pdf)
   :noquery t
   :sentinel (lambda (process _event)
               (when (and (memq (process-status process) '(exit signal))
                          (not (eql 0 (process-exit-status process))))
                 ;; A warning, not an error: a sentinel's error is only a message
                 ;; in the echo area (and ends a batch Emacs).
                 (display-warning
                  'emacs-cpp
                  (format "%s %s failed (exit %s) (D-202)"
                          opener pdf (process-exit-status process))
                  :error)))))

(defun emacs-cpp-markdown-pdf ()
  "Write this Markdown file's PDF through pandoc and show it in pdf-tools (D-184, D-199).
The PDF goes beside the file, named as it with .pdf; the engine is
`emacs-cpp-markdown-pdf-engine'.  Return the pandoc process."
  (interactive)
  (emacs-cpp-markdown--check-tools emacs-cpp-markdown-pdf-engine)
  (emacs-cpp-markdown--export #'emacs-cpp-markdown--show-pdf))

(defun emacs-cpp-markdown-pdf-open ()
  "Write this Markdown file's PDF as `emacs-cpp-markdown-pdf' does; open it outside Emacs.
The opener is `emacs-cpp-default-pdf-open-command': `open' on the Mac, as Finder
does, `xdg-open' on Arch (D-202).  `markdown-open-command', so on `C-c C-c o'.
Return the pandoc process."
  (interactive)
  ;; Read now: the opener checked is the one pandoc's sentinel calls.
  (let ((opener emacs-cpp-default-pdf-open-command))
    (emacs-cpp-markdown--check-tools emacs-cpp-markdown-pdf-engine opener)
    (emacs-cpp-markdown--export (lambda (pdf) (emacs-cpp-markdown--open-pdf opener pdf)))))

(defun emacs-cpp-markdown--export (show)
  "Start pandoc on this Markdown file's PDF; on success call SHOW with the PDF's name.
The tools are checked by the caller.  Return the pandoc process."
  (let* ((file (or buffer-file-name
                   (user-error "emacs-cpp: this buffer visits no file")))
         (engine emacs-cpp-markdown-pdf-engine)
         (monofont emacs-cpp-markdown-pdf-monofont)
         (mainfont emacs-cpp-markdown-pdf-mainfont)
         (margin emacs-cpp-markdown-pdf-margin)
         (pdf (emacs-cpp-markdown--pdf-file file))
         (output (get-buffer-create emacs-cpp-markdown--pdf-output))
         (default-directory (file-name-directory file)))
    (save-buffer)
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (message "emacs-cpp: pandoc writing %s ..." (file-name-nondirectory pdf))
    (make-process
     :name "emacs-cpp-markdown-pdf"
     :buffer output
     :command (emacs-cpp-markdown--pdf-command file engine monofont margin mainfont)
     :noquery t
     :sentinel (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (emacs-cpp-markdown--pdf-finished
                    (process-exit-status process) file pdf show))))))

(defun emacs-cpp-markdown--pdf-finished (status file pdf &optional show)
  "Call SHOW on PDF when pandoc exited with STATUS 0 on FILE; else show its output,
signal.  SHOW defaults to `emacs-cpp-markdown--show-pdf'.
Characters LaTeX dropped for want of a glyph are a warning naming them (D-185):
pandoc exits 0 and the PDF silently lacks them."
  (if (eql 0 status)
      (let ((missing (emacs-cpp-markdown--missing-characters
                      (with-current-buffer
                          (get-buffer-create emacs-cpp-markdown--pdf-output)
                        (buffer-string)))))
        (prog1 (funcall (or show #'emacs-cpp-markdown--show-pdf) pdf)
          (if (null missing)
              (message "emacs-cpp: wrote %s" pdf)
            (display-warning
             'emacs-cpp
             (format "%s lacks %d characters its fonts have no glyph for: %s; \
see %s, `emacs-cpp-markdown-pdf-mainfont' (text) and \
`emacs-cpp-markdown-pdf-monofont' (code) (D-185, D-205)"
                     pdf (length missing) (string-join missing " ")
                     emacs-cpp-markdown--pdf-output)))))
    (display-buffer (get-buffer-create emacs-cpp-markdown--pdf-output))
    (error "emacs-cpp: pandoc failed (exit %s) on %s; its output is in %s"
           status file emacs-cpp-markdown--pdf-output)))

(use-package markdown-mode
  :custom
  ;; `C-c C-c o': the PDF opened outside Emacs (D-202).
  (markdown-open-command #'emacs-cpp-markdown-pdf-open)
  ;; The HTML of `C-c C-c p', `v', `e' through pandoc only, bare URIs linked (D-204).
  (markdown-command #'emacs-cpp-markdown--html)
  :config
  (keymap-set markdown-mode-command-map "x" #'emacs-cpp-markdown-pdf)
  ;; `C-c C-c p' writes FILE.html beside the file, so relative image paths resolve:
  ;; `markdown-preview' wrote it to a temporary directory (D-203).
  (keymap-set markdown-mode-command-map "p" #'markdown-export-and-preview))

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
