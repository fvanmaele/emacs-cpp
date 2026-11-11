;;; emacs-cpp-internals.el --- Internals of other packages, checked when they load  -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs's own packages (eglot, jsonrpc, which-key, python) change with Emacs, and a
;; double dash marks what they may rename without notice.  A module that uses such a
;; name checks it when the package loads, so a new Emacs fails there, naming the file
;; to fix, not at the first key that reaches the code (DESIGN 4).  The vendored
;; packages are pinned (D-006), so their internals change only with a pin bump.

;;; Code:

(require 'seq)

(defun emacs-cpp-check-internals (package user &rest symbols)
  "Signal an error unless each of SYMBOLS is a function or a variable.
SYMBOLS are internals of PACKAGE that the file USER relies on.  The error is also
shown as a warning: one raised while a package loads from a hook is only a line
in the echo area."
  (when-let* ((missing (seq-remove (lambda (symbol) (or (fboundp symbol) (boundp symbol)))
                                   symbols)))
    (let ((message (format "emacs-cpp: this %s lacks %s, which %s uses; adapt %s to \
this Emacs (%s)"
                           package (mapconcat #'symbol-name missing ", ") user user
                           emacs-version)))
      (display-warning 'emacs-cpp message :error)
      (error "%s" message))))

(provide 'emacs-cpp-internals)
;;; emacs-cpp-internals.el ends here
