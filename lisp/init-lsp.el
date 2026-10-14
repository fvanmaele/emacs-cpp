;;; init-lsp.el --- eglot for every language, and the code commands  -*- lexical-binding: t; -*-

;;; Commentary:

;; eglot's one form (DESIGN 4, principle 3) with what holds for every language
;; server, and the code commands on `C-c l' (D-004, T-007), which which-key lists
;; after a pause.  Each language module names its own server and settings through
;; `emacs-cpp-lsp-server' and `emacs-cpp-lsp-settings' and adds its own keys to
;; `emacs-cpp-code-map' (D-091): clangd in lisp/init-cpp.el, pyright in
;; lisp/init-python.el, texlab in lisp/init-latex.el.

;;; Code:

(defun emacs-cpp-lsp-server (modes contact)
  "Make eglot start CONTACT for buffers in MODES, ahead of its own entries (D-091).
MODES and CONTACT as in `eglot-server-programs'; the latest call wins for a mode."
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs (cons modes contact))))

(defun emacs-cpp-lsp-settings (section settings)
  "Answer the servers that ask for SECTION with the plist SETTINGS (D-091).
Through the default `eglot-workspace-configuration'; a project's .dir-locals.el
can still set its own."
  (with-eval-after-load 'eglot
    (setq-default eglot-workspace-configuration
                  (plist-put (copy-sequence (default-value 'eglot-workspace-configuration))
                             section settings))))

(use-package eglot
  ;; Not autoloaded by eglot; `C-c l' (below) can come before eglot has loaded.
  :commands (eglot-rename eglot-code-actions eglot-format eglot-format-buffer
             eglot-find-implementation eglot-find-typeDefinition eglot-find-declaration
             eglot-show-call-hierarchy eglot-show-type-hierarchy eglot-inlay-hints-mode)
  :config
  ;; RET indents by Emacs's rules (electric indentation, D-062's rules), not by the
  ;; server: on each newline eglot would ask it to format, and clangd then also
  ;; rewrites the line just ended (hand alignment collapsed, `{' moved to its own
  ;; line) (D-065, superseding D-061).
  (add-to-list 'eglot-ignored-server-capabilities :documentOnTypeFormattingProvider)
  ;; No JSON event log (the eglot manual's first performance advice); shut a server
  ;; down when its last buffer closes.
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t
        ;; Library headers reached with M-. (deal.II, Boost) join the project's
        ;; clangd, so M-. keeps working inside them (D-019).
        eglot-extend-to-xref t)
  ;; macOS watches files with kqueue, one file descriptor per directory, and Emacs
  ;; refuses watches beyond 975: pyright asks to watch Python's library and
  ;; site-packages, about 2000 directories, and exits when the request fails.
  ;; Watch only the project, and cap the watches well below 975 (D-054).  At the
  ;; cap eglot also fails the request (pyright then exits too); pyright registers
  ;; three times, so this holds projects up to about 160 directories (O-26).
  (when (eq system-type 'darwin)
    (setq eglot-watch-files-outside-project-root nil
          eglot-max-file-watches 500)))

(use-package flymake
  :commands flymake-show-project-diagnostics)

(use-package consult-eglot
  :after (consult eglot))

(defun emacs-cpp-lsp--defined-here-p (identifier)
  "Non-nil when every definition of IDENTIFIER is on the line at point."
  (let ((definitions (xref-backend-definitions (xref-find-backend) identifier))
        (file (buffer-file-name))
        (line (line-number-at-pos)))
    (and definitions
         (seq-every-p (lambda (item)
                        (let ((location (xref-item-location item)))
                          (and (equal (xref-location-group location) file)
                               (eql (xref-location-line location) line))))
                      definitions))))

(defun emacs-cpp-lsp-mouse-definition-or-references (event)
  "Go to the definition of the symbol clicked, or list its references when the
click is on its definition, as CLion's Cmd+Click (D-093)."
  (interactive "e")
  (require 'xref)
  (mouse-set-point event)
  (let ((identifier (xref-backend-identifier-at-point (xref-find-backend))))
    (unless identifier
      (user-error "No symbol here"))
    (if (emacs-cpp-lsp--defined-here-p identifier)
        (xref-find-references identifier)
      (xref-find-definitions identifier))))

(defun emacs-cpp-lsp-mouse-implementation (event)
  "Go to the implementations of the symbol clicked (D-093)."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-implementation))

(defun emacs-cpp-lsp-mouse-type-definition (event)
  "Go to the type of the symbol clicked (D-093)."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-typeDefinition))

;; Navigation clicks, CLion's (D-093): Cmd on the Mac, Super on Arch
;; (`emacs-cpp-default-mouse-modifier', D-055); with Opt / Alt implementations,
;; with Shift the type.  The press is unbound so the click arrives (none of these
;; presses is bound by Emacs).
(defun emacs-cpp-lsp--mouse-key (modifiers event)
  "Return the key description of EVENT with MODIFIERS, in Emacs's order."
  (key-description
   (vector (event-convert-list
            (append (cons emacs-cpp-default-mouse-modifier modifiers) (list event))))))

(pcase-dolist (`(,modifiers . ,command)
               '((() . emacs-cpp-lsp-mouse-definition-or-references)
                 ((meta) . emacs-cpp-lsp-mouse-implementation)
                 ((shift) . emacs-cpp-lsp-mouse-type-definition)))
  (keymap-global-unset (emacs-cpp-lsp--mouse-key modifiers 'down-mouse-1) t)
  (keymap-global-set (emacs-cpp-lsp--mouse-key modifiers 'mouse-1) command))

(defun emacs-cpp-lsp-context-menu (menu click)
  "Add the language server's commands for the spot CLICKed to MENU (D-093).
Only in a buffer eglot manages; each entry first moves point to the click."
  (when (and (fboundp 'eglot-managed-p) (eglot-managed-p))
    (let ((at-click (lambda (command)
                      (lambda ()
                        (interactive)
                        (mouse-set-point click)
                        (call-interactively command)))))
      (define-key-after menu [emacs-cpp-lsp-separator] menu-bar-separator)
      (define-key-after menu [emacs-cpp-lsp-rename]
        `(menu-item "Rename Symbol..." ,(funcall at-click #'eglot-rename)))
      (define-key-after menu [emacs-cpp-lsp-actions]
        `(menu-item "Code Actions..." ,(funcall at-click #'eglot-code-actions)))
      (define-key-after menu [emacs-cpp-lsp-implementation]
        `(menu-item "Go to Implementation"
                    ,(funcall at-click #'eglot-find-implementation)))
      (define-key-after menu [emacs-cpp-lsp-format]
        `(menu-item "Format Buffer" eglot-format-buffer))))
  menu)

;; Right click's menu (lisp/init-ui.el) gets them after Emacs's own entries.
(add-hook 'context-menu-functions #'emacs-cpp-lsp-context-menu 90)

(defvar-keymap emacs-cpp-code-map
  :doc "Code commands on `C-c l' (D-004).  Eglot's need a managed buffer.
Language modules add their own (D-091)."
  "r" #'eglot-rename
  "a" #'eglot-code-actions
  "f" #'eglot-format
  "i" #'eglot-find-implementation
  "d" #'eglot-find-declaration
  "h" #'eglot-show-call-hierarchy
  "t" #'eglot-show-type-hierarchy
  "s" #'consult-eglot-symbols
  "e" #'flymake-show-project-diagnostics
  ;; Eglot turns inlay hints on in every managed buffer; this hides / shows them.
  "I" #'eglot-inlay-hints-mode)
(keymap-global-set "C-c l" emacs-cpp-code-map)

(provide 'init-lsp)
;;; init-lsp.el ends here
