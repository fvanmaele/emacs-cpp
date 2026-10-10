;;; init-project.el --- Projects and the project tree  -*- lexical-binding: t; -*-

;;; Commentary:

;; projectile and treemacs, carried over from the retired ~/.emacs (DESIGN 12).
;; `C-c t' toggles the tree; it shows only the current buffer's project and follows
;; it to other projects (D-029), not into library files outside them (D-070).  It
;; opens only on `C-c t' (D-049).  Two options turn the following off (D-067).

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

(defcustom emacs-cpp-tree-follow-project t
  "Non-nil: the tree switches to the project of the selected buffer (D-029).
nil: it keeps the project `C-c t' opened it with (D-067)."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-tree--set-follow
  :group 'tools)

(defcustom emacs-cpp-tree-follow-file nil
  "Non-nil: the tree expands to and marks the selected buffer's file, as
treemacs does by default.  nil (the default): it stays where you left it (D-067)."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-tree--set-follow
  :group 'tools)

(defun emacs-cpp-tree--apply-follow ()
  "Turn treemacs's two follow modes on or off as the options say (D-067).
Turning the project follow mode off needs patches/treemacs/0001 (T-041, D-069)."
  (treemacs-project-follow-mode (if emacs-cpp-tree-follow-project 1 -1))
  (treemacs-follow-mode (if emacs-cpp-tree-follow-file 1 -1)))

(defun emacs-cpp-tree--set-follow (symbol value)
  "Set SYMBOL to VALUE; once treemacs is loaded, apply it at once."
  (set-default-toplevel-value symbol value)
  (when (featurep 'treemacs)
    (emacs-cpp-tree--apply-follow)))

(defun emacs-cpp-tree--follow-target-p ()
  "Non-nil if the tree may follow to the current buffer's project (D-070).
Only to a project under version control or with a .projectile file: a library
header reached with `M-.' leaves the tree where it is, also when projectile
takes the library's directory for a project (deal.II's install has a Makefile).
`C-c p' and `C-c t' keep projectile's full rules."
  (let ((dir (if buffer-file-name
                 (file-name-directory buffer-file-name)
               default-directory)))
    (and dir (or (projectile-root-local dir) (projectile-root-bottom-up dir)))))

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
  (emacs-cpp-tree--apply-follow)
  (advice-add 'treemacs--do-follow-project :before-while
              #'emacs-cpp-tree--follow-target-p))

;; Lets treemacs add and follow projectile projects; loaded once both are loaded.
;; With `use-package-always-defer' an :after form alone never loads (it did not,
;; T-002 to T-015).
(use-package treemacs-projectile
  :demand t
  :after (treemacs projectile))

(provide 'init-project)
;;; init-project.el ends here
