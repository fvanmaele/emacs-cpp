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
  '("/opt/local/bin" "/opt/local/sbin" "/Library/TeX/texbin")
  "Directories put in front of `exec-path' and PATH at startup when missing (D-089).
Emacs started from the Dock or Finder gets launchd's PATH, /usr/bin:/bin:/usr/sbin:
/sbin, whatever Emacs.app's Info.plist asks for: then rg, cmake, ninja, pyright
(MacPorts, D-053; ty since D-182) were not found.  /Library/TeX/texbin: MacTeX's
engines, which pandoc runs for Markdown's PDF (D-184).")

(defun emacs-cpp-default--newest-llvm-tools-dir (libexec)
  "Return the bin directory of the newest llvm-N under LIBEXEC with clang-tidy, or nil.
Newest by N as a number: llvm-9 is older than llvm-21."
  (car (sort (seq-filter (lambda (dir)
                           (file-executable-p (expand-file-name "clang-tidy" dir)))
                         (file-expand-wildcards (expand-file-name "llvm-*/bin" libexec)))
             :key (lambda (dir)
                    (string-match "llvm-\\([0-9]*\\)[^/]*/bin\\'" dir)
                    (string-to-number (match-string 1 dir)))
             :reverse t)))

(defconst emacs-cpp-default-llvm-tools-dir
  (emacs-cpp-default--newest-llvm-tools-dir "/opt/local/libexec")
  "Directory of clang's command-line tools (clang-move, run-clang-tidy ...), or
nil for exec-path (D-094).  MacPorts keeps them out of /opt/local/bin, one
directory per LLVM port: the newest installed that holds clang-tidy, found at
startup, so a port upgrade (llvm-23 to llvm-24) needs no edit here (D-206).")

(defconst emacs-cpp-default-mouse-modifier 'super
  "Modifier of the navigation clicks (D-093): Command, which Emacs calls super on
the Mac, as CLion's Cmd+Click.")

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

(defconst emacs-cpp-default-auto-revert-use-notify nil
  "Non-nil: buffers outside project roots follow their files by notification
(D-162 (a)).  nil: polled every `auto-revert-interval' (5 s); a kqueue watch is
one descriptor per buffer, refused beyond 975 (D-127), and `M-.' into libraries
opens many (D-019).")

(defconst emacs-cpp-default-python-server '("ty" "server")
  "The Python language server eglot starts (D-140, D-182): Astral's ty, from the
local MacPorts port in packaging/macports (D-180, D-181).  Its first `M-.' and a
large `M-?' answer sooner than pyright's, its first `M-?' complete
\(RESEARCH_python_ty 4c).")

(defconst emacs-cpp-default-python-server-install
  "make macos-ports (in the emacs-cpp repository)"
  "The command that installs `emacs-cpp-default-python-server' (D-180, D-181).")

(defconst emacs-cpp-default-markdown-pdf-install
  "sudo port install pandoc; LaTeX: MacTeX (https://tug.org/mactex/)"
  "The commands that install pandoc and its LaTeX engine (D-184).")

(defconst emacs-cpp-default-pdf-open-command "open"
  "Opens a file as Finder does, in its default application (D-202).")

(provide 'defaults-darwin)
;;; defaults-darwin.el ends here
