# 0032 - Milestone v0.4.0: polish

- **Date:** 2026-10-08
- **Commits:** tag `v0.4.0` (owner request 2026-10-08)
- **Tier:** 1 (milestone record)
- **Decisions:** D-038 .. D-048 added since v0.2.0
- **Done when:** DESIGN scope ladder v0.4: diff-hl, breadcrumb, `C-c l` map complete,
  inlay hints, treemacs-magit. (v0.3, debugging, was already in v0.2.0; no v0.3 tag.)
- **Tag:** v0.4.0

> Plain English record of what the milestone contains.

## What + why
The owner asked for the v0.4 tag after a code review (0031). Since v0.2.0:
- v0.4 items: changed lines in the right fringe (diff-hl, T-016), path and function in
  the header line (breadcrumb, T-017), twelve code keys on `C-c l` with inlay hints on
  by default and `C-c l I` to hide them (T-007), the tree's git colours after magit
  (treemacs-magit, T-015; treemacs-projectile now actually loads);
- startup 0.36 -> 0.15 s (garbage collection during startup, T-008, D-038);
- package manuals in `C-h i` (T-010, D-039);
- a saved theme survives a restart (D-040); recent files kept (D-041);
- the tree opens with the first project file (D-048); gud off dape's prefix (D-044);
- clangd: a header opened first after a restart gets its includer's flags, about
  0.9 s after opening on RMO (patches 0006, 0007, pkgrel 5; S9; T-019);
- Python rides along: python-ts-mode, pyright, debugpy on localhost (T-018, D-045);
- user manual `docs/MANUAL.md` next to the cheat sheet.

## Assumptions + risks  (the postmortem ledger)
- **Open at the tag:** T-020 (patch 0008, from the review; owner rules when), O-12
  (deal.II sources index, deferred until after v0.4: now due).
- **Risk:** the local clangd patches (0001 - 0007) are pinned to LLVM 23.1.1; an LLVM
  upgrade needs them rebased.

## How to verify
`git show v0.4.0`; `make test` (45 tests).
