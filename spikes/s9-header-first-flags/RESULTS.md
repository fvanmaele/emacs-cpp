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

## Run 3 (2026-10-08 21:46, pkgrel 5 with patches 0006 and 0007, load 3.3 / 2.3 / 3.8)
Raw output: `results-run3.log`. Same copy, index session 3950 shards after 45.0 s.

| opened first | runs | command from | errors | open -> decision | load end -> decision |
|---|---|---|---|---|---|
| header | 10 | index (`lumping.cc`) | 0 | 907 - 1016 ms | -9 .. -5 ms |
| source | 10 | index (`lumping.cc`) | 0 | 394 - 441 ms (header) | -6 .. -5 ms |

- The decision now comes with the end of the shard load (a few ms before its log
  line), no longer 0.6 s after it: header first 0.91 - 1.02 s after opening (run 2:
  1.48 - 1.56 s), and a header opened after the source 0.39 - 0.44 s (run 2: about
  1 s).
- T-019's done-when holds: 10 / 10 from the index, 0 errors, all under 1.5 s.

## Run 4 (2026-10-09 22:27, pkgrel 7 with patches 0008 and 0009, load 0.98 / 0.71 / 0.35)
Raw output: `results-run4.log`. Same copy, index session 3950 shards after 41.0 s.

| opened first | runs | command from | errors | open -> decision | load end -> decision |
|---|---|---|---|---|---|
| header | 10 | index (`lumping.cc`) | 0 | 849 - 895 ms | -7 .. -4 ms |
| source | 10 | index (`lumping.cc`) | 0 | 383 - 409 ms (header) | -5 ms |

- Unchanged from run 3, as T-020 and T-033 require: 10 / 10 header-first sessions
  take the includer's command, 0 errors, the decision with the end of the shard load.
  The shard load itself: 375 - 412 ms (run 3: 0.39 - 0.46 s).
- Header first 0.85 - 0.90 s (run 3: 0.91 - 1.02 s), on a machine idle this time
  (run 3: 5-minute load 2.3); not attributed to 0008, whose early answer needs an
  includer already known, which a header opened first after a restart never has.
- S9 does not exercise 0009: the runner keeps only the header's decision and the load
  lines, so whether a flagged shard was re-indexed is not in this log (0042 covers it).
