;;; init-lsp.el --- eglot for every language, and the code commands  -*- lexical-binding: t; -*-

;;; Commentary:

;; eglot's one form (DESIGN 4, principle 3) with what holds for every language
;; server, and the code commands on `C-c l' (D-004, T-007), which which-key lists
;; after a pause.  Each language module names its own server and settings through
;; `emacs-cpp-lsp-server' and `emacs-cpp-lsp-settings' and adds its own keys to
;; `emacs-cpp-code-map' (D-091): clangd in lisp/init-cpp.el, pyright in
;; lisp/init-python.el, texlab in lisp/init-latex.el.

;;; Code:

(defun emacs-cpp-lsp-server (modes contact)
  "Make eglot start CONTACT for buffers in MODES, ahead of its own entries (D-091).
MODES and CONTACT as in `eglot-server-programs'; the latest call wins for a mode."
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs (cons modes contact))))

(defun emacs-cpp-lsp-settings (section settings)
  "Answer the servers that ask for SECTION with the plist SETTINGS (D-091).
Through the default `eglot-workspace-configuration'; a project's .dir-locals.el
can still set its own."
  (with-eval-after-load 'eglot
    (setq-default eglot-workspace-configuration
                  (plist-put (copy-sequence (default-value 'eglot-workspace-configuration))
                             section settings))))

(use-package eglot
  ;; Not autoloaded by eglot; `C-c l' (below) can come before eglot has loaded.
  :commands (eglot-rename eglot-code-actions eglot-format eglot-find-implementation
             eglot-find-declaration eglot-show-call-hierarchy eglot-show-type-hierarchy
             eglot-inlay-hints-mode)
  :config
  ;; RET indents by Emacs's rules (electric indentation, D-062's rules), not by the
  ;; server: on each newline eglot would ask it to format, and clangd then also
  ;; rewrites the line just ended (hand alignment collapsed, `{' moved to its own
  ;; line) (D-065, superseding D-061).
  (add-to-list 'eglot-ignored-server-capabilities :documentOnTypeFormattingProvider)
  ;; No JSON event log (the eglot manual's first performance advice); shut a server
  ;; down when its last buffer closes.
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t
        ;; Library headers reached with M-. (deal.II, Boost) join the project's
        ;; clangd, so M-. keeps working inside them (D-019).
        eglot-extend-to-xref t)
  ;; macOS watches files with kqueue, one file descriptor per directory, and Emacs
  ;; refuses watches beyond 975: pyright asks to watch Python's library and
  ;; site-packages, about 2000 directories, and exits when the request fails.
  ;; Watch only the project, and cap the watches well below 975 (D-054).  At the
  ;; cap eglot also fails the request (pyright then exits too); pyright registers
  ;; three times, so this holds projects up to about 160 directories (O-26).
  (when (eq system-type 'darwin)
    (setq eglot-watch-files-outside-project-root nil
          eglot-max-file-watches 500)))

(use-package flymake
  :commands flymake-show-project-diagnostics)

(use-package consult-eglot
  :after (consult eglot))

(defvar-keymap emacs-cpp-code-map
  :doc "Code commands on `C-c l' (D-004).  Eglot's need a managed buffer.
Language modules add their own (D-091)."
  "r" #'eglot-rename
  "a" #'eglot-code-actions
  "f" #'eglot-format
  "i" #'eglot-find-implementation
  "d" #'eglot-find-declaration
  "h" #'eglot-show-call-hierarchy
  "t" #'eglot-show-type-hierarchy
  "s" #'consult-eglot-symbols
  "e" #'flymake-show-project-diagnostics
  ;; Eglot turns inlay hints on in every managed buffer; this hides / shows them.
  "I" #'eglot-inlay-hints-mode)
(keymap-global-set "C-c l" emacs-cpp-code-map)

(provide 'init-lsp)
;;; init-lsp.el ends here
