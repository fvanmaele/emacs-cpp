# S8 - clangd navigation from the index

## Risk
DESIGN 11, O-11: with clangd, the first `M-.` / `M-?` in each file waits for its parse
(10.5 s for RMO's main.cc in S6). A local change to clangd 23.1.1 (D-025,
`~/source/repos/llvm-clangd`, commits 8b73a0490 and 2c0b7bf32) answers them from the
file's stored background-index shard while the parse runs, behind the hidden flag
`--navigation-from-index`. Question: on RMO, after a restart with the index on disk,
how fast is the first `M-.` with the patched clangd, and is the answer the same?

## Prerequisites
The patched clangd built: `ninja -C ~/source/repos/llvm-clangd/build clangd`
(standalone build against the system LLVM 23.1.1; 1409 / 1409 ClangdTests pass).
cmake, ninja, rsync, the shipped config built. The copy goes to `/tmp/s8/work/rmo`.
Best on an idle machine.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s8-clangd-index-navigation/run.sh ~/source/repos/RMO-gross-pitaevskii
```
About 5 minutes (each variant: one session that builds the index and waits 120 s,
then one timed session).

## What it measures
For the system clangd and for the patched clangd with `--navigation-from-index`:
session 1 (empty index) and session 2 (fresh server, index on disk): the first `M-.`
on the first `dealii::` / `std::` name in `src/main.cc`, its target file, then `M-?`
and its count, and the time since opening the file.

## Pass criteria
PASS if, in session 2, the patched clangd's first `M-.` takes under 2 s and returns
the same target file as the system clangd, and its `M-?` contains every distinct
location of the system clangd's `M-?` (the log lists them). (Superseded 2026-10-08:
"`M-?` returns the same count"; the system answer can list locations twice, see
RESULTS.md.)

## Dry run (synthetic deal.II + Boost project, 2026-10-08)
Session 2: system clangd first `M-.` 6662 ms, patched 604 ms, same target
(`vector.h`), `M-?` 132 references in both. Session 1 unchanged (about 6.8 s), as
expected: there is no stored shard yet. The patched binary's `--version` names the
first commit (8b73a0490); LLVM embeds the revision only at configure time, the binary
contains both commits.

## Run 2 (after run 1, see RESULTS.md)
Rebuild the patched clangd first (`ninja -C ~/source/repos/llvm-clangd/build clangd`,
already done on 2026-10-08), remove `/tmp/s8`, move `results.log` away (done: kept as
`results-run1.log`), then the same command.

## Hand back
`spikes/s8-clangd-index-navigation/results.log`; delete `/tmp/s8` afterwards.
