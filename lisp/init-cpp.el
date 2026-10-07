;;; init-cpp.el --- C++ editing with eglot and clangd  -*- lexical-binding: t; -*-

;;; Commentary:

;; C++ buffers use `c++-ts-mode' on the system tree-sitter grammar (D-008), and eglot
;; starts clangd for them with the active CMake preset's build directory (D-016,
;; D-017, lisp/emacs-cpp-presets.el).  Navigation (M-. M-? M-,), rename, code actions
;; and diagnostics are eglot's; keys beyond these come with the `C-c l' map (T-007).

;;; Code:

(require 'emacs-cpp-presets)

;; Fail loudly (DESIGN 4): without the grammar `c++-ts-mode' cannot work.
(unless (treesit-language-available-p 'cpp)
  (error "emacs-cpp: tree-sitter C++ grammar missing; install tree-sitter-cpp (D-008)"))

(add-to-list 'major-mode-remap-alist '(c++-mode . c++-ts-mode))
;; .h is C++ in the owner's projects, and no C grammar is installed (D-008).
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-ts-mode))

(use-package eglot
  :hook (c++-ts-mode . eglot-ensure)
  :config
  ;; Ahead of eglot's own clangd entry, which starts clangd without a database.
  (add-to-list 'eglot-server-programs
               '(c++-ts-mode . emacs-cpp-presets-clangd-contact))
  ;; No JSON event log (the eglot manual's first performance advice); shut clangd
  ;; down when its last buffer closes.
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t))

(use-package consult-eglot
  :after (consult eglot))

(keymap-global-set "C-c l P" #'emacs-cpp-presets-select)

(provide 'init-cpp)
;;; init-cpp.el ends here
