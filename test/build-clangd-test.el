;;; build-clangd-test.el --- the patched clangd's build: one pin, self-contained  -*- lexical-binding: t; -*-

;;; Commentary:

;; packaging/clangd-index-nav (D-207): the PKGBUILD pins the LLVM release for both
;; machines and depends on nothing of pacman's LLVM; build-macos.sh takes the release
;; and the tarball's checksum from the PKGBUILD.  These tests read the two files.

;;; Code:

(require 'ert)
(require 'build-packages)

(defun build-clangd-test--file (name)
  "Return the text of NAME in packaging/clangd-index-nav."
  (with-temp-buffer
    (insert-file-contents (expand-file-name (concat "packaging/clangd-index-nav/" name)
                                            build-packages-root))
    (buffer-string)))

(defun build-clangd-test--assignment (name)
  "Return the PKGBUILD's line or parenthesized block assigning NAME."
  (let ((text (build-clangd-test--file "PKGBUILD")))
    (should (string-match (format "^%s=\\(([^)]*)\\|.*\\)" (regexp-quote name)) text))
    (match-string 1 text)))

(ert-deftest build-clangd-pkgbuild-needs-nothing-of-pacmans-llvm ()
  "D-207: no llvm, llvm-libs or clang among the PKGBUILD's dependencies."
  (dolist (name '("depends" "makedepends"))
    (should-not (string-match-p "llvm\\|clang" (build-clangd-test--assignment name)))))

(ert-deftest build-clangd-pkgbuild-pins-a-release ()
  "D-207: pkgver is a release, three numbers, and names the first source."
  (should (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\'"
                          (build-clangd-test--assignment "pkgver")))
  (should (string-match-p "llvm-project-\\$pkgver\\.src\\.tar\\.xz\""
                          (build-clangd-test--assignment "source"))))

(ert-deftest build-clangd-macos-script-takes-the-pin-from-the-pkgbuild ()
  "D-207: build-macos.sh names no release and no checksum of its own."
  (let ((text (build-clangd-test--file "build-macos.sh")))
    (should (string-match-p "^version=\\$pkgver$" text))
    (should (string-match-p "^tarball_sha256=\\${sha256sums\\[0\\]}$" text))
    (should-not (string-match-p "[0-9]+\\.[0-9]+\\.[0-9]+" text))
    (should-not (string-match-p "[0-9a-f]\\{64\\}" text))))

(provide 'build-clangd-test)
;;; build-clangd-test.el ends here
