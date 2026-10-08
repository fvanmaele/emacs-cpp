;;; init-git.el --- Git  -*- lexical-binding: t; -*-

;;; Commentary:

;; magit's autoloads bind `C-x g' (magit-status) and its other global keys.

;;; Code:

(use-package magit)

;; After magit stages, commits or checks out, the project tree's git colours update
;; (T-015).  Ships with the treemacs submodule; loaded once both packages are.
(use-package treemacs-magit
  ;; With `use-package-always-defer' an :after form alone never loads.
  :demand t
  :after (treemacs magit))

(provide 'init-git)
;;; init-git.el ends here
