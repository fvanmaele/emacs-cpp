;;; init-project.el --- Projects and the project tree  -*- lexical-binding: t; -*-

;;; Commentary:

;; projectile and treemacs, carried over from the retired ~/.emacs (DESIGN 12).
;; `C-c t' toggles the tree; it shows only the current buffer's project and follows
;; it to other projects (D-029).

;;; Code:

(require 'emacs-cpp-presets)

(use-package projectile
  :hook (after-init . projectile-mode)
  :config
  (keymap-set projectile-mode-map "C-c p" #'projectile-command-map)
  ;; C-c p c o / c c / c t configure, build and test the active CMake preset from any
  ;; buffer of the project (D-035); projectile asks again on every run, so a preset
  ;; switch (C-c l P) takes effect at once.
  (projectile-update-project-type
   'cmake
   :configure #'emacs-cpp-presets-configure-command
   :compile #'emacs-cpp-presets-compile-command
   :test #'emacs-cpp-presets-test-command))

(defun emacs-cpp-treemacs-toggle ()
  "Close the tree if it is visible, else show the current project in it (D-029).
`treemacs' itself asks for a project root while its workspace is empty."
  (interactive)
  (if-let* ((window (treemacs-get-local-window)))
      (delete-window window)
    (treemacs-add-and-display-current-project-exclusively)))

(use-package treemacs
  :bind ("C-c t" . emacs-cpp-treemacs-toggle)
  :commands treemacs-get-local-window
  :config
  (treemacs-project-follow-mode))

;; Lets treemacs add and follow projectile projects; loaded once both are loaded.
(use-package treemacs-projectile
  :after (treemacs projectile))

(provide 'init-project)
;;; init-project.el ends here
