;;; init-cpp.el --- C++ editing with eglot and clangd  -*- lexical-binding: t; -*-

;;; Commentary:

;; C++ buffers use `c++-ts-mode' on the system tree-sitter grammar (D-008), and eglot
;; starts clangd for them with the active CMake preset's build directory (D-016,
;; D-017, lisp/emacs-cpp-presets.el).  Navigation (M-. M-? M-,), rename, code actions
;; and diagnostics are eglot's (lisp/init-lsp.el); the code commands are on `C-c l'
;; (D-004, T-007), two of them C++'s own (below).

;;; Code:

(require 'emacs-cpp-presets)
(require 'init-lsp)

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

(defcustom emacs-cpp-indent-case-labels nil
  "Non-nil: indent `case' labels one step in from their `switch'.
nil: at the `switch''s column, as Emacs does.  Like clang-format's
`IndentCaseLabels'.  Meant for a project's .dir-locals.el (T-040)."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

(defun emacs-cpp-indent--offset-p (value)
  "Non-nil when VALUE is nil or an integer: safe for the offset options."
  (or (null value) (integerp value)))

(defcustom emacs-cpp-indent-access-offset nil
  "Where `public:', `private:', `protected:' go, as clang-format's
`AccessModifierOffset': the step plus this, from the class's column (-1 with a
step of 2 puts them one column in).  nil: at the class's column, as Emacs does.
Meant for a project's .dir-locals.el."
  :type '(choice (const :tag "At the class's column" nil) integer)
  :safe #'emacs-cpp-indent--offset-p
  :group 'tools)

(defcustom emacs-cpp-indent-initializer-offset nil
  "How far a constructor's `: member(...)' line goes in from the declaration,
as clang-format's `ConstructorInitializerIndentWidth'.  nil: the indent step.
Meant for a project's .dir-locals.el."
  :type '(choice (const :tag "The indent step" nil) integer)
  :safe #'emacs-cpp-indent--offset-p
  :group 'tools)

(defcustom emacs-cpp-indent-continuation-offset nil
  "How far arguments go in after a `(' that ends a line, as clang-format's
`ContinuationIndentWidth'.  nil: the indent step.  Meant for a project's
.dir-locals.el."
  :type '(choice (const :tag "The indent step" nil) integer)
  :safe #'emacs-cpp-indent--offset-p
  :group 'tools)

(defcustom emacs-cpp-indent-align-arguments t
  "Non-nil: arguments on later lines align with the first one after the `(',
as Emacs does.  nil: they go in by `emacs-cpp-indent-continuation-offset' from
the statement, as clang-format's `AlignAfterOpenBracket: DontAlign'.  Meant
for a project's .dir-locals.el."
  :type 'boolean
  :safe #'booleanp
  :group 'tools)

;; Offsets for the rules below, read when a line is indented.
(defun emacs-cpp-indent--access (&rest _)
  "Offset of an access specifier from the class's column."
  (if emacs-cpp-indent-access-offset
      (+ c-ts-indent-offset emacs-cpp-indent-access-offset)
    0))

(defun emacs-cpp-indent--initializer (&rest _)
  "Offset of a constructor's initializer line from the declaration."
  (or emacs-cpp-indent-initializer-offset c-ts-indent-offset))

(defun emacs-cpp-indent--continuation (&rest _)
  "Offset of arguments after a `(' that ends a line."
  (or emacs-cpp-indent-continuation-offset c-ts-indent-offset))

(defun emacs-cpp-indent--first-argument-p (node parent &rest _)
  "Non-nil when NODE, at the start of its line, is the first in an argument or
parameter list: the `(' ended the line before."
  (and (treesit-node-match-p parent (rx bos (or "argument_list" "parameter_list") eos))
       (treesit-node-eq node (treesit-node-child parent 0 t))))

(defun emacs-cpp-indent--later-argument-p (node parent &rest _)
  "Non-nil when NODE, at the start of its line, is a later argument or parameter
of a list, not its first and not its closing `)'."
  (and (treesit-node-match-p parent (rx bos (or "argument_list" "parameter_list") eos))
       (not (treesit-node-eq node (treesit-node-child parent 0 t)))
       (not (treesit-node-match-p node (rx bos (or ")" "comment") eos)))))

(defun emacs-cpp-indent--apply ()
  "Rebuild this buffer's indent rules from its (possibly local) settings.
Rebuilds from `c-ts-mode-indent-style' each time, so running twice is harmless."
  (c-ts-mode-set-style c-ts-mode-indent-style)
  ;; Arguments after a `(' that ends a line go one step in, the others align with
  ;; the first argument: clang-format's way in every style (T-040).
  (setq-local c-ts-common-list-indent-style 'simple)
  ;; Tab stops at the indent step, so `M-i' and `C-x TAB' then `S-<right>' move a
  ;; line by one step by hand; Emacs repeats the last interval (D-066).
  (setq-local tab-stop-list (list c-ts-indent-offset (* 2 c-ts-indent-offset)))
  (treesit-simple-indent-add-rules
   'cpp `(((parent-is "namespace_definition") standalone-parent 0)
          ((parent-is "class_specifier") standalone-parent 0)
          ((node-is "access_specifier") parent-bol emacs-cpp-indent--access)
          ((and (parent-is "field_declaration_list")
                (not (node-is ,(rx (or "access_specifier" "}" "preproc")))))
           parent-bol c-ts-indent-offset)
          (emacs-cpp-indent--first-argument-p standalone-parent
                                              emacs-cpp-indent--continuation)
          ,@(unless emacs-cpp-indent-align-arguments
              '((emacs-cpp-indent--later-argument-p standalone-parent
                                                    emacs-cpp-indent--continuation)))
          ;; A constructor's `: member(...)' in from the declaration, comments
          ;; before it too (T-040).
          ((node-is "field_initializer_list") standalone-parent
           emacs-cpp-indent--initializer)
          ;; Later lines: `, member(...)' and comments under the `:'; a member
          ;; after `member(...),' aligned with the first one.
          ((and (parent-is "field_initializer_list") (node-is ,(rx (or "," "comment"))))
           parent-bol 0)
          ((parent-is "field_initializer_list") (nth-sibling 0 t) 0)
          ((and (node-is "comment") (parent-is "function_definition"))
           standalone-parent emacs-cpp-indent--initializer)
          ;; A `requires' clause on its own line, one step in (T-040).
          ((node-is "requires_clause") standalone-parent c-ts-indent-offset)
          ,@(when emacs-cpp-indent-case-labels
              '(((node-is "case_statement") standalone-parent c-ts-indent-offset)))
          ,@(unless emacs-cpp-indent-namespace-body
              '(((n-p-gp nil "declaration_list" "namespace_definition")
                 parent-bol 0))))))

(defun emacs-cpp-indent-setup ()
  "Apply the indent rules now and again once local variables are in (D-062).
Mode hooks run before a visited file's local variables are read."
  (emacs-cpp-indent--apply)
  (add-hook 'hack-local-variables-hook #'emacs-cpp-indent--apply nil t))

(add-hook 'c++-ts-mode-hook #'emacs-cpp-indent-setup)

;; clangd with the active preset's build directory, ahead of eglot's own clangd
;; entry, which starts clangd without a database (D-016, D-091).
(emacs-cpp-lsp-server 'c++-ts-mode #'emacs-cpp-presets-clangd-contact)
;; A source missing from the preset's database gets a warning, not silence (D-068).
(add-hook 'eglot-managed-mode-hook #'emacs-cpp-presets-warn-if-not-in-database)

;; Header line: project-relative path, then the class and function at point (D-043).
(use-package breadcrumb
  :hook (c-ts-base-mode . breadcrumb-local-mode))

;; C++'s own code commands on `C-c l' (D-004): by name across the project (RMO
;; keeps headers in include/rmo/, sources in src/), and the active CMake preset.
(keymap-set emacs-cpp-code-map "o" #'projectile-find-other-file)
(keymap-set emacs-cpp-code-map "P" #'emacs-cpp-presets-select)

(provide 'init-cpp)
;;; init-cpp.el ends here
