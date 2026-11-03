# 0110 - S20 `fswatch-shown`: PASS on Arch, S20 passes on both machines

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  runs by the owner on H-22, 2026-11-03 23:05 - 23:07Z
- **Tier:** 3 (spike S20)
- **Decisions:** D-153 (O-78 (e)), D-151, D-152 (its edge cases)
- **Done when:** three runs of `fswatch-shown` on each machine pass the criteria in
  `spikes/s20-fswatch-reverter/RUN.md` (confirmed with the session's plan
  2026-11-03); 0103 covered the Mac, this entry covers Arch.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0103 left S20's new mode with its Arch half open (H-22). The owner ran it three times
on the Arch workstation, idle (load 0.85 - 1.31), with the session's commits through
b9e2146. Criteria 1 - 6 hold in every run; criterion 7, the wiring of
`window-buffer-change-functions`, is checked on the Mac only, as `RUN.md` says.

A 190-file checkout leaves every unedited buffer current 0.13 - 0.14 s after `git`,
Emacs is blocked at most 0.14 s (limit 0.25 s), the three shown buffers name the new
branch and have fresh diff-hl marks 0.33 - 0.36 s after `git`, and showing one of the
186 hidden buffers costs 0.02 - 0.05 s. The idle fswatch holds 6 descriptors and
5.2 MB. The contrast mode with diff-hl's own revert hook left in place blocks Emacs
1.6 - 2.4 s per checkout, so holding that hook back matters on Arch as on the Mac.
Numbers per run in `spikes/s20-fswatch-reverter/RESULTS.md`.

So S20 passes in mode `fswatch-shown` on both machines; T-128 is no longer waiting on
S20. It still waits on O-79's ruling (the block during clangd's reparse) before its
code is written.

## Concepts (Emacs Lisp) explained
- One filter call per checkout on Arch: inotify reports four records per file and the
  patched fswatch hands Emacs all 761 - 763 at once, so the process filter reverts
  all 189 buffers in one call (124 - 141 ms). That single call is Emacs's whole block
  here; on the Mac FSEvents splits the same checkout into 2 - 3 smaller calls (87 -
  95 ms longest).
- Ready time is inotify's setup: fswatch adds one watch per directory (about 2000 in
  the generated repository), 0.54 s, against FSEvents' 0.02 s on the Mac.

## Key files walked
- `spikes/s20-fswatch-reverter/arch-shown-run1.log` .. `arch-shown-run3.log` - the runs.
- `spikes/s20-fswatch-reverter/RUN.md` - criteria 1 - 7 of `fswatch-shown`.
- `spikes/s20-fswatch-reverter/RESULTS.md` - the Arch section and the verdict line.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 190 files stand for a daily checkout. **Would break if:** a checkout of
  several hundred files; the one filter call grows with it (about 0.7 ms per buffer
  here, UNVERIFIED beyond 190 files, linear would pass 0.25 s near 340). T-128's note
  "queue reverts too" covers it. **DESIGN bet:** D-153.
- **Assumed:** batch Emacs's direct call of the show handler costs what the hook costs
  in a running Emacs (as in 0103; wiring checked on the Mac only). **Would break if:**
  redisplay on Linux / GTK adds work per show. **DESIGN bet:** D-153.
- **Assumed:** the owner's idle desktop (load about 1) is representative. **Would break
  if:** a build running beside the checkout stretches the filter call past 0.25 s
  (unmeasured on Arch). **DESIGN bet:** D-057, D-153.

## How to verify
On Arch: `S20_MODES="fswatch-shown fswatch-diffhl" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
