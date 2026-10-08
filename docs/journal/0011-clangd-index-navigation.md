# 0011 - clangd answers navigation from its index (local patch, spike S8 ready)

- **Date:** 2026-10-08
- **Commits:** clangd tree `~/source/repos/llvm-clangd`: 8b73a0490, 2c0b7bf32; this repo:
  see `git log -- spikes/s8-clangd-index-navigation`
- **Tier:** 3 (spike S8)
- **Decisions:** D-025
- **Done when:** the clangd change builds, its tests and clangd's test suite pass, and
  S8 is ready for the owner
- **Tag:** none

> Plain English for someone who does not read C++ or clangd's code fluently.

## What + why
With clangd, the first `M-.` in a file waits until clangd has parsed the file and
everything it includes (about 10 s for RMO). Yet clangd's background index already
stores, for every file, each name occurrence with its position, written by an earlier
full parse. The owner asked for the change that uses this. Implemented locally in
clangd 23.1.1: if the open file is unchanged since it was indexed, clangd looks up the
name under the cursor in that stored data and answers from the index; otherwise, and
for positions the index does not cover, it answers from the parse as before. On a
synthetic deal.II project the first `M-.` after a restart dropped from 6.6 s to 0.6 s.

## Concepts explained
- **Shard:** the part of clangd's on-disk index for one file; it records the file's
  content fingerprint (digest), so clangd can tell whether it still matches.
- **Racing two answers:** clangd starts both the index lookup and the normal parse;
  the first to finish answers, the other is ignored. The index lookup retries for a
  few seconds because clangd loads its stored index in the background at startup.
- **What stays slow:** local variables (not indexed), the `auto` keyword, `#include`
  lines, files with unsaved edits, and the very first session of a build directory
  (no stored index yet).

## Key files walked
- clangd `XRefs.cpp`: `symbolAtFromShard`, `locateIndexedSymbol`,
  `findReferencesToIndexedSymbol`.
- clangd `ClangdServer.cpp`: `indexedSymbolAt`, `FirstAnswer`, `pollIndex`, and the
  two request methods.
- clangd `unittests/BackgroundIndexTests.cpp`: `NavigationFromShardTest` (4 tests).
- `spikes/s8-clangd-index-navigation/` - run script for the owner's RMO measurement.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** an unchanged digest means the shard's positions are exactly the parse's.
  **Would break if:** the compile command changed without the content changing (the
  shard's command is not compared yet). **DESIGN bet:** O-11.
- **Risk:** a polling task can delay clangd's shutdown by up to 5 s.
- **Risk:** the patch is local; upstream acceptance is unknown, and every clangd
  release needs it reapplied (or the patched build kept at 23.1.1).

## How to verify
`ninja -C ~/source/repos/llvm-clangd/build ClangdTests && .../ClangdTests
--gtest_filter='NavigationFromShardTest.*'`; S8 per its RUN.md.

## Open questions
Integration into the config (patched clangd vs the ccls branch) after S8.
