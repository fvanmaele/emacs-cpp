;;; init-r.el --- R with ESS  -*- lexical-binding: t; -*-

;;; Commentary:

;; R rides along like Python (D-072): `.R' files open in ESS's `ess-r-mode', which
;; starts an R process and sends code to it (`C-c C-r' region, `C-c C-b' buffer,
;; `C-M-x' function; cells in lisp/init-cells.el).  R starts in the project root
;; without a question, as the build commands do.  No eglot: the R language server
;; is a CRAN package, packaged neither on Arch nor in MacPorts (D-072).  R itself
;; comes from the Arch package r, on macOS from the MacPorts port R.

;;; Code:

(use-package ess-r-mode
  :init
  ;; ESS takes its own directory from the file its autoloads are read from (D-072).
  ;; Ours are all in lib/autoloads.el, so it would look for its etc/ in lib/ and stop
  ;; with "stringp nil" when an R file opens, and it put lib/ and lib/obsolete on
  ;; `load-path'.  Name its real directory before it loads, and drop those two.
  (let ((wrong ess-lisp-directory))
    (setq ess-lisp-directory (file-name-directory (locate-library "ess")))
    (setq load-path (delete (directory-file-name wrong)
                            (delete (directory-file-name (expand-file-name "obsolete" wrong))
                                    load-path))))
  :custom
  ;; ESS starts R in the project root (`project-current'), outside a project in
  ;; the file's directory; this only stops it from asking first.
  (ess-ask-for-ess-directory nil)
  ;; ESS lints through the R package lintr, CRAN-only like the language server;
  ;; without it every check logs "lintr package not installed" as an error.
  (ess-use-flymake nil))

(provide 'init-r)
;;; init-r.el ends here
