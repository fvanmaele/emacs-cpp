# S14 results

Verdict: PASS (owner's run, 2026-10-15): criteria 1 - 5 as refined in RUN.md.

## Environment
Owner's Mac (Apple silicon, Darwin 27); baseline the installed
`~/opt/clangd-index-nav/bin/clangd` (23.1.3, patches 0001 - 0009), spike the same
plus `0001-middle-and-loose-scope-matches.patch` (`build.sh`); deal.II's step-1,
preset `mac-debug`, `src/main.cc` opened, the index cloned afresh for each run;
each run about 31 s until the index was idle and a probe answered the same twice.
The dry runs before it, and what each changed: `DRY-RUN.md`.

## Measurements (owner's run)
| Criterion | Result |
|---|---|
| 1. mid-word queries gain matches containing the query | 8 of 8 |
| 1b. they rank after every fuzzy match | 8 of 8 |
| 2. abbreviated scopes reach their class or namespace | 7 of 7 (baseline 0) |
| 3. fuzzy, limit 10000: baseline's reply leads, order up to ties | 20 of 20 (exactly 3) |
| 4. time, median (fuzzy / mid-word / scoped) | 2.0 / 1.3 / 1.3 ms (1.4 / 1.3 / 1.3) |
| 4. time, slowest (fuzzy / mid-word / scoped) | 86.5 / 6.3 / 1.3 ms (92.4 / 1.3 / 1.3) |
| 5. `AllowMiddleMatch` set only in `getWorkspaceSymbols` | yes (read in the patch) |

Limit 100, fuzzy (reported, not judged): the same names as the baseline in 2 of 20;
a second baseline run matched the first in 5 of 20 (ties at the 100th place);
complete replies equal between the baseline runs in 20 of 20.

Examples, limit 10000 (spike count, baseline in brackets): `atrix` 158 (0), first
`dealii::BlockMatrixBase`; `ector` 924 (13); `ngulat` 53 (0); `uadrat` 90 (0);
`geom::vert` 34 (0) and `gi::vert` 34 (0), `dealii::GeometryInfo::vertex_indices`
among the first; `tria::n_act` 34 (0), first `dealii::Triangulation::n_active_cells`;
`dof::n_dofs` 12 (0), first `dealii::DoFHandler::n_dofs`; `vt::interp` 22 (0);
`spm::vmult` 4 (0), first `dealii::SparseMatrix::vmult`.

## Decision
Patches 0011 (loose qualifier) and 0012 (mid-word), written fresh, switched per
request as D-113 rules: request fields next to `limit`, support announced in the
`initialize` reply's capabilities; built with O-50's 0010 in one rebuild.

## Gotchas
- The index multiplies the match score by the symbol's quality, and some fuzzy
  matches score 0: only a negative score (and a large offset in
  `getWorkspaceSymbols`) keeps mid-word matches after every fuzzy one.
- A class template's constructor is named with its arguments
  (`DiagonalMatrix<VectorType>`): match the identifier before `<` only.
- Many symbols tie at a limit of 100, and which make it varies between runs of the
  same clangd; compare complete replies, and order only up to ties.
- Runs sharing one index directory load each other's shards; clone it per run.
- Mid-word matches are many (`ector`: 924): `M-o` shows them after the fuzzy ones,
  `C-c l s` at the end of its kind groups (D-106).

## Follow-ups (folded elsewhere)
- T-104: patches 0011 / 0012 per D-113, with clangd unit tests; tier 2 after this
  PASS, done when to agree.
