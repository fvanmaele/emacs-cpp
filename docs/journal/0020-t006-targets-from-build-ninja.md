# 0020 - T-006 fix: `gdb-preset` targets from build.ninja

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/init-debug.el`
- **Tier:** 2 (fix inside T-006, owner ruled D-033)
- **Decisions:** D-033 (supersedes the program list of D-031)
- **Done when:** T-006's line (0019, TASKS); here additionally: a target that was
  configured but never built is offered and built; make test / make check pass.
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
The owner's first try on RMO answered "no program in .../build/debug": that build
directory was configured but never built, and 0019 offered only programs that already
existed, although `gdb-preset` builds before it starts gdb. The list now comes from
`build.ninja`, which CMake writes at configure time and which names every executable
target with its output path. RMO's lists 10 (`main`, `main_bench`, ..., `test_m_matrix`)
with nothing built. The owner chose this over CMake's file API (D-033).

The owner's second report, "C-x a b is undefined": not reproduced. In a terminal Emacs
with the shipped config, `C-x C-a b` loads dape and sets a breakpoint (`C-h l` shows
the loader, then `dape-breakpoint-toggle`); `C-x a` is Emacs's abbrev prefix, so the
key that arrived was `C-x a b` without Control on `a`.

## Concepts explained
- **A Ninja link block:** `build sub/be$ tool: CXX_EXECUTABLE_LINKER__b_x_Debug ...`
  says "file `sub/be tool` is made by the link rule of target `b_x` in configuration
  Debug". `$ ` is Ninja's escaped space. The block's `CONFIG = Debug` line gives the
  suffix to strip; without a build type there is no such line and the rule ends in `_`
  (checked with cmake on a toy project).
- **Target name versus file name:** CMake's `OUTPUT_NAME` lets a target `b_x` produce
  `be tool`. 0019 guessed the target from the file name; reading the rule removes that
  guess, so `cmake --build --target` always gets the real name.

## Key files walked
- `lisp/init-debug.el` - `emacs-cpp-debug-programs` reads the link blocks into
  `(TARGET . PROGRAM)` pairs; the prompt offers target names; the build command looks
  the program up again, so a `:program` typed by hand must be a target's output.
- `test/init-debug-test.el` - a build.ninja shaped like CMake's (subdirectory,
  `OUTPUT_NAME` with a space, a shared library, no CONFIG); the session test now only
  configures the toy project, so the session's own build makes the program.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** CMake keeps the rule name `<LANG>_EXECUTABLE_LINKER__<target>_<config>`
  (true for CMake 3.28 - 4.x checked here). **Would break if:** a CMake release renames
  it; the list is then empty and the session refused with "no executable target"
  (loud). **DESIGN bet:** D-033.
- **Assumed:** presets use the single-config Ninja generator (RMO does). **Would break
  if:** a project uses "Ninja Multi-Config" or Makefiles; no build.ninja (or no link
  blocks in it) refuses the session.
- **Superseded:** 0019's "target name = file name" assumption.

## How to verify
`make test`. Owner, on RMO: as in 0019 "How to verify"; the prompt is now "Target in
~/source/repos/RMO-gross-pitaevskii/build/debug:" and lists all 10 targets even
before the first build; picking `main` builds it (deal.II link, takes a while) and
then stops at the breakpoint.
