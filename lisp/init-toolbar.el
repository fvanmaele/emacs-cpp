;;; init-toolbar.el --- An icon tool bar for the common commands  -*- lexical-binding: t; -*-

;;; Commentary:

;; The frame's tool bar with this configuration's own buttons (D-210): sidebar, go to
;; anything, text search, git status, build, debug, and the debugger's steps while a
;; session runs.  Each tooltip names the command's key.  The icons are Lucide's SVGs
;; (icons/lucide, ISC), drawn in the theme's foreground; Emacs's stock buttons are not
;; shown.  On macOS the bar is the window's own (icons only, at the top) and the
;; window's title area follows the theme, dark or light, so the icons stay readable.
;; `M-x tool-bar-mode' hides the bar.

;;; Code:

(require 'color)
(require 'emacs-cpp-internals)

(defconst emacs-cpp-toolbar-icon-directory (expand-file-name "icons/lucide" emacs-cpp-root)
  "Directory of the tool bar's SVG icons, Lucide 1.69.0 (D-210).")

(defconst emacs-cpp-toolbar-icon-size 20
  "Width and height of a tool bar icon, in pixels before the display's scaling.")

(defcustom emacs-cpp-toolbar-icon-color nil
  "Colour of the tool bar's icons (D-210).
nil is the theme's foreground, which suits a bar drawn dark under a dark theme
and light under a light one.  macOS is made to do so; where the desktop's
toolkit draws the bar in its own colours (GTK), name a colour that shows on it."
  :type '(choice (const :tag "The theme's foreground" nil) color))

(defconst emacs-cpp-toolbar-items
  '((sidebar "Sidebar" emacs-cpp-treemacs-toggle "C-c t" "panel-left" always)
    (go-to "Go to anything" emacs-cpp-go-to-anything "M-o" "search" always)
    (text "Search text" consult-ripgrep "M-s r" "text-search" always)
    (git "Git status" magit-status "C-x g" "git-branch" always)
    (build "Build" projectile-compile-project "C-c p c c" "hammer" always)
    (debug "Debug" dape "C-x C-a d" "bug-play" no-session)
    (continue "Continue" dape-continue "C-x C-a c" "play" stopped)
    (step-over "Step over" dape-next "C-x C-a n" "redo-dot" stopped)
    (step-in "Step into" dape-step-in "C-x C-a s" "arrow-down-to-dot" stopped)
    (step-out "Step out" dape-step-out "C-x C-a o" "arrow-up-from-dot" stopped)
    (stop "Stop debugging" dape-quit "C-x C-a q" "square" session))
  "The tool bar's buttons, left to right (D-210).
Each is (ID LABEL COMMAND KEY ICON WHEN): KEY is named in the tooltip, ICON is a
file of `emacs-cpp-toolbar-icon-directory' without its extension, WHEN is
`always', `no-session' (shown while no debug session runs), `session' (shown
while one runs) or `stopped' (shown while one runs, greyed out unless the
program is stopped).")

(defun emacs-cpp-toolbar--session-p ()
  "Return non-nil while a debug session runs.  Never loads dape."
  (and (fboundp 'dape--live-connection)
       (dape--live-connection 'parent t)))

(defun emacs-cpp-toolbar--stopped-p ()
  "Return non-nil while a debugged program is stopped.  Never loads dape."
  (and (fboundp 'dape--live-connection)
       (dape--live-connection 'stopped t)))

(defun emacs-cpp-toolbar--color ()
  "Return the colour the icons are drawn in."
  (or emacs-cpp-toolbar-icon-color
      ;; A terminal or batch frame has no colour name here; no image is drawn there.
      (let ((foreground (face-foreground 'default nil t)))
        (and foreground (color-defined-p foreground) foreground))
      "gray50"))

(defun emacs-cpp-toolbar--image (icon color)
  "Return the image of ICON, a file name without extension, drawn in COLOR."
  (let ((file (expand-file-name (concat icon ".svg") emacs-cpp-toolbar-icon-directory)))
    (unless (file-readable-p file)
      (error "emacs-cpp: the tool bar's icon %s is missing (D-210)" file))
    (create-image (string-replace "currentColor" color
                                  (with-temp-buffer
                                    (insert-file-contents file)
                                    (buffer-string)))
                  'svg t
                  :width emacs-cpp-toolbar-icon-size :height emacs-cpp-toolbar-icon-size
                  :mask 'heuristic)))

(defun emacs-cpp-toolbar--map ()
  "Return a tool bar keymap of `emacs-cpp-toolbar-items'."
  (let ((map (make-sparse-keymap))
        (color (emacs-cpp-toolbar--color)))
    (pcase-dolist (`(,id ,label ,command ,key ,icon ,when) emacs-cpp-toolbar-items)
      (define-key-after map (vector id)
        `(menu-item ,label ,command
                    :image ,(emacs-cpp-toolbar--image icon color)
                    :help ,(format "%s (%s)" label key)
                    ,@(pcase when
                        ('always nil)
                        ('no-session '(:visible (not (emacs-cpp-toolbar--session-p))))
                        ('session '(:visible (emacs-cpp-toolbar--session-p)))
                        ('stopped '(:visible (emacs-cpp-toolbar--session-p)
                                    :enable (emacs-cpp-toolbar--stopped-p)))
                        (_ (error "emacs-cpp: tool bar item %s: unknown WHEN %s"
                                  id when))))))
    map))

