;;; init-toolbar.el --- An icon tool bar for the common commands  -*- lexical-binding: t; -*-

;;; Commentary:

;; The frame's tool bar with this configuration's own buttons (D-210, D-211): sidebar,
;; go to anything, text search, git status, build, debug, and the debugger's buttons
;; while a session runs.  Each tooltip names the command's key.  The icons are
;; Lucide's SVGs (icons/lucide, ISC), drawn in the theme's foreground; Emacs's stock
;; buttons are not shown.  On macOS the bar is the window's own (icons only, at the
;; top) and the window's title area follows the theme, dark or light, so the icons
;; stay readable.  `M-x tool-bar-mode' hides the bar.

;;; Code:

(require 'color)
(require 'seq)
(require 'tool-bar)
(require 'emacs-cpp-internals)

(defconst emacs-cpp-toolbar-icon-directory (expand-file-name "icons/lucide" emacs-cpp-root)
  "Directory of the tool bar's SVG icons, Lucide 1.69.0 (D-210).")

(defconst emacs-cpp-toolbar-icon-size 20
  "Width and height of a tool bar icon, in pixels before the display's scaling.")

(defvar emacs-cpp-toolbar--set-up nil
  "Non-nil once `emacs-cpp-toolbar-setup' has run.")

(defvar emacs-cpp-toolbar--drawn-on-graphic nil
  "Non-nil when the bar was last built from a graphical frame's colours.")

