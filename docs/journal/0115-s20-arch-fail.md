# 0115 - S20 on Arch: `fswatch-shown` runs 4 - 6 and `shipped` fail criterion 3

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20; T-128's Arch done when)
- **Decisions:** D-166 (owner: "S20 (a)"); opens O-81
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB), not the Xeon W-2145 workstation
  (recorded 2026-11-04)
- **Done when:** D-162 (d)'s Arch half (H-23) run and judged; not met.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0110 called S20's `fswatch-shown` a PASS on Arch from the owner's three runs. The
session ran the same commands three more times on Arch (hp-elitedesk; the owner's
runs name no host) at a normal desktop load (1.3 - 1.9). Run 6's first checkout
blocked Emacs 0.30 s, over the 0.25 s limit.
The owner ruled (D-166) that this counts: S20 fails on Arch, and the reverter must
revert from a queue instead of reverting all 189 buffers in one go.

The session had offered that option as "before any T-128 code", but the module had
already shipped that morning on the Mac (e1f3599), and the session had not seen those
commits yet. With them on Arch, the session ran H-23's steps itself: `make test` passes
(151 of 151), and the shipped module's three S20 runs block Emacs at most 0.13, 0.15
and 0.25 s (the filter call 250.6 ms in run 3). That is over the limit too, at a
higher load (3.1 - 3.4, right after `make test`). So the change lands in the shipped
module; how is O-81.

## Concepts (Emacs Lisp) explained
- One process filter call is one uninterrupted stretch: Emacs reads nothing, redraws
  nothing and runs no keys until it returns. On Arch inotify delivers a 190-file
  checkout as one batch of 761 records, so the filter reverts every buffer inside that
  one call; its length (124 - 302 ms over six runs) is the whole block.
- A queue with a time budget: the filter would only list the buffers, and a timer step
  would revert some of them, stop after a few tens of milliseconds and arm the next
  step, so Emacs handles input between steps. Shown buffers would go first.

## Key files walked
- `spikes/s20-fswatch-reverter/arch-shown-run4.log` .. `arch-shown-run6.log`.
- `spikes/s20-fswatch-reverter/arch-shipped-run1.log` .. `arch-shipped-run3.log`.
- `spikes/s20-fswatch-reverter/RESULTS.md` - both Arch sections, the verdict line.
- `lisp/emacs-cpp-reverter.el` - read for the shape only (reverts at once); unchanged.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** run 6's 0.30 s is ordinary desktop use, not a fault of the run.
  **Would break if:** the disk or CPU was used by something unusual (`git` took
  0.11 - 0.13 s against 0.05 - 0.07 s; unknown what). **DESIGN bet:** D-166.
- **Assumed:** the per-buffer cost (0.7 - 1.6 ms) is spread evenly, so a time budget
  per step bounds the block. **Would break if:** a single revert costs tens of
  milliseconds (a large file, eglot's didOpen); then the budget needs a per-buffer
  check too. **DESIGN bet:** O-81.
- **Assumed:** the shipped runs' higher load does not void them. **Would break if:**
  the owner rules idle runs only for `shipped`; they are recorded with their load.
  **DESIGN bet:** D-166.

## How to verify
On Arch: `S20_MODES="fswatch-shown fswatch-diffhl" sh
spikes/s20-fswatch-reverter/run.sh </dev/null` and `S20_MODES=shipped sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
