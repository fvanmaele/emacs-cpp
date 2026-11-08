# 0111 - D-160: the residual stall traced; the Mac's on-access scan, not the pipe

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  the CPU time correction is 43cf94b
- **Tier:** 3 (spike S20)
- **Decisions:** D-160 (O-79, "do more research on the leftover write stall"); O-80
  opened
- **Done when:** the residual stall split into time clangd leaves the pipe full and
  time Emacs waits with room in it (D-160).

> Plain English for someone who does not read C, Emacs Lisp or C++ fluently.

## What + why
D-159 left the 56 KB write that seemed to wait 162 - 170 ms with two explanations.
D-160 looked at the pipe itself. A small C library, loaded into the spike's Emacs only,
logs every write to clangd's input pipe, how full the pipe is, and every sleep Emacs
takes while a write waits. The pipe held the 56 KB write for only 10 - 15 ms. The rest
of the "stalled send" was the reverter's own filter: while Emacs waited on the full
pipe, it read fswatch's next batch of changed files and reverted them inside the
send. In all six runs that showed such a stall, its length equals that second filter
call's to within 2 ms.

The pipe part is small and has both suspected causes. clangd starts reading 3 - 10 ms
after the pipe fills, and Emacs, which does not notice the pipe emptying, then sleeps
out a fixed 20 ms with room in it. With stock flags the pipe never fills.

The freeze that remains (about a quarter second) is the reverts themselves, and Emacs
spends most of it not running: in the file reads. On this Mac, G DATA's antivirus
checks every newly written file the first time anything opens it, and holds the open
until it is done. While clangd keeps 7 - 9 of the 11 cores busy, the checker gets
little CPU, so each revert's open waits several ms. A test without clangd shows the
same with plain CPU burners: first opens of new files up to 0.7 s in this
repository's tree, against 0.2 - 0.3 ms idle. Arch has no such checker.

On the way the session found that Emacs 31.1 reports other processes' CPU time 41.7
times too small on Apple silicon. S18 had judged the Mac's watch cost with it; that
correction is O-80 (43cf94b).

## Concepts explained
- `DYLD_INSERT_LIBRARIES` and interposing: macOS loads an extra library into a
  program when it starts; a table in that library (`__DATA,__interpose`) redirects the
  program's calls to `write` and `pselect` to the library's own functions, which call
  the real ones and log. It works for programs without the hardened runtime (Emacs and
  clangd here are ad hoc signed). macOS drops `DYLD_*` when a system program such as
  `/bin/sh` starts the target, so `EMACS` must name the binary, not a wrapper script.
- `fstat` on a pipe's write end: `st_size` is the number of bytes waiting in the pipe.
- Re-entrant filters: while Emacs waits inside a send (or `accept-process-output`), it
  reads every process's output and runs their filters and due timers, so a filter can
  run inside itself.
- Endpoint security: a macOS interface through which an antivirus is asked before a
  file opens; the open waits for its answer.
- `current-cpu-time` against wall time: a call that takes much longer than the CPU
  it used was waiting, for a CPU or for the kernel.

## Key files walked
- `spikes/s20-fswatch-reverter/pipetrace.c` - `trace_write`, `trace_pselect`, `monitor`.
- `spikes/s20-fswatch-reverter/pipetrace.py` - `blocked_sends`, `shares`.
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--filter` (wall and CPU per call),
  the `insert-file-contents` advice, `s20-cpu-scale`, `s20--start-sample`.
- Emacs 31.1 `src/process.c` (`send_process`, `wait_reading_process_output`),
  `src/sysdep.c` (Darwin `system_process_attributes`); clangd `TUScheduler.cpp`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the trace does not change what it measures (its polling thread runs
  only while the pipe holds data). **Would break if:** the traced runs differed from
  untraced ones; their blocks (0.250, 0.291 s) are near the untraced runs' (0.209 -
  0.282 s). **DESIGN bet:** D-160.
- **Assumed:** the off-CPU time in the reverts' reads is G DATA's on-access scan.
  **Would break if:** with real-time protection paused the first opens stay slow under
  load (then the file system itself). **DESIGN bet:** O-79 (s).
- **Assumed:** the batch Emacs stands for the GUI one. **Would break if:** the GUI's
  `ns_select` loop wakes differently; the 20 ms wait is the same code (UNVERIFIED in
  the GUI). **DESIGN bet:** O-79.

## How to verify
`S20_PIPETRACE=$TMPDIR/s20-trace S20_STEP_WAITS=1 S20_CLANGD_FLAGS=patched
S20_MODES=eglot EMACS=/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`; in
`spikes/s20-fswatch-reverter/eglot-share.log` the `pipetrace (D-160)` block, the
`filter calls (D-160)` and `reverts (D-160)` lines of back-to-back 2.
