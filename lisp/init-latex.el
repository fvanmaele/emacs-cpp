;;; init-latex.el --- LaTeX with AUCTeX and texlab  -*- lexical-binding: t; -*-

;;; Commentary:

;; LaTeX rides along like Python and R (D-090): AUCTeX (from GNU ELPA, lib/auctex)
;; edits, texlab through eglot navigates across the files of a project (definitions
;; and references of labels, citations and own commands, symbols in `M-o').
;; `C-c l b' builds through texlab (latexmk) and then shows the line in the PDF
;; viewer (Skim on macOS, zathura on Arch, `emacs-cpp-default-pdf-viewer').
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

;; AUCTeX (D-090): `.tex' files open in its `LaTeX-mode' (its tex-site.el, loaded
;; through lib/autoloads.el, sends Emacs's own `latex-mode' there).
(use-package tex
  :hook (LaTeX-mode . emacs-cpp-latex-eglot-ensure))

;; Built in: `.bib' files; texlab completes and formats them too.
(use-package bibtex
  :hook (bibtex-mode . emacs-cpp-latex-eglot-ensure))

(provide 'init-latex)
;;; init-latex.el ends here
