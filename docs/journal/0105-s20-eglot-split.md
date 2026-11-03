# 0105 - S20 D-154: writes to clangd are the back-to-back block

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-154 (O-79 (c)); O-79's options revisited
- **Done when:** S20's eglot run times each revert during clangd's reparse, split
  into didClose, didOpen (its sends to clangd) and the rest of the revert (D-154).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0104 found that a checkout landing while clangd still reparses after the previous
one freezes Emacs 0.36 - 0.98 s, and first blamed eglot. Its contrast without eglot
had no clangd running at all, so that blame was not shown; the same day's correction
said so and the owner ruled O-79 (c): measure where the time goes. The eglot run now
times every revert in parts. With clangd idle all 39 files' sends take under a
millisecond. During the reparse the sends are most of the freeze, and a single
write to clangd waits 0.26 - 1.04 s: clangd stops reading its input for that long.
The rest of a revert (reading the file, tree-sitter) is 2 - 4 times slower too, but
small. Smaller batches of reverts would not help if one write alone can wait a
second, which is why O-79's options were revisited.

## Concepts (Emacs Lisp) explained
- `process-send-string` writes to a subprocess's input and returns only when all of
  it is written. A pipe holds a limited amount (64 KB on macOS at most); when the
  reader stops reading, the writer waits. eglot sends each reopened file whole.
- `:around` advice wraps a function: the spike's wrapper notes the time before and
  after calling the original, by key, per checkout (`s20--timed`, `s20-split`).

## Key files walked
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--timed`, the advice in
  `s20--setup-eglot`, the `split (D-154)` line in `s20--checkout`.
- `spikes/s20-fswatch-reverter/mac-split-run1.log` .. `mac-split-run3.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the stalled writes are clangd not reading, not Emacs's own send
  loop. **Would break if:** Emacs's `send_process` waits for other reasons (it reads
  other processes' output while it waits); clangd's verbose log would tell.
  **DESIGN bet:** O-79.
- **Assumed:** advice on `process-send-string` sees all of eglot's writes. **Would
  break if:** jsonrpc writes another way; the byte counts (463 - 473 KB for 39 whole
  files) fit what eglot sends. **DESIGN bet:** D-154.

## How to verify
On the Mac: `S20_MODES=eglot sh spikes/s20-fswatch-reverter/eglot-share.sh
</dev/null`; the `split (D-154)` lines in
`spikes/s20-fswatch-reverter/eglot-share.log`.
