;;; init-cpp.el --- C++ editing with eglot and clangd  -*- lexical-binding: t; -*-

;;; Commentary:

;; C++ buffers use `c++-ts-mode' on the system tree-sitter grammar (D-008), and eglot
;; starts clangd for them with the active CMake preset's build directory (D-016,
;; D-017, lisp/emacs-cpp-presets.el).  Navigation (M-. M-? M-,), rename, code actions
;; and diagnostics are eglot's; the rest of the code commands are on `C-c l' (D-004,
;; T-007), which which-key lists after a pause.

;;; Code:

(require 'emacs-cpp-presets)

;; Fail loudly (DESIGN 4): without the grammar `c++-ts-mode' cannot work.
(unless (treesit-language-available-p 'cpp)
  (error "emacs-cpp: tree-sitter C++ grammar missing; install tree-sitter-cpp (D-008)"))

(add-to-list 'major-mode-remap-alist '(c++-mode . c++-ts-mode))
;; .h is C++ in the owner's projects, and no C grammar is installed (D-008).
(add-to-list 'auto-mode-alist '("\\.h\\'" . c++-ts-mode))

;; Only files of preset projects start eglot (D-005, D-019).
(add-hook 'c++-ts-mode-hook #'emacs-cpp-presets-eglot-ensure)

;; Indentation by data in .dir-locals.el (D-062), working around two gaps of
;; Emacs 31.1's `c++-ts-mode', both reported upstream: a local
;; `c-ts-mode-indent-style' is set but not applied, because the mode builds its
;; rules before local variables are read (T-037); and a `{' on its own line after
;; `namespace' or `class' is indented in every style (T-036).  A third: after a
;; blank line, a class member is aligned with the first thing in the class body,
;; which is `public:' at the class's column when the class starts with one; the
;; fallback rule takes a class body for an initializer list (T-039).

(defcustom emacs-cpp-indent-namespace-body t
  "Non-nil: indent the contents of a namespace one step, as Emacs does.
nil: leave them at the namespace's column, like clang-format's
`NamespaceIndentation: None'.  Meant for a project's .dir-locals.el (D-062)."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

(defun emacs-cpp-indent--apply ()
  "Rebuild this buffer's indent rules from its (possibly local) settings.
Rebuilds from `c-ts-mode-indent-style' each time, so running twice is harmless."
  (c-ts-mode-set-style c-ts-mode-indent-style)
  (treesit-simple-indent-add-rules
   'cpp `(((parent-is "namespace_definition") standalone-parent 0)
          ((parent-is "class_specifier") standalone-parent 0)
          ((and (parent-is "field_declaration_list")
                (not (node-is ,(rx (or "access_specifier" "}" "preproc")))))
           parent-bol c-ts-indent-offset)
          ,@(unless emacs-cpp-indent-namespace-body
              '(((n-p-gp nil "declaration_list" "namespace_definition")
                 parent-bol 0))))))

(defun emacs-cpp-indent-setup ()
  "Apply the indent rules now and again once local variables are in (D-062).
Mode hooks run before a visited file's local variables are read."
  (emacs-cpp-indent--apply)
  (add-hook 'hack-local-variables-hook #'emacs-cpp-indent--apply nil t))

(add-hook 'c++-ts-mode-hook #'emacs-cpp-indent-setup)

