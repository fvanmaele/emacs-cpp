# 0025 - T-007: code commands on `C-c l`

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/init-cpp.el`
- **Tier:** 2
- **Decisions:** D-004 (implements its letters)
- **Done when:** every D-004 letter under `C-c l` runs its command (test), which-key
  lists them (TASKS, agreed 2026-10-08).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
D-004 promised one prefix, `C-c l`, for the code commands that have no Emacs-native
key; until now only `C-c l P` (preset) existed and the cheat sheet said `M-x ...`.
Now `r a f i d h t o s e I P` are bound, and which-key (D-034) shows them after a
pause. Inlay hints were a separate v0.4 item, but eglot 31 already turns them on in
every buffer it manages; `C-c l I` hides or shows them.

## Concepts explained
- **`defvar-keymap`:** defines a named keymap from key / command pairs; binding the
  map to `C-c l` makes it a prefix.
- **Autoloads via `:commands`:** most of eglot's commands are not autoloaded, so
  before eglot has loaded, `C-c l r` would point at an undefined function. Listing them
  in eglot's `use-package` form creates autoloads: the first press loads eglot.
  flymake gets the same for `flymake-show-project-diagnostics`.

## Key files walked
- `lisp/init-cpp.el` - `emacs-cpp-code-map`, the `:commands` lists.
- `test/init-cpp-test.el` - `init-cpp-code-map-on-c-c-l`: each key's command, that it
  is callable before eglot loads, and that which-key's own binding list for `C-c l`
  is exactly those twelve.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the eglot commands are wanted on a global prefix; outside an
  eglot-managed buffer they report that there is no server (loud, not wrong).
- **Choice:** `o` is projectile's other-file (by name across the project), not
  `ff-find-other-file` (nearby directories only), for RMO's include/ and src/ split.

## How to verify
`make test` (38 tests). In a C++ buffer: `C-c l` then pause shows the twelve keys;
`C-c l r` renames, `C-c l I` hides the inlay hints.