(defun emacs-cpp-toolbar--set-option (symbol value)
  "Set SYMBOL to VALUE; once the bar is set up, draw it again (D-211).
The `:set' of the bar's options, so Customize shows a change at once."
  (set-default-toplevel-value symbol value)
  (when emacs-cpp-toolbar--set-up
    (emacs-cpp-toolbar-refresh)))

(defcustom emacs-cpp-toolbar-icon-color nil
  "Colour of the tool bar's icons (D-210).
nil is the theme's foreground, which suits a bar drawn dark under a dark theme
and light under a light one.  macOS is made to do so; where the desktop's
toolkit draws the bar in its own colours (GTK), name a colour that shows on it."
  :type '(choice (const :tag "The theme's foreground" nil) color)
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-toolbar--set-option)

(defcustom emacs-cpp-toolbar-title-follows-theme t
  "Non-nil: on macOS, each window's title area follows the theme (D-210, D-211).
The title area holds the tool bar and is painted by the system's appearance,
not the theme, so a dark theme on a light system would put light icons on a
light bar.  Non-nil sets each frame's `ns-appearance' to the theme's side, dark
or light, at every theme change.  nil leaves `ns-appearance' alone; frames
already changed keep their value until Emacs restarts."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-toolbar--set-option)

(defconst emacs-cpp-toolbar-items
  '((sidebar "Sidebar" emacs-cpp-treemacs-toggle "C-c t" "panel-left" always)
    (go-to "Go to anything" emacs-cpp-go-to-anything "M-o" "search" always)
    (text "Search text" consult-ripgrep "M-s r" "text-search" always)
    (git "Git status" emacs-cpp-toolbar-git-status "C-x g" "git-commit-vertical" always)
    (build "Build" projectile-compile-project "C-c p c c" "hammer" always
           "asks for the command, RET runs it")
    (debug "Debug" dape "C-x C-a d" "bug-play" no-session
           "asks for the configuration")
    (continue "Continue" dape-continue "C-x C-a c" "play" stopped)
    (pause "Pause" dape-pause "C-x C-a p" "pause" running)
    (step-over "Step over" dape-next "C-x C-a n" "redo-dot" step)
    (step-in "Step into" dape-step-in "C-x C-a s" "arrow-down-to-dot" step)
    (step-out "Step out" dape-step-out "C-x C-a o" "arrow-up-from-dot" step)
    (stop "Stop debugging" dape-kill "C-x C-a K" "square" session))
  "The tool bar's buttons, left to right (D-210, D-211).
Each is (ID LABEL COMMAND KEY ICON WHEN [NOTE]).  KEY is named in the tooltip;
it is written here, not looked up, because dape's keys exist only once dape
loads (`:bind-keymap' in lisp/init-debug.el), after the bar is built; the test
`init-toolbar-items-have-icon-command-and-key' checks each against its binding.
ICON is a file of `emacs-cpp-toolbar-icon-directory' without its extension.
WHEN is `always'; `no-session' (shown while no debug session runs); `session'
(shown while one runs); `stopped' or `running' (shown while one runs and the
program is stopped, or not); `step' (shown while one runs, greyed out unless the
program is stopped).  NOTE, if given, follows the key in the tooltip.")

(defun emacs-cpp-toolbar--session-p ()
  "Return non-nil while a debug session runs.  Never loads dape."
  (bound-and-true-p dape-active-mode))

(defun emacs-cpp-toolbar--stopped-p ()
  "Return non-nil while a debugged program is stopped.  Never loads dape.
dape has no public answer; its internal `dape--live-connection' is checked when
dape loads, and its `stopped' TYPE by the test `init-toolbar-dape-stopped-type'."
  (and (fboundp 'dape--live-connection)
       (dape--live-connection 'stopped t)))

(defun emacs-cpp-toolbar-git-status ()
  "Show magit's status of the current repository; outside one, say so (D-211).
`magit-status' (\\[magit-status]) outside a repository offers to create one; a
click on the bar never does."
  (interactive)
  (require 'magit)
  (unless (magit-toplevel)
    (user-error "Not inside a git repository: %s" default-directory))
  (call-interactively #'magit-status))

(defun emacs-cpp-toolbar--graphic-frame ()
  "Return the selected frame if graphical, else the first graphical frame, else nil.
A daemon's first frame and `emacs -nw' are terminal frames: their faces have no
colours to draw icons in."
  (seq-find #'display-graphic-p (cons (selected-frame) (frame-list))))

(defun emacs-cpp-toolbar--color (frame)
  "Return the colour the icons are drawn in, from FRAME's theme.
FRAME nil (no graphical frame yet: batch, a daemon, `emacs -nw') gives a
placeholder; the first graphical frame draws the bar again."
  (or emacs-cpp-toolbar-icon-color
      (and frame (face-foreground 'default frame t))
      "gray50"))

(defun emacs-cpp-toolbar--image (icon color)
  "Return the image of ICON, a file name without extension, drawn in COLOR.
Lucide's strokes are `currentColor', which Emacs sets from `:foreground'."
  (let ((file (expand-file-name (concat icon ".svg") emacs-cpp-toolbar-icon-directory)))
    (unless (file-readable-p file)
      (error "emacs-cpp: the tool bar's icon %s is missing (D-210)" file))
    (create-image file 'svg nil
                  :foreground color
                  :width emacs-cpp-toolbar-icon-size :height emacs-cpp-toolbar-icon-size
                  :mask 'heuristic)))

(defun emacs-cpp-toolbar--map (frame)
  "Return a tool bar keymap of `emacs-cpp-toolbar-items', in FRAME's colours."
  (let ((map (make-sparse-keymap))
        (color (emacs-cpp-toolbar--color frame)))
    (pcase-dolist (`(,id ,label ,command ,key ,icon ,when ,note) emacs-cpp-toolbar-items)
      (define-key-after map (vector id)
        `(menu-item ,label ,command
                    :image ,(emacs-cpp-toolbar--image icon color)
                    :help ,(format "%s (%s)%s" label key (if note (concat ": " note) ""))
                    ,@(pcase when
                        ('always nil)
                        ('no-session '(:visible (not (emacs-cpp-toolbar--session-p))))
                        ('session '(:visible (emacs-cpp-toolbar--session-p)))
                        ('stopped '(:visible (and (emacs-cpp-toolbar--session-p)
                                                  (emacs-cpp-toolbar--stopped-p))))
                        ('running '(:visible (and (emacs-cpp-toolbar--session-p)
                                                  (not (emacs-cpp-toolbar--stopped-p)))))
                        ('step '(:visible (emacs-cpp-toolbar--session-p)
                                 :enable (emacs-cpp-toolbar--stopped-p)))
                        (_ (error "emacs-cpp: tool bar item %s: unknown WHEN %s"
                                  id when))))))
    map))

(defun emacs-cpp-toolbar--dark-p (&optional frame)
  "Return non-nil when FRAME's theme background is dark, nil when light or unknown."
  (when-let* ((background (face-background 'default frame t))
              (rgb (color-name-to-rgb background frame)))
    (color-dark-p rgb)))

(defun emacs-cpp-toolbar--chrome-follows-theme (frame)
  "On macOS, draw each window's title area, the tool bar in it, as FRAME's theme.
Does nothing without a graphical FRAME (its theme's colours are unknown) or when
`emacs-cpp-toolbar-title-follows-theme' is nil."
  (when (and emacs-cpp-toolbar-title-follows-theme
             frame (eq (framep frame) 'ns))
    (let ((appearance (if (emacs-cpp-toolbar--dark-p frame) 'dark 'light)))
      (setf (alist-get 'ns-appearance default-frame-alist) appearance)
      (dolist (other (frame-list))
        (when (eq (framep other) 'ns)
          (set-frame-parameter other 'ns-appearance appearance))))))

(defun emacs-cpp-toolbar-refresh (&rest _)
  "Draw the tool bar's icons again, in the current theme's colour."
  (interactive)
  (let ((frame (emacs-cpp-toolbar--graphic-frame)))
    (emacs-cpp-toolbar--chrome-follows-theme frame)
    ;; tool-bar.el caches the bar it builds under the map's address; a new map at a
    ;; collected map's address would get that map's icons, in an old colour (D-211).
    (clrhash tool-bar-keymap-cache)
    (setq-default tool-bar-map (emacs-cpp-toolbar--map frame))
    (setq emacs-cpp-toolbar--drawn-on-graphic (and frame t)))
  (force-mode-line-update t))

(defun emacs-cpp-toolbar--frame-made (frame)
  "Draw the bar again when FRAME is the first graphical frame (D-211).
A daemon starts with a terminal frame, so its bar waits for `emacsclient -c'."
  (when (and (display-graphic-p frame) (not emacs-cpp-toolbar--drawn-on-graphic))
    (with-selected-frame frame
      (emacs-cpp-toolbar-refresh))))

(defun emacs-cpp-toolbar--redraw ()
  "Have the tool bar show and hide its buttons by the debugger's state now."
  (force-mode-line-update t))

(defun emacs-cpp-toolbar-setup ()
  "Show the tool bar with this configuration's buttons (D-210)."
  (unless (image-type-available-p 'svg)
    (error "emacs-cpp: this Emacs cannot draw SVG images, which the tool bar's \
icons are (D-210)"))
  ;; The bar first: given a map of one entry, `tool-bar-mode' puts Emacs's stock
  ;; buttons into it.  The refresh then replaces whatever map is there.
  (tool-bar-mode 1)
  (emacs-cpp-toolbar-refresh)
  (setq emacs-cpp-toolbar--set-up t)
  (add-hook 'enable-theme-functions #'emacs-cpp-toolbar-refresh)
  (add-hook 'disable-theme-functions #'emacs-cpp-toolbar-refresh)
  (add-hook 'after-make-frame-functions #'emacs-cpp-toolbar--frame-made))

;; Built in.  The same buttons in every buffer: Info, Help and other modes would put
;; their own bar in place of this one while their buffer is selected.
(use-package tool-bar
  :custom (tool-bar-always-show-default t))

;; After the theme (lisp/init-ui.el loads it on this hook at depth -90): the icons
;; take its foreground.  Last on the hook (depth 90): an error here (no SVG, an icon
;; missing) is still shown, but the hooks before it have run (D-211).  early-init.el
;; draws the first frame without a bar.
(add-hook 'after-init-hook #'emacs-cpp-toolbar-setup 90)

;; dape is configured in lisp/init-debug.el; here only its state reaches the bar.
(with-eval-after-load 'dape
  (emacs-cpp-check-internals 'dape "lisp/init-toolbar.el" 'dape--live-connection)
  (add-hook 'dape-update-ui-hook #'emacs-cpp-toolbar--redraw))

(provide 'init-toolbar)
;;; init-toolbar.el ends here
