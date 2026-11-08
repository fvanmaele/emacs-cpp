# 0107 - D-157: CPU contention does not explain the stalled writes

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-157 (O-79 (h))
- **Done when:** stock flags with the second checkout 1 s after the first, the
  patched flags the same, and the patched flags with `-j=5` in the usual pair, each
  run once on the Mac (D-157).

> Plain English for someone who does not read Emacs Lisp or C++ fluently.

## What + why
After T-130's premise fell (3505d11), the suspect for clangd not reading Emacs's
messages was a starved main thread: with the patched header flags the reparse keeps
all 11 cores busy twice as long. D-157 tested it two ways. Stock flags with the
second checkout landing 1 s into the reparse, deep inside the busiest part, never
stalled a write. The patched flags with clangd limited to 5 worker threads, leaving
6 cores free, still stalled (209 and 137 ms). So contention is not the cause.

clangd's verbose log offers one more clue: right before a long gap, its main thread
logs that it is sending the empty diagnostics it sends when a file is closed, and
the gap lasts until it reads Emacs's next message. A write blocked on a full pipe
back to Emacs would look like that, since Emacs reads nothing while the reverter's
filter runs. But stock clangd writes six times more output and never stalls, so
volume alone does not explain it. The cause is open; sampling clangd's threads
during a stall is proposed (O-79 (k)).

## Concepts explained
- `-j=N` sets clangd's number of worker threads (default: one per core); the main
  thread, which reads and answers messages, is separate.
- The gap variant (`S20_GAP`): the first back-to-back checkout returns a fixed time
  after `git`, so the second one surely lands inside the reparse.

## Key files walked
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--checkout`'s `settle`
  argument (nil, `quiet`, or seconds), `S20_CLANGD_JOBS` in `s20--setup-eglot`.
- `spikes/s20-fswatch-reverter/mac-d157-*.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** one run per variant suffices to rule contention out. **Would break
  if:** the stock run's lack of stalls was luck; earlier stock runs (0106, round 1
  and 2) had none either. **DESIGN bet:** O-79.
- **Assumed:** the `>>>` log line is written before the message itself. **Would
  break if:** clangd logs after writing; then the gap is something else. A thread
  sample would show. **DESIGN bet:** O-79 (k).

## How to verify
`S20_CLANGD_FLAGS=stock S20_GAP=1 S20_MODES=eglot sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`, and with
`S20_CLANGD_FLAGS=patched S20_CLANGD_JOBS=5`; the `stalled send` lines in
`spikes/s20-fswatch-reverter/eglot-share.log`.
