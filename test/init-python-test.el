;;; init-python-test.el --- Python rides along: mode, language server, debugpy  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests in the shipped profile (T-018, D-045): `.py' files open in
;; `python-ts-mode'; eglot starts ty (D-140, D-182) in a project (git, or
;; pyproject.toml), not for a loose file; `M-.' crosses files and rename changes
;; both; on the Mac ty finds MacPorts' and the user's packages only where the
;; project sets no environment of its own (D-182); dape's `debugpy' stops at a
;; breakpoint and listens on localhost only.  Needs tree-sitter-python, ty,
;; python-debugpy and git.

;;; Code:

(require 'ert)
(require 'init-test)

(defmacro init-python-test--with-dir (files git &rest body)
  "Write FILES (alist NAME . CONTENT) into a temporary `root', `git init' if GIT,
run BODY, then shut down eglot servers and kill the buffers it visited."
  (declare (indent 2))
  `(let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-py" t))))
          (default-directory root)
          (buffers-before (buffer-list)))
     (unwind-protect
         (progn
           (pcase-dolist (`(,name . ,content) ,files)
             (write-region content nil (expand-file-name name root)))
           (when ,git
             (should (eql 0 (call-process "git" nil nil nil "init" "-q"))))
           ,@body)
       (dolist (server (apply #'append (hash-table-values eglot--servers-by-project)))
         (ignore-errors (eglot-shutdown server)))
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (let ((kill-buffer-query-functions nil))
             (kill-buffer buffer))))
       (delete-directory root t))))

(defun init-python-test--visit (file)
  "Visit FILE and run one command loop step; eglot connects from post-command-hook."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer (run-hooks 'post-command-hook))
    buffer))

(defconst init-python-test--files
  '(("a.py" . "def area(width, height):\n    return width * height\n")
    ("b.py" . "from a import area\n\nprint(area(2, 3))\n"))
  "Two modules: a definition and a use in another file.")

(ert-deftest init-python-server-per-platform ()
  "D-140, D-182: ty on both machines, each with the command that installs it; on
the Mac it starts with `python3''s true directory first on PATH (D-182 (p))."
  (init-test--load)
  (should (equal emacs-cpp-default-python-server '("ty" "server")))
  (require 'eglot)
  (let ((contact (cdr (assoc '(python-ts-mode python-mode) eglot-server-programs))))
    (pcase-exhaustive system-type
      ('gnu/linux
       (should (equal emacs-cpp-default-python-server-install "sudo pacman -S ty"))
       (should (equal contact emacs-cpp-default-python-server)))
      ('darwin
       (should (equal emacs-cpp-default-python-server-install
                      "make macos-ports (in the emacs-cpp repository)"))
       (should (functionp contact))
       (let ((dir (file-name-directory (file-truename (executable-find "python3")))))
         (should (equal (funcall contact)
                        `("env" ,(concat "PATH=" (directory-file-name dir) ":"
                                         (getenv "PATH"))
                          "ty" "server"))))))))

