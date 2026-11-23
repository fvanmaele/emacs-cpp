# 0149 - T-164: reindex every TU that includes a changed file (patch 0022)

- **Date:** 2026-11-23
- **Commits:** this entry's commit (patch 0022, PKGBUILD pkgrel 5)
- **Tier:** 2 (after spike S24, 0148)
- **Decisions:** D-219 (O-97 (a))
- **Done when:** (O-97's line, ruled with (a) 2026-11-23) `loadProject` queues and marks
  every TU reached backwards from a stale file; a ClangdTests test with three includers
  (fails without); ClangdTests all pass on the Mac; S24 `many.py correct` right in s3
  for all three TUs; an unchanged restart queues 0 TUs

> Plain English for a reader who does not read C++ fluently.

## What + why
At startup clangd compares every stored file with the disk. For a changed header it
used to reindex one source that includes it; the others kept answering from stale
stored indexes (S24, 0148). Patch 0022 turns the stored include lists around ("which
files include this one?") and walks from each changed file up to every source file
that reaches it, then queues them all; patch 0021 already makes a queued file answer
through the full parse until its reindex is served.

Written fresh from S24's numbers, not from its prototype: a function `tusReaching`
beside `shardIsStale`, called after the parallel staleness check.

The first version of the test passed without the change: each `setCompileCommand`
announces one file, so each source got its own project load and queued itself. A real
`compile_commands.json` announces all files at once; the test now does too
(`AnnounceTogetherCDB`), and then fails without the change (B.cc and C.cc stale).

## Concepts (C++) explained
- `llvm::ArrayRef<T>`: a read-only view of an array (here the loaded shards and their
  stale flags), passed without copying.
- `PathRef` (an `llvm::StringRef`): a view of a path string owned elsewhere; the walk
  returns views into the loaded shards, which live until the end of `loadProject`.

## Key files walked
- `index/Background.cpp` - `tusReaching` and its call in `loadProject`.
- `unittests/BackgroundIndexTests.cpp` - `EveryIncluderOfAChangedHeaderIsReindexed`.

## Assumptions + risks
- **Assumed:** a stored shard's direct includes are those of its last indexing. **Would
  break if:** a header is included only under a branch the indexed command did not take;
  that TU is missed, as before.
- **Risk (accepted, D-219):** a change to a header N TUs include reindexes N TUs (S24:
  1000 TUs 359.5 s); they answer through the AST until then.

## How to verify
Measured 2026-11-23 on the Mac: ClangdTests 1437 / 1437; the new test fails without the
change; S24 `many.py correct` with the built clangd: all three TUs right in s2 and s3,
the walk queued 3 TUs in s2 and 0 in s3 (an unchanged restart) (`logs/correct-t164.txt`);
patches 0001 - 0022 apply to the 23.1.5 tarball and give the tested tree; pkgrel 5 in
`~/opt`: `make test` 206 tests, 2 skipped. Arch: H-42.
