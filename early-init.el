;;; early-init.el --- emacs-cpp: settings needed before the first frame  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded through the symlink ~/.emacs.d/early-init.el (D-003).  Only settings that
;; must exist before packages or the first frame belong here (DESIGN 5).

;;; Code:

;; Startup allocates far more than the default 800 KB between collections: 22 of them
;; took 0.22 of 0.36 s (T-008, DESIGN 11).  64 MB leaves one (startup 0.15 s); the
;; default comes back once startup is over, where a higher value measured no gain.
(let ((normal gc-cons-threshold))
  (setq gc-cons-threshold (* 64 1024 1024))
  (add-hook 'emacs-startup-hook (lambda () (setq gc-cons-threshold normal)) 100))

;; Packages come from the submodules in lib/ (D-006), never from package.el.
(setq package-enable-at-startup nil)

;; No tool bar.  Set as a frame parameter so the first frame is drawn without it.
(push '(tool-bar-lines . 0) default-frame-alist)
(setq tool-bar-mode nil)

;;; early-init.el ends here
