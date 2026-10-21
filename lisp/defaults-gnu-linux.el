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

(defconst emacs-cpp-default-llvm-tools-dir nil
  "Directory of clang's command-line tools (clang-move, run-clang-tidy ...), or
nil for exec-path (D-094): pacman's `clang' puts them in /usr/bin.")

(defconst emacs-cpp-default-mouse-modifier 'super
  "Modifier of the navigation clicks (D-093): Super, where the Mac has Command, so
Ctrl's clicks keep Emacs's buffer menu and rectangle drag (owner 2026-10-14).")

(defconst emacs-cpp-default-pdf-viewer
  '("zathura" "--synctex-forward" "%l:1:%f" "%p")
  "Program and arguments texlab runs to show a line of a LaTeX source in its PDF
\(forward search, D-090); %l line, %p PDF, %f source.  zathura (pacman `zathura'
with `zathura-pdf-mupdf' or `zathura-pdf-poppler').")

(defconst emacs-cpp-default-xref-search-program 'grep
  "The program textual searches run, `C-c p ?' among them (D-081, D-055).
GNU grep: Arch has no ripgrep (DESIGN 3).")

(defconst emacs-cpp-default-library-include-dir "/usr/include"
  "Where installed libraries' headers lie, for the version a library index is
checked against (D-131): pacman installs deal.II's under /usr/include.")

(defconst emacs-cpp-default-fswatch-program "/opt/fswatch-no-loss/bin/fswatch"
  "The patched fswatch that watches files for language servers (D-109, D-127).
pacman's package from packaging/fswatch-no-loss installs it under /opt, apart
from any stock fswatch.")

(defconst emacs-cpp-default-python-server '("ty" "server")
  "The Python language server eglot starts (D-140): Astral's ty, pacman `extra/ty'.
Its first `M-.' and a large `M-?' answer several times sooner than pyright's
\(RESEARCH_python_ty 4b).")

(defconst emacs-cpp-default-python-server-install "sudo pacman -S ty"
  "The command that installs `emacs-cpp-default-python-server' (D-140).")

(provide 'defaults-gnu-linux)
;;; defaults-gnu-linux.el ends here
