# S17 results

Verdict: PASS (run 3, the session's, Arch, 2026-10-21) with a compile-time prelude in
each module: criteria 1 - 3 hold in both rounds (`byte` JIT on 0.194 / 0.194 s against
`interp` JIT on 0.199 / 0.198 s; `emacs-cpp-match-tier` native). Without it, run 1
(owner) FAILED criterion 2 by 222 ms; run 2 found why. The criteria in RUN.md are still
marked proposed; the owner confirms them. The prelude is spike code: the fix's shape is
O-74.

## Run 2 (session, Arch, 2026-10-21): what loads magit
`find-magit.sh` (NEW): the `byte` tree, one start after measure-startup's warm-up, with
the JIT on and off, recording the backtrace when `magit.el` finishes loading
(`after-load-functions`), the features and the native compiler's queue at exit. Log:
`arch-run2-find-magit.log`.
- JIT off, and the warm-up start with the JIT on (no `.eln` yet): 220 features, magit
  not loaded.
- JIT on, the start after the warm-up: 318 features, magit loaded, 45 files queued.
  Backtrace: `require(magit nil t)` inside use-package's `condition-case` with "Cannot
  load %s", called from `require(init-git)`.
- Cause: the JIT compiles `.eln` files from the `.el` sources in its own Emacs
  process, which never runs init.el, so `use-package-always-defer` and
  `use-package-expand-minimally` are nil there (init.el:32-33 sets them; compile.el
  sets them for the bytecode only). Expanded that way, `(use-package magit)` is
  `(require 'magit nil nil)` (checked by `macroexpand-all` both ways: with the
  settings it is `nil`). So every deferred package of every module loads at start
  once the modules are native; the 45 queued files are the libraries loaded that way,
  compiled again at each start.

## Run 3 (session, Arch, 2026-10-21): the settings at compile time
`run.sh` with `S17_PRELUDE=1`: after `;;; Code:` each module of the copy gets
`(eval-when-compile (setq use-package-always-defer t use-package-expand-minimally t))`,
so every compiler of the file, the JIT's included, expands as init.el does. Two runs of
one round each (`run.sh 10 1`), load 1.33 - 1.72; logs `arch-run3.log`,
`arch-run3-find-magit.log`.

| tree | JIT on | JIT off |
|---|---|---|
| interp | 0.199 / 0.198 s | 0.201 / 0.201 s |
| byte | 0.194 / 0.194 s | 0.193 / 0.193 s |

Forms as in run 1 (native with the JIT on, bytecode off). With the prelude, the start
after the warm-up has 220 features, magit not loaded; 3 files are queued at exit (which
ones not recorded, UNVERIFIED).

## Run 1 (owner, Arch, 2026-10-20)
Verdict then: FAIL, criterion 2 (+222 ms).

### Environment
Owner's Arch workstation, Linux x86_64, GNU Emacs 31.1 (native compilation);
`run.sh 10 2`; load 0.90 - 1.42 (RUN.md asks below 1; the differences below are 20
times the spread, so the load does not decide). Log: `owner-arch-run1.log`.

### Measurements (owner's run 1)
| Criterion | Result |
|---|---|
| 1. compile, 19 files | 0 failed (37 warning lines; Mac 36) |
| 2. startup median, `byte` JIT on against `interp` JIT on | 0.418 / 0.419 s against 0.196 / 0.197 s: +222 ms |
| 3. `emacs-cpp-match-tier` in `byte`, JIT on | native |

Startup medians, rounds 1 / 2 (Mac dry run in brackets):
| tree | JIT on | JIT off |
|---|---|---|
| interp | 0.196 / 0.197 s (0.397 / 0.407) | 0.200 / 0.200 s (0.363 / 0.374) |
| byte | 0.418 / 0.419 s (0.915 / 0.909) | 0.191 / 0.192 s (0.360 / 0.372) |

### Reading
- Arch repeats the Mac's shape: bytecode costs nothing (JIT off 9 ms faster than
  interpreted), native modules cost the start about 220 ms here, 510 ms on the Mac.
  The Mac's diagnosis (`DRY-RUN.md`: magit and about 90 further features loaded, 45
  files queued for native compilation at every start) is not repeated on Arch;
  assumed the same cause (UNVERIFIED on Arch).
- The form that loads magit under native code is still unfound: that was planned as
  run 2 before the Arch verdict, and is the next step. Once found and deferred, a
  run of this spike decides D-125; until then `lisp/` ships interpreted.
