# 0119 - The rewritten reverter: S20 `shipped` PASS on Arch; T-128 done

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  4bf8f6d (the rewrite)
- **Tier:** 3 (T-128's done when, D-162 (d))
- **Decisions:** D-168 (the module's steps; owner to confirm), D-167
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB), not the Xeon W-2145 workstation
  (recorded 2026-11-04)
- **Done when:** D-162 (d): `make test` and three runs of S20 `shipped` passing
  `fswatch-shown`'s criteria 1 - 6 on both machines; the Mac in 0118, Arch here. Met.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The Mac session rewrote `lisp/emacs-cpp-reverter.el` from the `fswatch-chunked` spike
(0118) and left the Arch half as H-26. This session pulled the commits on Arch and ran
H-26's steps itself: `make test` passes (151 of 151) and the three S20 runs of mode
`shipped` pass criteria 1 - 6. A 190-file checkout leaves every unedited buffer
current 0.21 - 0.30 s after `git`, Emacs is blocked at most 0.07 - 0.09 s (limit
0.25 s, down from 0.30 s for the module before the rewrite, 0115), and the shown
buffers have their branch and marks 0.45 - 0.54 s after `git`. So T-128's done when
holds on both machines and T-128 is done. D-168, which the Mac session decided within
D-167's rewrite, still waits for the owner's confirmation.

## Concepts (Emacs Lisp) explained
- One timer, one kind of work per step (D-168): a step either reverts queued buffers
  until 0.05 s are spent or, when no revert is queued, refreshes one shown buffer's
  VC state and diff-hl marks. The spike ran the two on separate timers, and both could
  fall due in one pass; on Arch that pair was the spike's 0.08 - 0.11 s block.
- A budget cannot split a revert: on checkout `a` one step ran 63 - 65 ms in every
  run, so one revert in it cost 13 - 15 ms. Still well under the limit.

## Key files walked
- `spikes/s20-fswatch-reverter/arch-shipped-chunked-run1.log` .. `run3.log`.
- `spikes/s20-fswatch-reverter/RESULTS.md` - the new Arch section.
- `lisp/emacs-cpp-reverter.el` - read for its shape only; unchanged.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** load 2.2 - 2.5 right after `make test` is no easier than an idle
  machine. **Would break if:** an idle run is slower (no reason seen). **DESIGN bet:**
  D-168.
- **Assumed:** the 13 - 15 ms revert on `a` is the generated repository's, not a cost
  that grows. **Would break if:** it is the deleted file's buffer returning and such
  buffers cost more in real checkouts. Verified 2026-11-04 (0120): a garbage
  collection, a different file each run. **DESIGN bet:** D-168.
- **Assumed:** the module's 11 ms filter (the spike's: 4 - 5 ms) stays small. **Would
  break if:** its per-path checks grow with the project's size. Verified 2026-11-04
  (0120): `get-file-buffer` once per record, not per path; 4.0 ms with one record per
  path. **DESIGN bet:** D-168.

## How to verify
On Arch: `make test </dev/null` and `S20_MODES="shipped fswatch-chunked" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
