# S19 - gap trigrams and a third match tier in clangd

## Risk
O-68 (c), owner 2026-11-04 (D-171). clangd's index offers a symbol to
`workspace/symbol` only if it holds every three-letter run of the query
(`identifierTrigrams`: next letter of a segment, or the next segment's first letter),
and `FuzzyMatcher` / `tieredMatch` (patches 0012, 0013) accept a gap only before a
segment start. So letters in order with a gap inside a word (`eto` -> `Vector`,
`cml` -> `class_multilevel_experiment`) never reach the ranking
(`RESEARCH_go_to_anything.md` 20). Question: do gap trigrams find them at today's
query cost, with memory and build time inside the limits below, without changing code
completion? Spike code is never promoted; a PASS leads to clangd patch 0014 written
fresh, with clangd unit tests (D-069).

## What the spike builds
One patch on the patched tree (patches 0001 - 0013, pkgrel 10), from section 20:
- `Trigram.cpp`: a second generator, gap trigrams: every in-order letter triple whose
  first letter starts a segment and whose jumps stay inside a word or go to the next
  segment's first letter; `Token.h`: a token kind for them.
- `Dex.cpp`: posting lists for the gap kind built with the ordinary ones; with the
  request field set, the query's gap trigrams are intersected in place of the
  ordinary ones.
- `FuzzyMatch.cpp`: tier 3 in `tieredMatch`, the first letter at a segment start and
  the rest in order with any gaps, scored below every tier-2 match (as
  `secondTierScore` does for tier 2).
- The request field (`Index.h` / `Index.cpp`, `Protocol.*`, `FindSymbols.cpp`): set
  only by `workspace/symbol` on the client's request, as `middleMatch`; code
  completion, the include fixer and xrefs never set it.
- A benchmark linked against the build's clangd libraries (`Dex::build`,
  `Dex::fuzzyFind`, memory from `Dex::estimateMemoryUsage`), medians of 21 runs, as
  section 20 measured; a client for `workspace/symbol` as S15's `client.py`.

## Pass criteria (proposed 2026-11-04 in T-132; owner confirmed 2026-11-04: "Confirm
S19, run on Arch")
On Arch (D-057), deal.II 9.8's library index (`indexes/dealii.dex`) and RMO's
background index, the patched clangd with the spike's patch against pkgrel 10:
1. Found: with the field, `eto` returns deal.II's `Vector` and `cml` RMO's
   `class_multilevel_experiment`; for the 12 queries of section 20 (`eto`, `ptr`,
   `get`, `tria`, `nac`, `rnm`, `cml`, `vec`, `vector`, `dfh`, `fev`, `qgau`), gap
   matches rank below every tier 1 - 2 match.
2. Unchanged: without the field, code completion and `workspace/symbol` return the
   same lists as pkgrel 10 for those queries.
3. Memory: deal.II's Dex grows at most 20 MB (estimate 8 - 12).
4. Build: `Dex::build` for deal.II at most 2.5 s (today 1.08 s).
5. Query: each of the 12 queries at most 5 ms per index (today 0.02 - 1.84 ms).
6. `M-o` on RMO in S11's harness: keys within S11's 2 - 30 ms.

## Prerequisites
- Arch: the tree `makepkg` left in `packaging/clangd-index-nav/src` (pkgrel 10),
  `indexes/dealii.dex` (`make library-index LIBRARY=dealii`), RMO with its build
  directory.

## Commands
Not written yet: the session on Arch writes the patch, `build.sh`, the benchmark,
`run.sh` and `compare.py` here, dry-runs them, then adds the commands and the
dry run's numbers.
