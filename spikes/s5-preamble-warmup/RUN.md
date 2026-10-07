# S5 - preamble warm-up

## Risk
DESIGN 11, owner reports 2026-10-08: `M-.` and rename wait 7 - 13 s the first time in
each file, because clangd must parse ("preamble") everything the file includes, deal.II
and Boost, before it answers. clangd's options do not change this (DESIGN 11 table).
CLion hides it by analysing files ahead of time. The spike measures the Emacs
equivalent on RMO: open every project source in the background when eglot starts, so
the parse is done before it is needed. Question: is the first `M-.` then instant, and
what does it cost in wall time and clangd memory? Also checks whether a header opened
after the warm-up gets correct flags (O-5).

## Prerequisites
cmake, ninja, clangd, rsync and the shipped config built (`make packages`). The project
is copied to `/tmp/s5/work/rmo` and configured with its `debug` preset; the real project
is never written to. Best run while no simulation is using the CPU (the log records the
load).

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s5-preamble-warmup/run.sh ~/source/repos/RMO-gross-pitaevskii
```
Takes a few minutes.

## Run 2 (after run 1, see RESULTS.md)
Same command. Each scenario now runs twice: round 1 on the fresh copy (index empty),
round 2 with the index clangd persisted in round 1 (daily use). Scenario C warms only
`src/main.cc` and two more sources. If you can, run it while no simulation uses the
CPU, and name the RAM clangd may use alongside your simulations.

## What it measures
- A (today): only `src/main.cc` opened; time of the first `M-.` on a `dealii::` name,
  clangd memory; then a header under `include/` opened, its "not found" errors counted.
- B (warm-up): every project source in the database (fmt excluded) opened first; time
  until clangd has parsed all of them, clangd memory; then the same `M-.` and header.

## Pass criteria
PASS if B's first `M-.` is under 0.5 s and clangd memory after the warm-up stays under
a budget the owner names (DESIGN 3: 31 GB RAM, simulations run alongside). The warm-up
time is recorded, not judged (it runs in the background).

## Hand back
`spikes/s5-preamble-warmup/results.log`; delete `/tmp/s5` afterwards.
