# 0123 - T-131: refresh first, S20 `shipped` PASS on the Mac; T-131 done

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  the code d3a1ea1
- **Tier:** 2 (T-131)
- **Decisions:** D-169
- **Done when:** D-169: `emacs-cpp-reverter-steps` checks the order, `make test`
  passes, S20 `shipped` passes `fswatch-shown`'s criteria 1 - 6 in three runs on each
  machine. Arch met it (0122); this entry covers the Mac (H-27, run by the session).
  Met: T-131 done.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
D-169 has the reverter refresh a shown buffer's branch and diff-hl marks before it
reverts the remaining hidden buffers. Arch passed in 0122; H-27 asked for the same on
the Mac, where this session runs, so it ran H-27's steps 3 - 6 itself at d3a1ea1.
`make test` passes (151 run, 0 unexpected, the usual 3 skips) and all three S20
`shipped` runs pass: Emacs blocked at most 0.08 - 0.11 s (limit 0.25 s), shown buffers
complete 0.23 - 0.31 s after `git` (D-168 on the Mac: 0.49 - 0.58 s), every buffer
current within 0.53 s (limit 1.0 s).

## Concepts (Emacs Lisp) explained
- Nothing new: the order of two queues served by one timer (0122).

## Key files walked
- `spikes/s20-fswatch-reverter/mac-d169-shipped-run1.log` .. `run3.log`.
- `spikes/s20-fswatch-reverter/RESULTS.md` - the new Mac section; Arch's verdict line.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a load of 2.6 - 3.1 counts as the Mac's ordinary state, as for the
  earlier judged Mac runs (2.54 - 4.32). **Would break if:** the owner rules idle runs
  only; the times would then be lower. **DESIGN bet:** D-169.
- **Assumed:** a single refresh step stays near 0.1 s on the Mac (0.104 s here, 0.102 s
  in 0118). **Would break if:** a larger file or a slower git pushes one step past
  0.25 s; a budget cannot split it. **DESIGN bet:** D-153.

## How to verify
On the Mac: `make test </dev/null`, then `S20_MODES="shipped fswatch-chunked" sh
spikes/s20-fswatch-reverter/run.sh </dev/null` and read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6.
