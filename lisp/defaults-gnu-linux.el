;;; defaults-gnu-linux.el --- emacs-cpp defaults on Arch Linux  -*- lexical-binding: t; -*-

;;; Commentary:

;; Choices that differ by platform live in one file per platform (D-055), loaded by
;; init.el before the modules; defaults-darwin.el defines the same names.  Platform
;; mechanics (paths, limits) stay in the modules that use them.

;;; Code:

(defconst emacs-cpp-default-debug-configuration 'gdb-preset
  "The debug configuration `C-x C-a d' offers first in C++ buffers (D-051, D-055).")

(provide 'defaults-gnu-linux)
;;; defaults-gnu-linux.el ends here
