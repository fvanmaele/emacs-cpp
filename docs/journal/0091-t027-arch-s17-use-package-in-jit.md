# 0091 - Arch measurements (T-027) and why native modules loaded magit (S17)

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "S17 runs 2 and 3"`; D-131 in 6f16d4a, 936793b
- **Tier:** 3 (spike runs, spike code only) and 1 (measurements into DESIGN 11)
- **Decisions:** D-131 (O-73 (a)); O-74 opened; bears on D-125, D-128
- **Done when:** T-027's Arch numbers in DESIGN 11; S17's cause shown and a fix measured
- **Tag:** none

> Plain English record of measurements the session ran on the Arch machine.

## What + why
The owner ruled O-73 (a) with "proper user diagnostics" (D-131; T-118's done when
proposed) and asked to revisit the remaining tasks on Arch. Of the open tasks, three
needed only this machine: T-027's Arch numbers, S17's run 2, and the closing of two
TASKS rows whose entries were done already (T-077, T-024).
- **T-027** (DESIGN 11): startup median 0.182 s (portable-bench, 0089); first `M-.` on
  `std::visit` in RMO's `main.cc` with the index on disk 0.96 s patched, 6.9 s system
  (S8's runner, run 3); RSS from S10 run 2. Done; O-24 (b) was ruled already (D-057).
- **S17 run 2** found the form: Emacs's JIT compiles each module's `.eln` in a separate
  Emacs that never runs init.el, so `use-package-always-defer` is nil there and
  `(use-package magit)` becomes `(require 'magit nil nil)`. Bytecode is compiled with
  the settings (the spike's prelude), so only native code loads magit. **Run 3** set the
  two settings at compile time in each module of a copy: 0.194 s against 0.199 s
  interpreted, two rounds; criteria 1 - 3 PASS (still to be confirmed by the owner).

## Concepts (Emacs Lisp) explained
- `use-package` is a macro: what it becomes is decided when the file is compiled, from
  the settings of the Emacs doing the compiling. `use-package-always-defer` t makes a
  bare `(use-package magit)` expand to nothing (the package's autoloads load it later);
  nil makes it expand to `(require 'magit)`, a load at start.
- `eval-when-compile` runs its body while the file is compiled (and, in source loaded
  without compiling, while it is loaded); so settings put there reach any compiler of
  the file, including the JIT's separate process.

## Key files walked
- `spikes/s17-compiled-lisp/find-magit.sh` (NEW): a backtrace from
  `after-load-functions` when `magit.el` loads, features and queue at exit.
- `spikes/s17-compiled-lisp/run.sh`: `S17_PRELUDE=1` inserts the settings after each
  module's `;;; Code:` in the copy.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** only the two use-package settings differ between init.el's Emacs and
  the JIT's. **Would break if:** another setting changes a macro's expansion (a
  `defcustom` read at macro time); the 3 files still queued at exit in run 3 are not
  identified. **DESIGN bet:** D-125, O-74.
- **Assumed:** T-027's S8 numbers at load 1.2 stand for idle. **Would break if:** an
  idle rerun differs by more than S8's own run-to-run spread.

## How to verify
`S17_PRELUDE=1 sh spikes/s17-compiled-lisp/run.sh 10 2 </dev/null`; `S17_PRELUDE=1 sh
spikes/s17-compiled-lisp/find-magit.sh </dev/null` (magit not loaded with the JIT on).