(defun emacs-cpp-toolbar--dark-p ()
  "Return non-nil when the theme's background is dark, nil when light or unknown."
  (when-let* ((background (face-background 'default nil t))
              (rgb (color-name-to-rgb background)))
    (color-dark-p rgb)))

(defun emacs-cpp-toolbar--chrome-follows-theme ()
  "On macOS, draw each window's title area, the tool bar in it, as the theme: dark
or light.  It followed the system's appearance, so a dark theme on a light
system put the theme's light icons on a light bar."
  (when (featurep 'ns)
    (let ((appearance (if (emacs-cpp-toolbar--dark-p) 'dark 'light)))
      (setf (alist-get 'ns-appearance default-frame-alist) appearance)
      (dolist (frame (frame-list))
        (when (eq (framep frame) 'ns)
          (set-frame-parameter frame 'ns-appearance appearance))))))

(defun emacs-cpp-toolbar-refresh (&rest _)
  "Draw the tool bar's icons again, in the current theme's colour."
  (interactive)
  (emacs-cpp-toolbar--chrome-follows-theme)
  (setq-default tool-bar-map (emacs-cpp-toolbar--map))
  (force-mode-line-update t))

(defun emacs-cpp-toolbar--redraw ()
  "Have the tool bar show and hide its buttons by the debugger's state now."
  (force-mode-line-update t))

(defun emacs-cpp-toolbar-setup ()
  "Show the tool bar with this configuration's buttons (D-210)."
  (unless (image-type-available-p 'svg)
    (error "emacs-cpp: this Emacs cannot draw SVG images, which the tool bar's \
icons are (D-210)"))
  (emacs-cpp-toolbar-refresh)
  (add-hook 'enable-theme-functions #'emacs-cpp-toolbar-refresh)
  (add-hook 'disable-theme-functions #'emacs-cpp-toolbar-refresh)
  (tool-bar-mode 1))

;; Built in.  The same buttons in every buffer: Info, Help and other modes would put
;; their own bar in place of this one while their buffer is selected.
(use-package tool-bar
  :custom (tool-bar-always-show-default t))

;; After the theme (lisp/init-ui.el loads it on this hook, earlier): the icons take
;; its foreground.  early-init.el draws the first frame without a bar.
(add-hook 'after-init-hook #'emacs-cpp-toolbar-setup)

;; dape is configured in lisp/init-debug.el; here only its state reaches the bar.
(with-eval-after-load 'dape
  (emacs-cpp-check-internals 'dape "lisp/init-toolbar.el" 'dape--live-connection)
  (add-hook 'dape-update-ui-hook #'emacs-cpp-toolbar--redraw))

(provide 'init-toolbar)
;;; init-toolbar.el ends here
