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
;;
;; Settings follow the packages' READMEs at the pinned versions.  This module loads
;; before init-project so projectile's prompts already use vertico.

;;; Code:

;;;; Minibuffer

(use-package vertico
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

(provide 'init-completion)
;;; init-completion.el ends here
