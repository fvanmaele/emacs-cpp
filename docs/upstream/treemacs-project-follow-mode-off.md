# treemacs issue draft: turning `treemacs-project-follow-mode` off signals an error

Draft for https://github.com/Alexander-Miller/treemacs/issues. Not sent; the owner
sends it (D-067, T-041). Checked 2026-10-10: master's
`treemacs--tear-down-project-follow-mode` is unchanged from 2ab5a3c.

---

**Title:** Turning off treemacs-project-follow-mode: (wrong-type-argument timerp nil)

### Environment
- treemacs 2ab5a3c89fa01bbbd99de9b8986908b2bc5a7b49 (same code on master), Emacs 31.1.

### What happens
Turning the mode off signals an error whenever no follow is pending, which is almost
always:

```
emacs -Q --batch -L treemacs/src/elisp -L <dash, s, ace-window, pfuture, hydra, ht, cfrs> \
  --eval '(progn (require (quote treemacs)) (require (quote treemacs-project-follow-mode))
                 (treemacs-project-follow-mode 1) (treemacs-project-follow-mode -1))'
=> (wrong-type-argument timerp nil)
```

The same with `M-x treemacs-project-follow-mode` in an interactive session, and with
`(treemacs-project-follow-mode -1)` while the mode is already off (a config that
turns it off at load time).

### Cause
`treemacs--tear-down-project-follow-mode` calls
`(cancel-timer treemacs--project-follow-timer)` unchecked. The debounce in
`treemacs--follow-project` sets the variable back to nil after every follow, and
`treemacs--setup-project-follow-mode` sets it to nil, so it is nil between follows.

### Fix
Guard it as the setup function already does:

```elisp
(when treemacs--project-follow-timer (cancel-timer treemacs--project-follow-timer))
(setf treemacs--project-follow-timer nil)
```
