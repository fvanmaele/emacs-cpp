# 0122 - T-131: shown buffers refreshed before the remaining reverts; Arch PASS

- **Date:** 2026-11-04
- **Commits:** see `git log -- lisp/emacs-cpp-reverter.el` (this entry's commit)
- **Tier:** 2 (owner's ruling O-82 (b), D-169)
- **Decisions:** D-169 (amends D-168)
- **Done when:** D-169: `emacs-cpp-reverter-steps` checks the order, `make test`
  passes, S20 `shipped` passes criteria 1 - 6 three times on each machine. Arch met
  here; the Mac on H-27.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
After a checkout the reverter works through two lists: buffers to revert, and shown
buffers whose version-control branch and diff-hl marks need refreshing. D-168 let a
step refresh only when no revert was left, so the buffers on screen were the last to
look right (about 0.5 s after `git`). The owner ruled O-82 (b): a step now refreshes
a waiting shown buffer first, and reverts only when none waits. Each step still does
one kind of work, so Emacs is never blocked longer than one step.

`emacs-cpp-reverter--step` swaps its two branches, and every step is followed by the
next 0.01 s later while either list holds a buffer. The step test gains a check that
the step after the shown buffer's revert refreshes it and reverts nothing; that check
fails on the module before the change. On Arch three S20 runs pass: shown buffers
complete 0.20 - 0.25 s after `git`, Emacs blocked at most 0.07 - 0.09 s, every buffer
current within 0.56 s.

## Concepts (Emacs Lisp) explained
- `if-let*` binds `next` to the oldest shown buffer waiting and takes the first branch
  only when there is one, so "refresh if any, else revert" is one form.
- `unwind-protect` arms the next step even when a revert or refresh signals, so an
  error in one buffer does not leave the rest of either list waiting forever.

## Key files walked
- `lisp/emacs-cpp-reverter.el` - `--step` (order), `emacs-cpp-reverter-pause` and
  `-step` (docstrings), the commentary.
- `test/emacs-cpp-reverter-test.el` - `emacs-cpp-reverter-steps`.
- `spikes/s20-fswatch-reverter/arch-d169-shipped-run1.log` .. `run3.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** steps 0.01 s apart for refreshes too leave Emacs room (0120's gaps).
  **Would break if:** many shown buffers' refreshes (0.04 - 0.1 s each) run back to
  back with only 10 ms between them while the user types; each still one step.
  **DESIGN bet:** D-169.
- **Assumed:** the Mac shows the same ordering. **Would break if:** the Mac's slower
  refreshes (up to 0.102 s, 0118) push the hidden reverts past 1.0 s; H-27 measures
  it. **DESIGN bet:** D-169.

## How to verify
`make test </dev/null`; `S20_MODES="shipped fswatch-chunked" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
