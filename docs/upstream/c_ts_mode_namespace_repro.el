;;; c_ts_mode_namespace_repro.el --- c++-ts-mode indents braces after namespace / class  -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l c_ts_mode_namespace_repro.el
;; Needs the tree-sitter C++ grammar.  Prints, for each built-in style, the
;; sample re-indented by `indent-region', then the same with three added rules.

(require 'c-ts-mode)

(defconst repro-sample
  "namespace a\n{\nclass B\n{\npublic:\n    int f()\n    {\n        return 1;\n    }\n};\n}\n"
  "Code with braces on their own lines and an unindented namespace body.")

(defun repro-indent (style &optional extra-rules)
  "Return `repro-sample' re-indented in STYLE, with EXTRA-RULES added first."
  (with-temp-buffer
    (insert repro-sample)
    (c++-ts-mode)
    (setq-local c-ts-indent-offset 4 indent-tabs-mode nil)
    (c-ts-mode-set-style style)
    (when extra-rules
      (treesit-simple-indent-add-rules 'cpp extra-rules))
    (indent-region (point-min) (point-max))
    (buffer-string)))

(message "Emacs %s" emacs-version)
(dolist (style '(gnu k&r linux bsd))
  (message "--- %s:\n%s" style (repro-indent style)))
(message "--- bsd with three added rules:\n%s"
         (repro-indent 'bsd '(((parent-is "namespace_definition") standalone-parent 0)
                              ((parent-is "class_specifier") standalone-parent 0)
                              ((n-p-gp nil "declaration_list" "namespace_definition")
                               parent-bol 0))))

;;; c_ts_mode_namespace_repro.el ends here
