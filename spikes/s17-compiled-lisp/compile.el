;;; compile.el --- S17: byte-compile a copy's lisp/ with init.el's prelude  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-125).  Run in a temporary HOME:
;;   emacs -Q --batch -l compile.el TREE
;; TREE: a copy of the repository's init.el, early-init.el, lib/ and lisp/.  The
;; prelude follows review 0084's compile-lisp.patch: the generated load path and
;; autoloads, use-package's settings, the platform defaults file.  Warnings are
;; counted, not fatal (a spike measures; the build would refuse them).

(let* ((tree (file-name-as-directory (expand-file-name (pop command-line-args-left))))
       (lisp (expand-file-name "lisp" tree))
       (defaults (pcase system-type
                   ('gnu/linux "defaults-gnu-linux") ('darwin "defaults-darwin")
                   (_ (error "s17: no defaults file for %s" system-type))))
       (files (directory-files lisp t "\\`[^.].*\\.el\\'"))
       (failed 0))
  (defvar emacs-cpp-root)
  (defvar use-package-always-defer)
  (defvar use-package-expand-minimally)
  (setq emacs-cpp-root tree)
  (load (expand-file-name "lib/load-path.el" tree) nil t)
  (load (expand-file-name "lib/autoloads.el" tree) nil t)
  (add-to-list 'load-path lisp)
  (require 'use-package)
  (setq use-package-always-defer t use-package-expand-minimally t)
  (require (intern defaults))
  (dolist (file files)
    (unless (byte-compile-file file)
      (setq failed (1+ failed))))
  (message "s17-compile: %d files, %d failed, %d .elc written"
           (length files) failed
           (length (directory-files lisp nil "\\.elc\\'")))
  (kill-emacs (if (= failed 0) 0 1)))
