# 0106 - T-129: the stall is the header-flags flag plus timers inside Emacs's write

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20, task T-129)
- **Decisions:** D-155 (T-129, O-79 reopens on a removable cause); O-79 reopened
- **Done when:** the stall is placed (a flag, a clangd lock, Emacs's send loop) or
  ruled out on the Mac, recorded in S20 RESULTS and O-79 (TASKS T-129).

> Plain English for someone who does not read Emacs Lisp or C++ fluently.

## What + why
0105 showed that a checkout during clangd's reparse freezes Emacs mostly inside its
writes to clangd. T-129 asked why. Four flag sets were compared on the same clone and
checkouts, with clangd's verbose log and new timing in Emacs.

Two things combine. First, clangd: the patched flag `--header-flags-from-index`
(D-028) makes clangd look up, for every header it is told about, a source file that
includes it, in its index. During the reparse that lookup takes up to about 12 ms on
clangd's main thread, the thread that also reads Emacs's messages, so for a few
dozen headers clangd stops reading long enough for the pipe between the two to fill.
With stock flags, or with the other patched flag alone, no write ever waits.

Second, Emacs: when a write finds the pipe full, Emacs waits, and while it waits it
runs any timer that is due. The reverter's own queue step (VC state and diff-hl for
a shown buffer, up to 280 ms during the reparse) ran there, and so did a chain of
other timers that themselves wrote to clangd, found the pipe full and waited in
turn. The freeze is mostly that Lisp, run inside a write. O-79 reopens with options
for both halves.

Correction (2026-11-03, when T-130 started): the lookup does not run on clangd's
main thread. clangd fetches a file's compile command inside the file's own worker
task (`ASTWorker::update`, `TUScheduler.cpp:871` in clangd 23.1.3), so the "Compile
command" lines seen in the main thread's gaps came from worker threads writing to
the same log. The measured part stands (stalls with the flag, none without, the
reparse twice as long with it); why the main thread stops reading is open again,
CPU starvation by the heavier header builds being the suspect (DESIGN O-79).

## Concepts explained
- A pipe has a fixed buffer. When the reading process (clangd) stops reading, the
  writer (Emacs) gets "try again" (EAGAIN) once the buffer is full.
- Emacs's `send_process` (C) handles that by waiting in
  `wait_reading_process_output`, the same loop `accept-process-output` uses: it
  reads other processes' output and runs due timers. So Lisp can run "inside"
  `process-send-string`; jsonrpc even reschedules its own filter on a timer to avoid
  recursion (bug#60088), which is one source of the nested timers.
- `timer-event-handler` is the Lisp function Emacs calls for each due timer;
  `:around` advice on it, bound to whether a send is running, shows what ran inside
  sends.

## Key files walked
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--setup-eglot` (the flag sets,
  the verbose log through `/bin/sh -c 'exec ...'` so the pid stays clangd's, the
  advice on `process-send-string`, `jsonrpc--process-filter`,
  `eglot-handle-notification` and `timer-event-handler`), the `T-129` lines in
  `s20--checkout`.
- `spikes/s20-fswatch-reverter/mac-t129-*.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the gaps in clangd's verbose log are its main thread busy with the
  includer lookup. **Would break if:** another main-thread step of the patched
  didOpen is the cost; the "Compile command ... (index)" lines sit in the gaps but
  are not timed themselves. **DESIGN bet:** O-79 (f). Broken 2026-11-03: the lookup
  runs on the worker thread (`TUScheduler.cpp:871`); O-79 reopened for (f).
- **Assumed:** the timers inside sends are what the config would run too. **Would
  break if:** the spike's own timers (its queue step) dominate and the config's are
  fewer; the nested closure's identity is UNVERIFIED (byte-compiled, 2 arguments).
  **DESIGN bet:** O-79 (e).
- **Assumed:** round 1's stock run is usable although a `make test` overlapped it.
  **Would break if:** the overlap hid stalls; round 2's clean stock run agrees (none).

## How to verify
On the Mac: `S20_CLANGD_FLAGS=stock S20_MODES=eglot sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null` and the same with `patched`;
compare the `stalled send` and `timers inside sends` lines in
`spikes/s20-fswatch-reverter/eglot-share.log`. `S20_CLANGD_LOG=<file>` adds clangd's
verbose log.
