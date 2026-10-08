;;; init-project.el --- Projects and the project tree  -*- lexical-binding: t; -*-

;;; Commentary:

;; projectile and treemacs, carried over from the retired ~/.emacs (DESIGN 12).
;; `C-c t' toggles the tree; it shows only the current buffer's project and follows
;; it to other projects (D-029).  It opens by itself with the first project file of a
;; session, unless `emacs-cpp-tree-open-automatically' is nil (D-048).

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

(defcustom emacs-cpp-tree-open-automatically t
  "Non-nil: show the project tree with the first project file of a session (D-048).
Once per session: after `C-c t' has closed the tree, it stays closed."
  :type 'boolean
  :group 'tools)

(defvar emacs-cpp--tree-opened nil
  "Non-nil once the tree was shown in this session (D-048).")

(defun emacs-cpp-treemacs-open-once ()
  "Show the tree for the visited file if it is the session's first project file.
From `find-file-hook'; waits until the buffer is shown in a window, so files
visited in the background (magit, `M-.' previews) do not count, nor do git's own
files (a commit message under .git/)."
  (when (and emacs-cpp-tree-open-automatically
             (not emacs-cpp--tree-opened)
             (not (string-match-p "/\\.git/" (or buffer-file-name "")))
             (project-current))
    (let ((buffer (current-buffer)))
      (run-at-time
       0 nil
       (lambda ()
         (when-let* (((not emacs-cpp--tree-opened))
                     ((buffer-live-p buffer))
                     (window (get-buffer-window buffer)))
           (unless (treemacs-get-local-window)
             ;; The tree takes the focus; give it back to the file.
             (with-selected-window window
               (treemacs-add-and-display-current-project-exclusively)))
           ;; Only once it is shown: a failure above leaves the next file to try.
           (setq emacs-cpp--tree-opened t)))))))

(defun emacs-cpp-treemacs-toggle ()
  "Close the tree if it is visible, else show the current project in it (D-029).
`treemacs' itself asks for a project root while its workspace is empty."
  (interactive)
  (if-let* ((window (treemacs-get-local-window)))
      (delete-window window)
    (treemacs-add-and-display-current-project-exclusively)))

(use-package treemacs
  :bind ("C-c t" . emacs-cpp-treemacs-toggle)
  :commands (treemacs-get-local-window
             treemacs-add-and-display-current-project-exclusively)
  :init
  (add-hook 'find-file-hook #'emacs-cpp-treemacs-open-once)
  :config
  (treemacs-project-follow-mode))

;; Lets treemacs add and follow projectile projects; loaded once both are loaded.
;; With `use-package-always-defer' an :after form alone never loads (it did not,
;; T-002 to T-015).
(use-package treemacs-projectile
  :demand t
  :after (treemacs projectile))

(provide 'init-project)
;;; init-project.el ends here
