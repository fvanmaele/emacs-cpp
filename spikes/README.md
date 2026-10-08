# spikes/

Throwaway prototypes that turn one DESIGN risk into a measured PASS/FAIL verdict BEFORE app
code is written for it. Each spike is a self-contained directory with its own build files.

## Rules
- One spike answers one risk from the DESIGN risk register. It produces a verdict, not code.
- Two docs per spike: `RUN.md` (which risk, prerequisites, exact commands, ends by pointing
  at RESULTS.md) and `RESULTS.md` (opens with `Verdict: PASS/FAIL`, then environment,
  measurements against the stated budget, Decision, gotchas, follow-ups folded elsewhere).
- Spike code is NEVER promoted into app code. Lift patterns and numbers into DESIGN and a
  journal entry, then write app code fresh.
- Anything on the owner's real data or real devices is the owner's to run.
- A spike that finds a defect in existing code records it; it does not fix it.

## Blocking spikes (must PASS before the first app code of v0.1)
- **S1 compile-db discovery** - with a CMake preset building into `build/<preset>/`, which
  of `.clangd` CompilationDatabase / root symlink / `--compile-commands-dir` makes clangd
  resolve includes and cross-file references, with no manual step after each configure?
  Decides DESIGN 7 (O-1).

## Later spikes (each gates its feature)
- **S5 preamble warm-up** - does opening every project source in the background when
  eglot starts make the first `M-.` instant, and at what memory and time cost on RMO?
  Also observes cold headers (O-5). Gates T-012 (DESIGN 11).
- **S6 ccls** - can ccls replace clangd (O-8)? Measures first `M-.` with an empty and a
  persisted cache, indexing time, memory, cache size, references, and a header opened
  first (O-5), against clangd on the same copy.
- **S7 sharded pre-index** - does `clangd-indexer --index-type=sharded` from the
  unmerged LLVM PR 175209 (built by `spikes/s7-clangd-indexer/PKGBUILD`) produce shards
  the system clangd 23.1.1 loads without re-indexing, and how long does it take on RMO?
  Addresses index build time (first start, preset switch), not the per-file parse.
- **S8 clangd navigation from the index** - does a clangd patched to answer `M-.` /
  `M-?` from the file's stored index shard (D-025, O-11) make the first `M-.` after a
  restart fast on RMO, with the same answers?
- **S9 header opened first** - does a header opened as the first file after a restart
  get guessed flags because it asks before the project reaches the background index
  (O-21, D-028)? Owner ruled spike first (tier 3) before patch 0006.
- **S10 deal.II sources index** - does an offline index of deal.II's sources make
  `M-.` reach definitions and `M-?` uses inside the library on RMO, with the patched
  clangd, at what memory (O-12)?
- **S4 cold-header flags** - DROPPED 2026-10-08: replaced by D-028 (patched clangd
  takes an includer from its index; owner ruled tier 2, toy reproduction as evidence).
  Was: which mechanism gives a header opened first (no including
  file open) the flags of a translation unit that includes it: (a) header entries added
  to a generated database from `ninja -t deps` after a build, (b) Emacs opens an
  including source file in the background, (c) accept and document. Gates T-011
  (DESIGN 7, O-5).
- **S2 dape gdb launch** - can dape start `gdb -i dap` on a preset-built debug binary,
  stop at a source breakpoint, step, and show locals / stack? Gates v0.3 (DESIGN 9).
- **S3 treesit grammars** - DROPPED 2026-10-07: the owner installed `tree-sitter-cpp`
  (D-008) and CMake editing uses the system `cmake-mode` (O-4), so no grammar is built.

## Status
| Spike | Status | RESULTS |
|---|---|---|
| S1 | PASS (run 2) | s1-compile-db/RESULTS.md |
| S5 | FAIL, closed by owner ruling (D-021) | s5-preamble-warmup/RESULTS.md |
| S6 | PASS | s6-ccls/RESULTS.md |
| S7 | PKGBUILD ready, owner to build | |
| S8 | PASS (run 2) | s8-clangd-index-navigation/RESULTS.md |
| S2 | PASS (run 1) | s2-dape-gdb/RESULTS.md |
