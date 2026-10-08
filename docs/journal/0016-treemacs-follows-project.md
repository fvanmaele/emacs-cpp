# 0016 - Project tree on `C-c t`, following the project

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/init-project.el`
- **Tier:** 2
- **Decisions:** D-029
- **Done when:** (owner's choice of options, 2026-10-08) `C-c t` opens the tree showing
  only the current buffer's project and closes it again; the tree follows the project
  of the selected buffer; not opened at startup; `make test` covers key and toggle
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner asked how to get treemacs by default or per project. Chosen: a key, and the
tree always shows the project you are working in. treemacs has a mode for exactly this
(`treemacs-project-follow-mode`); it finds the project through projectile. The key
runs a small command instead of `treemacs` itself: with an empty workspace `treemacs`
first asks "Project root:", whereas the command adds the current project and shows it.

## Concepts (Emacs Lisp) explained
- **`:bind` in use-package:** binds the key and loads treemacs on first use, so startup
  does not pay for it.
- **`if-let*`:** "if the tree window exists, call it `window` and close it, else ...".

## Key files walked
- `lisp/init-project.el` - `emacs-cpp-treemacs-toggle`, the treemacs `use-package`.
- `test/init-test.el` - `init-treemacs-follows-the-project`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** following works in the interactive Emacs. Checked in batch only by
  calling treemacs's follow function directly: its trigger is an idle timer after a
  window change, and batch Emacs is never idle. **Would break if:** the owner sees
  the tree stay on the old project.
- **Risk:** the follow mode rewrites the treemacs workspace to the one current
  project; projects added by hand to the workspace are replaced.

## How to verify
`make test`. Owner: open a file of RMO, `C-c t`; visit a file of another project and
wait about 2 s; `C-c t` closes the tree.
