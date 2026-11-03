# 0108 - D-158: clangd waits in read; Emacs's timers were the freeze, (e) cuts it

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-158 (O-79 (k)); D-156 (e) measured in the spike
- **Done when:** clangd's threads sampled during the back-to-back pair's second
  checkout, patched and stock (D-158); O-79 ruled on where clangd's main thread
  waits.

> Plain English for someone who does not read Emacs Lisp or C++ fluently.

## What + why
The question since 0105 was why Emacs's writes to clangd stall during a reparse.
D-158 looked inside clangd with macOS's `sample`, which records every thread's call
stack every millisecond or so. During a 264 ms stall clangd's main thread was waiting
for input in all 831 samples: clangd was ready to read, so it was not the one
holding things up.

The time went to Emacs itself. When a write finds the pipe full for a moment, Emacs
waits and, while waiting, runs any timer that is due. The reverter's queue step
(refreshing VC state and diff-hl for a shown buffer, which takes up to half a second
while clangd keeps every core busy) ran there, and a chain of small jsonrpc timers
around it. Garbage collection played no part.

D-156 (e), already ruled for T-128, stops the queue step from running while the
reverter's filter runs. Tried in the spike, it cuts the worst case from 0.42 - 1.12 s
to 0.22 - 0.28 s. One large write (a 56 KB header) still waits 74 - 173 ms with the
patched flags only; its cause is not known. O-79 asks whether to stop here.

## Concepts explained
- `sample <pid> <seconds> <ms>` (macOS) suspends the process briefly at intervals
  and records each thread's stack; the report counts how often each call path was
  seen. A thread that waits shows its waiting call (`read`) in almost every sample.
- D-156 (e) in the spike: `s20--in-filter` is bound while the filter reverts;
  `s20--shown-step` that finds it set arms its 0.05 s timer again instead of
  refreshing.

## Key files walked
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--start-sample`,
  `s20--shown-step` / `s20--shown-step-1`, the garbage collection lines.
- `spikes/s20-fswatch-reverter/mac-d158-*.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the sampled stall (a timer one) stands for the others before (e).
  **Would break if:** the earlier large-write stalls had a clangd cause; the
  residual 56 KB write after (e) is unsampled. **DESIGN bet:** O-79 (l) / (m).
- **Assumed:** the spike's (e) is the T-128 design. **Would break if:** T-128's
  filter and queue differ (several filter calls per checkout, other timers in the
  config). **DESIGN bet:** D-156.

## How to verify
`S20_STEP_WAITS=1 S20_CLANGD_FLAGS=patched S20_MODES=eglot sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`; the back-to-back 2 lines
in `spikes/s20-fswatch-reverter/eglot-share.log`. `S20_SAMPLE=<file>` adds the
thread sample.
