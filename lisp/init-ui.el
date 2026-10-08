;;; init-ui.el --- Theme, key hints  -*- lexical-binding: t; -*-

;;; Commentary:

;; Frame settings that must precede the first frame live in early-init.el.

;;; Code:

;; Built-in theme, carried over from the retired ~/.emacs.
(load-theme 'modus-vivendi-tritanopia t)

;; Built in: after a prefix such as `C-c p', its keys appear once you pause
;; (`which-key-idle-delay', 1 s) (D-034).  `C-h' after a prefix still searches them.
(use-package which-key
  :hook (after-init . which-key-mode))

(provide 'init-ui)
;;; init-ui.el ends here
