;;; build-packages-test.el --- Tests for scripts/build-packages.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests on a throw-away directory tree; no submodule or network needed.

;;; Code:

(require 'ert)
(require 'build-packages)

(defmacro build-packages-test--with-tree (files &rest body)
  "Create FILES (relative paths) under a temporary root bound to `root', run BODY.
`root' is a true name: lib/load-path.el resolves symbolic links, and on macOS the
temporary directory /var/... is one for /private/var/...."
  (declare (indent 1))
  `(let ((root (file-name-as-directory
                (file-truename (make-temp-file "build-packages-test" t)))))
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
                  "submodule.dash.build-exclude b.el"
                  "submodule.magit.info docs/magit.texi"
                  "submodule.magit.info docs/magit-section.texi"
                  "submodule.dash.patch patches/dash/0001-a.patch"
                  "submodule.dash.patch patches/dash/0002-b.patch"))))
    (should (equal (mapcar (lambda (s) (plist-get s :name)) specs) '("magit" "dash")))
    (should (equal (plist-get (nth 0 specs) :load-path) '("lisp")))
    (should (equal (plist-get (nth 1 specs) :load-path) '(".")))
    (should (equal (plist-get (nth 1 specs) :build-exclude) '("a.el" "b.el")))
    (should (equal (plist-get (nth 0 specs) :info)
                   '("docs/magit.texi" "docs/magit-section.texi")))
    (should-not (plist-get (nth 1 specs) :info))
    (should (equal (plist-get (nth 1 specs) :patch)
                   '("patches/dash/0001-a.patch" "patches/dash/0002-b.patch")))
    (should-not (plist-get (nth 0 specs) :patch))))

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

(defconst build-packages-test--texi
  "\\input texinfo
@setfilename toy.info
@settitle Toy
@dircategory Emacs
@direntry
* Toy: (toy).           A toy manual.
@end direntry
@node Top
@top Toy
Hello.
@bye
"
  "The smallest manual with a `dir' entry.")

(ert-deftest build-packages-info-manuals-and-dir ()
  "D-039: listed manuals are built into DIR with a `dir' entry; old ones go."
  (build-packages-test--with-tree '("lib/p/docs/toy.texi")
    (write-region build-packages-test--texi nil (expand-file-name "lib/p/docs/toy.texi" root))
    (let ((dir (expand-file-name "lib/info" root))
          (spec (list :name "p" :path "lib/p" :info '("docs/toy.texi"))))
      (make-directory dir t)
      (write-region "" nil (expand-file-name "stale.info" dir))
      (should (= (build-packages-write-info root (list spec) dir) 1))
      (should (file-exists-p (expand-file-name "toy.info" dir)))
      (should-not (file-exists-p (expand-file-name "stale.info" dir)))
      (should (string-match-p "\\* Toy: (toy)\\."
                              (with-temp-buffer
                                (insert-file-contents (expand-file-name "dir" dir))
                                (buffer-string))))
      ;; A listed manual that is missing, a broken one, and no makeinfo all stop.
      (should-error (build-packages-write-info
                     root (list (list :name "p" :path "lib/p" :info '("docs/gone.texi")))
                     dir))
      (write-region "@node Top\n@top T\n@xref{Nowhere}.\n@bye\n" nil
                    (expand-file-name "lib/p/docs/toy.texi" root))
      (should-error (build-packages-write-info root (list spec) dir))
      (write-region build-packages-test--texi nil (expand-file-name "lib/p/docs/toy.texi" root))
      (let ((exec-path nil))
        (should-error (build-packages-write-info root (list spec) dir)))
      ;; Two manuals with one base name would overwrite each other.
      (make-directory (expand-file-name "lib/q/doc" root) t)
      (write-region build-packages-test--texi nil (expand-file-name "lib/q/doc/toy.texi" root))
      (should-error (build-packages-write-info
                     root (list spec (list :name "q" :path "lib/q" :info '("doc/toy.texi")))
                     dir)))))

(defun build-packages-test--git (dir &rest args)
  "Run git ARGS in DIR; fail the test unless it succeeds."
  (with-temp-buffer
    (unless (eql 0 (apply #'call-process "git" nil t nil "-C" dir args))
      (error "git %s: %s" (string-join args " ") (buffer-string)))))

(ert-deftest build-packages-patches-apply-once-and-fail-loudly ()
  "D-069: listed patches are applied in order, also a second time; a patch
that no longer fits, a missing one and an unlisted one stop the build."
  (build-packages-test--with-tree '("lib/p/p.el")
    (let* ((dir (expand-file-name "lib/p" root))
           (file (expand-file-name "p.el" dir))
           (spec (list :name "p" :path "lib/p"
                       :patch '("patches/p/0001-one.patch" "patches/p/0002-two.patch"))))
      ;; A pinned package: one commit, then two patches made against it.
      (write-region "(defun p () 1)\n" nil file)
      (build-packages-test--git dir "init" "-q")
      (build-packages-test--git dir "add" "p.el")
      (build-packages-test--git dir "-c" "user.name=t" "-c" "user.email=t@t"
                                "commit" "-q" "-m" "pin")
      (make-directory (expand-file-name "patches/p" root) t)
      (dolist (step '(("(defun p () 2)\n" . "0001-one.patch")
                      ("(defun p () 3)\n" . "0002-two.patch")))
        (with-temp-buffer
          (write-region (car step) nil file)
          (call-process "git" nil t nil "-C" dir "diff")
          (write-region nil nil (expand-file-name (cdr step) (expand-file-name "patches/p" root))))
        (build-packages-test--git dir "add" "p.el")
        (build-packages-test--git dir "-c" "user.name=t" "-c" "user.email=t@t"
                                  "commit" "-q" "-m" (cdr step)))
      (build-packages-test--git dir "reset" "-q" "--hard" "HEAD~2")
      (should (equal (build-packages-apply-patches root (list spec)) 2))
      (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                     "(defun p () 3)\n"))
      ;; A second `make packages': the same result, no error.
      (should (equal (build-packages-apply-patches root (list spec)) 2))
      (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                     "(defun p () 3)\n"))
      ;; The pin moved under the patches: they no longer apply, and git leaves
      ;; the file as it was.
      (build-packages-test--git dir "checkout" "-q" "--" "p.el")
      (write-region "(defun p () 9)\n" nil file)
      (should-error (build-packages-apply-patches root (list spec)))
      (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                     "(defun p () 9)\n"))
      (build-packages-test--git dir "checkout" "-q" "--" "p.el")
      ;; Listed but missing; present but not listed.
      (should-error (build-packages-apply-patches
                     root (list (plist-put (copy-sequence spec) :patch
                                           '("patches/p/0001-one.patch"
                                             "patches/p/0002-two.patch"
                                             "patches/p/0003-gone.patch")))))
      (should-error (build-packages-apply-patches
                     root (list (plist-put (copy-sequence spec) :patch
                                           '("patches/p/0001-one.patch")))))
      ;; Neither error touched the files.
      (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string))
                     "(defun p () 1)\n")))))

;; ESS's doc/ess.texi has `@include ../VERSION', a path from its own directory.
(ert-deftest build-packages-info-includes-relative-to-the-manual ()
  "D-072: a manual's @include is found relative to the manual, not to the root."
  (build-packages-test--with-tree '("lib/p/VERSION" "lib/p/doc/toy.texi")
    (write-region "@set TOYVER 1.2\n" nil (expand-file-name "lib/p/VERSION" root))
    (write-region (replace-regexp-in-string
                   "Hello\\." "@include ../VERSION\nVersion @value{TOYVER}."
                   build-packages-test--texi t t)
                  nil (expand-file-name "lib/p/doc/toy.texi" root))
    (let ((dir (expand-file-name "lib/info" root))
          (default-directory root))
      (should (= (build-packages-write-info
                  root (list (list :name "p" :path "lib/p" :info '("doc/toy.texi"))) dir)
                 1))
      (should (string-match-p "Version 1\\.2"
                              (with-temp-buffer
                                (insert-file-contents (expand-file-name "toy.info" dir))
                                (buffer-string)))))))

(provide 'build-packages-test)
;;; build-packages-test.el ends here
