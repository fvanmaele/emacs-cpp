;;; init-project.el --- Projects and the project tree  -*- lexical-binding: t; -*-

;;; Commentary:

;; projectile and treemacs, carried over from the retired ~/.emacs (DESIGN 12).

;;; Code:

(use-package projectile
  :hook (after-init . projectile-mode)
  :config
  (keymap-set projectile-mode-map "C-c p" #'projectile-command-map))

(use-package treemacs)

;; Lets treemacs add and follow projectile projects; loaded once both are loaded.
(use-package treemacs-projectile
  :after (treemacs projectile))

(provide 'init-project)
;;; init-project.el ends here
