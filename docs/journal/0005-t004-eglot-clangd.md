# 0005 - T-004: eglot + clangd from the active preset

- **Date:** 2026-10-07
- **Commits:** see `git log -- lisp/init-cpp.el lisp/emacs-cpp-presets.el` (with this)
- **Tier:** 2
- **Decisions:** D-008, D-011, D-016, D-017 (new), D-018 (new)
- **Done when:** in the reference project `M-.` crosses files, `M-?` lists usages,
  `eglot-rename` renames across files, a clang-tidy warning shows in flymake, corfu pops
  up clangd completions while typing; consult-eglot vendored and
  `consult-eglot-symbols` lists project symbols
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner tried eglot before this task and saw 21 errors in `src/main.cc` and a dead
`M-.`. Cause: nothing told clangd where the compile database is (and RMO had never been
configured with a preset), so clangd guessed default flags, could not find deal.II or
the project headers, and could not resolve symbols. This is spike S1's variant A, which
also gave 21 errors. T-004 connects the pieces decided earlier: C++ files open in
`c++-ts-mode`, eglot starts automatically, and the clangd command is computed from the
project's active CMake preset (D-016, D-017). When the database is missing or lacks
`-std`, eglot is refused with a visible error that names the command to run (D-018),
instead of starting a clangd that reports false errors.

## Concepts (Emacs Lisp) explained
- **eglot-server-programs:** eglot's table from major mode to language-server command.
  An entry can be a function instead of a fixed command; eglot calls it with the
  project, so the command can depend on the project (here: its preset's build dir).
- **eglot-ensure:** put on `c++-ts-mode-hook`, it starts or joins the project's server
  when a C++ file is opened. It catches errors from the command function and only logs
  them, which is why the refusal also raises an error-level warning buffer.
- **major-mode-remap-alist:** tells Emacs to use `c++-ts-mode` wherever it would have
  chosen `c++-mode`; `.h` is mapped to C++ explicitly.
- **CMake preset inheritance:** a preset can inherit fields from others; the earlier
  parent in the list wins, the preset's own fields win over all, `hidden` is not
  inherited. The library follows that rule and expands macros such as
  `${sourceDir}/build/${presetName}`; anything it does not understand is an error.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets-clangd-contact`: active preset ->
  build dir -> database checks -> `("clangd" "--compile-commands-dir=...")`;
  `emacs-cpp-presets-select` (`C-c l P`) switches and restarts eglot.
- `lisp/init-cpp.el` - grammar check, mode mapping, eglot setup, consult-eglot.
- `test/emacs-cpp-presets-test.el` - 7 unit tests (inheritance, macros, user presets,
  stored choice, `-std` check, refusal and command).
- `test/init-cpp-test.el` - toy CMake project configured with a preset; eglot starts
  real clangd through the contact; `M-.` must reach another file and a clang-tidy
  finding must reach flymake. A negative control with a bare `clangd` found no
  definition, so the test distinguishes the two cases.
- `Makefile` - `make test` now loads every `test/*-test.el` once, by `require`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** clangd's defaults are right for RMO and deal.II scale (only
  `--compile-commands-dir` is passed). **Would break if:** T-008 measures indexing or
  memory problems a flag would fix. **DESIGN bet:** D-010, principle 7.
- **Assumed:** project.el's project root (the git root) is the CMake source directory.
  **Would break if:** a project keeps CMakeLists.txt below its git root.
  **DESIGN bet:** D-016.
- **Assumed:** parsing `compile_commands.json` on every eglot start is cheap. **Would
  break if:** a deal.II-sized database makes the start visibly slow. **DESIGN bet:**
  D-018.
- **Assumed:** the owner wants clang-tidy checks chosen per project in `.clang-tidy`.
  **Would break if:** the owner wants one global check set (would need a clangd user
  config, which Qt Creator currently owns). **DESIGN bet:** DESIGN 7.
- **Known gap:** headers opened first still get wrong flags (O-5, spike S4, T-011).

## How to verify
`make test` (21 tests). Owner, in RMO:
```
cd ~/source/repos/RMO-gross-pitaevskii && cmake --preset debug
```
then add a `.clang-tidy` (owner's choice of checks), open `src/main.cc` in a restarted
Emacs, and check the done-when items. Before configuring, opening `src/main.cc` should
show the D-018 refusal with the `cmake --preset debug` command.

## Open questions
None new.
