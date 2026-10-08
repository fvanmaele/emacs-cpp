;;; init-python-test.el --- Python rides along: mode, pyright, debugpy  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests in the shipped profile (T-018, D-045): `.py' files open in
;; `python-ts-mode'; eglot starts pyright in a project (git, or pyproject.toml), not
;; for a loose file; `M-.' crosses files and rename changes both; dape's `debugpy'
;; stops at a breakpoint and listens on localhost only.  Needs tree-sitter-python,
;; pyright, python-debugpy and git.

;;; Code:

(require 'ert)
(require 'init-test)

(defmacro init-python-test--with-dir (files git &rest body)
  "Write FILES (alist NAME . CONTENT) into a temporary `root', `git init' if GIT,
run BODY, then shut down eglot servers and kill the buffers it visited."
  (declare (indent 2))
  `(let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-py" t)))
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

(ert-deftest init-python-pyright-navigates-and-renames ()
  (init-test--load)
  (require 'eglot)
  (init-python-test--with-dir init-python-test--files t
    (let ((use (init-python-test--visit (expand-file-name "b.py" root)))
          (eglot-confirm-server-edits nil))
      (with-current-buffer use
        (should (eq major-mode 'python-ts-mode))
        (should (eglot-managed-p))
        (should (equal (car (process-command (jsonrpc--process (eglot-current-server))))
                       "pyright-langserver"))
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
          (should (string-match-p "def surface" (buffer-string))))))))

(ert-deftest init-python-eglot-only-in-projects ()
  (init-test--load)
  (require 'eglot)
  ;; A directory with pyproject.toml is a project for Python files, without git.
  (init-python-test--with-dir (cons '("pyproject.toml" . "[project]\nname = \"toy\"\n")
                                    init-python-test--files)
      nil
    (with-current-buffer (init-python-test--visit (expand-file-name "a.py" root))
      (should (eglot-managed-p))
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
