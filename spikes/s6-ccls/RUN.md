# S6 - ccls

## Risk
DESIGN 11, O-8: with clangd every file waits 7 - 13 s for its first `M-.` in a
session, and warm-up through extra open files is ruled out (D-021). ccls keeps a
per-file index with token positions on disk and may answer `M-.` from it without
parsing the open file again. Headers that no open source includes get wrong flags in
clangd (O-5); ccls may do better. The spike compares both on a copy of RMO, through the
shipped config (hook path, preset, D-016 - D-019), with ccls swapped in for clangd.

## Prerequisites
ccls installed (`sudo pacman -S ccls`; 0.20250815.1 on clang 23.1.1, 2026-10-08),
cmake, ninja, clangd, rsync, the shipped config built (`make packages`). The copy goes
to `/tmp/s6/work/rmo`; ccls's cache goes to its `build/debug/.ccls-cache`. Best run on
an idle machine (the log records the load).

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s6-ccls/run.sh ~/source/repos/RMO-gross-pitaevskii
```
Takes a few minutes (ccls indexes the whole project in round 1).

## What it measures
- clangd baseline: first `M-.` on the first `dealii::` name in `src/main.cc`, its
  references, errors in main.cc, memory.
- ccls round 1 (empty cache): first `M-.` (retried while ccls refuses with "not
  indexed"), time until indexing is done, peak memory, then `M-.`, references, errors,
  memory, cache size.
- ccls round 2 (new ccls, cache on disk): `M-.` right after the start, time until the
  first non-empty answer, time until idle, memory, references.
- ccls round 3 (new ccls): `include/rmo/fe/assemble.h` opened first, its errors (O-5);
  then `M-.` in main.cc.
- Any "Error running timer" with the timer function (seen in every ccls session of the
  dry run: a jsonrpc message is dropped).

## Pass criteria
PASS if ccls round 2 gives a correct `M-.` within 2 s of starting, references match or
exceed clangd's, main.cc shows no errors clangd does not show, round 3's header has no
"not found" errors, and ccls memory stays at or below clangd's (D-021). The timer
error must be understood (harmless or fixable) before any adoption.

## Hand back
`spikes/s6-ccls/results.log`; delete `/tmp/s6` afterwards.
