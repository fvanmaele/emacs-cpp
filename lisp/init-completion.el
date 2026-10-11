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
;; Go to anything on `M-o' (D-074 .. D-078) combines them in one prompt.
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

;;;; Go to anything

;; CLion's "search everywhere" on `M-o' (D-074 .. D-078): one prompt over buffers,
;; recent files, bookmarks and the project's files from the first key, clangd's
;; symbols from the third; commands (`x') and known projects (`p') behind narrow
;; keys.  Spike S11 measured it on RMO and the deal.II tree: the settings bound in
;; `emacs-cpp-go-to-anything' keep each key under 25 ms on RMO (0049).

(defun emacs-cpp-go--highlight-first (limit)
  "Return a consult regexp compiler that highlights only LIMIT strings per input.
Highlighting every hit of a one-letter input is most of the filter's time (S11);
with `:sort nil' the first hits are the ones on screen."
  (lambda (input type ignore-case)
    (pcase-let ((`(,regexps . ,highlight)
                 (consult--default-regexp-compiler input type ignore-case))
                (count 0))
      (cons regexps
            (and highlight
                 (lambda (string)
                   (setq count (1+ count))
                   (when (<= count limit)
                     (funcall highlight string))))))))

(defun emacs-cpp-go--symbol-request (servers)
  "Return an async step asking SERVERS for the workspace symbols of each input.
An empty input sends nothing (D-077): consult-eglot's own source asks for \"\"
when its prompt opens, which lists 100 arbitrary symbols.  A reply to an input
that has since changed is dropped."
  (lambda (sink)
    (let (latest)
      (lambda (action)
        (when (and (stringp action) (not (equal action "")))
          (let ((query action) (replies nil))
            (setq latest query)
            (dolist (server servers)
              (jsonrpc-async-request
               server :workspace/symbol `(:query ,query)
               :success-fn
               (lambda (reply)
                 (when (equal query latest)
                   (setq replies (sort (append replies reply nil)
                                       :key (lambda (symbol)
                                              (- (or (plist-get symbol :score) 0)))))
                   (funcall sink 'flush)
                   (funcall sink replies)))
               :error-fn
               (lambda (error)
                 (message "emacs-cpp: workspace/symbol %S failed: %S" query error))
               :timeout-fn
               (lambda ()
                 (message "emacs-cpp: workspace/symbol %S timed out" query))))))
        (funcall sink action)))))

(defun emacs-cpp-go--symbol-source ()
  "Return the clangd symbol source, or nil when no server of the project has one.
The candidates and their preview come from consult-eglot."
  (when (featurep 'eglot)
    (require 'consult-eglot)
    (when-let* ((servers (consult-eglot--servers)))
      (list :name "Symbol" :narrow ?s :category 'consult-eglot-symbols
            :state (lambda ()
                     (let ((state (consult-eglot--state)))
                       (lambda (action candidate)
                         (funcall state action
                                  (and candidate
                                       (get-text-property 0 'consult--candidate
                                                          candidate))))))
            :emacs-cpp-action (lambda (_) (run-hooks 'consult-after-jump-hook))
            :async (consult--async-pipeline
                    (consult--async-min-input 3)
                    (consult--async-throttle 0.05 0.05)
                    (emacs-cpp-go--symbol-request servers)
                    (consult--async-map #'consult-eglot--transformer))))))

(defun emacs-cpp-go--file-source (root)
  "Return the source of ROOT's files, listed now, or nil when ROOT is nil.
Listed before the prompt opens: inside it consult computes a static source
under `while-no-input' and lists again when interrupted (S11 run 2)."
  (when root
    (list :name "Project File" :narrow ?f :category 'file :face 'consult-file
          :history 'file-name-history :state #'consult--file-state
          :items (mapcar (lambda (file) (cons file (concat root file)))
                         (projectile-project-files root)))))

(defun emacs-cpp-go--commands (buffer)
  "Return the names of the commands `M-x' offers in BUFFER."
  (let (names)
    (mapatoms (lambda (symbol)
                (when (and (commandp symbol)
                           (or (null read-extended-command-predicate)
                               (funcall read-extended-command-predicate symbol buffer)))
                  (push (symbol-name symbol) names))))
    names))

(defun emacs-cpp-go--sources (buffer root)
  "Return the sources of the go-to-anything prompt for BUFFER in project ROOT."
  (delq nil
        (list consult-source-buffer
              ;; consult's recent files narrow with `f', taken here by the project's.
              (append '(:name "Recent File" :narrow ?r) consult-source-recent-file)
              consult-source-bookmark
              (emacs-cpp-go--file-source root)
              (with-current-buffer buffer (emacs-cpp-go--symbol-source))
              (list :name "Command" :narrow ?x :hidden t :category 'command
                    :history 'extended-command-history
                    :items (lambda () (emacs-cpp-go--commands buffer))
                    :emacs-cpp-action (lambda (name) (command-execute (intern name) 'record)))
              (list :name "Project" :narrow ?p :hidden t :category 'file
                    :items #'projectile-relevant-known-projects
                    :emacs-cpp-action #'projectile-switch-project-by-name))))

(defun emacs-cpp-go-to-anything ()
  "Go to a buffer, recent file, bookmark, project file or clangd symbol.
Commands (narrow with `x') and known projects (`p') are hidden until narrowed.
Narrow with `<' and the letter (b r m f s x p), or the letter and SPC; `<' first
does not filter the files by the letter (D-079).  `< <' widens again.
Symbols need three characters and a running eglot server.  The settings of
D-077 hold only while the prompt is open; the command or project chosen runs
after it, with the usual ones."
  (interactive)
  (require 'consult)
  (let* ((buffer (current-buffer))
         (root (projectile-project-root))
         (selected
          ;; No collection while the files are listed or while typing (S11: 69 %
          ;; of a key's time; 6 collections at opening on 34583 files).
          (let ((gc-cons-threshold (* 64 1024 1024)))
            (let ((sources (emacs-cpp-go--sources buffer root))
                  (default-directory (or root default-directory))
                  (consult--regexp-compiler (emacs-cpp-go--highlight-first 100))
                  ;; clangd answers in under 25 ms; consult's 0.2 s was the wait.
                  (consult-async-refresh-delay 0.05)
                  ;; No `#' in front of the input (D-078).
                  (consult-async-split-style nil))
              (consult--multi sources :prompt "Go to: " :require-match t :sort nil)))))
    (when-let* ((action (plist-get (cdr selected) :emacs-cpp-action)))
      (funcall action (car selected)))))

(keymap-global-set "M-o" #'emacs-cpp-go-to-anything)

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
