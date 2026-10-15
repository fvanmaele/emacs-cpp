# S14 - CLion's mid-word and loose-qualifier symbol matches in clangd

## Risk
O-57 (b) + (c), owner 2026-10-15: "Spike for O-57 (b) + (c), drop (d)". CLion's Go
to Symbol finds `TangentVector` for `ector` (a match starting mid-word) and
`GeometryInfo::vertices_per_cell` for `geom::vec` (an abbreviated qualifier); clangd
refuses both (`RESEARCH_go_to_anything.md` 16). Question: does a clangd change make
both work on deal.II's index without changing what fuzzy queries return today, and
without slowing `M-o` / `C-c l s`? Spike code is never promoted; a PASS leads to
clangd patches 0011 / 0012 written fresh, with clangd unit tests (0010 is O-50's).

## What the spike builds
`0001-middle-and-loose-scope-matches.patch` on the patched tree of `build-macos.sh`
(23.1.3, patches 0001 - 0009):
- (c) `FuzzyFindRequest::AllowMiddleMatch`, set by `getWorkspaceSymbols` only, for
  queries of 3 or more characters: where `FuzzyMatcher` refuses a name, Dex,
  MemIndex and `getWorkspaceSymbols` accept it when its identifier (before any
  template arguments) contains the query in any case. Its score is negative, so it
  ranks after every fuzzy match and is the first dropped at a limit. Code completion
  never sets the field. (Changed during the dry runs: RESULTS.md.)
- (b) `fuzzyScopeMatch`: a symbol's scope passes when each segment of the query's
  qualifier fuzzy-matches one of the scope's segments, in order (`geom::` matches
  `GeometryInfo::`, `vt::` matches `VectorTools::`); the exact rule
  (`approximateScopeMatch`) still passes what it passed.

## Pass criteria (proposed 2026-10-15, refined after the dry runs; owner to confirm)
On deal.II's `step-1` (its `mac-debug` preset, its index, cloned afresh for each
run), baseline = the installed patched clangd, spike = the same plus the spike
patch, each query with limit 100 and 10000, a second baseline run for reference
(`compare.py` checks them):
1. Mid-word: each of 8 mid-word queries (`ector`, `ngulat`, ...) gains matches, each
   containing the query in its name; they rank after every match the baseline gives
   (1b).
2. Scoped: each of 7 abbreviated-scope queries (`geom::vert`, `vt::interp`,
   `spm::vmult`, ...) reaches its class or namespace (`GeometryInfo`,
   `VectorTools`, ...); the baseline misses at least one.
3. No regression: for 20 fuzzy queries as typed today, with limit 10000 (complete
   replies, the same in two baseline runs), the baseline's reply is the head of the
   spike's, in the same order up to ties (symbols of equal score). With limit 100
   many symbols tie at the cut, and which make it varies between two baseline runs
   by itself: reported, not judged.
4. Time: per query set the median reply time at most 1.5 times the baseline's (plus
   1 ms), every reply under 100 ms.
5. Completion: `AllowMiddleMatch` is set nowhere but in `getWorkspaceSymbols`
   (read in the patch).
Otherwise the findings go to RESULTS.md and decide.

## Prerequisites
macOS, the tree `packaging/clangd-index-nav/build-macos.sh` left in its `src/`, the
installed `~/opt/clangd-index-nav/bin/clangd`, CMake and Ninja (MacPorts), Python 3,
deal.II's `step-1` configured with its `mac-debug` preset and indexed once (opened in
Emacs). The first build takes about as long as `build-macos.sh` (3283 steps).

## Commands
```
bash spikes/s14-symbol-matches/build.sh
bash spikes/s14-symbol-matches/run.sh       # step-1, build/mac-debug, src/main.cc
```
`run.sh` clones `build/mac-debug` into `~/.cache/emacs-cpp-s14/run`, so the project is
only read. Other project: `run.sh PROJECT PRESET_DIR OPENED_FILE`.

Dry runs so far: `DRY-RUN.md`. Results: `RESULTS.md` (from the owner's run).
