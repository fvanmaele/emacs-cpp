;;; init-cmake.el --- CMake files  -*- lexical-binding: t; -*-

;;; Commentary:

;; CMakeLists.txt and *.cmake use `cmake-mode' from the system cmake package
;; (D-013), which matches the installed CMake version: Arch's cmake package, or
;; MacPorts' cmake port on macOS (D-050, D-053).  An Emacs from the same package
;; manager may have the directory on `load-path' already; it is named here so that
;; any start, also -Q (the tests), gets the same.  Building is projectile's, on the
;; active preset (D-035).

;;; Code:

(defconst emacs-cpp-cmake-mode-directory
  (pcase system-type
    ('gnu/linux "/usr/share/emacs/site-lisp")
    ('darwin "/opt/local/share/emacs/site-lisp")
    (_ (error "emacs-cpp: no cmake-mode directory known for %s (D-050)" system-type)))
  "Where the system cmake package installs cmake-mode.el (D-013, D-053).")

;; Fail loudly (DESIGN 4): without it CMake files open in fundamental-mode.
(unless (file-exists-p (expand-file-name "cmake-mode.el" emacs-cpp-cmake-mode-directory))
  (error "emacs-cpp: no cmake-mode.el in %s; install %s (D-013)"
         emacs-cpp-cmake-mode-directory
         (if (eq system-type 'darwin) "the cmake port" "the cmake package")))

(use-package cmake-mode
  :load-path emacs-cpp-cmake-mode-directory
  :mode ("CMakeLists\\.txt\\'" "\\.cmake\\'"))

(provide 'init-cmake)
;;; init-cmake.el ends here
