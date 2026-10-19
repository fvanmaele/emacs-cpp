# S15 - mid-word matches ranked by shape in clangd

## Risk
O-67 (a), owner 2026-10-19: "O-67 (a) agree". With patch 0012 clangd ranks every
mid-word match after every fuzzy one, and fuzzy matches scattered over word starts
(Kokkos's `EBOBaseImpl<T, true, CtorNotOnDevice>` constructor as `E` + `Ctor` for
`ector`) head the list; among themselves the mid-word matches tie, and Dex scores
them -1 times quality, so at a limit it keeps the lowest-quality ones
(`RESEARCH_go_to_anything.md` 19). Question: does rule R4 in clangd put the
contiguous matches (`Vector` for `ector`, `degree` for `egree`) first in `C-c l s`'s
100 without changing the order of the good fuzzy matches, and without slowing the
prompts? Spike code is never promoted; a PASS leads to clangd patch 0013 written
fresh, with clangd unit tests.

## What the spike builds
`0001-rank-mid-word-by-shape.patch` on the patched tree (patches 0001 - 0012):
- `middleRank` (FuzzyMatch.h / .cpp): a fuzzy match whose query appears
  contiguously from a word start of the identifier (before template arguments,
  without `~`) keeps its fuzzy score (High); a scattered fuzzy match and a mid-word
  match are Low, scored by the share of the identifier the query covers, doubled
  when the match ends a word segment (a scattered match's fuzzy score if higher).
- Dex, MemIndex and `getWorkspaceSymbols` use it when the request has `middleMatch`
  and the query is at least that long; a Low match's final score (after the
  multiplication by quality) becomes -1 / (1 + score), in (-1, 0): it follows every
  High one and keeps its order among the Low ones. Patch 0012 multiplied -1 by
  quality (the better symbol ranked lower) and subtracted 1e6 from a float (steps of
  0.0625, so Low matches tied). Code completion never sets `middleMatch`.
- For compare.py only, `getWorkspaceSymbols` reports its ranking score in `score`
  (spike only; the baseline reports the score without the name match).

## Pass criteria (proposed 2026-10-19 after the dry run; owner to confirm)
On the project's index (cloned afresh for each run), baseline = the installed
patched clangd (pkgrel 8), spike = the same plus the spike patch, 12 mid-word and 20
fuzzy queries, each with limit 100 (as `C-c l s`) and 100000 (every match), a
second baseline run for reference (`compare.py` checks them):
1. The cut: for every mid-word query the spike's reply at limit 100 holds every
   match that ranks at or above its complete reply's 10th (ties counting as equal):
   Dex's own cut keeps the best ones. (The rest of the 100 is not judged: Dex keeps
   its 100 by its own score before clangd re-ranks, and many symbols tie; the
   baseline misses the first 10 of `typ`, `ope`, `fin` at limit 100 too.)
2. Shape: in every complete reply, every High match precedes every Low one.
3. No regression: the baseline's High matches, taken in the baseline's order, never
   rise in the spike's ranking score: the two orders differ only among ties.
4. Same matches: the complete replies hold the same symbols as the baseline's.
5. Mid-word preferred: for every mid-word query the first result at limit 100
   contains the query contiguously in its identifier.
6. Time: per query set the median reply at limit 100 at most 1.5 times the
   baseline's plus 1 ms, every reply under 100 ms.
7. Completion: `middleRank` is called only under `middleMatch` (read in the patch).
Reported, not judged: criterion 1 for the fuzzy queries; their top 100 shared with
the baseline; each mid-word query's first five, spike and baseline.

## Prerequisites
- Arch: the tree `makepkg` left in `packaging/clangd-index-nav/src` (pkgrel 8), the
  installed `/opt/clangd-index-nav/bin/clangd`, `llvm` (headers), CMake, Ninja.
- macOS: the tree `build-macos.sh` left there, `~/opt/clangd-index-nav/bin/clangd`,
  CMake and Ninja (MacPorts); the first build takes about as long as
  `build-macos.sh`.
- Python 3; the project configured and indexed once (opened in Emacs).

## Commands
```
bash spikes/s15-mid-word-rank/build.sh
bash spikes/s15-mid-word-rank/run.sh                                  # macOS: step-1
bash spikes/s15-mid-word-rank/run.sh PROJECT PROJECT/build/debug PROJECT/src/main.cc
```
`run.sh` copies the build directory into `~/.cache/emacs-cpp-s15/run` afresh for each
of its three runs, so the project is only read.

Dry runs so far: `DRY-RUN.md`. Results: `RESULTS.md` (from the owner's run).
