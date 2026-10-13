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

;; Built in: right click opens a menu (D-093): in code, Find Definition and Find
;; References at the click (Emacs's own), the language server's commands
;; (lisp/init-lsp.el), and the editing entries.  Shift+Click still extends the
;; selection (`mouse-save-then-kill'), which right click did before.
(use-package mouse
  :hook (after-init . context-menu-mode))

;; Built in: after a stepping key of the debugger (`C-x C-a n'), plain `n', `s', `o',
;; `c' ... repeat it; any other key ends that (D-037).  Emacs's own repeat maps
;; (`C-x o o', `C-x u u') come with it.
(use-package repeat
  :hook (after-init . repeat-mode))

(defconst emacs-cpp-ui-narrow-key-delay 0.2
  "Seconds before which-key lists a prompt's narrow keys after `<' (D-080).")

;; which-key has one idle timer for every prefix, and `which-key-delay-functions'
;; can only make it later.  So while a prompt is open the timer runs at 0.2 s, and
;; every prefix but consult's narrow key waits the rest of the 3 s.
(defun emacs-cpp-ui--which-key-prompt-opened ()
  "Run which-key's timer at `emacs-cpp-ui-narrow-key-delay' while a prompt is open."
  (when which-key-mode
    (which-key--start-timer emacs-cpp-ui-narrow-key-delay)))

(defun emacs-cpp-ui--which-key-prompt-closed ()
  "Give which-key's timer its usual delay back when the last prompt closes.
The prompt being closed still counts in `minibuffer-depth'."
  (when (and which-key-mode (<= (minibuffer-depth) 1))
    (which-key--start-timer)))

(defun emacs-cpp-ui--which-key-delay (keys _length)
  "Return how much longer the prefix KEYS waits while a prompt is open (D-080).
KEYS is the prefix as `key-description' gives it.  Consult's narrow key in a
prompt waits no longer; any other prefix waits up to `which-key-idle-delay'.
Nil outside prompts, where the timer has its usual delay."
  (and (> (minibuffer-depth) 0)
       (not (and (minibufferp)
                 ;; Unbound until consult loads; no prompt has narrow keys before.
                 (bound-and-true-p consult-narrow-key)
                 (equal keys (key-description (key-parse consult-narrow-key)))))
       (- which-key-idle-delay emacs-cpp-ui-narrow-key-delay)))

;; Built in: after a prefix such as `C-c p', its keys appear once you pause 3 s
;; (D-034, D-071: 1 s brought the list up after every ESC).  `C-h' after a prefix
;; still searches them.  In a prompt with consult's narrow keys (`M-o', `C-x b',
;; `M-g i' ...), pausing 0.2 s after `<' lists them; ESC and every other prefix
;; still wait 3 s, in prompts too (D-080).
(use-package which-key
  :hook (after-init . which-key-mode)
  :custom (which-key-idle-delay 3.0)
  :config
  (add-hook 'minibuffer-setup-hook #'emacs-cpp-ui--which-key-prompt-opened)
  (add-hook 'minibuffer-exit-hook #'emacs-cpp-ui--which-key-prompt-closed)
  (add-hook 'which-key-delay-functions #'emacs-cpp-ui--which-key-delay))

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
