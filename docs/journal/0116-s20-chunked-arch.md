# 0116 - S20 `fswatch-chunked`: PASS on Arch, the Mac on H-25

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  5854382 (D-167)
- **Tier:** 3 (spike S20)
- **Decisions:** D-167 (O-81 (b))
- **Done when:** three runs of `fswatch-chunked` on each machine pass `fswatch-shown`'s
  criteria 1 - 6 in `spikes/s20-fswatch-reverter/RUN.md`; this entry covers Arch.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
S20 failed on Arch (D-166, 0115) because one call of the fswatch process filter
reverted all 189 buffers of a checkout, 124 - 302 ms in which Emacs did nothing else.
The owner ruled O-81 (b) (D-167): first measure a reverter that takes the reverts out
of the filter. The new mode `fswatch-chunked` does that. The filter only works out
which open buffers the reported files belong to and puts them in a queue, shown
buffers at the front. A timer then reverts from the queue until 0.05 s have passed,
lets Emacs handle anything else waiting, and goes on.

On Arch all three runs pass criteria 1 - 6. Emacs is blocked at most 0.14 s
(`fswatch-shown`, run beside it: 0.13 - 0.21 s), the filter takes at most 7.7 ms, and
every revert step ends within 2.6 ms of its budget. Buffers become current 0.23 -
0.51 s after `git` instead of about 0.15 s, well inside the 1.0 s limit. Numbers per
run in `spikes/s20-fswatch-reverter/RESULTS.md`.

## Concepts (Emacs Lisp) explained
- A time budget per step: the step notes the time, reverts one buffer after another
  while less than `s20-budget` has passed, and arms a one-shot timer (0.01 s) for the
  rest. The last revert may run past the budget by one revert's cost (0.6 - 3.6 ms
  here).
- Why the block is still larger than one step: the spike measures how long one
  `accept-process-output` call takes. Emacs runs every timer that is due inside such
  a call, so a revert step and a shown buffer's VC / diff-hl refresh step can fall in
  the same call and add up (0.14 s at most). The module should let only one of them
  run per pass.
- The skipped-buffers message is sent when the revert queue is empty, not per filter
  call, because the checks for edited and deleted files now run in the steps.

## Key files walked
- `spikes/s20-fswatch-reverter/s20-run.el` - `s20--path-buffer`, `s20--revert-buffer`
  (split out of `s20--revert`), `s20--enqueue`, `s20--revert-step`, the filter's
  `s20-chunked` branch, the `revert queue:` report line.
- `spikes/s20-fswatch-reverter/run.sh` - header only.
- `spikes/s20-fswatch-reverter/arch-chunked-run1.log` .. `arch-chunked-run3.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a 0.05 s budget fits both machines. **Would break if:** the Mac's
  reverts cost more per buffer and a step plus a refresh step pass 0.25 s; H-25
  measures it. **DESIGN bet:** D-167.
- **Assumed:** no single revert costs tens of milliseconds. **Would break if:** a large
  file or eglot's didOpen per revert (0104) makes one revert overrun the budget alone;
  the budget cannot split a revert. **DESIGN bet:** D-167.
- **Assumed:** a 0.01 s timer between steps lets Emacs read input in a running Emacs,
  not only in batch (a timer armed inside a step should wait for the next pass of
  `keyboard.c`'s `timer_check`; UNVERIFIED, the source not read this session).
  **Would break if:** steps run back to back in a live
  Emacs. **DESIGN bet:** D-167.

## How to verify
On Arch: `S20_MODES="fswatch-chunked fswatch-shown" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6. The Mac:
H-25.