(ert-deftest init-python-server-navigates-and-renames ()
  "D-045, D-140: the platform's server crosses files with `M-.' and renames in both."
  (init-test--load)
  (require 'eglot)
  (init-python-test--with-dir init-python-test--files t
    (init-test--recording-diagnostics
      (let ((use (init-python-test--visit (expand-file-name "b.py" root)))
            (eglot-confirm-server-edits nil))
        (with-current-buffer use
          (should (eq major-mode 'python-ts-mode))
          (should (init-test--wait-managed))
          (should (equal (emacs-cpp-go--server-name (eglot-current-server))
                         (car emacs-cpp-default-python-server)))
          ;; pyright answers a rename with null until its first analysis is done,
          ;; which it reports with the file's first diagnostics; ty pulls its
          ;; diagnostics and has analysed the file when it answers.
          (when (equal (car emacs-cpp-default-python-server) "pyright-langserver")
            (should (init-test--wait-diagnostics)))
          ;; M-. on the use reaches the definition in a.py.
          (goto-char (point-min))
          (search-forward "print(area")
          (backward-char 2)
          (let ((items (xref-backend-definitions
                        'eglot (xref-backend-identifier-at-point 'eglot))))
            (should items)
            (should (equal (file-name-nondirectory
                            (xref-location-group (xref-item-location (car items))))
                           "a.py")))
          ;; C-c l r: rename in both files.
          (eglot-rename "surface")
          (should (string-match-p "surface(2, 3)" (buffer-string)))
          (with-current-buffer (find-file-noselect (expand-file-name "a.py" root))
            (should (string-match-p "def surface" (buffer-string)))))))))

(defun init-python-test--revealed (seconds)
  "Wait up to SECONDS for the revealed type flymake shows in this buffer; return it."
  ;; In batch no idle timer starts flymake; eglot then pulls ty's diagnostics.
  (flymake-start)
  (let ((deadline (+ (float-time) seconds)) found)
    (while (and (not found) (< (float-time) deadline))
      (accept-process-output nil 0.2)
      (setq found (seq-some (lambda (diagnostic)
                              (let ((text (flymake-diagnostic-text diagnostic)))
                                (and (string-match "Revealed type: `\\([^`]*\\)`" text)
                                     (match-string 1 text))))
                            (flymake-diagnostics))))
    found))

(ert-deftest init-python-ty-return-type-inference ()
  "D-142: ty infers unannotated return types only in a project whose .dir-locals.el
sets `emacs-cpp-ty-return-type-inference'; the setting reaches ty as its inline
configuration."
  (init-test--load)
  (require 'eglot)
  (let ((source "from typing import reveal_type\n\n\ndef ret():\n    return 1\n\n\nreveal_type(ret())\n"))
    (pcase-dolist (`(,locals ,revealed)
                   '((nil "Unknown")
                     ("((nil . ((emacs-cpp-ty-return-type-inference . t))))\n"
                      "Literal[1]")))
      (init-python-test--with-dir (append `(("main.py" . ,source))
                                          (and locals `((".dir-locals.el" . ,locals))))
          t
        (with-current-buffer (init-python-test--visit (expand-file-name "main.py" root))
          (should (init-test--wait-managed 20))
          (should (equal (init-python-test--revealed 20) revealed)))))))

