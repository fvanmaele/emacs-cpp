# S24 - reindex every includer of a stale file: results

Verdict: PASS (2026-11-23, session, the Mac): criteria 1 - 3 hold as written in RUN.md
(committed before the runs, 2d8ace5); criterion 4 recorded. The cost it records (a
change to a header every TU includes reindexes them all, as long as a first full index)
goes to the owner as O-97.

Environment: MacBook Pro M3 Pro, macOS, load average 4.5 - 7.5, G DATA's on-access scan
on. `baseline`: `~/opt/clangd-index-nav/bin/clangd` (pkgrel 4, patches 0001 - 0021).
`proto`: the same tree plus `prototype.patch`, built in `src/build-tests` (a test build
of LLVM; built and copied away, then the tree restored to 0001 - 0021).

## Criterion 1 - correctness (`logs/correct-run1.txt`)
Three TUs include `types.h`; `using Widget = A` became `= B`; definition at `w.run()`.

| | s2 (all three TUs) | s3 a.cpp | s3 b.cpp | s3 c.cpp |
|---|---|---|---|---|
| baseline | correct | correct | stale (A::run) | stale (A::run) |
| proto | correct | correct | correct | correct |

The prototype's log: 4 shards, 3 edges, 1 stale file, 3 TUs queued (2 added by the
walk). s2 does not tell the two apart: these TUs parse in milliseconds, so the AST
answered first in both (0.02 s); s3, after the reindex, does: the baseline queued only
a.cpp (the header's `DependentTU`) and b.cpp, c.cpp kept their old shards.

## Criteria 2 - 4 - N = 1000 TUs (`logs/cost-run1.txt`)
2807 shards, 7637 include edges (1000 TUs, 1000 leaf headers, `common.h`, `mid.h`,
the standard headers of `<vector>`, `<string>`, `<map>`).

| restart | proto: queued (walk added), walk ms | proto: idle after | baseline: idle after |
|---|---|---|---|
| unchanged 0 / 1 / 2 | 0 (0); 7.96 / 8.18 / 8.25 | 1.2 / 0.7 / 0.8 s | 1.1 / 0.8 / 0.7 s |
| `common.h` changed | 1000 (999); 8.23 | 359.5 s | 1.9 s |
| `leaf_7.h` changed | 1 (0); 8.20 | 2.3 s | 2.8 s |

- Criterion 2 PASS: 0 TUs queued after an unchanged restart.
- Criterion 3 PASS: the reverse graph and walk take 8 ms (under 50 ms); linear in
  shards and edges.
- Criterion 4 recorded: a change to a header all 1000 TUs include reindexes all of them,
  359.5 s of background indexing (the first full index took 367.1 s); during it those
  TUs answer through the AST (0021). The baseline is idle after 1.9 s, and 999 TUs then
  answer from stale shards.

## Not measured
- A real project (RMO, deal.II sized): the walk's cost scales with edges; S23's deal.II
  TU had 2661 shards, so a project of many such TUs shares most of them.
- Arch.
