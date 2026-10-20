# S17 results

Verdict: FAIL (owner's run 1, Arch, 2026-10-20): criteria 1 and 3 hold, criterion 2
does not: `byte` with the JIT on starts 222 ms slower than `interp` (limit 10 ms), in
both rounds. The criteria in RUN.md are still marked proposed; the owner confirms
them. D-125 is not gated through, and with it D-124 (S16 PASS compiled) waits.

## Environment
Owner's Arch workstation, Linux x86_64, GNU Emacs 31.1 (native compilation);
`run.sh 10 2`; load 0.90 - 1.42 (RUN.md asks below 1; the differences below are 20
times the spread, so the load does not decide). Log: `owner-arch-run1.log`.

## Measurements (owner's run 1)
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

## Reading
- Arch repeats the Mac's shape: bytecode costs nothing (JIT off 9 ms faster than
  interpreted), native modules cost the start about 220 ms here, 510 ms on the Mac.
  The Mac's diagnosis (`DRY-RUN.md`: magit and about 90 further features loaded, 45
  files queued for native compilation at every start) is not repeated on Arch;
  assumed the same cause (UNVERIFIED on Arch).
- The form that loads magit under native code is still unfound: that was planned as
  run 2 before the Arch verdict, and is the next step. Once found and deferred, a
  run of this spike decides D-125; until then `lisp/` ships interpreted.
