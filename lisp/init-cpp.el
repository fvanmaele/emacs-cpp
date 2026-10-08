;;; init-cpp.el --- C++ editing with eglot and clangd  -*- lexical-binding: t; -*-

;;; Commentary:

;; C++ buffers use `c++-ts-mode' on the system tree-sitter grammar (D-008), and eglot
;; starts clangd for them with the active CMake preset's build directory (D-016,
;; D-017, lisp/emacs-cpp-presets.el).  Navigation (M-. M-? M-,), rename, code actions
;; and diagnostics are eglot's; the rest of the code commands are on `C-c l' (D-004,
;; T-007), which which-key lists after a pause.

;;; Code:

(require 'emacs-cpp-presets)

;; Fail loudly (DESIGN 4): without the grammar `c++-ts-mode' cannot work.
(unless (treesit-language-available-p 'cpp)
  (error "emacs-cpp: tree-sitter C++ grammar missing; install tree-sitter-cpp (D-008)"))

(add-to-list 'major-mode-remap-alist '(c++-mode . c++-ts-mode))
;; .h is C++ in the owner's projects, and no C grammar is installed (D-008).
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-ts-mode))

;; Only files of preset projects start eglot (D-005, D-019).
(add-hook 'c++-ts-mode-hook #'emacs-cpp-presets-eglot-ensure)

(use-package eglot
  ;; Not autoloaded by eglot; `C-c l' (below) can come before eglot has loaded.
  :commands (eglot-rename eglot-code-actions eglot-format eglot-find-implementation
             eglot-find-declaration eglot-show-call-hierarchy eglot-show-type-hierarchy
             eglot-inlay-hints-mode)
  :config
  ;; Ahead of eglot's own clangd entry, which starts clangd without a database.
  (add-to-list 'eglot-server-programs
               '(c++-ts-mode . emacs-cpp-presets-clangd-contact))
  ;; No JSON event log (the eglot manual's first performance advice); shut clangd
  ;; down when its last buffer closes.
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t
        ;; Library headers reached with M-. (deal.II, Boost) join the project's
        ;; clangd, so M-. keeps working inside them (D-019).
        eglot-extend-to-xref t))

(use-package flymake
  :commands flymake-show-project-diagnostics)

(use-package consult-eglot
  :after (consult eglot))

(defvar-keymap emacs-cpp-code-map
  :doc "Code commands on `C-c l' (D-004).  Eglot's need a managed buffer."
  "r" #'eglot-rename
  "a" #'eglot-code-actions
  "f" #'eglot-format
  "i" #'eglot-find-implementation
  "d" #'eglot-find-declaration
  "h" #'eglot-show-call-hierarchy
  "t" #'eglot-show-type-hierarchy
  ;; By name across the project: RMO keeps headers in include/rmo/, sources in src/.
  "o" #'projectile-find-other-file
  "s" #'consult-eglot-symbols
  "e" #'flymake-show-project-diagnostics
  ;; Eglot turns inlay hints on in every managed buffer; this hides / shows them.
  "I" #'eglot-inlay-hints-mode
  "P" #'emacs-cpp-presets-select)
(keymap-global-set "C-c l" emacs-cpp-code-map)

(provide 'init-cpp)
;;; init-cpp.el ends here
