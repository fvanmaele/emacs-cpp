# S9 - compile command of a header opened first

## Risk
O-21 (owner report 2026-10-08): right after a restart, `include/rmo/gpe/iteration.h`
opened from `C-x C-r` showed "too many errors"; opening another file first was fine.
D-028 (patch 0005) gives a header the command of a source file that includes it, from
the stored index, waiting up to 5 s while the index loads. Hypothesis from reading
clangd: the header can ask before the project is handed to the background index (the
compile database announces it on its own thread, `BroadcastThread`, which calls
`BackgroundIndex::enqueue`, where the patch's load counter rises), so the patch sees
no load, does not wait, finds no includer and the guess is used. Question: on RMO,
does a header opened first get the guess, how often, and does the log show the
decision before "Enqueueing"?

## Prerequisites
The patched clangd pkgrel 3 at `/opt/clangd-index-nav/bin/clangd` (D-027; or set
`S9_CLANGD`). cmake, ninja, rsync, the shipped config built (`make packages`). The
copy goes to `/tmp/s9/work/<project name>`. Best on an idle machine.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s9-header-first-flags/run.sh ~/source/repos/RMO-gross-pitaevskii \
   include/rmo/gpe/iteration.h src/main.cc 10
```
About 25 minutes: one index session (until the shard count is stable for 15 s, at
most 600 s), then 10 sessions that open the header first and 10 that open `main.cc`
first, alternating, each a fresh Emacs and clangd.

## What it measures
Per session: whether the header's command came from the index ("from X, which
includes it") or the guess ("no source file includes it", "inferred from" another
file), flymake's error count in the header, and clangd's timestamps for the start
("Enqueueing N commands") and end ("after loading index from disk") of the load of
the stored shards, next to the patch's decision.

## Verdict criteria
CONFIRMED if at least one header-first session gets the guess with its decision
logged at or before "Enqueueing", and no source-first session does. REFUTED if every
session gets the includer; then the report needs another cause (for example the 5 s
cap: a decision more than 5 s after "Enqueueing" with "load end" later still).

## Dry run (toy shaped like RMO, 2026-10-08)
`include/toy/gpe/iteration.h` included only by `staging/test/lumping.cc`, a vendored
`fmt` library whose file the guess picks; 88 shards. Header first: run 1 from the
index (decision 16 ms after "Enqueueing"), run 2 the guess from `fmt/src/format.cc`,
5 errors (decision and "Enqueueing" in the same millisecond); an earlier set of 3
runs all from the index. Source first: always from the index. The race is there and
depends on timing.

## Hand back
`spikes/s9-header-first-flags/results.log`; delete `/tmp/s9` afterwards.
