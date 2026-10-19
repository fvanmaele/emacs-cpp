# S15 results

Verdict: PASS (owner's run 2, 2026-10-19): criteria 1 - 7 as in RUN.md.

## Environment
Owner's Arch workstation; baseline the installed `/opt/clangd-index-nav/bin/clangd`
(23.1.1, pkgrel 8, patches 0001 - 0012), spike the same plus
`0001-rank-mid-word-by-shape.patch` (`build.sh`, PKGBUILD's flags); RMO
(`RMO-gross-pitaevskii`, preset `build-release`, 14 sources; deal.II, Kokkos,
Trilinos, PETSc, Boost headers), `src/main.cc` opened, the build directory copied
afresh for each of the three runs; each run 31 - 34 s until the index was idle. The
owner ruled RMO on Arch decides (was step-1 on the Mac). The dry runs before it:
`DRY-RUN.md`.

## Measurements (owner's run 2)
| Criterion | Result |
|---|---|
| 1. mid-word: limit 100 holds the complete reply's first 10 | 12 of 12 |
| 2. High before Low in every complete reply | 32 of 32 |
| 3. High matches in the baseline's order, up to ties | 32 of 32 |
| 4. same complete set of matches as the baseline | 32 of 32 |
| 5. mid-word: first result contains the query | 12 of 12 |
| 6. time, limit 100, median (mid-word / fuzzy) | 4.7 / 7.7 ms (baseline 4.8 / 6.6) |
| 6. time, limit 100, slowest (mid-word / fuzzy) | 9.6 / 27.0 ms |
| 7. `middleRank` only behind `middleMatch` | yes (read in the patch) |

Complete replies (every match, not asked for by either prompt): slowest 351.4 ms.

First results at limit 100, spike | baseline:
- `ector`: `dealii::Vector`, its constructors, `EpetraWrappers::Vector` | five
  Kokkos `EBOBaseImpl` constructors.
- `egree`: `PiecewisePolynomial::degree`, `boost::math::...::degree` |
  `Triangulation::ExcGridReadError`, `boost::concepts::DegreeMeasure`.
- `ensor`: `FEValuesViews::Tensor`, `dealii::Tensor` | `enrich_sort`,
  `DM_POLYTOPE_SEG_PRISM_TENSOR`.
- `ngulat`: `parallel::shared::Triangulation`, `dealii::Triangulation` |
  `DistributedTriangulationBase`.
- `ssembl`: PETSc's `MatAssembled`, `MatAssemblyEnd` | Epetra's `GlobalAssemble`.
- `uadrat`: `TSGetQuadratureTS`, `KSPQCGGetQuadratic`, then `dealii::Quadrature`
  4th | five `Exc...Quadrature...` exceptions.

Reported, not judged: criterion 1 for fuzzy queries, `fin` 1, `ope` 0, `poi` 0,
`sol` 0, `typ` 0, `quad` 8 of 10 (Dex's own pre-ranking, the baseline alike); fuzzy
top 100 shared with the baseline at limit 100 from 0 (`ope`) to 100, median 93 (ties
at the cut; criterion 3 shows no High match moved).

Run 1 (same day, same setup, replies kept in `~/.cache/emacs-cpp-s15/owner-run1`):
6 of 7, criterion 4 failed for `ass` only: baseline run 1 held 24 Boost
`type_traits` symbols (`has_bit_and_assign` ...) that baseline run 2 and the spike
both lacked; the spike equalled baseline run 2 in all 32 queries. The owner asked
for a rerun (run 2, above), where all three runs agree.

## Decision
Clangd patch 0013, written fresh: R4 (`RESEARCH_go_to_anything.md` 19) in
`getWorkspaceSymbols`, Dex and MemIndex behind `middleMatch`; a Low match's score
-1 / (1 + score), replacing patch 0012's -1 times quality and minus 1e6; with clangd
unit tests; pkgrel 9 and a Mac rebuild (T-108, done when to agree).

## Gotchas
- Dex keeps its 100 by its own score before clangd re-ranks, and many symbols tie
  at the cut: a limit-100 reply is not the head of the complete reply, in either
  binary.
- Symbol positions are not unique (a template and its specializations); compare
  by position, container and name.
- clang's builtin headers lie next to each binary: compare their paths relative to
  `lib/clang/N/include`.
- `Score -= 1e6f` loses everything below 0.0625 in a float.
- The installed clangd's complete reply for one query differed between two runs on
  the same copied index (run 1, `ass`): judge sets against more than one baseline
  run.
- The spike reports its ranking score in `score`; the shipped patch keeps
  clangd's meaning of the field.

## Follow-ups (folded elsewhere)
- T-108: patch 0013 per the Decision; tier 2 after this PASS, done when to agree.
