# 0026 - T-016, T-017: diff-hl and breadcrumb

- **Date:** 2026-10-08
- **Commits:** see `git log -- lib/diff-hl lib/breadcrumb`
- **Tier:** 2
- **Decisions:** D-042 (diff-hl), D-043 (breadcrumb)
- **Done when:** T-016: in a git file buffer, changed lines are marked in the right
  fringe (margin in a terminal), refreshed after magit stages or commits; test on a
  toy repository. T-017: C++ buffers show the project-relative path and the function
  at point in the header line; test on a toy project. (Agreed 2026-10-08.)
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
Two v0.4 items that CLion shows by default: which lines differ from the last commit
(its gutter colours) and where you are (its navigation bar). diff-hl marks changed
lines in the right fringe; breadcrumb puts the path in the project and the function
at point in the header line above each C++ buffer. Both came in as new submodules,
fetched with the owner's consent (D-014): diff-hl at its tag 1.10.0, breadcrumb at
its latest commit (it has no tags).

## Concepts explained
- **Fringe and margin:** the fringe is the thin strip beside the text in a graphical
  frame; a terminal has none, so diff-hl uses a text margin there. The left side
  already carries dape's breakpoint dots and the debugger's arrow, hence the right.
- **Hook depth:** `add-hook` normally puts a function first. diff-hl must run after
  vc has noticed the file is under git (`vc-refresh-state`), or it postpones its
  first drawing to a hook that has already run; depth 90 places it late. Found by
  the test: marks appeared only after this change.
- **imenu:** the per-file index of definitions; breadcrumb reads it to name the
  function at point. It rescans when Emacs is idle.

## Key files walked
- `lisp/init-git.el` - the diff-hl form: right side, margin in a terminal, the
  find-file hook, magit's pre / post refresh hooks.
- `lisp/init-cpp.el` - the breadcrumb form on `c-ts-base-mode-hook`.
- `test/init-git-test.el` - a toy repository: change a committed file, visit it,
  marks on the right; `magit-run-git commit` clears them.
- `test/init-cpp-test.el` - `init-cpp-breadcrumb-shows-path-and-function`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** marks after save are enough; CLion marks while typing. **Would break
  if:** the owner wants live marks; `diff-hl-flydiff-mode` does that on an idle timer.
- **Assumed:** a per-file hook is equivalent to `global-diff-hl-mode` for files
  (buffers without a file, such as `vc-dir`, get no marks). Saves 39 ms at startup;
  startup now 0.155 s (5 runs).
- **Risk:** breadcrumb is pinned to an untagged commit; updating means picking a
  commit by hand.

## How to verify
`make test` (40 tests). In a graphical Emacs: edit a line of a committed file, save:
a mark in the right fringe; commit with magit: it goes. The header line of a `.cc`
buffer shows e.g. `rmo/src/main.cc : main`.