(defun init-python-test--unresolved (seconds)
  "Return the modules ty cannot resolve in this buffer, sorted, once it reported the
control import `nosuchmodule_control'; `timeout' if it did not within SECONDS."
  (flymake-start)
  (let ((deadline (+ (float-time) seconds)) texts)
    (while (and (not (seq-some (lambda (text) (string-search "nosuchmodule_control" text))
                               texts))
                (< (float-time) deadline))
      (accept-process-output nil 0.2)
      (setq texts (mapcar #'flymake-diagnostic-text (flymake-diagnostics))))
    (if (not (seq-some (lambda (text) (string-search "nosuchmodule_control" text)) texts))
        'timeout
      (sort (delete-dups
             (delq nil (mapcar (lambda (text)
                                 (and (string-match "imported module `\\([^`]+\\)`" text)
                                      (match-string 1 text)))
                               texts)))
            #'string<))))

(defun init-python-test--package (dir name)
  "Make an empty package NAME in DIR."
  (make-directory (expand-file-name name dir) t)
  (write-region "" nil (expand-file-name (concat name "/__init__.py") dir)))

(defun init-python-test--system-package ()
  "Return a package of `python3''s own site-packages (MacPorts' on the Mac)."
  (let ((purelib (car (process-lines "python3" "-c"
                                     "import sysconfig; print(sysconfig.get_paths()['purelib'])"))))
    (seq-find (lambda (name)
                (and (string-match-p "\\`[a-z][a-z0-9]*\\'" name)
                     (file-exists-p (expand-file-name (concat name "/__init__.py") purelib))))
              (directory-files purelib))))

(ert-deftest init-python-ty-package-directories ()
  "D-182: on the Mac ty finds MacPorts' packages (`python3''s true directory first
on its PATH) and the user site-packages, the latter only where the project uses
the base interpreter: not with a .venv, not with its own `python' for ty, not with
`emacs-cpp-ty-user-site-packages' nil in its .dir-locals.el."
  (init-test--load)
  (skip-unless (eq system-type 'darwin))
  ;; It writes a package into the user site-packages: only in a temporary HOME (D-104).
  (skip-unless (not (file-equal-p "~" (concat "~" (user-login-name)))))
  (require 'eglot)
  (let* ((user-site (car (last (process-lines "python3" "-c" "import site; \
print(site.getusersitepackages())"))))
         (system (init-python-test--system-package))
         (source (format "import %s\nimport usersiteonly\nimport nosuchmodule_control\n"
                         system))
         (pinned-cfg (format "home = %s\nversion = %s\ninclude-system-site-packages = false\n"
                             (directory-file-name (emacs-cpp-python--interpreter-dir))
                             (car (process-lines "python3" "-c" "import platform; \
print(platform.python_version())")))))
    (should system)
    (should (string-prefix-p (file-truename (expand-file-name "~")) (file-truename user-site)))
    (init-python-test--package user-site "usersiteonly")
    (setq emacs-cpp-python--user-site 'unknown)
    (unwind-protect
        (pcase-dolist (`(,label ,files ,setup ,expected)
                       `((plain nil nil ("nosuchmodule_control"))
                         (locals ((".dir-locals.el" . "((nil . ((emacs-cpp-ty-user-site-packages . nil))))\n"))
                                 nil ("nosuchmodule_control" "usersiteonly"))
                         (pinned (("pyproject.toml" . "[tool.ty.environment]\npython = \"altenv\"\n"))
                                 (lambda (root)
                                   (let ((site (expand-file-name "altenv/lib/python3.14/site-packages" root)))
                                     (init-python-test--package site "altonly")
                                     (write-region ,pinned-cfg nil (expand-file-name "altenv/pyvenv.cfg" root))))
                                 ,(sort (list system "nosuchmodule_control" "usersiteonly") #'string<))
                         (venv nil
                               (lambda (root)
                                 (should (eql 0 (call-process "python3" nil nil nil "-m" "venv"
                                                              "--without-pip"
                                                              (expand-file-name ".venv" root))))
                                 (init-python-test--package
                                  (car (file-expand-wildcards
                                        (expand-file-name ".venv/lib/python3*/site-packages" root)))
                                  "venvonly"))
                               ,(sort (list system "nosuchmodule_control" "usersiteonly") #'string<))))
          (init-python-test--with-dir (cons `("main.py" . ,(if (memq label '(pinned venv))
                                                              (concat source (format "import %sonly\n"
                                                                                     (if (eq label 'pinned) "alt" "venv")))
                                                            source))
                                            files)
              t
            (when setup (funcall setup root))
            (with-current-buffer (init-python-test--visit (expand-file-name "main.py" root))
              (should (init-test--wait-managed 20))
              (should (equal (cons label (init-python-test--unresolved 30))
                             (cons label expected))))))
      (setq emacs-cpp-python--user-site 'unknown)
      (delete-directory (expand-file-name "usersiteonly" user-site) t))))

(ert-deftest init-python-ty-toml-names-python ()
  "D-182: the line-wise check finds ty's `python' in the forms it knows."
  (init-test--load)
  (let ((file (make-temp-file "emacs-cpp-toml" nil ".toml")))
    (unwind-protect
        (pcase-dolist (`(,parent ,text ,expected)
                       '(("" "[environment]\npython = \".venv2\"\n" t)
                         ("" "environment.python = \"x\"\n" t)
                         ("" "environment = { python = \"x\" }\n" t)
                         ("" "[environment]\nextra-paths = [\"a\"]\n" nil)
                         ("" "[src]\npython = \"x\"\n" nil)
                         ("tool.ty" "[tool.ty.environment]\npython = \"x\"\n" t)
                         ("tool.ty" "[tool.ty]\nenvironment.python = \"x\"\n" t)
                         ("tool.ty" "[project]\nname = \"p\"\n[tool.ty.environment]\nextra-paths = []\n" nil)
                         ("tool.ty" "[tool.other.environment]\npython = \"x\"\n" nil)))
          (write-region text nil file)
          (should (equal (list parent text
                               (and (emacs-cpp-python--toml-names-python-p file parent) t))
                         (list parent text expected))))
      (delete-file file))))

(ert-deftest init-python-eglot-only-in-projects ()
  (init-test--load)
  (require 'eglot)
  ;; A directory with pyproject.toml is a project for Python files, without git.
  (init-python-test--with-dir (cons '("pyproject.toml" . "[project]\nname = \"toy\"\n")
                                    init-python-test--files)
      nil
    (with-current-buffer (init-python-test--visit (expand-file-name "a.py" root))
      (should (init-test--wait-managed))
      (should (equal (directory-file-name (project-root (project-current)))
                     (directory-file-name root)))))
  ;; A loose file: no project, no server.
  (init-python-test--with-dir init-python-test--files nil
    (with-current-buffer (init-python-test--visit (expand-file-name "a.py" root))
      (should (eq major-mode 'python-ts-mode))
      (should-not (eglot-managed-p)))))

(ert-deftest init-python-debugpy-stops-at-a-breakpoint ()
  (init-test--load)
  (require 'dape)
  (should (member "127.0.0.1" (plist-get (alist-get 'debugpy dape-configs) 'command-args)))
  (should-not (member "0.0.0.0" (plist-get (alist-get 'debugpy dape-configs) 'command-args)))
  (should (equal (plist-get (alist-get 'debugpy dape-configs) 'host) "127.0.0.1"))
  (init-python-test--with-dir '(("run.py" . "x = 20\ny = x + 22\nprint(y)\n")) t
    (let ((source (find-file-noselect (expand-file-name "run.py" root)))
          (stops 0)
          (dape-start-hook nil)
          (dape-update-ui-hook nil)
          (dape-display-source-hook nil)
          connection)
      (let ((dape-stopped-hook (list (lambda () (cl-incf stops)))))
        (with-current-buffer source
          (goto-char (point-min))
          (forward-line 1)
          (dape-breakpoint-toggle)
          (dape (let ((default-directory root)) (dape--config-eval 'debugpy nil))))
        (let ((deadline (+ (float-time) 60)))
          (while (and (or (= stops 0) (not (dape--live-connection 'stopped t)))
                      (< (float-time) deadline))
            (accept-process-output nil 0.1)))
        (setq connection (dape--live-connection 'stopped t))
        (should connection)
        ;; Connected to the IPv4 loopback address, not through a name lookup.
        (should (equal (plist-get (process-contact (jsonrpc--process connection) t) :host)
                       "127.0.0.1"))
        (let (done frame result)
          (dape--stack-trace connection (dape--current-thread connection) 20
                             (lambda (&rest _) (setq done t)))
          (while (not done) (accept-process-output nil 0.1))
          (setq frame (car (plist-get (dape--current-thread connection) :stackFrames)))
          (should (equal (plist-get frame :line) 2))
          (dape-request connection :evaluate
                        (list :expression "x * 2" :frameId (plist-get frame :id)
                              :context "watch")
                        (lambda (body error) (setq result (or error body))))
          (let ((deadline (+ (float-time) 30)))
            (while (and (not result) (< (float-time) deadline))
              (accept-process-output nil 0.1)))
          (should (equal (plist-get result :result) "40")))
        (dape-kill connection)
        (let ((deadline (+ (float-time) 30)))
          (while (and (dape--live-connections) (< (float-time) deadline))
            (accept-process-output nil 0.1)))
        (should-not (dape--live-connections))))))

(provide 'init-python-test)
;;; init-python-test.el ends here
