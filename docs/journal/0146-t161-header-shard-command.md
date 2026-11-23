# 0146 - T-161: header shards keep their command (patch 0020)

- **Date:** 2026-11-23
- **Commits:** this entry's commit (patch 0020, PKGBUILD pkgrel 3, the S23 driver's
  `navdev` label and control case)
- **Tier:** 2
- **Decisions:** D-217 (a); O-95
- **Done when:** (agreed 2026-11-23) a header's shard stores the indexing TU's command;
  from a header the index answers only when it equals the includer's current command,
  else the AST answers (logged); a ClangdTests test for S23's case 3 and a shard without
  a command; ClangdTests all pass on the Mac; S23 `reproduce` case 3 with `nav` answers
  right in s2 and s3; pkgrel bumped; Arch install on an H-n

> Plain English for a reader who does not read C++ fluently.

## What + why
S23 case 3: a header opened directly after a `-D` change got answers from the old
`#ifdef` branch, in every session. clangd threw away the compile command of every
header's stored index ("shard"), so patch 0017's check had nothing to compare.

Patch 0020 keeps the command in a header's shard too: the command of the source file
whose indexing wrote it. When navigation starts in a header, the index answers only if
that stored command has the same flags as the current command of the header's recorded
includer; otherwise the full parse answers and the log says why. "Same flags" ignores the
source file name and the output and dependency file names (`-o`, `-MF`, `-MT`, `-MQ`),
which differ between two sources of one CMake target: without that, a header written by
`b.cpp` but recorded as included by `a.cpp` would never answer from the index.

One gap found while running S23's case: at startup the header's includer is recorded only
once the stored shards are loaded, and the first version checked before that, so the
header always fell back to the parse. It now waits for the load as the rest of navigation
from the index does (`waitForNavigationIndex`); a control case (`header_first_same`,
flags unchanged) shows the index answering from the header in 0.28 - 0.30 s.

## Concepts (C++) explained
- `std::optional<T>`: a value or nothing; `std::nullopt` is "nothing". The new
  `knownIncluderOf` returns one, so "no includer known" is part of the type.
- `llvm::function_ref<bool()>`: a cheap reference to a callable, here "has the AST
  answered already?", passed so the wait stops as soon as the race is lost.
- `IncludeGraphNode::SourceFlag::IsTU`: the bit that marks a shard's file as a source of
  the compile database, which is how the code tells a header's shard from a source's.

## Key files walked
- `index/Background.cpp` - `update()` no longer resets a header shard's `Cmd`;
  `knownIncluderOf` reads the recorded includer without waiting.
- `XRefs.cpp` - `headerShardCommandMatches` and its `sharedArguments` (the flags two
  sources of a target share); `shardIsOfMainFile`.
- `ClangdServer.cpp` - `navigationShard` picks the source or the header check.

## Assumptions + risks
- **Assumed:** sources of one target differ only in the source file, `-o` and the
  dependency file options. **Would break if:** a generator adds per-source flags
  (CMake's `set_source_files_properties`); those headers then fall back to the parse,
  slower, never wrong. **DESIGN bet:** D-217.
- **Assumed:** no option value ends in a source extension. **Would break if:** one
  does: it is dropped from both commands, and the check is looser by that value.
- **Known gap (accepted by D-217):** after a flag change nothing reindexes an unchanged
  header, so it falls back to the parse until its content changes. Shards stored by
  pkgrel 2 have no header command and fall back until reindexed.

## How to verify
```
cd packaging/clangd-index-nav/src/build-tests
ninja ClangdTests && tools/clang/tools/extra/clangd/unittests/ClangdTests --gtest_brief=1
cd spikes/s23-index-freshness/reproduce
S23_CLANGD=<that build>/bin/clangd CASES="header_first_define header_first_same" \
  LABELS=navdev OUT=summary-t161.txt sh run.sh </dev/null
```
Measured 2026-11-23 on the Mac: ClangdTests 1434 / 1434 (two new; `CmdLineHash` now
expects the header's command); the three changed expectations fail without the fix.
S23 case 3: the AST answers right in s2 and s3 (`summary-t161.txt`); the patches 0001 -
0020 apply to the 23.1.5 tarball and give the tested tree. Arch: the owner's install
(H-n with T-162).
