# 0021 - T-005: build the active preset from any buffer

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/emacs-cpp-presets.el lisp/init-project.el`
- **Tier:** 2
- **Decisions:** D-035 (owner ruling on O-17); supersedes DESIGN 8's PROPOSED
  `projectile-enable-cmake-presets` line
- **Done when:** preset build errors jump to source (TASKS, agreed before this work);
  owner ruling: from any buffer, with the active preset's build directory.
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
`C-c p c c` ran projectile's fixed CMake command `cmake --build build` in the project
root. RMO's presets put builds in `build/debug` and `build/release`, so that could not
work, and projectile's own preset mode asks for a preset on each run, ignoring the
active one that eglot uses. Now projectile's `cmake` project type takes its configure,
build and test commands from the presets library: they always name the active preset's
build directory, whatever buffer you are in, like CLion's Build button.

## Concepts explained
- **Projectile project types:** projectile recognises a CMake project by its
  `CMakeLists.txt` and keeps one command per lifecycle phase (configure, compile, test,
  ...). `projectile-update-project-type` replaces them; a command given as a function
  is called on every run, so the answer follows `C-c l P` at once. If you edit the
  command at the prompt, projectile remembers your edit for that project instead
  (`projectile-discard-command-cache` forgets it).
- **Why errors jump to source from anywhere:** compilation mode turns each `file:line:`
  in the output into a link; Ninja gives the compiler absolute source paths (seen in
  RMO's build.ninja), so the link works whichever directory the build ran in.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets-compile-command` and its two
  siblings; `emacs-cpp-presets--current` finds root, active preset and its directory.
- `lisp/init-project.el` - projectile's one `use-package` form registers them.
- `test/init-build-test.el` - a toy project with an error: from the header buffer,
  configure, build, then the first error opens `src/main.cc` at line 3.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the build runs in the project root, where projectile runs cmake
  projects (its `compilation-dir` for this type is the root). **Would break if:** a
  `.dir-locals.el` sets `projectile-project-compilation-dir`; the relative directory
  is then wrong (cmake says so). **DESIGN bet:** D-035.
- **Assumed:** a CMake project without `CMakePresets.json` should refuse to build
  (D-005), so `C-c p c c` there now errors instead of running `cmake --build build`.
  **Would break if:** the owner builds such projects with projectile; then add a
  fallback only by a ruling.
- **Not changed:** `C-c p c i` / `c p` (install, package) still use projectile's
  `build` directory.

## How to verify
`make test` (32 tests). Owner, on RMO: open any file (a header too), `C-c p c c`; the
prompt shows `cmake --build build/debug`; RET builds; `M-g n` on an error opens the
source line. `C-c l P release`, then `C-c p c c` shows `build/release`. `C-c p c t`
runs the 6 registered tests.
