# 0080 - S15: mid-word matches ranked by shape in clangd, PASS on RMO

- **Date:** 2026-10-19
- **Commits:** `git log -- spikes/s15-mid-word-rank`
- **Tier:** 3 (spike S15)
- **Decisions:** D-119 (O-67 (a))
- **Done when:** RESULTS.md has a verdict on criteria 1 - 7 from the owner's run on
  RMO on Arch (a dry run here first)
- **Tag:** none

> Plain English. No configuration code changed; everything lives in the spike's
> directory and in a scratch clangd under `~/.cache/emacs-cpp-s15`.

## What + why
Typing `ector` in `C-c l s` listed Kokkos constructors (`EBOBaseImpl<..., CtorNotOnDevice>`,
matched as `E` + `Ctor`) before any `Vector`, and the project's own
`Vector` could fall outside the 100 shown (`RESEARCH_go_to_anything.md` 18, 19).
clangd ranked every match that starts inside a word after every other match, and
those scattered matches counted as "other". The spike tried rule R4: a match whose
typed text runs unbroken from a word start keeps its place; scattered and mid-word
matches follow, ordered by how much of the name they cover. On RMO all seven
criteria pass: `ector` now gives `dealii::Vector` first, and no good match of an
ordinary query moved.

## Concepts (C++) explained
- **Two rankings, one after the other.** clangd's index (Dex) first keeps the best
  `limit` symbols by its own score (name match times a stored quality), then
  `getWorkspaceSymbols` scores those again with more signals and sorts. A rule that
  lives only in the second step cannot rescue what the first already dropped, so the
  spike changes both.
- **Floats near a million.** A `float` has 24 bits of precision; around 1,000,000
  the next value is 0.0625 away. Patch 0012 pushed mid-word matches down with
  `Score -= 1e6f`, which rounded their small differences away and made them tie.
  `-1 / (1 + score)` maps every score into (-1, 0) instead, below every normal match
  (0 or more), and keeps the order.
- **Word starts.** clangd splits names into segments (`has_boundary_lines` ->
  `has`, `boundary`, `lines`; `TangentVector` -> `Tangent`, `Vector`) with a small
  lookup table (`calculateRoles`); the spike and `compare.py` (a Python port of the
  table) use the same split.

## Key files walked
- `spikes/s15-mid-word-rank/0001-rank-mid-word-by-shape.patch` - `middleRank` in
  `FuzzyMatch.cpp`, used by Dex, MemIndex and `getWorkspaceSymbols`.
- `spikes/s15-mid-word-rank/compare.py` - the seven criteria; `DRY-RUN.md` - why
  criteria 1 and 3 changed during the dry runs; `RESULTS.md` - the owner's runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** covering more of the name means a better mid-word match. **Would
  break if:** long names are what the owner looks for; then `ector` lists short
  `Vector`s before `TangentVector`. **DESIGN bet:** D-119.
- **Assumed:** RMO's index stands for step-1's (deal.II both, RMO adds Kokkos,
  Trilinos, PETSc). **Would break if:** the Mac's 23.1.3 tree ranks differently;
  patch 0013 is built and tested on both.
- **Risk:** the installed clangd's reply to one query changed between two runs on
  the same index (run 1); not explained, recorded in RESULTS.md.
- **Risk:** this departs from CLion, which lists mid-word matches last.

## How to verify
`bash spikes/s15-mid-word-rank/build.sh`, then `run.sh` with RMO's project,
`build-release` and `src/main.cc` (RUN.md): `check: 7 of 7`.
