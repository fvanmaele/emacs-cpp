;;; init-completion.el --- Minibuffer and in-buffer completion  -*- lexical-binding: t; -*-

;;; Commentary:

;; CLion's "search everywhere", "go to file / symbol" and completion popup, built
;; from the completion group of DESIGN 12 (T-003):
;;
;;   vertico     vertical candidate list for every minibuffer prompt
;;   orderless   space-separated parts match in any order ("mod gpe" finds gpe/model.h)
;;   marginalia  annotations next to candidates (file size, docstring, key binding)
;;   consult     search and jump commands with live preview (buffers, lines, grep, imenu)
;;   embark      actions on the candidate at point (`C-.'); loads embark-consult itself
;;   corfu       completion popup in buffers on TAB or C-M-i, fed by completion-at-point
;;   cape        extra completion sources; here file names
;;   yasnippet   snippets: the servers' argument placeholders, templates on `C-c y'
;;               from yasnippet-snippets (D-095)
;;
;; Go to anything on `M-o' (D-074 .. D-078) combines them in one prompt, in
;; lisp/init-go-to-anything.el (D-099), which loads after projectile and eglot.
;;
;; Settings follow the packages' READMEs at the pinned versions.  This module loads
;; before init-project so projectile's prompts already use vertico.

;;; Code:

;;;; Minibuffer

;; PgDn / PgUp page through the candidates, as `C-v' / `M-v' do (vertico remaps
;; those); the minibuffer bound them to the next / previous history element, so
;; in `M-o' they said "End of history; no default available" (D-084).  History
;; stays on `M-n' / `M-p' and `M-r'.
(use-package vertico
  :bind (:map vertico-map
              ("<next>" . vertico-scroll-up)
              ("<prior>" . vertico-scroll-down))
  :init
  (vertico-mode))

;; Typing a path: DEL removes a whole directory, RET enters a directory.
(use-package vertico-directory
  :after vertico
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

;; History survives restarts; vertico sorts candidates by it.
(use-package savehist
  :init
  (savehist-mode))

(defun emacs-cpp-recentf-state-file-p (file)
  "Non-nil if FILE is under `user-emacs-directory''s .cache/ (state, not work)."
  (file-in-directory-p file (expand-file-name ".cache/" user-emacs-directory)))

;; Recently visited files survive restarts (D-041): `C-x b' lists them below the
;; buffers, `C-x C-r' picks one, `C-c p e' those of the project.
(use-package recentf
  :init
  (setopt recentf-max-saved-items 200
          ;; Emacs's own state files (treemacs, caches) are not "recent files".
          recentf-exclude (list #'emacs-cpp-recentf-state-file-p))
  (recentf-mode))

(use-package orderless
  :demand t
  :config
  (setopt completion-styles '(orderless basic)
          completion-category-defaults nil
          completion-category-overrides '((file (styles partial-completion)))
          completion-pcm-leading-wildcard t))

(use-package marginalia
  :init
  (marginalia-mode))

(setopt enable-recursive-minibuffers t
        ;; M-x hides commands that do not apply in the current mode.
        read-extended-command-predicate #'command-completion-default-include-p
        minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))

;;;; Search and jump

(use-package consult
  :bind (("C-x b" . consult-buffer)
         ("C-x C-r" . consult-recent-file)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x p b" . consult-project-buffer)
         ("M-y" . consult-yank-pop)
         ("M-g g" . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ("M-g f" . consult-flymake)
         ("M-g e" . consult-compile-error)
         ("M-g o" . consult-outline)
         ("M-s r" . consult-ripgrep)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s d" . consult-fd)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         :map minibuffer-local-map
         ("M-r" . consult-history))
  :init
  ;; `M-.' / `M-?' with several results: a consult list with preview, not a buffer.
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  :config
  (setq consult-narrow-key "<"))

(use-package embark
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :init
  ;; After a prefix key, `C-h' lists its bindings with completion.
  (setq prefix-help-command #'embark-prefix-help-command))

;;;; In-buffer completion

(use-package corfu
  :init
  ;; No popup while typing (owner, 2026-10-08): completion is asked for with TAB
  ;; (`tab-always-indent' below) or C-M-i.  Set before the mode, which reads it
  ;; when it turns on in a buffer.
  (setq corfu-auto nil)
  (global-corfu-mode)
  (corfu-popupinfo-mode)                ; documentation next to the candidate
  (corfu-history-mode))                 ; recently chosen candidates first

(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file))

(setopt tab-always-indent 'complete     ; TAB indents, then completes
        text-mode-ispell-word-completion nil)

;;;; Snippets

(defun emacs-cpp-snippets--completing-p ()
  "Non-nil while completion is offered in the buffer (corfu's popup is open).
yasnippet's field keys step aside then, so TAB completes there (D-095)."
  completion-in-region-mode)

(defun emacs-cpp-snippets-expand ()
  "Expand the snippet key before point, or say there is none (D-095).
The first call loads yasnippet-snippets' collection."
  (interactive)
  (require 'yasnippet-snippets)
  (unless (yas-maybe-expand-abbrev-key-filter t)
    (user-error "No snippet key before point (%s)" major-mode))
  (yas-expand))

(defun emacs-cpp-snippets-insert ()
  "Choose a snippet by name and insert it, as `yas-insert-snippet' (D-095).
The first call loads yasnippet-snippets' collection."
  (interactive)
  (require 'yasnippet-snippets)
  (call-interactively #'yas-insert-snippet))

;; yasnippet (D-095): the language servers' snippets (clangd's argument placeholders
;; when a completion is chosen, texlab's environments; eglot announces snippet
;; support once yasnippet is there) and yasnippet-snippets' templates.  A snippet's
;; key expands on `C-c y', never on TAB, so TAB indents and completes as before
;; (D-020); inside an expanded snippet TAB / S-TAB move to the next / previous field.
;; The collection takes 130 - 150 ms to scan (Mac), so it loads at the first `C-c y'
;; or `C-c & C-s', not with yasnippet (patch 0001 drops its autoload).
(use-package yasnippet
  :hook ((prog-mode LaTeX-mode bibtex-mode) . yas-minor-mode)
  :config
  (keymap-unset yas-minor-mode-map "TAB" t)
  (keymap-unset yas-minor-mode-map "<tab>" t)
  (keymap-set yas-minor-mode-map "C-c y" #'emacs-cpp-snippets-expand)
  (keymap-set yas-minor-mode-map "<remap> <yas-insert-snippet>" #'emacs-cpp-snippets-insert)
  (add-hook 'yas-keymap-disable-hook #'emacs-cpp-snippets--completing-p))

(provide 'init-completion)
;;; init-completion.el ends here
