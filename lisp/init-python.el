;;; init-python.el --- Python rides along  -*- lexical-binding: t; -*-

;;; Commentary:

;; Python is not what this configuration is for (DESIGN 2) but rides along (D-045):
;; `python-ts-mode' on the system grammar, pyright through eglot in project files,
;; and dape's own `debugpy' configuration (`C-x C-a d debugpy RET' debugs the current
;; file).  All three come from the Arch packages tree-sitter-python, pyright and
;; python-debugpy.  The C++ setup is not touched; eglot's pyright entry is in eglot's
;; form (lisp/init-cpp.el), the debugger's in dape's (lisp/init-debug.el).

;;; Code:

;; Fail loudly (DESIGN 4), as for C++ (D-008).
(unless (treesit-language-available-p 'python)
  (error "emacs-cpp: tree-sitter Python grammar missing; install tree-sitter-python \
\(D-045)"))

(defun emacs-cpp-python-eglot-ensure ()
  "Start eglot (pyright) for a Python file of a project; not for a loose file.
A project is what projectile finds: a git repository, else a directory with
pyproject.toml, setup.py or another of its markers."
  (when (project-current)
    (eglot-ensure)))

(use-package python
  :init
  (add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode))
  (add-hook 'python-ts-mode-hook #'emacs-cpp-python-eglot-ensure))

(provide 'init-python)
;;; init-python.el ends here
