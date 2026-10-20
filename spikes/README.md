# spikes/

Throwaway prototypes that turn one DESIGN risk into a measured PASS/FAIL verdict BEFORE app
code is written for it. Each spike is a self-contained directory with its own build files.

## Rules
- One spike answers one risk from the DESIGN risk register. It produces a verdict, not code.
- Two docs per spike: `RUN.md` (which risk, prerequisites, what the session runs and what
  the owner does, or the script and its report; ends by pointing at RESULTS.md) and
  `RESULTS.md` (opens with `Verdict: PASS/FAIL`, then environment,
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
- **S12 change signature** - can a clangd code action add, reorder and remove a
  function's parameters at every call across the project's files, from the index,
  without wrong edits and in under 2 s (O-43 (b))? FAIL (runs 1, 2): no wrong edit,
  calls in templates left to the user (T-069, `s12-change-signature/RESULTS.md`).
- **S13 symlinked paths** - does a clangd patch naming the background index's main
  files by their real directory restore the references a project reached through a
  symlink loses, with shards still loading on a restart and header flags from an
  includer (O-50 (c))? PASS: criteria 1 - 4 on Arch, 5 (macOS under `/tmp`) on the Mac
  (T-077, `s13-symlinked-paths/RESULTS.md`).
- **S14 symbol matches** - do CLion's mid-word (`ector`) and abbreviated-qualifier
  (`geom::vert`) symbol matches work in clangd on deal.II's index without changing
  today's fuzzy replies or slowing them (O-57 (b), (c))? PASS (owner's run on
  step-1, 2026-10-15; T-103, `s14-symbol-matches/RESULTS.md`).
- **S15 mid-word rank** - does rule R4 in clangd (contiguous fuzzy matches first,
  then scattered fuzzy and mid-word ones by how much of the name they cover) put
  `Vector` first for `ector` within `C-c l s`'s 100, without changing the order of
  good fuzzy matches or slowing replies (O-67 (a), D-119)? PASS (owner's run on RMO,
  2026-10-19; T-107, `s15-mid-word-rank/RESULTS.md`).
- **S10 deal.II sources index** - does an offline index of deal.II's sources make
  `M-.` reach definitions and `M-?` uses inside the library on RMO, with the patched
  clangd, at what memory (O-12)?
- **S11 go to anything** - are project files, filtering and clangd's
  `workspace/symbol` fast enough on RMO and the deal.II tree for one combined prompt
  (D-074)? Gates T-049.
- **S16 match function** - does D-120's tier rule written as a function
  (`string-search` plus a word-start predicate, D-124) give the regexps' tier for
  every name of a large tree, keep the spec rows, and sort a prompt's candidates
  faster than the regexps, in which compilation state? Gates D-124 (T-112).
- **S17 compiled lisp/** - does byte-compiling `lisp/` keep startup within 10 ms of
  interpreted, and do the modules then run as native code (D-125)? Gates D-125 and,
  through it, D-124 (T-113).
- **S18 fswatch backend** - does one patched fswatch per server and root, read by config
  Lisp over the built-in eglot, deliver every change of a 20000-change burst on an
  LLVM-sized tree to pyright while Emacs is blocked, on the Mac and on Arch, at an
  acceptable CPU cost? Gates D-127 (T-116).
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
Status words: `not started`, `ready` (RUN.md written, the owner runs it; no RESULTS.md yet),
`running`, `PASS`, `FAIL` (copied from RESULTS.md).
| Spike | Status | RESULTS |
|---|---|---|
| S1 | PASS (run 2) | s1-compile-db/RESULTS.md |
| S5 | FAIL, closed by owner ruling (D-021) | s5-preamble-warmup/RESULTS.md |
| S6 | PASS | s6-ccls/RESULTS.md |
| S7 | ready (PKGBUILD built here; owner to build and run) | |
| S10 | FAIL run 2 (first `M-.` before the index loads); config fix confirmed | s10-library-index/RESULTS.md |
| S8 | PASS (run 2) | s8-clangd-index-navigation/RESULTS.md |
| S2 | PASS (run 1) | s2-dape-gdb/RESULTS.md |
| S11 | runs 2, 3 PASS; run 4 recorded; run 1 FAIL in part | s11-go-to-anything/RESULTS.md |
| S12 | FAIL (runs 1, 2); owner rules O-43 (b) | s12-change-signature/RESULTS.md |
| S16 | PASS compiled, FAIL interpreted (D-124 with D-125) | s16-match-function/RESULTS.md |
| S17 | PASS run 3 with the settings at compile time (O-74); criteria to confirm | s17-compiled-lisp/RESULTS.md |
| S18 | PASS on Arch (run 2, `dedup`); Mac rerun of `dedup` left (H-13) | s18-fswatch-backend/RESULTS.md |
