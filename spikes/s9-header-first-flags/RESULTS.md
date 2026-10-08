# S9 - compile command of a header opened first: results

Verdict: PASS (run 1, 2026-10-08): the hypothesis is confirmed. On RMO, every session
that opened `include/rmo/gpe/iteration.h` first got the guessed command (from
`fmt/src/os.cc`, 21 errors); the patch's decision was logged at or 1 ms before
"Enqueueing 13 commands for indexing", the moment the project reaches the background
index. Every session that opened `src/main.cc` first gave the header the command of
`staging/test/lumping.cc`, which includes it, and 0 errors. The 5 s cap of patch 0005 is
not involved: loading the stored shards takes about 0.4 s.

## Run 1 (2026-10-08 20:23, load 0.56)
Raw output: `results-run1.log`. Patched clangd pkgrel 3 (23.1.1), copy of RMO in
`/tmp/s9/work`, index session: 3950 shards after 48.7 s.

| opened first | runs | command from | errors | decision - Enqueueing | load |
|---|---|---|---|---|---|
| header | 10 | guess (`fmt/src/os.cc`) | 21 | -1 .. 0 ms | 0.39 - 0.44 s |
| source | 10 | index (`lumping.cc`) | 0 | +970 .. +1010 ms | 0.39 - 0.43 s |

(load: from "Enqueueing" to "after loading index from disk".)

Header first, time from opening to the decision: 499 - 555 ms. Source first, the
header's decision came 967 - 1024 ms after the header was opened (it was opened once
the source's parse had started).

## Findings
- The race is deterministic on RMO (10 / 10), on the toy it was 1 / 5: the decision
  and the handover fall in the same millisecond, and on RMO the decision wins.
- The cause is the order, not the wait: when the header asks, the load counter of
  patch 0005 is still 0 because `BackgroundIndex::enqueue` has not run yet (it runs on
  the compile database's broadcast thread), so `includerOf` returns at once with no
  includer.
- Waiting for the broadcast (`blockUntilIdle` on the compile database), then for the
  load, would cost a header opened first about 0.4 s more (the load) on RMO.
- Owner's earlier pass with `assemble.h` opened first (0015) must have been a session
  in which the handover won; not reproduced here.

## Decision
Patch 0006 as proposed in O-21; owner rules its done-when (tier 2 now that the spike
confirmed the cause).

## Run 2 (2026-10-08 21:16, pkgrel 4 with patch 0006, load 3.1 / 13.4 / 14.8)
Raw output: `results-run2.log`. Same copy, index session 3950 shards after 49.2 s.

| opened first | runs | command from | errors | open -> decision | Enqueueing -> decision |
|---|---|---|---|---|---|
| header | 10 | index (`lumping.cc`) | 0 | 1476 - 1555 ms | 966 - 1036 ms |
| source | 10 | index (`lumping.cc`) | 0 | 976 - 1081 ms (header) | 977 - 1081 ms |

- Patch 0006 fixes the race: 10 / 10 header-first sessions take the includer's
  command (run 1: 0 / 10).
- Where the time goes, in both kinds of session alike: the shards load in 0.39 -
  0.46 s ("Enqueueing" to "after loading index from disk"), then 0.57 - 0.63 s pass
  until the decision. `loadProject` logs that line and then still builds the
  searchable index from the 3950 shards and works out which files need re-indexing;
  patch 0005's wait ends only when `loadProject` returns. Run 1's source-first
  sessions show the same 1 s.
- Against T-019's done-when ("decision under 1.5 s after opening"): 5 of 10 runs are
  above, by at most 55 ms (median 1497 ms). The 1.5 s rested on the estimate "the load
  takes 0.4 s"; the wait also covers the 0.6 s check. The machine was not idle before
  the run (5-minute load 13.4).
- The includers are recorded right after the shards are read, before the symbols
  are merged and the index is built, so the wait could end there (at least 0.6 s
  earlier for every header that waits).
