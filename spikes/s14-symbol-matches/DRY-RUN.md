# S14 dry runs (before the owner's run)

Not a verdict: RESULTS.md comes from the owner's run, after the refined criteria in
RUN.md are confirmed. The dry run on a clone of step-1's index passes criteria 1 - 5
(2026-10-15, below).

## Environment
Mac (Apple silicon, Darwin 27), clangd 23.1.3 with patches 0001 - 0009 (installed,
baseline) and the same plus `0001-middle-and-loose-scope-matches.patch` (spike, built
by `build.sh` in `~/.cache/emacs-cpp-s14`); deal.II's step-1, preset `mac-debug`
(4567 index shards), `src/main.cc` opened; the index cloned aside for each run, so
step-1 itself was only read. Each run: about 31 s until the index is idle and a
probe answers the same twice.

## Dry run 5 (the one that counts for now)
| Criterion | Result |
|---|---|
| 1. mid-word gains matches containing the query | 8 of 8 queries |
| 1b. they rank after every fuzzy match | 8 of 8 |
| 2. abbreviated scopes reach their class or namespace | 7 of 7 (baseline 0 of 7) |
| 3. fuzzy, limit 10000: baseline's reply leads, order up to ties | 20 of 20 (exactly 3) |
| 4. time, median (fuzzy / mid-word / scoped) | 2.0 / 1.3 / 1.3 ms (baseline 1.3 each) |
| 4. time, slowest (fuzzy / mid-word / scoped) | 71.6 / 6.5 / 1.3 ms (73.7 / 1.3 / 1.3) |
| 5. `AllowMiddleMatch` set only in `getWorkspaceSymbols` | yes (`FindSymbols.cpp:313`) |

Examples (limit 10000, spike count, baseline count in brackets): `ector` 952 (13),
`ngulat` 53 (0), `olution` 35 (0), `atrix` 178 (0); `geom::vert` 34 (0), first
`dealii::GeometryInfo::vertex_indices`; `tria::n_act` 34 (0), first
`dealii::Triangulation::n_active_cells`; `vt::interp` 22 (0), all
`dealii::VectorTools::interpolate`; `spm::vmult` 4 (0), `dealii::SparseMatrix::vmult`.
Limit 100, fuzzy: the same names as the baseline in 2 of 20 queries; a second
baseline run matches the first in 5 of 20 (ties at the cut).

## What the dry runs changed (each found by the run before)
1. Run 1: the mid-word score 0.01 let some mid-word matches outrank fuzzy ones (the
   index multiplies the match score by the symbol's quality). Lowered to 1e-6.
2. Run 2: `mt::create` reached nothing in either build: step-1 never includes
   `matrix_tools.h`. Replaced by `spm::vmult`. The second baseline run then
   disagreed with the first in 15 of 20 fuzzy queries: all runs shared one cloned
   index, each loading what the run before had written. Each run now clones afresh.
3. Run 3: a run still started measuring while the index swapped in its rebuilt
   tables; the client now waits until a probe answers the same twice, 2 s apart.
4. Run 4: the remaining baseline-to-baseline differences were only at limit 100
   (ties at the 100th place); complete replies were equal. Two real spike defects
   showed: a class template's constructor is named `DiagonalMatrix<VectorType>`, so
   `ector` matched inside the template argument (now the identifier before `<`
   only); and even 1e-6 outranked fuzzy matches that score 0 (now a negative score
   in the index and a large offset in `getWorkspaceSymbols`, so mid-word matches
   always come last and go first at a limit).
5. Run 5: every criterion passes; the complete fuzzy replies hold the baseline's
   names in the baseline's order except within ties, which the extra candidates
   reorder in clangd's top-N heap.

## For patches 0011 / 0012 (if PASS)
- The mid-word rule as run 5 has it: identifier only, 3+ characters, negative score
  in Dex and MemIndex, strictly after fuzzy matches in `getWorkspaceSymbols`; the
  request field also in `operator==` and the JSON of `FuzzyFindRequest`.
- The scope rule: `fuzzyScopeMatch` next to `approximateScopeMatch`.
- clangd unit tests for both (FindSymbolsTests, DexTests).
- With O-50's patch 0010, one rebuild on both machines.

## Owner's run
```
bash spikes/s14-symbol-matches/build.sh   # skips what is built
bash spikes/s14-symbol-matches/run.sh
```
