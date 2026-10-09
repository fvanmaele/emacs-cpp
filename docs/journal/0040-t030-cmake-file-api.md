# 0040 - T-030: debug targets from CMake's file API

- **Date:** 2026-10-09
- **Commits:** see `git log -- test/fixtures/file-api`
- **Tier:** 2
- **Decisions:** D-056 (built here), supersedes D-033's build.ninja reading; D-035
- **Done when:** `gdb-preset` / `lldb-preset` list the same targets as before on RMO
  (Ninja) and on a Makefiles preset; a build directory without a reply refuses the
  session naming `C-c p c o`, which writes the query and, after configuring, makes
  the targets appear; the CMake 3.31 and 4 `build.ninja` fixtures are replaced by
  reply fixtures from both CMake versions; the lldb and gdb session tests unchanged;
  make test passes on the Mac and on Arch (agreed 2026-10-09).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
The debug presets need the list of programs a preset builds. They read it from
`build.ninja` with regular expressions over CMake's rule names, which broke once
between CMake versions (0034). The owner ruled for CMake's file API (O-25, D-056): a
documented, versioned JSON description of the build that CMake writes on every
configure, if asked.

Asking means an empty file, `.cmake/api/v1/query/codemodel-v2`, in the build
directory. The configure command (`C-c p c o`) writes it before running `cmake
--preset`; the debug presets write it too when they find no answer, and then say to
configure once. CLion asks the same way, so its build directories already have the
answer. Any generator works now, Makefiles included.

On the owner's CLion build of RMO (`step-1`) the new reading lists the same 11
programs, with the same paths, as the old `build.ninja` reading did.

## Concepts explained
- **Query and reply.** A client puts an empty file named after what it wants into
  `query/`; at the next configure CMake writes `reply/index-<time>.json`, which points
  to `codemodel-v2-<hash>.json`, which lists each target with its own JSON file. A
  target file has `type` (EXECUTABLE, SHARED_LIBRARY, ...), `name` (what `cmake
  --build --target` takes) and `artifacts` (the file it produces, relative to the
  build directory). The newest index is the one with the greatest name.
- **Fixtures.** `test/fixtures/file-api/cmake-3.31` and `cmake-4.3` are real replies
  of one toy project (a program in a subdirectory whose output name has a space, a
  shared library, a C program with its own output directory), with the absolute paths
  replaced by `/toy`. Both versions give the same three programs.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets-request-codemodel` writes the
  query; the configure command calls it.
- `lisp/init-debug.el` - `emacs-cpp-debug--codemodel` (index, codemodel),
  `emacs-cpp-debug-programs` (executables, or the refusal).
- `test/init-debug-test.el` - both CMake versions, no reply, two configurations, a
  Makefiles preset configured first by hand (refused) then with the command (listed);
  the gdb and lldb sessions configure through the command.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the first artifact of an executable is the program. **Would break
  if:** a platform lists another file first (Windows lists the `.pdb` too; not a
  platform here).
- **Assumed:** `cmake --preset` run by hand keeps working for clangd; only the debug
  presets need the reply. **Risk:** a project configured by hand once shows the
  refusal at the first `C-c C-a d`; the message names the fix, and the query is
  already written, so any later configure fixes it.
- **Not supported:** multi-config generators (two configurations in the reply);
  refused with a message.

## Arch verification (2026-10-09)
CMake 4.4.4: `make test` 54 / 54, including the file API tests and the gdb and lldb
session tests. T-030 done.

## How to verify
`make test` (the new and changed tests in `test/init-debug-test.el`). Interactively:
`C-c p c o` in a preset project, then `C-x C-a d lldb-preset RET` (Mac) or
`gdb-preset` (Arch) lists the programs.
