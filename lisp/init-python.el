;;; init-python.el --- Python rides along  -*- lexical-binding: t; -*-

;;; Commentary:

;; Python is not what this configuration is for (DESIGN 2) but rides along (D-045):
;; `python-ts-mode' on the system grammar, the platform's language server through
;; eglot in project files (D-140: ty on Arch, pyright on the Mac), and dape's own
;; `debugpy' configuration (`C-x C-a d debugpy RET' debugs the current file).  On
;; Arch all three come from the packages tree-sitter-python, ty and python-debugpy.
;; The C++ setup is not touched; the debugger's entry is in dape's form
;; (lisp/init-debug.el).

;;; Code:

(require 'init-lsp)

;; Fail loudly (DESIGN 4), as for C++ (D-008).
(unless (treesit-language-available-p 'python)
  (error "emacs-cpp: tree-sitter Python grammar missing; install tree-sitter-python \
\(D-045)"))

;; The platform's server (D-140), named so that another server eglot knows (pylsp,
;; basedpyright) does not take over when installed later (D-091); a missing one
;; stops startup, as the search program does (D-081).
(unless (executable-find (car emacs-cpp-default-python-server))
  (error "emacs-cpp: the Python language server %s is not on exec-path; install it \
with `%s' (D-140)"
         (car emacs-cpp-default-python-server) emacs-cpp-default-python-server-install))
(emacs-cpp-lsp-server '(python-ts-mode python-mode) emacs-cpp-default-python-server)

(defcustom emacs-cpp-ty-return-type-inference nil
  "Non-nil: ty infers the return types of functions without annotations (D-142).
ty's `analysis.return-type-inference' \"always\", off by ty's default and here:
on a large unannotated project the first `M-?' took 12 times as long and the
server 7 times the memory (SymPy, RESEARCH_python_ty 8).  Meant for a project's
.dir-locals.el, ((nil . ((emacs-cpp-ty-return-type-inference . t)))); it
applies when ty starts, or after `M-x eglot-reconnect'.  pyright (the Mac,
D-140) infers return types anyway and does not read it."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

;; Sent as ty's inline configuration, which overrides its configuration files.
(emacs-cpp-lsp-settings
 :ty (lambda ()
       (and emacs-cpp-ty-return-type-inference
            '(:configuration (:analysis (:return-type-inference "always"))))))

(defun emacs-cpp-python-eglot-ensure ()
  "Start eglot for a Python file of a project; not for a loose file.
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
