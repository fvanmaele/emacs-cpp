# S24 - reindex every includer of a stale file

## Risk
O-96 (e), D-218, T-164: at startup clangd's background index queues one TU per stale
file (`LoadedShard::DependentTU`, the first TU whose include walk reached it; a FIXME in
`loadProject`). With patch 0021 that TU declines index answers until its reindex is
served; every other TU including the changed header answers from the index with
references resolved against the old header, without end. Proposed: mark and queue every
TU whose include graph reaches a stale file. Risks: the graph work delays the first
answer (it runs before navigation from the index may answer, 0021); a change to a
common header reindexes all its includers (background CPU as for a rebuild).

## Prior art (searches in DESIGN 1, 2026-11-23)
- clangd/clangd#1104 (open since 2022-04): references go stale after a header changes;
  restart no longer helps since the shard-update optimization; deleting `.cache/clangd`
  is the known workaround.
- llvm-project PR #140651 (draft, 2025-05-20, a clangd maintainer): drops the
  "update only changed files' shards" optimization (all shards of a TU rewritten, no
  FileFilter); its own added test shows several includers of a changed header still
  stale, because one TU is queued. Review: the one-TU policy was a deliberate cost
  choice; "reindex all includers" left as follow-up, its trigger open; a user proposed
  a threshold (fall back to one TU above X includers). Not merged as of the page read.
- This repository's 0021 already rewrites the main file's shard (the part of #140651
  that matters for navigation), not every header's.

## Prototype (spike code, never promoted)
`prototype.patch` on top of patches 0001 - 0021: in `loadProject`, after the parallel
staleness check, the loaded shards' include edges (each shard's node `DirectIncludes`)
are reversed; every TU (a node flagged `IsTU`) reachable backwards from a stale file is
marked and queued, not only `DependentTU`. Logs the graph size, the stale files, the TUs
queued and the time taken.

## Driver
`many.py` builds a project of N TUs (`common.h` included by all, `mid.h` by half,
`leaf_i.h` by one each, plus `<vector>`, `<string>`, `<map>`), indexes it, changes a
header, restarts clangd and asks `textDocument/definition` / `references` in several
TUs (LSP, as S23's `reproduce/lsp.py`).

## Pass criteria (written before the runs; the session runs them on the Mac)
1. Correctness: three TUs include `over.h`; `over.h` changes as in S23 case 1a. With the
   prototype, every one of the three answers right in s2 (the AST while queued) and s3.
   Patch 0021 alone (baseline) is expected to answer stale in two of them.
2. No spurious work: a restart with nothing changed queues 0 TUs (N = 1000).
3. Cost on the path to the first answer: the reverse graph and the walk take under
   50 ms for N = 1000 (median of 3 restarts, logged by the prototype).
4. Recorded, not judged: after `common.h` changes (N = 1000), the TUs queued and the
   wall time until the background index is idle; the same for `leaf_7.h` (1 TU).

## Hand back
`RESULTS.md` with a Verdict line, the logs in `logs/`.
