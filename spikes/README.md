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
- **S2 dape gdb launch** - can dape start `gdb -i dap` on a preset-built debug binary,
  stop at a source breakpoint, step, and show locals / stack? Gates v0.3 (DESIGN 9).
- **S3 treesit grammars** - DROPPED 2026-10-07: the owner installed `tree-sitter-cpp`
  (D-008) and CMake editing uses the system `cmake-mode` (O-4), so no grammar is built.

## Status
| Spike | Status | RESULTS |
|---|---|---|
| S1 | ready, owner to run | |
| S2 | not started | |
