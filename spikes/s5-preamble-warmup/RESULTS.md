# S5 - preamble warm-up: results

Verdict: FAIL (run 1, 2026-10-08). After warming all 10 sources the first `M-.` took
1109 ms, above the 0.5 s criterion, and no memory budget was set. The warm-up still
cut the wait about tenfold (10885 -> 1109 ms). Run 1 was skewed (below); run 2 measures
with a persisted index and a 3-file variant.

## Environment
Owner machine, 2026-10-08 00:22. clangd 23.1.1. Copy of RMO at `/tmp/s5/work/rmo`,
fresh `debug` configure, so the background index started empty. Load average 10.8 at
the start (owner simulation), 23.9 at the end; 17 GB RAM available at the start.
Raw output: `results-run1.log` (restored from the owner's paste, see Gotchas).

## Measurements
| scenario | first `M-.` in main.cc | clangd RSS | warm-up |
|---|---|---|---|
| A: only main.cc open (today) | 10885 ms | 4810 MB | - |
| B: all 10 sources opened first | 1109 ms | 9612 MB | 39682 ms |
A header (`include/rmo/fe/assemble.h`) opened after main.cc or after the warm-up had
0 "not found" errors in both scenarios.

## Findings
1. Warm-up works in principle: the per-file parse moves out of the user's way.
2. Memory grows by roughly 0.5 GB per additionally opened source ((9612 - 4810) / 9).
3. Both rows include clangd building the background index of the empty copy, which
   competes for CPU and memory; daily use starts from a persisted index. Together with
   the load of 10 - 24 this inflates A and B, and may explain why B's `M-.` still took
   1.1 s.
4. Headers are fine once an including source is open (as in S1 live check 5).

## Decision
None yet. Run 2 (index persisted after round 1, plus "C: warm 3 sources") and an owner
memory budget decide whether T-012 warms all sources, a bounded set, or nothing.

## Gotchas
- The run 2 script's dry run (on a synthetic project) overwrote `results.log` before it
  had been renamed; it was restored from the owner's paste. `run.sh` now refuses to
  overwrite an existing log.
