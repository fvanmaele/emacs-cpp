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
`/tmp/s1/work/rmo` (override with `S1_WORK=...`, at least three levels deep, see
Gotchas); the real project is never written to. The copy gets
`spikes/s1-compile-db/CMakePresets.json` (debug + release, Ninja,
`CMAKE_EXPORT_COMPILE_COMMANDS=ON`) only if the project has none of its own.

## Run 2 preparation (owner, in RMO-gross-pitaevskii; after run 1, see RESULTS.md)
```
cd ~/source/repos/RMO-gross-pitaevskii
sed -i 's/^set(CMAKE_CXX_STANDARD 20)$/&\nset(CMAKE_CXX_EXTENSIONS OFF)/' CMakeLists.txt
cp ~/source/repos/emacs-cpp/spikes/s1-compile-db/CMakePresets.json .
printf 'build/\n' >> .gitignore
git diff                  # expect: one CMakeLists line, one .gitignore line
git add CMakeLists.txt CMakePresets.json .gitignore
git commit -m 'build: explicit C++20 flag and CMake presets'
rm -rf /tmp/s1
```

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s1-compile-db/run.sh ~/source/repos/RMO-gross-pitaevskii
```
Then the live check in your current Emacs (eglot is built in, no config needed):
```
cd /tmp/s1/work/rmo && ln -s build/debug/compile_commands.json .
emacs src/main.cc        # then: M-x eglot, wait for the mode line to show eglot
```
In that buffer note yes / no for each:
1. `M-.` on a project type (e.g. a class from `rmo/gpe/model.h`) opens its header.
2. `M-?` on that type lists uses in more than one file.
3. `M-.` on a `dealii::` name opens a file under `/usr/include/deal.II/`.
4. `M-x flymake-show-buffer-diagnostics` shows no "file not found" errors.
5. Warm header: from main.cc, `M-.` into an `rmo/` header; its flymake diagnostics show
   no errors (clangd reuses main.cc's flags for headers it includes).
6. Cold header: quit Emacs, then `emacs include/rmo/fe/assemble.h`, `M-x eglot`; note
   whether flymake shows errors such as `rmo/lac_traits.h` not found.

## Pass criteria
PASS if at least one of B, C, D shows "Loaded compilation database", 0 "file not found"
and 0 real diagnostics for `src/main.cc`, and the live check answers yes to 1-5. Item 6
and the header lines of `run.sh` are recorded, not judged: they size the cold-header risk
(DESIGN 7), which gets its own task if it shows. The elapsed time and max RSS for
`src/main.cc` are recorded, not judged (they size Q-2 / D-010).
Proposed decision rule: if B, C and D all pass, prefer D, because Emacs then computes the
argument from the active preset and nothing is added to the project tree.

## Hand back
`spikes/s1-compile-db/results.log` plus your live-check answers (1-6). The next session
writes `RESULTS.md` (verdict, numbers, decision) from them; delete `/tmp/s1` afterwards.

## Gotchas
- 2026-10-07, first run: configure failed with `Unknown CMake command
  "deal_ii_initialize_cached_variables"`. Cause: the copy at `/tmp/s1-rmo` made the
  project's `find_package(deal.II HINTS ../ ../../)` reach `/`, where Arch's `/lib ->
  usr/lib` symlink exposes `/lib/cmake/deal.II`; deal.II then derived its root as `/`
  and found no macros. Fixed in the spike by copying three levels deep. Finding for the
  project (not fixed here): the relative HINTS make configure depend on where the
  checkout lives.
