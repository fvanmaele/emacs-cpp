# 0147 - T-162: a reindexed TU rewrites its shard, no answer while queued (pending)

- **Date:** 2026-11-23
- **Commits:** this entry's commit (patch 0021 in `packaging/clangd-index-nav/pending/`,
  not in the PKGBUILD; the S23 `firstnav` harness)
- **Tier:** 2
- **Decisions:** D-217 (d); O-96 opened
- **Done when:** (agreed 2026-11-23) first, the queued / indexing state is shown readable
  from the navigation path without a lock the AST path waits on (else back to the owner);
  a reindexed TU writes its main file's shard even when only an include changed; the index
  declines while the TU is queued or being indexed (logged); ClangdTests tests for S23's
  case 1a; ClangdTests all pass on the Mac; S23 `reproduce` case 1a with `nav` right in s2
  and s3; first `M-.` on S8's synthetic project still under 1 s after a restart with
  nothing changed
- **Status:** all met but the last on the Mac (1.10 - 1.19 s); T-162 waits on T-163;
  gap T-164 found; both to the owner as O-96

> Plain English for a reader who does not read C++ fluently.

## What + why
S23 case 1a: after a header changed on disk while clangd was not running, the main
file's stored shard still matched its own text, so navigation from the index answered
with references resolved against the old header, also after the reindex, which rewrote
only shards whose text had changed.

Patch 0021 does three things. A reindex always rewrites the main file's shard (and
collects its references again, which clangd skipped for unchanged files). The files
clangd's startup check finds stale are marked before navigation from the index may
answer, and their index answers are declined until the reindex is in the index clangd
serves (the background index swaps in a rebuilt copy only every 100 files or when idle,
so "indexed" is not yet "served"); each indexed file gets a number, and the served copy
knows up to which number it holds. The startup check reads its files in parallel.

Step 1 (the first done-when clause): clangd's queue holds only closures, so the patch
keeps its own map, file -> state, under its own mutex; the AST path never takes it.

## Measured (Mac, 2026-11-23, load 5 - 6, G DATA's on-access scan on)
- ClangdTests 1436 / 1436; `StaleTUWaitsForItsServedReindex` fails without the change.
- S23 case 1a (`reproduce/summary-t162.txt`): the AST answers right in s2 ("it is queued
  for reindexing or being indexed"), the index right in s3 (0.77 - 0.83 s); case 3 and
  its control as in 0146.
- First `M-.` after a restart, nothing changed (`firstnav/`, a project symbol in a file
  including deal.II, 2661 stored files): pkgrel 2 0.32 - 0.74 s; this patch with the
  check one file at a time 3.8 - 4.7 s (the check took 3.9 s, `run3.txt`); in parallel
  1.10 - 1.19 s (`run4.txt`). Before, the check ran after the first answer; now the
  answer waits for it. Reading the same 2670 files with 8 readers: 0.73 s, one: 8.4 s.

## Found
- T-163: the startup check on the path of the first answer: over 1 s on the Mac.
- T-164: upstream queues one TU per stale file (`LoadedShard::DependentTU`, the first TU
  whose walk reached it; a FIXME in `loadProject`). Other TUs including a changed header
  are neither reindexed nor marked, so they answer stale as before. S23's projects have
  one TU each and do not show it. UNVERIFIED by a run; read in the code.

## Concepts (C++) explained
- `llvm::parallelFor(Begin, End, Fn)`: runs `Fn(I)` for each index on LLVM's thread pool
  and returns when all are done.
- `llvm::Expected<unsigned>`: a value or an error that must be looked at; `index()` now
  returns the TU's number this way.

## Key files walked
- `index/Background.cpp` - `loadProject` (check, mark, then release the wait),
  `markQueued`, `markIndexed`, `reindexPending`.
- `index/BackgroundRebuild.cpp` - `indexedTU()` returns a number, `servedTUs()`.
- `ClangdServer.cpp` - `navigationShard` asks `reindexPending` for main files.

## Assumptions + risks
- **Assumed:** `RealFileSystem` reads are safe from several threads, one view each.
  **Would break if:** a view shares state; then the check's results could mix.
- **Assumed:** budgets bind on Arch only (D-057) may cover this criterion. UNVERIFIED;
  O-96 asks.

## How to verify
```
cd spikes/s23-index-freshness/firstnav
python3 -I firstnav.py navdev <built clangd> work </dev/null
```
