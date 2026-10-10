;;; init-ui.el --- Theme, key hints, manuals  -*- lexical-binding: t; -*-

;;; Commentary:

;; Frame settings that must precede the first frame live in early-init.el.

;;; Code:

;; Built-in theme, carried over from the retired ~/.emacs, unless one was saved with
;; `M-x customize-themes'.  custom.el loads at the end of init.el, so the choice is
;; known only after it; loading this theme first and the saved one from custom.el
;; left no theme in effect (white background, D-040).
(defun emacs-cpp-ui-default-theme ()
  "Load the default theme unless custom.el enabled one."
  (unless custom-enabled-themes
    (load-theme 'modus-vivendi-tritanopia t)))
(add-hook 'after-init-hook #'emacs-cpp-ui-default-theme -90)

;; Built in: after a stepping key of the debugger (`C-x C-a n'), plain `n', `s', `o',
;; `c' ... repeat it; any other key ends that (D-037).  Emacs's own repeat maps
;; (`C-x o o', `C-x u u') come with it.
(use-package repeat
  :hook (after-init . repeat-mode))

;; Built in: after a prefix such as `C-c p', its keys appear once you pause 3 s
;; (D-034, D-071: 1 s brought the list up after every ESC).  `C-h' after a prefix
;; still searches them.
(use-package which-key
  :hook (after-init . which-key-mode)
  :custom (which-key-idle-delay 3.0))

;; Built in: line numbers where code or text is edited (modes derived from
;; `prog-mode', `text-mode', `conf-mode': C++, CMake, Python, Markdown, ...), not in
;; tool buffers such as treemacs, magit or *compilation* (D-063).  Emacs 31.1's
;; `global-display-line-numbers-mode' turns on in every buffer but the minibuffer.
;; The column is as wide as the buffer's last line number needs when the mode turns
;; on and never narrows; by default it fit the lines in the window, so scrolling past
;; line 99 or 999 widened it and shifted the text (D-073).
(use-package display-line-numbers
  :hook ((prog-mode text-mode conf-mode) . display-line-numbers-mode)
  :custom
  (display-line-numbers-width-start t)
  (display-line-numbers-grow-only t))

(defconst emacs-cpp-info-directory (expand-file-name "lib/info" emacs-cpp-root)
  "Info manuals of the vendored packages, built by `make packages' (D-039).")

;; C-h i lists them next to Emacs's own manuals.
(use-package info
  :config
  (unless (file-exists-p (expand-file-name "dir" emacs-cpp-info-directory))
    (error "emacs-cpp: no %s/dir; run `make packages' in %s (D-039)"
           emacs-cpp-info-directory emacs-cpp-root))
  (add-to-list 'Info-additional-directory-list emacs-cpp-info-directory))

(provide 'init-ui)
;;; init-ui.el ends here
