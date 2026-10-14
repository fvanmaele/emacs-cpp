;;; init-latex.el --- LaTeX with AUCTeX and texlab  -*- lexical-binding: t; -*-

;;; Commentary:

;; LaTeX rides along like Python and R (D-090): AUCTeX (from GNU ELPA, lib/auctex)
;; edits, texlab through eglot navigates across the files of a project (definitions
;; and references of labels, citations and own commands, symbols in `M-o').
;; `C-c l b' builds through texlab (latexmk) and then shows the line in the PDF
;; viewer (Skim on macOS, zathura on Arch, `emacs-cpp-default-pdf-viewer').
;; `C-c l f' formats the buffer or a region with latexindent (D-101).
;; AUCTeX's own keys are kept.
;; texlab comes from pacman `texlab' on Arch, MacPorts `texlab' on the Mac.

;;; Code:

(require 'init-lsp)

;; texlab, named (D-091): eglot's own entry tries digestif first, which follows no
;; \ref or \cite into other files.  `LaTeX-mode' is AUCTeX's.
(emacs-cpp-lsp-server '(LaTeX-mode bibtex-mode) '("texlab"))
;; After a build (C-c l b) texlab shows the line in the platform's viewer (D-055).
(emacs-cpp-lsp-settings
 :texlab `(:build (:forwardSearchAfter t)
           :forwardSearch (:executable ,(car emacs-cpp-default-pdf-viewer)
                           :args ,(vconcat (cdr emacs-cpp-default-pdf-viewer)))))

(defun emacs-cpp-latex-eglot-ensure ()
  "Start eglot (texlab) for a LaTeX or BibTeX file of a project; not a loose file."
  (when (project-current)
    (eglot-ensure)))

(defconst emacs-cpp-latex-build-status
  '((0 . "done")
    (1 . "done, with errors (see the diagnostics)")
    (2 . "failed: the build program did not run")
    (3 . "cancelled"))
  "texlab's build results, `BuildStatus' (texlab wiki, LSP Internals).")

(defun emacs-cpp-latex-build ()
  "Build the document with texlab, then show this line in the PDF viewer (D-090).
texlab runs latexmk on the project's root document; Emacs stays usable meanwhile
and the result comes in the echo area.  Modified LaTeX and BibTeX buffers are
saved first, asking as `compile' does."
  (interactive)
  (let ((server (and (bound-and-true-p eglot--managed-mode) (eglot-current-server))))
    (unless (and server
                 (plist-get (plist-get (eglot--capabilities server) :experimental)
                            :textDocumentBuild))
      (user-error "emacs-cpp: no texlab here; it builds the LaTeX files of a project (D-090)"))
    (save-some-buffers nil (lambda () (derived-mode-p 'TeX-mode 'bibtex-mode)))
    (let ((name (file-name-nondirectory (buffer-file-name)))
          (start (float-time)))
      (message "LaTeX build of %s..." name)
      ;; texlab's own request (eglot has no command for it); the position is where
      ;; the viewer shows the document afterwards.
      (jsonrpc-async-request
       server :textDocument/build
       `(:textDocument ,(eglot--TextDocumentIdentifier)
         :position ,(eglot--pos-to-lsp-position))
       :timeout 600
       :success-fn
       (lambda (result)
         (message "LaTeX build of %s: %s (%.1f s)" name
                  (alist-get (plist-get result :status) emacs-cpp-latex-build-status
                             (format "unknown status %S" (plist-get result :status)))
                  (- (float-time) start)))
       :error-fn
       (lambda (error) (message "LaTeX build of %s failed: %S" name error))
       :timeout-fn
       (lambda () (message "LaTeX build of %s: no answer from texlab in 600 s" name))))))

