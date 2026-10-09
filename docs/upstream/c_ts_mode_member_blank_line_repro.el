;;; c_ts_mode_member_blank_line_repro.el --- class member after a blank line  -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l c_ts_mode_member_blank_line_repro.el
;; Needs the tree-sitter C++ grammar.  Re-indents three structs in each built-in
;; style and prints them: only the one whose body starts with an access
;; specifier and has a blank line before a member goes wrong.  (struct, not
;; class: a class's own-line brace is indented by a separate bug.)

(require 'c-ts-mode)

(defconst repro-sample
  (concat
   "struct A\n{\npublic:\nint f;\n\nint g;\n};\n"   ; access specifier + blank line
   "struct B\n{\npublic:\nint f;\nint g;\n};\n"     ; no blank line
   "struct C\n{\nint f;\n\nint g;\n};\n")           ; no access specifier
  "Three structs; `int g;' should be indented like `int f;' in all of them.")

(message "Emacs %s" emacs-version)
(dolist (style '(gnu k&r linux bsd))
  (with-temp-buffer
    (insert repro-sample)
    (c++-ts-mode)
    (setq-local c-ts-indent-offset 4 indent-tabs-mode nil)
    (c-ts-mode-set-style style)
    (indent-region (point-min) (point-max))
    (message "--- %s:\n%s" style (buffer-string))))

;; Which rule places `int g;' in struct A.
(with-temp-buffer
  (insert repro-sample)
  (c++-ts-mode)
  (setq-local c-ts-indent-offset 4 indent-tabs-mode nil)
  (goto-char (point-min))
  (search-forward "int g")
  (let ((treesit--indent-verbose t))
    (indent-for-tab-command))
  (message "struct A, int g; at column %d" (current-indentation)))

;;; c_ts_mode_member_blank_line_repro.el ends here
