# 0109 - D-159: the residual write stall sampled, clangd in read

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-159 (O-79 (m))
- **Done when:** clangd's threads sampled with D-156 (e) on and the patched flags
  during the back-to-back pair's second checkout (D-159).

> Plain English for someone who does not read Emacs Lisp or C++ fluently.

## What + why
With D-156 (e) the worst freeze dropped to about a quarter second, but one write of
a 56 KB header still waited 74 - 173 ms with the patched clangd flags. D-159 sampled
clangd during that write twice. Both times clangd's main thread sat in `read`,
the call that waits for Emacs's next message, in practically every sample.

A sample cannot tell "waiting for data" from "data arrived, but no CPU free yet to
run". So the residual has two possible readings: Emacs, after a write that would
block, sleeps up to 20 ms before trying again and does not wake when the pipe
drains; or clangd's reader is ready but waits for a CPU while the reparse runs.
Neither is the includer lookup, and neither is anything the reverter does. O-79
recommends stopping here.

A second patched clangd, from the owner's own Emacs on RMO-drafts, had been running
beside all of the day's runs; it adds to every absolute number.

## Concepts explained
- `wait_reading_process_output (0, 20 ms, ...)` in Emacs's `send_process`: the wait
  after a blocked write ends on its timeout or on output from any process, not on
  the pipe becoming writable again.
- A thread in a system call shows that call in every stack sample, whether it is
  blocked or merely not yet scheduled after being woken.

## Key files walked
- `spikes/s20-fswatch-reverter/mac-d159-run1.log`, `mac-d159-run2.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the residual is bounded by what was measured (up to about 0.17 s per
  large write). **Would break if:** projects with larger open headers (deal.II's
  own, if edited) or more of them push many large writes into one reparse.
  **DESIGN bet:** O-79 (l).
- **Assumed:** the owner's second clangd raised the load evenly across runs.
  **Would break if:** it was busy only in some runs; the comparisons between flag
  sets would then be skewed. **DESIGN bet:** O-79.

## How to verify
`S20_SAMPLE=<file> S20_STEP_WAITS=1 S20_CLANGD_FLAGS=patched S20_MODES=eglot sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`; in the sample file, the
call graph under `com.apple.main-thread`.
