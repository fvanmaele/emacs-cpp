;;; build-packages-test.el --- Tests for scripts/build-packages.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests on a throw-away directory tree; no submodule or network needed.

;;; Code:

(require 'ert)
(require 'build-packages)

(defmacro build-packages-test--with-tree (files &rest body)
  "Create FILES (relative paths) under a temporary root bound to `root', run BODY."
  (declare (indent 1))
  `(let ((root (file-name-as-directory (make-temp-file "build-packages-test" t))))
     (unwind-protect
         (progn
           (dolist (file ,files)
             (let ((abs (expand-file-name file root)))
               (make-directory (file-name-directory abs) t)
               (write-region "" nil abs)))
           ,@body)
       (delete-directory root t))))

(ert-deftest build-packages-parse-keeps-order-and-defaults ()
  (let ((specs (build-packages-parse-config-lines
                '("submodule.magit.path lib/magit"
                  "submodule.magit.url https://example.invalid/magit"
                  "submodule.magit.load-path lisp"
                  "submodule.dash.path lib/dash"
                  "submodule.dash.ignore untracked"
                  "submodule.dash.build-exclude a.el"
                  "submodule.dash.build-exclude b.el"))))
    (should (equal (mapcar (lambda (s) (plist-get s :name)) specs) '("magit" "dash")))
    (should (equal (plist-get (nth 0 specs) :load-path) '("lisp")))
    (should (equal (plist-get (nth 1 specs) :load-path) '(".")))
    (should (equal (plist-get (nth 1 specs) :build-exclude) '("a.el" "b.el")))))

(ert-deftest build-packages-parse-handles-dotted-names ()
  (let ((specs (build-packages-parse-config-lines
                '("submodule.dash.el.path lib/dash"))))
    (should (equal (plist-get (car specs) :name) "dash.el"))))

(ert-deftest build-packages-parse-rejects-unknown-key ()
  (should-error (build-packages-parse-config-lines
                 '("submodule.magit.path lib/magit"
                   "submodule.magit.load_path lisp"))))

(ert-deftest build-packages-parse-rejects-missing-path ()
  (should-error (build-packages-parse-config-lines
                 '("submodule.magit.url https://example.invalid/magit"))))

(ert-deftest build-packages-files-applies-excludes ()
  (build-packages-test--with-tree
      '("lib/p/p.el" "lib/p/p-extra.el" "lib/p/p-tests.el" "lib/p/p-pkg.el"
        "lib/p/.dir-locals.el" "lib/p/sub/deep.el" "lib/p/README")
    (let ((spec (list :name "p" :path "lib/p" :load-path '(".")
                      :build-exclude '("p-extra.el"))))
      (should (equal (mapcar #'file-name-nondirectory
                             (build-packages-files root spec))
                     '("p.el"))))))

(ert-deftest build-packages-missing-directory-is-an-error ()
  (build-packages-test--with-tree '("lib/p/p.el")
    (should-error (build-packages-load-path-dirs
                   root (list :name "p" :path "lib/p" :load-path '("lisp"))))))

(ert-deftest build-packages-stale-exclude-is-an-error ()
  (build-packages-test--with-tree '("lib/p/p.el")
    (should-error (build-packages-excluded-files
                   root (list :name "p" :path "lib/p" :load-path '(".")
                              :build-exclude '("gone.el"))))))

(ert-deftest build-packages-load-path-file-is-relative-and-loadable ()
  (build-packages-test--with-tree '("lib/a/a.el" "lib/b/lisp/b.el")
    (let ((specs (list (list :name "a" :path "lib/a" :load-path '("."))
                       (list :name "b" :path "lib/b" :load-path '("lisp"))))
          (file (expand-file-name "lib/load-path.el" root)))
      (build-packages-write-load-path root specs file)
      (should-not (string-search root (with-temp-buffer
                                        (insert-file-contents file)
                                        (buffer-string))))
      (let ((load-path nil))
        (load file nil t)
        (should (equal load-path
                       (list (expand-file-name "lib/a" root)
                             (expand-file-name "lib/b/lisp" root))))))))

(ert-deftest build-packages-autoloads-use-bare-library-names ()
  (build-packages-test--with-tree '()
    (let ((dir (expand-file-name "lib/p/lisp" root)))
      (make-directory dir t)
      (write-region ";;; p.el  -*- lexical-binding: t; -*-\n;;;###autoload\n(defun p-cmd () (interactive))\n(provide 'p)\n"
                    nil (expand-file-name "p.el" dir))
      (write-region ";;; p-tests.el  -*- lexical-binding: t; -*-\n;;;###autoload\n(defun p-test-cmd ())\n"
                    nil (expand-file-name "p-tests.el" dir))
      (let ((file (expand-file-name "lib/autoloads.el" root)))
        (build-packages-write-autoloads
         root (list (list :name "p" :path "lib/p" :load-path '("lisp"))) file)
        (let ((text (with-temp-buffer (insert-file-contents file) (buffer-string))))
          (should (string-match-p "(autoload 'p-cmd \"p\"" text))
          (should-not (string-match-p "p-test-cmd" text))
          (should-not (file-exists-p (expand-file-name ".build-packages-loaddefs" dir))))))))

(provide 'build-packages-test)
;;; build-packages-test.el ends here
