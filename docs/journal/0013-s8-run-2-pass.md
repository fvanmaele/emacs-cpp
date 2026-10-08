# 0013 - S8 run 2: PASS, the patched clangd is seven times faster on RMO

- **Date:** 2026-10-08
- **Commits:** clangd tree bd81165ed; here: `git log -- spikes/s8-clangd-index-navigation`
- **Tier:** 3 (spike S8)
- **Decisions:** D-025
- **Done when:** RESULTS.md carries a PASS or FAIL verdict
- **Tag:** none

> Plain English. No configuration code changed yet.

## What + why
With the references fix from run 1, the owner reran S8 on RMO. After a restart, with
clangd's index already on disk, the first `M-.` in `src/main.cc` took 1.4 s with the
patched clangd instead of 9.3 s, and went to the same place. Find-references listed
every place the normal clangd lists, plus the call under the cursor, which the normal
clangd misses, and without its duplicates. The very first session on a build
directory, before any index exists, is unchanged at about 10 s.

## Concepts explained
- **Session 1 vs session 2:** the speed-up comes from the index clangd stored in an
  earlier session; a fresh build directory (or a new preset) pays the full parse once.

## Key files walked
- `spikes/s8-clangd-index-navigation/RESULTS.md` - both runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO's `std::visit` case is representative. **Would break if:** other
  positions show missing references or wrong targets in daily use. **DESIGN bet:** O-11.
- **Risk:** the patched clangd is pinned to LLVM 23.1.1; a system LLVM update needs a
  rebuild (or a package pinned to 23).

## How to verify
`spikes/s8-clangd-index-navigation/results-run2.log`.

## Open questions
O-11: integration (T-014) and the ccls branch's future.
