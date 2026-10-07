# 0001 - S1 run 1: clangd finds the build, but not the C++ standard

- **Date:** 2026-10-07
- **Commits:** see `git log -- spikes/s1-compile-db` (this entry is committed with them)
- **Tier:** 3 (spike S1)
- **Decisions:** D-011, D-012, D-013
- **Done when:** RESULTS.md carries a verdict for run 1 (FAIL) and run 2 is ready to run
- **Tag:** none

> Plain English. No Emacs Lisp was written; this entry is about how clangd learns how a
> file is compiled, and why that went wrong.

## What + why
clangd, the C++ language server behind eglot, must know the exact compiler command of
every file, or it guesses and reports false errors. CMake writes those commands to
`compile_commands.json`, but with presets that file lands in `build/<preset>/`, where
clangd does not look. S1 compared three ways of pointing clangd there on the reference
project. All three worked equally well, so that question is reduced to taste (run 2
settles it). The run instead exposed two other problems that would have made the editor
show wrong errors no matter how clangd found the file.

## Concepts explained
- **Compilation database:** a JSON list, one entry per `.cc` file, with the full compiler
  command. Headers are not in it; clangd borrows a command for them.
- **Default standard:** each compiler assumes a C++ version when none is given. GCC 16
  assumes C++20, clang (inside clangd) assumes C++17. CMake drops the `-std` flag when
  the compiler's default already satisfies `CMAKE_CXX_STANDARD`, so the database never
  said "C++20" and clangd parsed the code as C++17. `CMAKE_CXX_EXTENSIONS OFF` asks for
  strict `c++20` instead of the default `gnu++20`; because that differs from GCC's
  default, CMake writes the flag.
- **Header interpolation:** for a header, clangd picks the database entry whose path
  looks most similar. In RMO that was a file of the bundled `fmt` library, so the
  header got fmt's include paths and could not find `rmo/...` or deal.II.

## Key files walked
- `spikes/s1-compile-db/run.sh` - copies the project, configures with a preset, runs
  `clangd --check` per variant and summarises; now separates real diagnostics from
  clangd's refactoring self-tests, which clangd also counts as errors.
- `spikes/s1-compile-db/RESULTS.md` - numbers and findings of run 1.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** with `-std` in the database, deal.II translation units parse cleanly in
  clangd. **Would break if:** run 2 still shows real diagnostics in `src/main.cc`.
  **DESIGN bet:** D-011.
- **Assumed:** `CMAKE_CXX_EXTENSIONS OFF` does not break the RMO build (strict C++20
  with GCC). **Would break if:** the owner's build fails on GNU-only constructs.
  **DESIGN bet:** D-011.
- **Assumed:** a running clangd gives headers correct flags once an including `.cc` is
  open. **Would break if:** run 2 live check 5 fails. **DESIGN bet:** none yet (O-5).
- **Assumed:** about 7.6 s and 457 MB per deal.II translation unit is acceptable as a
  first-open cost. **Would break if:** the owner finds it too slow in daily use.
  **DESIGN bet:** D-010.

## How to verify
Read `spikes/s1-compile-db/results-run1.log`. For the `-std` finding:
`c++ -dM -E -x c++ /dev/null | grep __cplusplus` prints `202002L`, and after the owner's
RMO change `grep -c -- -std= build/debug/compile_commands.json` is non-zero.

## Open questions
O-1 (mechanism, run 2) and O-5 (cold headers) are in the DESIGN ledger.
