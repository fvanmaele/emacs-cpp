;;; defaults-gnu-linux.el --- emacs-cpp defaults on Arch Linux  -*- lexical-binding: t; -*-

;;; Commentary:

;; Choices that differ by platform live in one file per platform (D-055), loaded by
;; init.el before the modules; defaults-darwin.el defines the same names.  Platform
;; mechanics (paths, limits) stay in the modules that use them.

;;; Code:

(defconst emacs-cpp-default-debug-configuration 'gdb-preset
  "The debug configuration `C-x C-a d' offers first in C++ buffers (D-051, D-055).")

(defconst emacs-cpp-default-exec-path-prepend nil
  "Directories put in front of `exec-path' and PATH at startup when missing (D-089).
None on Arch: pacman installs into /usr/bin.")

(defconst emacs-cpp-default-xref-search-program 'grep
  "The program textual searches run, `C-c p ?' among them (D-081, D-055).
GNU grep: Arch has no ripgrep (DESIGN 3).")

(provide 'defaults-gnu-linux)
;;; defaults-gnu-linux.el ends here
