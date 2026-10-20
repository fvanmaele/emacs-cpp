# S17 results

Verdict: PASS (run 3, the session's, Arch, 2026-10-21) with a compile-time prelude in
each module: criteria 1 - 3 hold in both rounds (`byte` JIT on 0.194 / 0.194 s against
`interp` JIT on 0.199 / 0.198 s; `emacs-cpp-match-tier` native). Without it, run 1
(owner) FAILED criterion 2 by 222 ms; run 2 found why. The criteria in RUN.md are
confirmed (owner, 2026-10-21: "S17 criteria confirmed"). The prelude is spike code:
the fix's shape is O-74.

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

## Run 4 (session, Arch, 2026-10-21): is compiling lisp/ worth it? (O-74)
Owner: "do more thorough benchmarks to rule if O-74 (a) is worthwhile". `bench.sh`,
`bench.el` (NEW): one copy of init.el, lib/ and lisp/; each state in a fresh batch
Emacs (interpreted; bytecode from compile.el; native from `native-compile` with the
same settings, form checked: native); median of 7 after a warm-up, GC included; load
0.76. Log: `arch-run4-bench.log`. The paths are lisp/'s code that runs many times per
action:

| path | interp | byte | native |
|---|---|---|---|
| B1 tier sort, deal.II files `tria` (12344 of 34704) | 148.8 ms | 137.8 ms | 133.6 ms |
| B1 tier sort, deal.II files `dofh` (5968) | 70.7 ms | 64.9 ms | 64.0 ms |
| B1 tier sort, deal.II files `vec` (4034) | 26.8 ms | 23.5 ms | 22.4 ms |
| B1 orderless's own filter, `tria` (for scale) | 91.5 ms | 92.3 ms | 91.0 ms |
| B1 M-x (4224 commands), RMO files (437): every input | 0.2 - 2.0 ms | 0.1 - 1.6 ms | 0.1 - 1.5 ms |
| B2 `emacs-cpp-go--under-root-p`, 10000 symbol replies | 10.6 ms | 4.4 ms | 3.0 ms |
| B3 `indent-region`, tria.cc (18694 lines) | 2465 ms | 2516 ms | 2491 ms |
| B4 startup (run 3) | 0.199 s | | 0.194 s |

Reading:
- Today's code gains little from compiling: the tier sort is three regexps per name,
  run by Emacs's C regexp engine, so 10 % at most (149 -> 134 ms); B2 saves 7 ms per
  `M-o` symbol reply; indentation's time is in treesit, Emacs's own (already native)
  code, so nothing; startup 5 ms.
- The gain is D-124's function, which only pays compiled (S16, same corpus, same
  machine): the `tria` sort 41.0 ms native against today's 148.8 ms interpreted, so
  a keystroke in a deal.II-sized file prompt goes from about 240 ms (filter 91 + sort
  149) to about 132 ms. Interpreted, D-124 is slower than today (308.6 ms, S16).
- Small prompts (M-x, a project the size of RMO) are under 2 ms in every state.


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
