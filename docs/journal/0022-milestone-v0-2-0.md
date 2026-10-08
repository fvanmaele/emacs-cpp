# 0022 - Milestone v0.2.0: build and debug

- **Date:** 2026-10-08
- **Commits:** tag `v0.2.0` (owner request 2026-10-08)
- **Tier:** 1 (milestone record)
- **Decisions:** D-030 .. D-037 added since v0.1.0
- **Done when:** DESIGN scope ladder v0.2: configure / build / test via presets; errors
  jump to source; CMake mode. Also met: v0.3 debug (breakpoint, step, locals, stack,
  watch via dape + gdb in the reference project).
- **Tag:** v0.2.0

> Plain English record of what the second milestone contains.

## What + why
The owner checked T-005 and T-006 on RMO and asked for the v0.2.0 tag. Since v0.1.0:
- build (T-005, D-035): `C-c p c o` / `c c` / `c t` configure, build and test the
  active preset from any buffer; compiler errors jump to the source line;
- CMake files in the system `cmake-mode` (D-013, wired up just before the tag: it was
  decided on 2026-10-07 but no module set it up);
- debugging (T-006, D-031 .. D-033, D-036, D-037): `C-x C-a d gdb-preset` picks a
  target of the active preset from build.ninja, builds it and debugs it with gdb's DAP
  mode; program arguments with `:args`; fringe clicks set breakpoints, drawn red; the
  stopped line is highlighted; stepping keys repeat;
- gdb options: shared-library symbols on demand (D-030), gdb scripts such as deal.II's
  printers (D-032), both off by default;
- key hints: which-key after any prefix (D-034); projectile's menu on `C-c p m`.

## Assumptions + risks  (the postmortem ledger)
- **Named v0.2.0 by the owner** although the v0.3 (debug) items are in too; a v0.3
  tag is the owner's call.
- **Open at the tag:** T-007 (`C-c l` keys), T-008 (performance numbers), T-010 (Info
  manuals); O-12 deferred until after v0.4.
- **Risk:** `gdb-preset` reads CMake's Ninja rule names (D-033) and drives dape 0.27.1
  internals in its test; a CMake or dape update can need the reader or test adjusted.

## How to verify
`git show v0.2.0`; `make test` (32 tests).
