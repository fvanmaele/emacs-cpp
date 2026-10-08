# 0018 - S2 run 1: PASS, dape + gdb on RMO

- **Date:** 2026-10-08
- **Commits:** see `git log -- spikes/s2-dape-gdb`
- **Tier:** 3 (spike S2)
- **Decisions:** D-002 holds; O-14 opened
- **Done when:** RUN.md pass criteria (stop at the breakpoint with `main` on top,
  variables, watch, step over and in, clean end, breakpoint restored after load)
- **Tag:** none

> Plain English summary of the spike result.

## What + why
Debugging is milestone v0.3, gated by S2. The owner ran the spike on RMO: dape drove
gdb 18.1 (and lldb-dap) through a whole session on the debug build of `main`, and
every variant met every criterion. Details and numbers: `spikes/s2-dape-gdb/RESULTS.md`.

## Concepts explained
- **DAP:** the Debug Adapter Protocol; gdb speaks it itself (`gdb -i dap`), so dape
  needs no extra adapter program.
- **Shared-library symbols:** gdb reads each library's debug information when the
  program starts; deal.II's debug library is 1.3 GB, which is why the first stop takes
  17 s. "On demand" postpones that until a deal.II frame is needed.
- **Pretty-printers:** small Python programs that make gdb show a `dealii::Vector` as
  its values instead of its internal members.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the first scope gdb reports for other functions is "Locals"; for RMO's
  `main` it was "Arguments", so gdb's Locals were not printed on RMO. **Would break
  if:** the Locals view misses variables; T-006's test opens the full view.
- **Risk:** the 17 s first stop on RMO; O-14 decides between full and on-demand
  symbols.

## How to verify
`spikes/s2-dape-gdb/results-run1.log`; rerun with `sh spikes/s2-dape-gdb/run.sh` after
removing `/tmp/s2` and moving the log away.

## Open questions
O-14 (gdb setup for T-006).
