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
  '("/opt/local/bin" "/opt/local/sbin" "/usr/local/bin" "/Library/TeX/texbin")
  "Directories put in front of `exec-path' and PATH at startup when missing (D-089).
Emacs started from the Dock or Finder gets launchd's PATH, /usr/bin:/bin:/usr/sbin:
/sbin, whatever Emacs.app's Info.plist asks for: then rg, cmake, ninja, pyright
(MacPorts, D-053), R (CRAN's, in /usr/local/bin) and TeX (MacTeX: pdflatex,
latexmk, dvipng for AUCTeX's preview and texlab's build, D-090) were not found.
Shells get /Library/TeX/texbin from /etc/paths.d, which launchd does not read.")

(defconst emacs-cpp-default-llvm-tools-dir "/opt/local/libexec/llvm-23/bin"
  "Directory of clang's command-line tools (clang-move, run-clang-tidy ...), or
nil for exec-path (D-094).  MacPorts keeps them out of /opt/local/bin.")

(defconst emacs-cpp-default-mouse-modifier 'super
  "Modifier of the navigation clicks (D-093): Command, which Emacs calls super on
the Mac, as CLion's Cmd+Click.")

(defconst emacs-cpp-default-pdf-viewer
  '("/Applications/Skim.app/Contents/SharedSupport/displayline" "-r" "-g" "%l" "%p" "%f")
  "Program and arguments texlab runs to show a line of a LaTeX source in its PDF
\(forward search, D-090); %l line, %p PDF, %f source.  Skim, installed outside
MacPorts: `-r' reloads the PDF, `-g' leaves Emacs in front.")

(defconst emacs-cpp-default-xref-search-program 'ripgrep
  "The program textual searches run, `C-c p ?' among them (D-081, D-055).
ripgrep (MacPorts): opening a file costs about 14 ms here, so BSD grep, one file
at a time, took 130 - 156 s over deal.II and ripgrep, in parallel, 10 s.")

(defconst emacs-cpp-default-library-include-dir nil
  "Where installed libraries' headers lie, for the version a library index is
checked against (D-131); nil: not known on the Mac yet (deal.II comes from
deal.II.app, path UNVERIFIED), so the check warns that it cannot read it.")

(defconst emacs-cpp-default-fswatch-program
  (expand-file-name "opt/fswatch-no-loss/bin/fswatch" (concat "~" (user-login-name)))
  "The patched fswatch that watches files for language servers (D-109, D-127).
packaging/fswatch-no-loss/build-macos.sh installs it under ~/opt; the home is
found through the user database, so a test run's temporary HOME finds it too.")

(provide 'defaults-darwin)
;;; defaults-darwin.el ends here
