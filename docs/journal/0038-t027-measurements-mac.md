# 0038 - T-027: load measurements on the Mac

- **Date:** 2026-10-09
- **Commits:** see `git log -- docs/journal/0038-t027-measurements-mac.md`
- **Tier:** 1 (measurements, no code)
- **Decisions:** O-24 (b) gets its numbers; D-038, D-026
- **Done when:** `scripts/measure-startup.sh` on both machines idle (10 runs each)
  plus the first `M-.` and memory on RMO, the numbers in DESIGN 11 per platform, and
  O-24 (b) put to the owner with them (proposed 2026-10-09; the owner asked for the
  measurements the same day). This entry covers the Mac; the Arch runs are the
  owner's.
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp and shell only in part.

## What + why
DESIGN 11 had numbers from Arch only. macOS is supported now (D-050), and the first
Mac startup measured 0.77 - 1.23 s under load (0034), five times Arch's. This entry
measures startup and the first `M-.` on RMO on the Mac. The numbers are in DESIGN 11.

- **Startup:** median 0.852 s over 10 runs (0.496 - 1.424), alternating between about
  0.5 - 0.6 s and 1.1 - 1.4 s. Not idle: load 5 - 9 and G DATA antivirus at 80 - 150 %
  CPU.
- **First `M-.` with the index on disk:** stock clangd 8.2 s, patched 2.6 s (Arch, S8:
  1.4 s). clangd's memory right after: 920 MB vs 241 MB.

## How it was measured
- **RMO on the Mac** is the owner's `CLionProjects/step-1`, which has no
  `CMakePresets.json` and uncommitted changes. Its `src`, `include`, `staging`, `fmt`
  and `CMakeLists.txt` were copied to `~/tmp-emacs-cpp-t027/rmo` with a `debug`
  preset (Ninja, compile commands, extensions off, deal.II 9.7.1 and Boost from
  `/Applications/deal.II.app`). Nothing was written into `step-1`. The copy is
  deleted after the runs.
- **Protocol** as S8: a batch Emacs with the shipped config opens `src/main.cc`, puts
  point on the first `std::` / `dealii::` name (`std::visit`), and times `M-.` and
  `M-?`. Session 1 starts with an empty index and waits until no new shard appears for
  20 s; session 2 starts a fresh clangd with that index on disk. clangd's memory is
  `ps -o rss`. The patched clangd is the owner's hand-built one in `~/opt` (same
  patches as `build-macos.sh`).

## Concepts explained
- **Why `/tmp` broke the patched clangd.** The patched clangd looks up the stored index
  shard of the file Emacs opened, by its path. On macOS `/tmp` is a symbolic link to
  `/private/tmp`. CMake writes `/tmp/...` into `compile_commands.json` (its path library
  maps `/private/tmp` back on purpose); Emacs visits the file under its true name
  `/private/tmp/...`. The two names do not match, the shard is "not found", and the
  answer waits for the parse (clangd's verbose log says "needs the AST: no stored index
  shard"). A first run under `/tmp` measured 9.4 s for the patched clangd; under the
  home directory, where both names agree, 2.6 s.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the load and the antivirus slow both variants alike, so the stock /
  patched comparison holds while the absolute numbers are pessimistic. **Would break
  if:** the scanner hits the patched clangd harder (it reads 4539 shards at start).
- **Risk:** the patched clangd gives no benefit for projects reached through a symbolic
  link whose two spellings differ between CMake and Emacs. Not seen for projects
  under the home directory.
- **Open:** startup's two groups (0.5 vs 1.2 s) are not explained; the antivirus and
  loading native code are suspects, not measured.
- **Open:** `M-?` found 14, 15 or 24 references for the same name in different runs;
  the index may still have been growing in content while the shard count stood still.

## How to verify
Arch (owner), idle machine:
```
sh scripts/measure-startup.sh 10
sh spikes/s8-clangd-index-navigation/run.sh ~/source/repos/RMO-gross-pitaevskii \
   /opt/clangd-index-nav/bin/clangd
```
The S8 runner writes `results.log` next to itself; move an old one away first.
