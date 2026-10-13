;;; init-project-test.el --- Textual find references (C-c p ?)  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-081): textual searches run the platform's program,
;; and a missing one stops startup; with patches/projectile/0001 (D-069) `C-c p ?'
;; searches the files projectile lists (tracked and untracked, not git-ignored)
;; with that program.  Without the patch the git-ignored file is found too.  Needs
;; git; ripgrep is tested where it is installed.

;;; Code:

(require 'ert)
(require 'init-test)

(ert-deftest init-project-search-program ()
  "D-081: the platform's search program, checked at startup."
  (init-test--load)
  (should (eq xref-search-program emacs-cpp-default-xref-search-program))
  (should (eq (emacs-cpp-search-program-check 'grep) 'grep))
  (should-error (emacs-cpp-search-program-check 'emacs-cpp-no-such-program)))

(ert-deftest init-project-find-references-searches-project-files ()
  "patches/projectile/0001: `C-c p ?' finds SYMBOL in the files projectile lists."
  (init-test--load)
  (should (eq (keymap-lookup projectile-command-map "?") #'projectile-find-references))
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-refs" t))))
         (default-directory root))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "sub" root))
          (make-directory (expand-file-name "build" root))
          (write-region "build/\n" nil (expand-file-name ".gitignore" root))
          (write-region "int needle_sym;\n" nil (expand-file-name "a.cc" root))
          (write-region "extern int needle_sym;\n" nil (expand-file-name "sub/b.h" root))
          (write-region "int other;\n" nil (expand-file-name "sub/c.h" root))
          (write-region "int f() { return needle_sym; }\n" nil
                        (expand-file-name "untracked.cc" root))
          (write-region "int needle_sym_copy;\n" nil
                        (expand-file-name "build/generated.cc" root))
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          (should (eql 0 (call-process "git" nil nil nil "add" ".gitignore" "a.cc"
                                       "sub/b.h" "sub/c.h")))
          (let ((buffer (find-file-noselect (expand-file-name "a.cc" root))))
            (unwind-protect
                (with-current-buffer buffer
                  (dolist (program (cons 'grep (and (executable-find "rg") '(ripgrep))))
                    (let ((xref-search-program program)
                          fetcher)
                      (cl-letf (((symbol-function 'xref-show-xrefs)
                                 (lambda (f _display) (setq fetcher f))))
                        (projectile-find-references "needle_sym"))
                      (should (equal (sort (mapcar (lambda (item)
                                                     (file-relative-name
                                                      (xref-location-group
                                                       (xref-item-location item))
                                                      root))
                                                   (funcall fetcher)))
                                     '("a.cc" "sub/b.h" "untracked.cc"))))))
              (kill-buffer buffer))))
      (delete-directory root t))))

(provide 'init-project-test)
;;; init-project-test.el ends here
