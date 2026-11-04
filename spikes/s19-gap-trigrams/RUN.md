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

## Machine and amended criteria (D-172, owner 2026-11-04: "All here")
S19 runs on hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch). Criteria 4 and 5 are
ratios of this machine's own baseline (pkgrel 1, the unpatched tree, medians of 21),
measured before the patch is built:
4. Build: `Dex::build` for deal.II at most 2.31 times the baseline (2.5 / 1.08 s).
5. Query: each of the 12 queries at most 5 ms times f per index, f = the baseline's
   sum of the 12 medians / 6.68 ms (section 20's sum on the Xeon).
Criteria 1 (`eto` on deal.II), 2 and 3 as above. RMO is not on this machine, so
criterion 6 runs where RMO is (an H-n once the patch builds); the verdict waits for
it.

## Tier 3's rule (D-173, owner 2026-11-04: "D-120's rule")
Tier 3 is D-120's: the query's letters in order, the first anywhere, gaps only over
letters and digits (D-141). Gap trigrams are every in-order triple inside one run of
letters and digits, stored where the ordinary trigrams lack them; with the field a
query trigram's candidates are its ordinary or its gap list. Criterion 1's `cml` half
is struck (D-120 ranks it tier 4); `eto` -> `Vector` stays. The generator and the
matcher in "What the spike builds" follow this rule, not "first letter starts a
segment". Counts (`count_trigrams.py`, deal.II here): ordinary 4.53 M entries, gap
lists 11.56 M more.

## Prerequisites
- Arch: the tree `makepkg` left in `packaging/clangd-index-nav/src` (pkgrel 10;
  LLVM 23.1.4 pkgrel 1 since the LLVM update), `indexes/dealii.dex` (`make
  library-index LIBRARY=dealii`, from a deal.II clone at `~/source/repos/dealii`,
  D-172), RMO with its build directory (not on hp-elitedesk).

## Commands (hp-elitedesk, 2026-11-04; the session's)
Index and harness:
```
make library-index LIBRARY=dealii
(cd packaging/clangd-index-nav/src/build && ninja dexp)
sh spikes/s19-gap-trigrams/build.sh /tmp/bench-base
SRC=classify.cpp sh spikes/s19-gap-trigrams/build.sh /tmp/classify
/tmp/bench-base indexes/dealii.dex 21 /tmp/lists-base.tsv \
    > spikes/s19-gap-trigrams/baseline.txt
python3 -I spikes/s19-gap-trigrams/client.py /opt/clangd-index-nav/bin/clangd \
    indexes/dealii.dex indexes/dealii-9.8.0-build/compile_commands.json /tmp/base1.jsonl
```
Patched: the 14 files of `s19.patch` applied in
`packaging/clangd-index-nav/src/llvm-project-23.1.4.src` (`patch -p1`), then
`ninja clangd dexp` in `src/build`, `build.sh /tmp/bench-gap -DS19_GAP`, the same
bench and `client.py` runs (`--gap` for the field). Compared with `compare.py same`
(criterion 2), `tiers` (criterion 1 at the server) and `lists` (criterion 1 in the
index). Restored: the saved originals copied back and touched (ninja reads mtimes),
`ninja clangd dexp`. Criterion 6: O-83.
