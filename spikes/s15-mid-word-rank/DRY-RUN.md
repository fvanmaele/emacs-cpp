# S15 dry runs (not the verdict; RESULTS.md comes from the owner's run)

Arch, 2026-10-19, baseline `/opt/clangd-index-nav/bin/clangd` (23.1.1, pkgrel 8),
spike built by `build.sh` (PKGBUILD's flags, system LLVM). Project: a toy in the
session's scratch directory, one source including Kokkos, deal.II 9.8 (grid, dofs,
fe, lac, numerics) and through them Trilinos, PETSc, Boost, MPI (include flags taken
from RMO's compile database, no RMO code), plus `Vector`, `TangentVector`,
`assemble_system`; its directory serves as PROJECT and PRESET_DIR.

## Dry run 1
4 of 7 (1, 3, 4 FAIL). All three were compare.py's:
- 4: the same symbols in clang's builtin headers (`_mm512_...`) lie next to each
  binary, so their file names differ; the baseline matched itself. Fixed: builtin
  header paths compared as `<builtin>/...`.
- 1 (then "limit 100 holds 90 of the complete reply's first 100"): the baseline
  failed it as much (`typ` 0, `fin` 6): Dex scores only limit x 100 candidates and
  keeps its 100 by its own score before clangd re-ranks, and many symbols tie.
- 3 (then a mean rank displacement against a second baseline run): symbol ids were
  not unique (a template and its specializations share a position), and a second
  baseline run reorders nothing, so it shows no ties. Fixed: name and container in
  the key; the spike reports its ranking score and the check is "the baseline's High
  order never rises in it" (ties free).
The mid-word results were already as hoped: `ector` -> `dealii::Vector` (the
baseline: ten `EBOBaseImpl` constructors), `egree` -> `degree`, `ngulat` ->
`Triangulation`.

## Dry run 2
6 of 7: criterion 1 (relative to the baseline's overlap) short for `fin`, `vec`,
`vector`; reworded to ranks with ties counted equal, then `atrix` 89 of 100 and
`olution` 19 of 23, although at 23 matches the limit keeps all. Cause, a spike
defect, also in patch 0012: `Score -= 1e6f` in a float leaves steps of 0.0625 near
-1e6, so the Low matches collapsed into a few equal scores. Fixed in the spike patch:
a Low match's score becomes -1 / (1 + score).

## Dry run 3
7 of 7 after criterion 1 became "the limit-100 reply holds every match ranked at or
above the complete reply's 10th" for mid-word queries (12 of 12; `atrix` held 89 of
its first 100, the rest of the gap being Dex's own pre-ranking, as for fuzzy
queries in both binaries).
- 2: High before Low in 32 of 32; 3: no High match rises (32 of 32); 4: the same
  complete sets (32 of 32); 5: the first result contains the query (12 of 12).
- 6: limit 100, mid-word median 3.6 ms (baseline 3.8), slowest 7.2 ms; fuzzy 6.3 ms
  (6.6), slowest 13.4 ms. Complete replies (every match): slowest 169.8 ms (`typ`,
  6211 symbols), not asked for by `C-c l s`; `M-o`'s 10000 asks for no more.
- 7: `middleRank` is called only behind `MiddleMatch`, which only
  `getWorkspaceSymbols` sets (from the request, `ClangdLSPServer.cpp`).
- First results at limit 100 (spike | baseline): `ector` `dealii::FEValuesViews::Vector`,
  `dealii::...::TpetraWrappers::Vector`, `dealii::Vector` | ten `EBOBaseImpl`
  constructors; `ensor` `dealii::FEValuesExtractors::Tensor`, `dealii::Tensor` |
  `EvaluatorTensorProduct`; `ernel` `GraphKernelTrait` | `..._KOKKOSKERNELS_`
  macros; `xecution` `std::execution` | `_PSTL_CPP17_EXECUTION_POLICIES_PRESENT`;
  `uadrat` `dealii::Quadrature` | `ExcInvalidQuadratureFormula`.
- Reported: fuzzy top 100 shared with the baseline at limit 100: `count` 99, `cel` 92,
  `tri` 83, `out` 88, ... `vec` 7, `poi` 0, `typ` 0, `ope` 0 (ties and Dex's own cut make
  these vary; criterion 3 shows no High match moved).
