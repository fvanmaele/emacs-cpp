# c++-ts-mode report draft: a member after a blank line aligns with `public:`

Draft for the Emacs bug tracker: `M-x report-emacs-bug`, or mail to
bug-gnu-emacs@gnu.org. Not sent; the owner sends it (D-062, T-039). Reproduction:
`c_ts_mode_member_blank_line_repro.el` in this directory. Searched the tracker
2026-10-10: #59966 (members right after an access specifier, fixed 2022-12-12) and
#76908 (a comment after an opening delimiter, fixed 2025) touch the same code; neither
reports this.

---

**Subject:** 31.1; c++-ts-mode: class member after a blank line is aligned with the
access specifier

### Environment
- GNU Emacs 31.1 (Arch Linux), tree-sitter-cpp grammar from the distribution.
- Same result with `lisp/progmodes/c-ts-common.el` from master at
  388717429c9c9a5eb2900953c07891f6fcb2046f and `c-ts-mode.el` at
  5465a93e06f93b6d5a6880a1bc73d9ff1f341987 loaded over 31.1.

### What happens
In a class or struct body that starts with an access specifier, a member that
follows a blank line is indented to the column of the access specifier instead of
one step in. All four styles, `c-ts-indent-offset` 4:

```
struct A                  struct B                  struct C
{                         {                         {
public:                   public:                       int f;
    int f;                    int f;
                              int g;                    int g;
int g;      <- wrong      };                        };
};
```

Without the blank line (B) or without the access specifier (C), `int g;` is placed
correctly. In practice: typing a new member after a blank line puts it at column 0,
and `indent-region` moves existing ones there.

### Cause
`treesit--indent-verbose` names `c-ts-common-baseline-indent-rule`. After a blank
line, condition 1 does not apply (the previous line is blank), and the branch
"Condition 2 for initializer list" matches, because a class body
(`field_declaration_list`) also starts with `{`. That branch aligns the node with the
parent's first named child, which here is the `access_specifier` at the class's
column. For an initializer list that is right; for a class body it is not.

### A possible fix
Keep that branch away from class bodies, in `c-ts-common-baseline-indent-rule`:

```diff
@@ -760,6 +760,7 @@
      ;;          4, 5, 6, --> Handled by this condition.
      ;;          7, 8, 9 }; --> Handled by condition 1.
      ((and (treesit-node-match-p (treesit-node-child parent 0) "{")
+           (not (treesit-node-match-p parent "field_declaration_list"))
            (treesit-node-prev-sibling node 'named))
       ;; If first sibling is a comment, indent like code; otherwise
       ;; align to first sibling.
```

Tested over 31.1 with master's files: the example then indents `int g;` at 4 in A,
and these initializer lists indent the same with and without the change:

```
int a[] = { 1, 2,
            4, 5 };
struct P p = {
    1,

    2 };
```

`c-ts-common.el` serves other languages too; `field_declaration_list` is the C / C++
grammar's name for a class or struct body, so the change should not reach them. A
`c-ts-mode` rule would do as well; the one used here as a workaround is
`((and (parent-is "field_declaration_list") (not (node-is ,(rx (or
"access_specifier" "}" "preproc"))))) parent-bol c-ts-indent-offset)`.

### Reproduction (emacs -Q)
`emacs -Q --batch -l c_ts_mode_member_blank_line_repro.el` prints the three structs
re-indented in each style, then the rule that placed `int g;` in A and its column.
(Structs rather than classes: a class's own-line `{` is indented by a separate bug,
reported as "brace on its own line after namespace or class is indented".) The file:

```elisp
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
```

Output on 31.1, `gnu` (the other styles the same):

```
struct A
{
public:
    int f;

int g;
};
...
Matched rule: c-ts-common-baseline-indent-rule
struct A, int g; at column 0
```

Measured on a real project (46 files, about 10,100 lines, `bsd`, offset 4): with
workarounds for the namespace / class brace bug, `indent-region` changed 2955 lines;
adding the rule above, 452.
