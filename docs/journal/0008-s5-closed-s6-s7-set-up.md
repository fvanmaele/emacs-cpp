# 0008 - S5 closed; ccls and PR 175209 spikes set up

- **Date:** 2026-10-08
- **Commits:** see `git log -- spikes/s5-preamble-warmup spikes/s6-ccls`, and S7
- **Tier:** 3 (spikes S5, S6, S7)
- **Decisions:** D-021, D-022
- **Done when:** S5 has its final verdict; S6 and S7 are ready for the owner
- **Tag:** none

> Plain English. No configuration code changed.

## What + why
S5 run 2 on an idle machine showed that warming three sources makes the first `M-.`
instant (6 ms) at 3 GB of clangd memory instead of 1.1 GB. The owner ruled out any
warm-up that keeps extra files open, because it raises memory from the start (D-021),
and ruled out running Emacs as a long-lived server (D-022). Two other routes are now
spikes. S6 compares ccls, a language server that keeps token positions on disk, with
clangd on RMO. S7 builds `clangd-indexer` with an unmerged LLVM change (PR 175209) that
writes clangd's background index offline; it can save index build time, not the
per-file parse. The owner also reported that headers reached with `M-.` can show "not
found" errors: the cold-header problem (O-5) is broader than first thought.

## Concepts explained
- **ccls vs clangd:** both are built on clang. clangd keeps only symbol locations on
  disk and must parse a file to know what is under the cursor. ccls stores, per file,
  where each token points, so a fresh ccls can answer from disk once it has loaded its
  cache (about 1 s in the dry run).
- **PKGBUILD:** the recipe Arch's `makepkg` uses to build and install a package; this
  one patches LLVM 23.1.1's sources with the PR and builds a single tool into `/opt`.

## Key files walked
- `spikes/s6-ccls/compare.el` - swaps ccls in through the shipped contact function,
  retries `M-.` while ccls refuses, polls `$ccls/info` until indexing is done.
- `spikes/s7-clangd-indexer/PKGBUILD` - standalone clang build of `clangd-indexer`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the ccls numbers from the synthetic dry run carry over to RMO.
  **Would break if:** S6 on RMO shows slow cache loading or high memory.
  **DESIGN bet:** none yet (O-8).
- **Risk:** ccls drops one jsonrpc message per session in Emacs 31 (timer error); must
  be understood before adoption.
- **Risk:** PR 175209 is unmerged and has open review points; S7 results may not hold
  for the merged version.

## How to verify
S6 and S7 `RUN.md`.

## Open questions
O-5 (broader), O-7, O-8 in the DESIGN ledger.
