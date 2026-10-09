;;; defaults-darwin.el --- emacs-cpp defaults on macOS  -*- lexical-binding: t; -*-

;;; Commentary:

;; Choices that differ by platform live in one file per platform (D-055), loaded by
;; init.el before the modules; defaults-gnu-linux.el defines the same names.  Platform
;; mechanics (paths, limits) stay in the modules that use them.

;;; Code:

(defconst emacs-cpp-default-debug-configuration 'lldb-preset
  "The debug configuration `C-x C-a d' offers first in C++ buffers.
Apple silicon has no gdb (D-051, D-055).")

(provide 'defaults-darwin)
;;; defaults-darwin.el ends here
