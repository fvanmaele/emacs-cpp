# S1 - compile-db discovery: results

Verdict: FAIL (run 1, 2026-10-07). Pass criteria not met: every variant that found the
database still reported errors (main.cc 12, header 39). Both causes are found and fixed
outside this repo (below); run 2 decides the final verdict. Run 2 (below): script part
meets the criteria; verdict waits for the owner's live-check answers.

## Environment
Owner machine, 2026-10-07. clangd 23.1.1 (upgraded from 22.1.8 since the DESIGN 3
survey), GCC 16.2.1 as `/usr/bin/c++`, cmake 4.4.3, Ninja, deal.II 9.8.0 system install.
Copy of RMO-gross-pitaevskii at `/tmp/s1/work/rmo` with the spike `CMakePresets.json`.
Raw output: `results-run1.log`.

## Measurements (src/main.cc, debug preset)
| variant | database | not found | errors | elapsed | max RSS |
|---|---|---|---|---|---|
| A-none | not found | 1 | 22 | 0.9 s | 115 MB |
| B-dotclangd | found | 0 | 12 | 7.6 s | 457 MB |
| C-symlink | found | 0 | 12 | 7.6 s | 457 MB |
| D-argument | found | 0 | 12 | 7.7 s | 457 MB |
| E-no-query-driver | found | 0 | 12 | 8.0 s | 457 MB |
Header `include/rmo/fe/assemble.h`: all variants 1 not found, 39 errors, about 7 s,
350 MB. Preamble for main.cc: 127 MB (from a follow-up check). The 12 errors include
3 refactoring self-test failures, which are not diagnostics.

## Findings
1. B, C and D are equivalent: same database, same errors, same cost. Without the
   database (A) the build directory is invisible to clangd. `--query-driver` makes no
   difference to the error count for this project (E vs D).
2. Missing `-std`: GCC 16 defaults to C++20 (`__cplusplus 202002L`), so CMake (policy
   CMP0128) omits `-std` for `CMAKE_CXX_STANDARD 20`; clangd falls back to clang's
   default (C++17) and reports false errors (`std::type_identity`,
   `map::contains`, deal.II `override` mismatches). Checked by Claude on 2026-10-07,
   read-only against a patched copy of the database in the session scratchpad:
   with `-std=gnu++20` or `-std=c++20` added, main.cc has 0 real diagnostics (only the
   tweak self-test lines remain). Toy project: `CMAKE_CXX_EXTENSIONS=OFF` makes CMake
   emit `-std=c++20`.
3. GCC module scanning flags (`-fmodules-ts`, `-fmodule-mapper`, `-fdeps-format`) that
   CMake adds for C++20 under Ninja do not affect clangd (same result with and without).
4. Headers are not in the database. A header opened without an including file open
   gets flags interpolated from the "nearest" entry, here `fmt/src/format.cc`, which
   lacks `-I include` and the deal.II flags: 39 errors, `rmo/lac_traits.h` not found.
   `clangd --check` cannot show whether a running clangd does better once an including
   `.cc` is open; run 2's live check answers that.

## Decision
- Owner ruling 2026-10-07: RMO sets `CMAKE_CXX_EXTENSIONS OFF` in CMakeLists.txt
  (D-011) and commits the spike `CMakePresets.json` (Q-4, D-012).
- O-1 stays open until run 2; if B, C, D stay equivalent, the RUN.md rule picks D.

## Run 2 (2026-10-07, after RMO commit 9dc35b7)
Raw output: `results-run2.log`. The project's own `CMakePresets.json` was used and all
12 database entries carry `-std`.
| variant | file | real diagnostics | elapsed | max RSS |
|---|---|---|---|---|
| A-none | main.cc | 21 | 0.7 s | 114 MB |
| B / C / D | main.cc | 0 | 13.3 - 13.4 s | 776 - 779 MB |
| E (no query-driver) | main.cc | 0 | 13.7 s | 778 MB |
| B / C / D / E | assemble.h | 17 (1 not found) | 6.6 - 8.0 s | 380 MB |
- main.cc is clean in every variant that finds the database; B, C, D remain tied.
- First-parse cost of a deal.II translation unit rose from 7.6 s / 457 MB to about
  13.4 s / 778 MB: with C++20 active, clangd now parses the deal.II code that the C++17
  fallback skipped. This is the real number for D-010.
- The cold header still takes flags from `fmt/src/format.cc` (O-5); live checks 5 and 6
  decide whether a running clangd does better.

## Gotchas
- clangd counts failed refactoring self-tests (`tweak: ... FAIL`) in its error total;
  `run.sh` now reports real diagnostics separately.
- See RUN.md for the configure failure caused by a shallow copy location.

## Follow-ups folded elsewhere
DESIGN 3 (clangd 23.1.1), DESIGN 7 (explicit standard requirement, header risk),
D-011, D-012, TASKS T-001 (run 2), T-009 (owner changes in RMO).
