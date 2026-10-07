# S1 - compile-db discovery

## Risk
DESIGN 7, O-1: CMake presets build into `build/<preset>/`, but clangd only looks for
`compile_commands.json` in the parent directories of a file and their `build/` subdir.
If clangd falls back to default flags, deal.II and project includes are "not found" and
navigation, rename and diagnostics are wrong. The spike decides which mechanism points
clangd at the active preset's database, and measures the per-file cost of a deal.II
translation unit (input for Q-2, D-010).

## Variants
- A-none: no help (baseline, expected to fail).
- B-dotclangd: project `.clangd` with `CompileFlags: CompilationDatabase: build/debug`.
- C-symlink: `compile_commands.json` in the project root -> `build/debug/...`.
- D-argument: clangd `--compile-commands-dir=build/debug` (Emacs would pass it).
- E-argument-no-query-driver: D without `--query-driver`, to see if gcc's system include
  discovery matters for this project.
Each variant is checked on `src/main.cc` and on the first header under `include/`
(headers are not in the database; clangd must infer their flags).

## Prerequisites
clangd, cmake, ninja, rsync, python3 (all present on 2026-10-07). The project is copied to
`/tmp/s1-rmo` (override with `S1_WORK=...`); the real project is never written to. The
copy gets `spikes/s1-compile-db/CMakePresets.json` (debug + release, Ninja,
`CMAKE_EXPORT_COMPILE_COMMANDS=ON`), the same file proposed for the real project later.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s1-compile-db/run.sh ~/source/repos/RMO-gross-pitaevskii
```
Then the live check in your current Emacs (eglot is built in, no config needed):
```
cd /tmp/s1-rmo && ln -s build/debug/compile_commands.json .
emacs src/main.cc        # then: M-x eglot, wait for the mode line to show eglot
```
In that buffer note yes / no for each:
1. `M-.` on a project type (e.g. a class from `rmo/gpe/model.h`) opens its header.
2. `M-?` on that type lists uses in more than one file.
3. `M-.` on a `dealii::` name opens a file under `/usr/include/deal.II/`.
4. `M-x flymake-show-buffer-diagnostics` shows no "file not found" errors.

## Pass criteria
PASS if at least one of B, C, D shows "Loaded compilation database", 0 "file not found"
and 0 errors for both files, and the live check answers yes to 1-4. The elapsed time and
max RSS for `src/main.cc` are recorded, not judged (they size Q-2 / D-010).
Proposed decision rule: if B, C and D all pass, prefer D, because Emacs then computes the
argument from the active preset and nothing is added to the project tree.

## Hand back
`spikes/s1-compile-db/results.log` plus your four live-check answers. The next session
writes `RESULTS.md` (verdict, numbers, decision) from them; delete `/tmp/s1-rmo` afterwards.
