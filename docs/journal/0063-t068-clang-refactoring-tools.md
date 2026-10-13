# 0063 - T-068: clang-tidy's fixes and clang-move on `C-c l`

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`lisp/emacs-cpp-refactor.el` (new),
  `lisp/init-cpp.el`, `lisp/defaults-*.el`, `test/emacs-cpp-refactor-test.el`)
- **Tier:** 2
- **Decisions:** D-094 (built here), O-43 (c)
- **Done when:** `C-c l T` run-clang-tidy -fix (checks asked), `C-c l N`
  clang-change-namespace, `C-c l M` clang-move, each in a compilation buffer on the
  active preset's database, buffers reverted; tool directory a D-055 default,
  checked loudly; tests with stubbed processes; a run of each on a generated
  project. Met for T and M; N not built (below).
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
clangd has no project-wide clean-ups and cannot move a class to other files; clang
ships command-line tools for both. `C-c l T` runs clang-tidy over every file of the
compilation database and applies its fixes (for example every `0` used as a null
pointer becomes `nullptr`); `C-c l M` moves classes out of a header and its source
into new ones. Both run like a build, in a compilation buffer, and afterwards Emacs
reloads the files they changed. The third agreed command, moving code to another
namespace, is not offered: the tool crashes when given two sources, and given one
at a time it renames the namespace in the header but not where the code is used,
which leaves a project that no longer compiles.

## Concepts explained
- **Compilation buffer:** `compilation-start` runs a shell command and shows its
  output; `compilation-finish-functions`, set in that buffer only, runs once it is
  done, here to revert the buffers whose files changed on disk.
- **Shell quoting:** each argument is quoted (`shell-quote-argument`), so a check
  list such as `-*,modernize-use-nullptr` reaches the tool unchanged; written as
  `-checks=...` it is one argument (run-clang-tidy took `-checks -*...` for two
  options).
- **Include root:** clang-move writes the new header's `#include` as its path
  relative to the directory it runs in. The command finds where the old source's
  `#include "geom/shapes.h"` starts (`include/`) and runs there, so the new one is
  `#include "geom/square.h"`, not an absolute path; `-old_depend_on_new` makes the
  old header include the new one, so the code using the classes keeps compiling.

## Key files walked
- `lisp/emacs-cpp-refactor.el` - `emacs-cpp-refactor--tool` (the tool or a loud
  error), `--project` (root, build directory, sources from the database), `--run`,
  `--include-root`, the two commands.
- `test/emacs-cpp-refactor-test.el` - the command lines split back into arguments,
  the include root, a missing tool, the keys.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** clang-move handles the owner's classes (templates, nested
  namespaces); tested with plain classes only. **Would break if:** it moves too
  little or too much; the compilation buffer and git show it.
- **Assumed:** Arch's clang tools behave like MacPorts' 23.1.3; not run there.
- **Known:** the new source is not added to CMakeLists.txt (a message says so).

## How to verify
- `make test`: the four refactor tests; the `C-c l` key test.
- Done here (Mac, generated project, shipped config): `C-c l T` with
  `-*,modernize-use-nullptr`: both `0`s replaced, run clean; `C-c l M` with
  `geom::Square`: `include/geom/square.h` and `src/square.cc` created, the old header
  includes the new one, the project built and ran once `square.cc` was listed;
  clang-change-namespace: exit 139 (segmentation fault) with two sources, half-edited
  with one.
- Owner: in RMO, `C-c l T` with a check of the project's `.clang-tidy`; `git diff`.
