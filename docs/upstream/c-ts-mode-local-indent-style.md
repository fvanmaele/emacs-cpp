# c-ts-mode report draft: c-ts-mode-indent-style from .dir-locals.el or -*- is ignored

Draft for the Emacs bug tracker: `M-x report-emacs-bug`, or mail to
bug-gnu-emacs@gnu.org. Not sent; the owner sends it (D-061, T-037). Reproduction:
`c_ts_mode_local_style_repro.el` in this directory. Searched the tracker 2026-10-10:
#78814 (custom style functions, fixed 2025-06-22) and #81151 (`setopt-local`, fixed
2026-09-07 in master) are about the same variable; neither covers local variables.

---

**Subject:** 31.1; c-ts-mode: c-ts-mode-indent-style set by .dir-locals.el or a
file's -*- line has no effect

### Environment
- GNU Emacs 31.1 (Arch Linux), tree-sitter-cpp grammar from the distribution.
- Same result with `lisp/progmodes/c-ts-mode.el` from master at
  5465a93e06f93b6d5a6880a1bc73d9ff1f341987 (which has the #81151 change) loaded over
  31.1.

### What happens
`c-ts-mode-indent-style` is marked safe as a file-local variable
(`c-ts-indent-style-safep`), so a project can set it in `.dir-locals.el`:

```
((c++-ts-mode . ((c-ts-mode-indent-style . bsd))))
```

After visiting a file there, the variable is `bsd`, buffer-locally, but the buffer
indents in `gnu` style. The same happens with `// -*- c-ts-mode-indent-style: bsd -*-`
in the file. The reason: `c-ts-mode` and `c++-ts-mode` build
`treesit-simple-indent-rules` from the variable in the mode body, and local
variables are applied after the body has run (`run-mode-hooks` ->
`hack-local-variables`). Nothing rebuilds the rules afterwards.

`c-ts-indent-offset` set the same way works, because the rules read it each time
they indent.

The workaround is `(eval . (c-ts-mode-set-style 'bsd))` in `.dir-locals.el`, which
Emacs asks the user to confirm as unsafe; the safe declaration of the variable
suggests it should not be needed.

### Reproduction (emacs -Q)
`emacs -Q --batch -l c_ts_mode_local_style_repro.el` writes an `if` with its brace
on its own line to a temporary directory and visits it three times: with the style
in `.dir-locals.el`, in the `-*-` line, and let-bound around the visit. Output on
31.1 (master the same):

```
--- dir-local.cc: c-ts-mode-indent-style is bsd (local: t)
int f(int x)
{
    if (x)
        {
            return 1;
        }
    return 0;
}

--- file-local.cc: c-ts-mode-indent-style is bsd (local: t)
...the same gnu layout...

--- let-bound.cc: c-ts-mode-indent-style is bsd (local: nil)
int f(int x)
{
    if (x)
    {
        return 1;
    }
    return 0;
}
```

The file:

```elisp
(require 'c-ts-mode)

(setq enable-local-variables :all)
(add-to-list 'major-mode-remap-alist '(c++-mode . c++-ts-mode))

(defconst repro-body "int f(int x)\n{\nif (x)\n{\nreturn 1;\n}\nreturn 0;\n}\n"
  "An `if' with its brace on its own line: bsd and gnu indent it differently.")

(defun repro-visit (dir file-name contents)
  "Write CONTENTS to FILE-NAME in DIR, visit it, re-indent it, report."
  (let ((file (expand-file-name file-name dir)))
    (with-temp-file file (insert contents))
    (with-current-buffer (find-file-noselect file)
      (setq-local c-ts-indent-offset 4 indent-tabs-mode nil)
      (indent-region (point-min) (point-max))
      (message "--- %s: c-ts-mode-indent-style is %S (local: %s)\n%s"
               file-name c-ts-mode-indent-style
               (local-variable-p 'c-ts-mode-indent-style) (buffer-string))
      (kill-buffer))))

(message "Emacs %s" emacs-version)
(let ((dir (make-temp-file "c-ts-style" t)))
  (with-temp-file (expand-file-name ".dir-locals.el" dir)
    (insert "((c++-ts-mode . ((c-ts-mode-indent-style . bsd))))\n"))
  (repro-visit dir "dir-local.cc" repro-body)
  (delete-file (expand-file-name ".dir-locals.el" dir))
  (repro-visit dir "file-local.cc"
               (concat "// -*- c-ts-mode-indent-style: bsd -*-\n" repro-body))
  (let ((c-ts-mode-indent-style 'bsd))
    (repro-visit dir "let-bound.cc" repro-body))
  (delete-directory dir t))
```

### A possible fix
Rebuild the rules once local variables are in. (cc-mode applies a local
`c-file-style` itself, with `c-before-hack-hook` on
`before-hack-local-variables-hook`.) Tested over both 31.1
and master's file: with this loaded, the dir-local and file-local cases indent in
`bsd`.

```elisp
(defun c-ts-mode--apply-local-style ()
  "Rebuild indent rules if `c-ts-mode-indent-style' was set locally."
  (when (local-variable-p 'c-ts-mode-indent-style)
    (c-ts-mode-set-style c-ts-mode-indent-style)))

;; In the bodies of `c-ts-mode' and `c++-ts-mode':
(add-hook 'hack-local-variables-hook #'c-ts-mode--apply-local-style nil t)
```
