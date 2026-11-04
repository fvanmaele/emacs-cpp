# 0121 - D-168 revisited: refresh first keeps the bound, shown buffers current sooner

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20, measurement only)
- **Decisions:** D-168 (revisited); opens O-82
- **Done when:** three runs each of the shipped order and one alternative on Arch,
  with the choice put to the owner with its case against each.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
D-168 was the Mac session's choice inside the rewrite: one timer, and each step does
one kind of work, reverting while any revert is queued, then refreshing the shown
buffers' version-control state and diff-hl marks. The owner asked to revisit it after
new runs. Its measured cost is that the buffers on screen get their branch and marks
last, about 0.5 s after `git`, after all 189 hidden buffers have their text.

A probe (`probe/refresh-first.el`) swaps the order without touching the module: when
a shown buffer waits for its refresh, the next step does that before the remaining
reverts. Each step still does one kind of work, so the block stays where D-168 put it
(0.07 - 0.09 s). The shown buffers are complete at 0.18 - 0.28 s, earlier than with
D-168 (0.45 - 0.55 s) and than with the spike's two timers (0.24 - 0.31 s), and the
hidden buffers' text arrives 0.15 - 0.2 s later (0.36 - 0.51 s, limit 1.0 s). The
choice is O-82; the session recommends refresh first.

## Concepts (Emacs Lisp) explained
- `:override` advice replaces a function's body while every caller, including timers
  armed with the function's name, reaches the replacement; the probe overrides
  `emacs-cpp-reverter--step` this way and calls the module's own revert and refresh
  functions.

## Key files walked
- `spikes/s20-fswatch-reverter/probe/refresh-first.el`, `run-probe.sh` (`FULL=1`).
- `lisp/emacs-cpp-reverter.el` - `--step`, `--revert-step`, `--arm`, read, unchanged.
- `spikes/s20-fswatch-reverter/arch-d168-*.log` - the runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the probe's step is what the module would ship. **Would break if:** the
  written change differs (delays between steps: the probe uses 0.01 s after every
  step). **DESIGN bet:** O-82.
- **Assumed:** text in hidden buffers matters less than state in shown ones. **Would
  break if:** something reads hidden buffers right after a checkout (a grep over
  buffers, eglot's didOpen per revert); still within criterion 1. **DESIGN bet:** O-82.
- **Assumed:** Arch's ordering holds on the Mac. **Would break if:** the Mac's slower
  refresh steps (up to 0.102 s, 0118) push the hidden reverts further. **DESIGN bet:**
  O-82.

## How to verify
`FULL=1 PROBE=refresh-first sh spikes/s20-fswatch-reverter/probe/run-probe.sh` and
`S20_MODES="shipped fswatch-chunked" sh spikes/s20-fswatch-reverter/run.sh </dev/null`.