;; RET indents by the project's .clang-format (D-061).  Eglot already asks the
;; server to format on newline (on-type formatting), but electric indentation runs
;; after it and re-indents the new line by the tree-sitter rules, which do not read
;; .clang-format.  So newline leaves `electric-indent-chars' in managed buffers, and
;; since clangd also reformats the line above (collapsing hand alignment), that line
;; is put back as typed.  TAB and the other electric characters keep Emacs's rules.

(defvar-local emacs-cpp-ret--line-above nil
  "Marker at the line above point and its text, saved before eglot's request.")

(defun emacs-cpp-ret--server-formats-newline-p ()
  "Non-nil when this buffer's server formats on newline, as eglot asks it to."
  (let ((provider (eglot-server-capable :documentOnTypeFormattingProvider)))
    (and provider
         (or (equal (plist-get provider :firstTriggerCharacter) "\n")
             (seq-contains-p (plist-get provider :moreTriggerCharacter) "\n")))))

(defun emacs-cpp-ret--save-line-above ()
  "After a newline, save the line it ended, before the server can change it.
Any other insertion clears what an earlier one saved, so a failed request
cannot leave a line to be restored later."
  (setq emacs-cpp-ret--line-above
        (and (eq last-command-event ?\n)
             (save-excursion
               (forward-line -1)
               (cons (copy-marker (pos-bol))
                     (buffer-substring-no-properties (pos-bol) (pos-eol)))))))

(defun emacs-cpp-ret--restore-line-above ()
  "Put back the line above as typed; keep the new line's indentation.
clangd may have split that line (a `{' moved to its own line), so everything
from its start up to the new line is replaced, not only its first line."
  (pcase-let ((`(,start . ,text) emacs-cpp-ret--line-above))
    (when start
      (setq emacs-cpp-ret--line-above nil)
      (let ((column (current-indentation))
            (end (1- (pos-bol))))
        (unless (equal (buffer-substring-no-properties start end) text)
          (save-excursion
            (delete-region start end)
            (goto-char start)
            (insert text)))
        (set-marker start nil)
        (indent-line-to column)))))

(defun emacs-cpp-ret-by-server ()
  "Let the server indent RET in this C++ buffer while eglot manages it (D-061).
Runs from `eglot-managed-mode-hook', so also when eglot lets the buffer go."
  (when (derived-mode-p 'c++-ts-mode)
    (if (and (eglot-managed-p) (emacs-cpp-ret--server-formats-newline-p))
        (progn
          (setq-local electric-indent-chars (remq ?\n electric-indent-chars))
          ;; Around eglot's own request (depth 0), before electric indentation (60).
          (add-hook 'post-self-insert-hook #'emacs-cpp-ret--save-line-above -50 t)
          (add-hook 'post-self-insert-hook #'emacs-cpp-ret--restore-line-above 50 t))
      (unless (memq ?\n electric-indent-chars)
        (setq-local electric-indent-chars (cons ?\n electric-indent-chars)))
      (remove-hook 'post-self-insert-hook #'emacs-cpp-ret--save-line-above t)
      (remove-hook 'post-self-insert-hook #'emacs-cpp-ret--restore-line-above t))))

(use-package eglot
  ;; Not autoloaded by eglot; `C-c l' (below) can come before eglot has loaded.
  :commands (eglot-rename eglot-code-actions eglot-format eglot-find-implementation
             eglot-find-declaration eglot-show-call-hierarchy eglot-show-type-hierarchy
             eglot-inlay-hints-mode)
  :config
  (add-hook 'eglot-managed-mode-hook #'emacs-cpp-ret-by-server)
  ;; Ahead of eglot's own clangd entry, which starts clangd without a database.
  (add-to-list 'eglot-server-programs
               '(c++-ts-mode . emacs-cpp-presets-clangd-contact))
  ;; Python rides along with pyright (D-045), named so that another server eglot
  ;; knows (pylsp, basedpyright) does not take over when installed later.
  (add-to-list 'eglot-server-programs
               '((python-ts-mode python-mode) . ("pyright-langserver" "--stdio")))
  ;; No JSON event log (the eglot manual's first performance advice); shut clangd
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

;; Header line: project-relative path, then the class and function at point (D-043).
(use-package breadcrumb
  :hook (c-ts-base-mode . breadcrumb-local-mode))

(use-package flymake
  :commands flymake-show-project-diagnostics)

(use-package consult-eglot
  :after (consult eglot))

(defvar-keymap emacs-cpp-code-map
  :doc "Code commands on `C-c l' (D-004).  Eglot's need a managed buffer."
  "r" #'eglot-rename
  "a" #'eglot-code-actions
  "f" #'eglot-format
  "i" #'eglot-find-implementation
  "d" #'eglot-find-declaration
  "h" #'eglot-show-call-hierarchy
  "t" #'eglot-show-type-hierarchy
  ;; By name across the project: RMO keeps headers in include/rmo/, sources in src/.
  "o" #'projectile-find-other-file
  "s" #'consult-eglot-symbols
  "e" #'flymake-show-project-diagnostics
  ;; Eglot turns inlay hints on in every managed buffer; this hides / shows them.
  "I" #'eglot-inlay-hints-mode
  "P" #'emacs-cpp-presets-select)
(keymap-global-set "C-c l" emacs-cpp-code-map)

(provide 'init-cpp)
;;; init-cpp.el ends here
