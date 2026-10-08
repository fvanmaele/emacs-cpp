;;; init-cmake.el --- CMake files  -*- lexical-binding: t; -*-

;;; Commentary:

;; CMakeLists.txt and *.cmake use `cmake-mode' from the system cmake package
;; (D-013), which matches the installed CMake version.  A normal Emacs start has its
;; directory on `load-path' already; it is named here so that a start with -Q (the
;; tests) gets the same.  Building is projectile's, on the active preset (D-035).

;;; Code:

(defconst emacs-cpp-cmake-mode-directory "/usr/share/emacs/site-lisp"
  "Where the Arch cmake package installs cmake-mode.el (D-013).")

;; Fail loudly (DESIGN 4): without it CMake files open in fundamental-mode.
(unless (file-exists-p (expand-file-name "cmake-mode.el" emacs-cpp-cmake-mode-directory))
  (error "emacs-cpp: no cmake-mode.el in %s; install the cmake package (D-013)"
         emacs-cpp-cmake-mode-directory))

(use-package cmake-mode
  :load-path emacs-cpp-cmake-mode-directory
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

(provide 'init-cmake)
;;; init-cmake.el ends here
