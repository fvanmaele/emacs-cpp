;;; build-clangd-test.el --- make clangd refuses mismatched LLVM versions  -*- lexical-binding: t; -*-

;;; Commentary:

;; scripts/build-clangd.sh (D-123) writes the PKGBUILD's pkgver from `llvm-config
;; --version' and builds; these tests run it with stub tools first on PATH and check
;; the two refusals, which stop it before it writes anything or runs makepkg.

;;; Code:

(require 'ert)
(require 'build-packages)

(defun build-clangd-test--run (llvm-version libs-version)
  "Run build-clangd.sh with stubs: llvm-config says LLVM-VERSION, pacman LIBS-VERSION.
Return (EXIT . OUTPUT).  updpkgsums and makepkg are stubs that fail if called."
  (let ((stubs (make-temp-file "build-clangd-test" t)))
    (unwind-protect
        (progn
          (pcase-dolist (`(,name . ,body)
                         `(("llvm-config" . ,(format "echo '%s'" llvm-version))
                           ("pacman" . ,(format "echo 'llvm-libs %s'" libs-version))
                           ("updpkgsums" . "echo updpkgsums called; exit 3")
                           ("makepkg" . "echo makepkg called; exit 3")))
            (let ((file (expand-file-name name stubs)))
              (write-region (concat "#!/bin/sh\n" body "\n") nil file)
              (set-file-modes file #o755)))
          (with-temp-buffer
            (let* ((process-environment
                    (cons (concat "PATH=" stubs path-separator (getenv "PATH"))
                          process-environment))
                   (exit (call-process "sh" nil t nil
                                       (expand-file-name "scripts/build-clangd.sh"
                                                         build-packages-root))))
              (cons exit (buffer-string)))))
      (delete-directory stubs t))))

(defun build-clangd-test--pkgbuild ()
  "Return the PKGBUILD's text."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "packaging/clangd-index-nav/PKGBUILD"
                                            build-packages-root))
    (buffer-string)))

(ert-deftest build-clangd-refuses-llvm-libs-of-another-release ()
  "D-123: llvm-config and llvm-libs at two releases stop the build, PKGBUILD untouched."
  (let* ((before (build-clangd-test--pkgbuild))
         (result (build-clangd-test--run "23.1.9" "23.1.8-1")))
    (should (= (car result) 1))
    (should (string-match-p "llvm-config says 23.1.9 but llvm-libs is 23.1.8" (cdr result)))
    (should-not (string-match-p "called" (cdr result)))
    (should (equal (build-clangd-test--pkgbuild) before))))

(ert-deftest build-clangd-refuses-a-version-that-is-no-release ()
  "D-123: a version that is no release (a development build) stops the build."
  (let* ((before (build-clangd-test--pkgbuild))
         (result (build-clangd-test--run "24.0.0git" "24.0.0git-1")))
    (should (= (car result) 1))
    (should (string-match-p "not a release version" (cdr result)))
    (should (equal (build-clangd-test--pkgbuild) before))))

(provide 'build-clangd-test)
;;; build-clangd-test.el ends here
