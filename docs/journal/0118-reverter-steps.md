# 0118 - The reverter reverts in timer steps (D-167, D-168)

- **Date:** 2026-11-04
- **Commits:** see `git log -- lisp/emacs-cpp-reverter.el` (this entry's commit)
- **Tier:** 3 (T-128; spike S20 `fswatch-chunked` PASS on both machines, 0116, 0117)
- **Decisions:** D-167, D-168 (session's, owner to confirm)
- **Done when:** D-162 (d) with D-167: the module rewritten from `fswatch-chunked`'s
  numbers; `make test` passes on both machines; S20 `shipped` passes `fswatch-shown`'s
  criteria 1 - 6 on the Mac (the session: met) and on Arch (H-26: open).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The reverter used to revert every buffer of a checkout inside one call of fswatch's
process filter; on Arch that blocked Emacs 0.30 s (D-166). Now the filter only puts
the buffers in a queue, those shown in a window first, and a timer reverts them in
steps of about 0.05 s with a 0.01 s pause between, so Emacs reads keys between steps.

The spike ran the reverts and the shown buffers' VC / diff-hl refreshes on two
timers; when both were due at once, Emacs ran them back to back (0.18 s on the Mac).
The module runs both queues from one timer and a step does one thing: revert while
reverts are queued, otherwise refresh one shown buffer (D-168). On the Mac the block
fell to 0.07 - 0.08 s in 5 of 6 checkouts (the spike's mode beside it: 0.11 - 0.13 s).

## Concepts (Emacs Lisp) explained
- A guard variable bound with `let` while a step runs (`emacs-cpp-reverter--busy`):
  Emacs may run timers while a revert waits on a send to clangd (O-79); a step that
  finds the guard set only schedules itself again. `let` undoes the binding even on
  an error, and `unwind-protect` arms the next step either way, so an error in one
  revert does not strand the rest of the queue.
- At least one revert per step: the loop reverts first, then checks the clock, so a
  budget of 0 still makes progress (the test uses that to step one buffer at a time).
- D-161 (p)'s deferred filter output is gone: it existed because the filter reverted,
  and a revert's blocked send let Emacs call the filter again inside itself. The
  filter now only queues and never waits.

## Key files walked
- `lisp/emacs-cpp-reverter.el` - `--enqueue-revert`, `--handle`, `--filter`,
  `--revert-step`, `--step`, `--arm`, `--release` (clears both queues).
- `test/emacs-cpp-reverter-test.el` - `emacs-cpp-reverter-steps` (new, in place of
  `-no-nesting`), `-queue` and `-overflow` adjusted.
- `spikes/s20-fswatch-reverter/s20-run.el` - `shipped` reports its revert steps.
- `spikes/s20-fswatch-reverter/mac-shipped-chunked-run1.log` .. `run3.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** Arch's block falls the same way. **Would break if:** inotify's single
  batch makes the first revert step run long there; H-26 measures it. **DESIGN
  bet:** D-168.
- **Assumed:** a refresh step stays under 0.25 s. **Would break if:** one buffer's VC
  and diff-hl refresh grows (a huge file, a slow git); the budget cannot split it
  (0.102 s seen here). **DESIGN bet:** D-153.
- **Assumed:** a timer armed at a step's end waits for the next pass of Emacs's timer
  loop, so keys are read between steps (UNVERIFIED in keyboard.c; batch runs only).
  **Would break if:** steps run back to back in a live Emacs. **DESIGN bet:** D-167.
- **Assumed:** load 7.8 - 8.2 does not void the runs; it raises times. **DESIGN bet:**
  D-168.

## How to verify
`make test </dev/null`; then `S20_MODES="shipped fswatch-chunked" sh
spikes/s20-fswatch-reverter/run.sh </dev/null` and read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
