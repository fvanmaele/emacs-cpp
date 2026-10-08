# 0033 - v0.4.1: the tree opens only on C-c t again

- **Date:** 2026-10-08
- **Commits:** see `git log -1 --grep D-049`
- **Tier:** 1
- **Decisions:** D-049 (withdraws D-048)
- **Done when:** visiting a project file does not open the tree; `C-c t` toggles it as
  in D-029; make test passes.
- **Tag:** v0.4.1 (owner request 2026-10-08)

> Plain English record of a small change.

## What + why
The owner asked to return to the earlier behaviour: the project tree appears only when
`C-c t` asks for it. The automatic opening of D-048 (with the first project file of a
session) and its option are removed, not just switched off, so no unused code stays.
Without it, treemacs is not loaded until the first `C-c t`.

## Key files walked
- `lisp/init-project.el` - the option, `emacs-cpp-treemacs-open-once` and the
  find-file hook are gone; `C-c t` and the follow mode are as in D-029.
- `test/init-test.el` - the auto-open test replaced by one that checks the hook and
  option are absent; `init-treemacs-follows-the-project` still covers `C-c t`.

## How to verify
`make test` (45 tests). A graphical start with a project file shows one window and
does not load treemacs (checked).
