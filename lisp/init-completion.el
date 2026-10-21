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

;;;; Match tiers (D-120)

;; A match is LSP 3.18's: the input's letters in order, case ignored.  Matches rank
;; in three tiers, as clangd ranks symbols with patch 0013: (1) the input runs
;; unbroken from a word start; (2) it runs unbroken inside a word, or its letters
;; start several words (`vt' in VectorTools); (3) letters in order with gaps inside
;; a word (`eto' in Vector).  Word starts as clangd's: the string's start, after a
;; character that is no letter or digit, a capital after a small letter or digit,
;; and the last of several capitals before a small letter (S in HTTPServer).

;; Each word of the input becomes four regexps, built once per input: tier 1, a
;; word start then the rest; tier 2, the word anywhere, or its letters each at a
;; word start; tier 3, its letters in order with gaps only over letters and digits,
;; so never across a separator (D-141; the prompts' filter is the same rule,
;; `emacs-cpp-orderless-in-word').  A candidate only a typed regexp matches is tier
;; 4.  Matching then runs in C; a loop over characters in Lisp took 0.5 ms per
;; candidate.

(defun emacs-cpp--match-class (char &optional lower-only)
  "Return a case-sensitive regexp for CHAR in either case, or LOWER-ONLY."
  (let ((lower (downcase char)) (upper (upcase char)))
    (cond ((= lower upper) (regexp-quote (char-to-string char)))
          (lower-only (char-to-string lower))
          (t (format "[%c%c]" lower upper)))))

(defun emacs-cpp--match-word-start (char &optional next)
  "Return a case-sensitive regexp for CHAR at a word start, NEXT the class after it.
After the start or a character that is no letter or digit; as a capital after a
small letter or digit; as a capital ending a run of capitals before a small letter
\(then NEXT, lower case, or any small letter, is matched too)."
  (let ((any (emacs-cpp--match-class char))
        (upper (char-to-string (upcase char))))
    (if (= (downcase char) (upcase char))
        (concat "\\(?:\\`\\|[^[:alnum:]]\\)" any)
      (concat "\\(?:\\(?:\\`\\|[^[:alnum:]]\\)" any
              "\\|[[:lower:][:digit:]]" upper
              "\\|[[:upper:]]" upper (or next "[[:lower:]]") "\\)"))))

(defun emacs-cpp--match-compile (component)
  "Return COMPONENT's tier-1, unbroken, initials and in-word regexps
\(case-sensitive, case-insensitive, case-sensitive, case-insensitive)."
  (let* ((chars (string-to-list component))
         (first (car chars))
         (letter (/= (downcase first) (upcase first)))
         (upper (char-to-string (upcase first)))
         (rest (mapconcat #'emacs-cpp--match-class (cdr chars) "")))
    (list
     (concat "\\(?:\\(?:\\`\\|[^[:alnum:]]\\)" (emacs-cpp--match-class first) rest
             (if letter
                 (concat "\\|[[:lower:][:digit:]]" upper rest
                         ;; Ending a run of capitals: the next character is small.
                         "\\|[[:upper:]]" upper
                         (if (cdr chars)
                             (concat (emacs-cpp--match-class (cadr chars) t)
                                     (mapconcat #'emacs-cpp--match-class (cddr chars) ""))
                           "[[:lower:]]"))
               "")
             "\\)")
     (regexp-quote component)
     (mapconcat #'emacs-cpp--match-word-start chars ".*")
     (mapconcat (lambda (char) (regexp-quote (char-to-string char))) chars
                "[[:alnum:]]*"))))

(defvar emacs-cpp--match-cache nil
  "The last input and its compiled words, as (INPUT . REGEXPS).")

(defun emacs-cpp-match-tier (input candidate)
  "Return the tier, 1 - 4, of CANDIDATE for INPUT (D-120, D-141); 1 for no INPUT.
INPUT's words, separated by spaces, each match somewhere; the worst decides."
  (unless (equal (car emacs-cpp--match-cache) input)
    (setq emacs-cpp--match-cache
          (cons input (mapcar #'emacs-cpp--match-compile (split-string input " " t)))))
  (let ((tier 1))
    (dolist (regexps (cdr emacs-cpp--match-cache) tier)
      (unless (let ((case-fold-search nil)) (string-match-p (nth 0 regexps) candidate))
        (setq tier (max tier
                        (if (or (let ((case-fold-search t))
                                  (string-match-p (nth 1 regexps) candidate))
                                (let ((case-fold-search nil))
                                  (string-match-p (nth 2 regexps) candidate)))
                            2
                          (if (let ((case-fold-search t))
                                (string-match-p (nth 3 regexps) candidate))
                              3
                            4))))))))

(defun emacs-cpp-match-sort-by-tier (input candidates &optional key)
  "Return CANDIDATES sorted by tier for INPUT, in their order within a tier.
KEY, if given, maps a candidate to the string to rank (default: itself)."
  (if (string-blank-p input)
      candidates
    (sort candidates
          :key (lambda (candidate)
                 (emacs-cpp-match-tier input (if key (funcall key candidate) candidate))))))

(defconst emacs-cpp-match-ordered-categories
  '(consult-location consult-grep consult-xref xref-location consult-compile-error
    consult-flymake-error kill-ring)
  "Completion categories whose candidates keep their order: places in a buffer
or a search's hits, not names to rank (D-120).")

(defun emacs-cpp-completion-sort (candidates)
  "Sort CANDIDATES as the prompt sorts them, then stably by tier (D-120).
Vertico's `vertico-sort-override-function'.  File names typed as paths
\(`C-x C-f') and the categories of `emacs-cpp-match-ordered-categories' keep
the prompt's order."
  (let* ((base (or (completion-metadata-get vertico--metadata 'display-sort-function)
                   vertico-sort-function))
         (sorted (if base (funcall base candidates) candidates)))
    (if (or minibuffer-completing-file-name
            (memq (completion-metadata-get vertico--metadata 'category)
                  emacs-cpp-match-ordered-categories))
        sorted
      (emacs-cpp-match-sort-by-tier
       (buffer-substring-no-properties (minibuffer-prompt-end) (point-max))
       sorted))))

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
  ;; Ranked by tier after the prompt's own order (D-120).
  (setopt vertico-sort-override-function #'emacs-cpp-completion-sort)
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

(defun emacs-cpp-orderless-in-word (component)
  "Match COMPONENT's characters in order, with gaps only over letters and digits.
D-120's tier 3, as an orderless matching style in place of `orderless-flex', whose
gaps crossed words and `/' (`ect' matched ~/sourc_e_/.../in_c_lude/.../me_t_ric.h,
D-141).  Groups mark the characters, for highlighting."
  `(seq ,@(cdr (cl-loop for char across component
                        append `((zero-or-more alnum) (group ,char))))))

(use-package orderless
  :demand t
  :config
  ;; LSP 3.18's match (D-120): letters in order, gaps inside a word (D-141), besides
  ;; literal, regexp and initials, case always ignored.  Paths typed in `C-x C-f'
  ;; keep partial-completion (`/u/s/e'), the one exception.
  (setopt completion-styles '(orderless basic)
          completion-category-defaults nil
          completion-category-overrides '((file (styles partial-completion)))
          completion-pcm-leading-wildcard t
          orderless-matching-styles '(orderless-literal orderless-regexp
                                      orderless-initialism emacs-cpp-orderless-in-word)
          orderless-smart-case nil
          completion-ignore-case t
          read-buffer-completion-ignore-case t))

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
