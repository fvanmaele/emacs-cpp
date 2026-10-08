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

;; Lines changed against git are marked in the right fringe (right margin in a
;; terminal); the left holds dape's breakpoints (D-036, D-042).  Turned on per visited
;; file: `global-diff-hl-mode' at startup costs 39 ms (T-008 measured 0.151 s).
(defun emacs-cpp-diff-hl-margin-in-terminal ()
  "Show this buffer's marks in the margin when the frame has no fringe."
  (unless (display-graphic-p)
    (diff-hl-margin-local-mode 1)))

(use-package diff-hl
  :hook (diff-hl-mode-on . emacs-cpp-diff-hl-margin-in-terminal)
  :init
  (setq diff-hl-side 'right)
  ;; Depth 90: after `vc-refresh-state', so diff-hl sees the file is under git and
  ;; draws at once (in front of it, the first update never ran).
  (add-hook 'find-file-hook #'turn-on-diff-hl-mode 90)
  :config
  ;; magit stages and commits behind the buffer's back; refresh the marks after it.
  (add-hook 'magit-pre-refresh-hook #'diff-hl-magit-pre-refresh)
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

(provide 'init-git)
;;; init-git.el ends here
