# c++-ts-mode report draft: a brace on its own line after namespace or class is indented

Draft for the Emacs bug tracker: `M-x report-emacs-bug`, or mail to
bug-gnu-emacs@gnu.org. Not sent; the owner sends it (O-28 (e), D-061, T-036).
Reproduction: `c_ts_mode_namespace_repro.el` in this directory. Searched the tracker
2026-10-10: #61635 (a `}` in a class in a namespace, fixed in 29.1) and #78814 (custom
style functions, fixed 2025-06-22; its reporter's workaround is a namespace rule)
are related; none reports this.

---

**Subject:** 31.1; c++-ts-mode: brace on its own line after namespace or class is
indented in every indent style

### Environment
- GNU Emacs 31.1 (Arch Linux), tree-sitter-cpp grammar from the distribution.
- Same result with `lisp/progmodes/c-ts-mode.el` from master at
  5465a93e06f93b6d5a6880a1bc73d9ff1f341987 loaded over 31.1.

### What happens
With the `{` of a namespace or a class on its own line, `indent-region` (or TAB)
indents that brace one step, and everything inside it follows. This happens in all
four styles (`gnu`, `k&r`, `linux`, `bsd`), with `c-ts-indent-offset` 4:

```
namespace a          namespace a
{                        {
class B                      class B
{                                {
public:                          public:
    int f()                          int f()
    {                                {
        return 1;                        return 1;
    }                                }
};                               };
}                        }
   input                    after indent-region, every style
```

A function's own-line `{` is not indented: the rule
`((parent-is ,(rx (or "function_definition" "struct_specifier" ...))) standalone-parent 0)`
in `c-ts-mode--simple-indent-rules` lists `function_definition`, `struct_specifier`,
`enum_specifier`, `union_specifier`, `function_declarator` and
`template_declaration`, but not `namespace_definition` or `class_specifier`. So a
`struct` brace is placed at the struct's column and a `class` brace one step in:

```
struct S             class C
{                        {
    int x;                   int y;
};                       };
```

### Expected
The `{` at the column of `namespace` / `class`, as for `struct` and functions. This is
the layout of BSD (Allman) style, and of clang-format's GNU, Microsoft and Mozilla
styles for classes (`BraceWrapping: AfterClass: true`).

### Related: no way to leave namespace bodies unindented
Many C++ projects do not indent namespace contents (clang-format's
`NamespaceIndentation: None`, set in its LLVM, Google, Chromium, Mozilla, Microsoft
and GNU styles; WebKit indents only inner namespaces). `c-ts-mode` has no option for it; a custom rule is needed. These three
rules, added with `treesit-simple-indent-add-rules`, give the expected result for the
example above (shown by the reproduction):

```
((parent-is "namespace_definition") standalone-parent 0)
((parent-is "class_specifier") standalone-parent 0)
((n-p-gp nil "declaration_list" "namespace_definition") parent-bol 0)
```

The first two would fix the bug; the third is the namespace option, perhaps as a user
option (say `c-ts-mode-indent-namespace-body`, default t as today).

### Reproduction (emacs -Q)
`emacs -Q --batch -l c_ts_mode_namespace_repro.el` prints the example re-indented in
each style, then with the three rules. The file:

```elisp
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
```

Measured on a real project (46 files, about 10,100 lines, written in that layout):
`indent-region` changes 7624 lines in `bsd` style, 2955 with the three rules.
