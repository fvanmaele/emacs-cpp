# 0117 - S20 `fswatch-chunked`: PASS on the Mac

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-167
- **Done when:** three runs of `fswatch-chunked` on each machine pass `fswatch-shown`'s
  criteria 1 - 6 in `spikes/s20-fswatch-reverter/RUN.md`; Arch passed (0116), this
  entry covers the Mac (H-25, run by the session). Met.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0116 measured the queued reverter on Arch; H-25 asked for the same three runs on the
Mac. The session runs on the Mac and ran them itself at d2669fd. All three pass
criteria 1 - 6: buffers current 0.32 - 0.60 s after `git` (limit 1.0 s), Emacs blocked
at most 0.18 s (limit 0.25 s), the fswatch filter at most 1.1 ms per call. So
`fswatch-chunked` passes on both machines, and D-167's next step is due: rewrite
`lisp/emacs-cpp-reverter.el` from these numbers, then run `shipped` on both machines.

The machine was not idle (load 4.40 - 4.55, macOS's `mediaanalysisd` at about one
core). The earlier judged Mac runs were at 2.54 - 4.32, so the session judged these;
the owner may rule a rerun at a lower load.

## Concepts (Emacs Lisp) explained
- On the Mac FSEvents splits a checkout into 2 - 3 batches, so the old filter's
  longest call was 115 - 126 ms (Arch: one batch, up to 302 ms). The queue takes that
  to about 1 ms, but the Mac's largest block stays about the same (0.12 - 0.18 s
  against 0.11 - 0.16 s): it now comes from a revert step and a shown buffer's VC /
  diff-hl refresh step both running inside one wait for process output.

## Key files walked
- `spikes/s20-fswatch-reverter/mac-chunked-run1.log` .. `mac-chunked-run3.log`.
- `spikes/s20-fswatch-reverter/RESULTS.md` - the new Mac section; the Arch section's
  verdict line.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a load of 4.4 - 4.6 does not void the runs. **Would break if:** the
  owner rules idle runs only; the numbers would then be higher than an idle Mac's, not
  lower, so a PASS should hold. **DESIGN bet:** D-167.
- **Assumed:** keeping the revert step and the refresh step out of one pass lowers the
  block (0116). **Would break if:** the refresh step alone (up to 0.127 s here) grows
  past 0.25 s with more shown buffers; S20 shows 3. **DESIGN bet:** D-167.
- **Assumed:** G DATA's on-access scan stayed off (D-161). UNVERIFIED this session:
  its client process used about 19 % CPU. **Would break if:** it was on; the runs
  then passed with it on, which only strengthens the PASS.

## How to verify
On the Mac: `S20_MODES="fswatch-chunked fswatch-shown" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
