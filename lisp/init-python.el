;;; init-python.el --- Python rides along  -*- lexical-binding: t; -*-

;;; Commentary:

;; Python is not what this configuration is for (DESIGN 2) but rides along (D-045):
;; `python-ts-mode' on the system grammar, ty through eglot in project files (D-140,
;; D-182), and dape's own `debugpy' configuration (`C-x C-a d debugpy RET' debugs
;; the current file).  On Arch all three come from the packages tree-sitter-python,
;; ty and python-debugpy; on the Mac ty from the local port (D-180).
;;
;; On the Mac ty misses two package directories (RESEARCH_python_ty 4d): it takes
;; MacPorts' `python3', a symlink into the framework, for an interpreter under
;; /opt/local and drops it, and it never searches the user site-packages (`pip
;; install --user').  So ty starts with the directory of `python3''s true name
;; first on its PATH, where its own discovery finds it only when a project sets no
;; environment of its own, and gets the user site-packages as an extra path only
;; when it uses that interpreter (D-182).
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

(defun emacs-cpp-python--interpreter-dir ()
  "Return the directory of `python3''s true name, or nil without a `python3'.
MacPorts: /opt/local/bin/python3 -> .../Python.framework/Versions/3.14/bin/."
  (when-let* ((python (executable-find "python3")))
    (file-name-directory (file-truename python))))

(defun emacs-cpp-python--server-contact (&optional _interactive)
  "The Python server's command; on the Mac with `python3''s true directory first on
PATH, through `env' (D-182 (p)).  Called by eglot each time it starts the server."
  (let ((dir (and (eq system-type 'darwin) (emacs-cpp-python--interpreter-dir))))
    (if (and dir (not (equal (file-name-directory (executable-find "python3")) dir)))
        `("env" ,(concat "PATH=" (directory-file-name dir) path-separator (getenv "PATH"))
          ,@emacs-cpp-default-python-server)
      emacs-cpp-default-python-server)))

(emacs-cpp-lsp-server '(python-ts-mode python-mode)
                      (if (eq system-type 'darwin)
                          #'emacs-cpp-python--server-contact
                        emacs-cpp-default-python-server))

(defcustom emacs-cpp-ty-return-type-inference nil
  "Non-nil: ty infers the return types of functions without annotations (D-142).
ty's `analysis.return-type-inference' \"always\", off by ty's default and here:
on a large unannotated project the first `M-?' took 12 times as long and the
server 7 times the memory (SymPy, RESEARCH_python_ty 8).  Meant for a project's
.dir-locals.el, ((nil . ((emacs-cpp-ty-return-type-inference . t)))); it
applies when ty starts, or after `M-x eglot-reconnect'."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

(defcustom emacs-cpp-ty-user-site-packages t
  "Non-nil: on the Mac ty also searches Python's user site-packages (D-182 (u)).
Only when ty uses the base interpreter, as Python does: the project has no .venv
in its root, VIRTUAL_ENV and CONDA_PREFIX are unset, its ty.toml or
pyproject.toml names no `python' for ty's environment, and Python reports
`site.ENABLE_USER_SITE'.  For a project that should not see them, its
.dir-locals.el, ((nil . ((emacs-cpp-ty-user-site-packages . nil)))); it applies
when ty starts, or after `M-x eglot-reconnect'."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

(defvar emacs-cpp-python--user-site 'unknown
  "The user site-packages directory Python reports, nil for none; `unknown' until
asked, once per session (one `python3' run, about 21 ms, RESEARCH_python_ty 4e).")

(defun emacs-cpp-python--user-site ()
  "Return Python's user site-packages directory if Python enables it and it exists."
  (when (eq emacs-cpp-python--user-site 'unknown)
    (setq emacs-cpp-python--user-site
          (when (executable-find "python3")
            (pcase (process-lines "python3" "-c" "import site; \
print(site.ENABLE_USER_SITE); print(site.getusersitepackages())")
              (`("True" ,dir) (and (file-directory-p dir) (file-name-as-directory dir)))))))
  emacs-cpp-python--user-site)

(defun emacs-cpp-python--toml-names-python-p (file section)
  "Non-nil if TOML FILE sets `python' in table SECTION (\"environment\" for ty.toml,
\"tool.ty.environment\" for pyproject.toml).  A line-wise check: a `python' key
under [SECTION], a dotted `environment.python' key under the parent table, or an
inline table `environment = { ... python ... }' there.  Other forms are missed
\(D-182)."
  (when (file-readable-p file)
    (let* ((parent (string-remove-suffix "environment"
                                         (string-remove-suffix ".environment" section)))
           (table "") found)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (and (not found) (not (eobp)))
          (let ((line (string-trim (buffer-substring (line-beginning-position)
                                                     (line-end-position)))))
            (cond
             ((string-match "\\`\\[\\([^]]+\\)\\]" line)
              (setq table (string-trim (match-string 1 line))))
             ((and (equal table section) (string-match-p "\\`python[ \t]*=" line))
              (setq found t))
             ((and (equal table parent)
                   (or (string-match-p "\\`environment\\.python[ \t]*=" line)
                       (string-match-p "\\`environment[ \t]*=[ \t]*{.*\\_<python[ \t]*=" line)))
              (setq found t))))
          (forward-line 1)))
      found)))

(defun emacs-cpp-python--user-site-for-ty ()
  "Return the user site-packages to send ty, or nil (D-182 (u)).
Called in a buffer of the project, its directory variables applied."
  (when-let* (((eq system-type 'darwin))
              (emacs-cpp-ty-user-site-packages)
              ((not (getenv "VIRTUAL_ENV")))
              ((not (getenv "CONDA_PREFIX")))
              (project (project-current))
              (root (expand-file-name (project-root project)))
              ((not (file-directory-p (expand-file-name ".venv" root))))
              ((not (emacs-cpp-python--toml-names-python-p
                     (expand-file-name "ty.toml" root) "environment")))
              ((not (emacs-cpp-python--toml-names-python-p
                     (expand-file-name "pyproject.toml" root) "tool.ty.environment"))))
    (emacs-cpp-python--user-site)))

;; Sent as ty's inline configuration, which overrides its configuration files;
;; `extra-paths' adds to a project's own list (RESEARCH_python_ty 4e).
(emacs-cpp-lsp-settings
 :ty (lambda ()
       (let ((analysis (and emacs-cpp-ty-return-type-inference
                            '(:return-type-inference "always")))
             (user-site (emacs-cpp-python--user-site-for-ty)))
         (when (or analysis user-site)
           `(:configuration
             (,@(and analysis `(:analysis ,analysis))
              ,@(and user-site
                     `(:environment (:extra-paths ,(vector (directory-file-name user-site)))))))))))

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
