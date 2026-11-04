# 0120 - S20 probes: GC, the filter's lookups per record, gaps between steps

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter/probe` (this entry's commit)
- **Tier:** 3 (spike S20, measurement only)
- **Decisions:** D-168 (its evidence); none new
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB), not the Xeon W-2145 workstation
  (recorded 2026-11-04)
- **Done when:** each UNVERIFIED mark of 0115 - 0119 that Arch can reach is measured or
  stated as out of reach.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner asked for the open UNVERIFIED marks to be checked. Four could be measured on
this Arch machine. Each probe is a small Lisp file that hooks the module's functions
(advice) before S20's run loads, so the module itself stays unchanged.

1. The one slow revert step on checkout `a` (63 - 65 ms, 0119) is a garbage
   collection: one revert held a 27 - 30 ms collection, a different file each run,
   never the deleted file's buffer. A budget cannot split it, and the step stays far
   under the 0.25 s limit.
2. The module's filter costs 10 - 11 ms where the spike's cost 4 - 5 ms because it
   looks each of the 761 records' buffers up (`get-file-buffer`, about four records
   per file) where the spike looks each path up once. With one record per path the
   module's filter takes 4.0 ms. A possible tier 1 change; not made (owner's call).
3. The module's "ready 0.01 s" (0115) is not faster fswatch: the module starts fswatch
   when the first file is visited, 3.6 s before S20 starts its ready check.
4. In a running terminal Emacs, a step that arms the next one 0.01 s later leaves a
   10 ms gap every time, and process output and typed keys are handled in each gap
   (0116's assumption). Not run in the GTK Emacs.

Left: the Mac-only marks (G DATA, clangd's residual write stall, the scan's share) and
why `git` was slow in 0115's run 6, a past moment nothing recorded.

## Concepts (Emacs Lisp) explained
- `gcs-done` and `gc-elapsed` count garbage collections and their total time; reading
  them before and after a call shows whether a collection ran inside it.
- `get-file-buffer` walks the buffer list comparing file names, so its cost is the
  number of calls times the number of open buffers; calling it once per path instead
  of once per record cuts the calls by about four.
- `advice-add` on a function not yet defined holds until the definition arrives, so a
  file loaded before `s20-run.el` can time the module's functions.

## Key files walked
- `spikes/s20-fswatch-reverter/probe/run-probe.sh`, `trace.el`, `dedupe.el`, `ready.el`.
- `spikes/s20-fswatch-reverter/probe/tstep.sh`, `tstep.el`, `ticker.sh`, `keys.sh`.
- `lisp/emacs-cpp-reverter.el` - `--handle`, `--filter`, `--step` read, unchanged.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the probes' advice does not change what they measure. **Would break
  if:** advice overhead hides a cost; the filter comparison was rerun without the
  trace advice (10.1 - 10.5 ms against 4.0 - 4.2 ms). **DESIGN bet:** D-168.
- **Assumed:** a terminal Emacs stands for the GTK one in how timers and input
  interleave. **Would break if:** GTK's event handling runs due timers back to back
  (not run). **DESIGN bet:** D-167, D-168.

## How to verify
`PROBE=trace sh spikes/s20-fswatch-reverter/probe/run-probe.sh`, likewise `dedupe`,
`ready`, `none`; `sh spikes/s20-fswatch-reverter/probe/tstep.sh` (Linux).