(keymap-set emacs-cpp-code-map "b" #'emacs-cpp-latex-build)

(defcustom emacs-cpp-latex-indent-program "latexindent"
  "latexindent, which formats LaTeX buffers and regions (D-101).
It comes with TeX Live (Arch: texlive-binextra) and MacTeX."
  :type 'string
  :group 'tools)

(defvar LaTeX-mode-map)                 ; latex.el, AUCTeX

(defun emacs-cpp-latex-format (&optional beg end)
  "Format the lines of the region with latexindent, else the buffer (D-101).
latexindent always reads the whole buffer; with a region it indents only the
region's lines (`--lines'), as it would when formatting the buffer.  Only what
latexindent changes is replaced, in one undo step."
  (interactive (and (use-region-p) (list (region-beginning) (region-end))))
  (if beg
      (emacs-cpp-latex--indent
       (line-number-at-pos beg)
       ;; A region ending at the start of a line leaves that line out.
       (save-excursion
         (goto-char end)
         (if (and (bolp) (> end beg)) (1- (line-number-at-pos)) (line-number-at-pos))))
    (emacs-cpp-latex--indent)))

(defun emacs-cpp-latex-format-buffer ()
  "Format the whole buffer with latexindent, also with a region (D-101)."
  (interactive)
  (emacs-cpp-latex--indent))

(defun emacs-cpp-latex--indent (&optional first last)
  "Replace the buffer with latexindent's indentation of it.
With FIRST and LAST, latexindent indents only those lines."
  (let* ((program (or (executable-find emacs-cpp-latex-indent-program)
                      (user-error "emacs-cpp: %s not found; it comes with TeX Live \
\(Arch: texlive-binextra) and MacTeX (D-101)" emacs-cpp-latex-indent-program)))
         (directory (make-temp-file "emacs-cpp-latexindent" t))
         (file (expand-file-name "document.tex" directory))
         (errors (expand-file-name "stderr" directory))
         (source (current-buffer))
         (coding-system-for-write 'utf-8-unix)
         (coding-system-for-read 'utf-8-unix))
    (unwind-protect
        (with-temp-buffer
          (let ((output (current-buffer)))
            (with-current-buffer source
              (save-restriction
                (widen)
                (write-region nil nil file nil 'silent)))
            ;; -c: latexindent's log goes to the temporary directory, not the project.
            (let ((status (apply #'call-process program nil (list output errors) nil
                                 "-c" (file-name-as-directory directory)
                                 (append (and first (list (format "--lines=%d-%d" first last)))
                                         (list file)))))
              (unless (eql status 0)
                (user-error "emacs-cpp: latexindent failed (%s): %s" status
                            (with-temp-buffer
                              (insert-file-contents errors)
                              (string-trim (buffer-string))))))
            (with-current-buffer source
              (let ((group (prepare-change-group)))
                (activate-change-group group)
                (save-restriction
                  (widen)
                  ;; Changes only what differs, so point and markers stay.
                  (replace-region-contents (point-min) (point-max) output 5))
                (undo-amalgamate-change-group group)
                (accept-change-group group)))))
      (delete-directory directory t))))

;; AUCTeX (D-090): `.tex' files open in its `LaTeX-mode' (its tex-site.el, loaded
;; through lib/autoloads.el, sends Emacs's own `latex-mode' there).
(use-package tex
  :hook (LaTeX-mode . emacs-cpp-latex-eglot-ensure)
  :config
  ;; `C-c l f' and the menu's Format Buffer run latexindent itself, not texlab:
  ;; texlab cannot format a region, and one program for both keeps them alike
  ;; (D-101).  `LaTeX-mode-map' is defined by latex.el, which loads after tex.el.
  (with-eval-after-load 'latex
    (keymap-set LaTeX-mode-map "<remap> <eglot-format>" #'emacs-cpp-latex-format)
    (keymap-set LaTeX-mode-map "<remap> <eglot-format-buffer>"
                #'emacs-cpp-latex-format-buffer)))

;; Built in: `.bib' files; texlab completes and formats them too.
(use-package bibtex
  :hook (bibtex-mode . emacs-cpp-latex-eglot-ensure))

(provide 'init-latex)
;;; init-latex.el ends here
