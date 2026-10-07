;;; early-init.el --- emacs-cpp: settings needed before the first frame  -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded through the symlink ~/.emacs.d/early-init.el (D-003).  Only settings that
;; must exist before packages or the first frame belong here (DESIGN 5).

;;; Code:

;; Packages come from the submodules in lib/ (D-006), never from package.el.
(setq package-enable-at-startup nil)

;; No tool bar.  Set as a frame parameter so the first frame is drawn without it.
(push '(tool-bar-lines . 0) default-frame-alist)
(setq tool-bar-mode nil)

;;; early-init.el ends here
