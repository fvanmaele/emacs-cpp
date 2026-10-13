;;; defaults-darwin.el --- emacs-cpp defaults on macOS  -*- lexical-binding: t; -*-

;;; Commentary:

;; Choices that differ by platform live in one file per platform (D-055), loaded by
;; init.el before the modules; defaults-gnu-linux.el defines the same names.  Platform
;; mechanics (paths, limits) stay in the modules that use them.

;;; Code:

(defconst emacs-cpp-default-debug-configuration 'lldb-preset
  "The debug configuration `C-x C-a d' offers first in C++ buffers.
Apple silicon has no gdb (D-051, D-055).")

(defconst emacs-cpp-default-exec-path-prepend
  '("/opt/local/bin" "/opt/local/sbin" "/usr/local/bin")
  "Directories put in front of `exec-path' and PATH at startup when missing (D-089).
Emacs started from the Dock or Finder gets launchd's PATH, /usr/bin:/bin:/usr/sbin:
/sbin, whatever Emacs.app's Info.plist asks for: then rg, cmake, ninja, pyright
(MacPorts, D-053) and R (CRAN's, in /usr/local/bin) were not found.")

(defconst emacs-cpp-default-pdf-viewer
  '("/Applications/Skim.app/Contents/SharedSupport/displayline" "-r" "-g" "%l" "%p" "%f")
  "Program and arguments texlab runs to show a line of a LaTeX source in its PDF
\(forward search, D-090); %l line, %p PDF, %f source.  Skim, installed outside
MacPorts: `-r' reloads the PDF, `-g' leaves Emacs in front.")

(defconst emacs-cpp-default-xref-search-program 'ripgrep
  "The program textual searches run, `C-c p ?' among them (D-081, D-055).
ripgrep (MacPorts): opening a file costs about 14 ms here, so BSD grep, one file
at a time, took 130 - 156 s over deal.II and ripgrep, in parallel, 10 s.")

(provide 'defaults-darwin)
;;; defaults-darwin.el ends here
