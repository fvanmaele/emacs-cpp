# 0065 - T-072: a patched clang-change-namespace on `C-c l N`

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`packaging/clang-change-namespace/`
  (new), `lisp/emacs-cpp-refactor.el`, `lisp/init-cpp.el`,
  `test/emacs-cpp-refactor-test.el`, `test/init-cpp-test.el`)
- **Tier:** 2
- **Decisions:** D-097 (built here), D-094, O-43 (c)
- **Done when:** packaging/clang-change-namespace/: the patch file and a build
  script (Mac: against MacPorts' llvm-23 into ~/opt/clang-change-namespace; Arch:
  against the system clang, same script) with the program path as a defcustom
  (refused loudly when missing). `C-c l N` asks old and new namespace, runs the tool
  on all sources of the database in a compilation buffer, then replaces `old::` with
  `new::` in the project's files through an editable list (as MANUAL 8's namespace
  route) for review. Run on a generated project: compiles after; tests with stubbed
  processes; make test. Met on the Mac; the script is not run on Arch yet.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp or shell fluently.

## What + why
clangd cannot rename a namespace. clang ships a tool that can move a namespace's
code, but LLVM 23's copy crashes as soon as it is given two source files (D-094
found the cause: it keeps pointers into the first file's data after that data is
freed). The fix is seven lines. This change ships it as a patch with a script that
builds the tool in under a minute, and puts a command on `C-c l N` that runs it on
the whole project and then deals with what the tool leaves by design: code outside
the namespace that still says `old::Thing`. Those lines appear in a list, already
changed to `new::Thing` in their buffers, for the owner to read before saving.

## Concepts explained
- **Building against installed libraries:** `llvm-config` reports the compiler
  flags, library directory and link flags of the LLVM that is installed; the script
  compiles the tool's two `.cpp` files with them and links `libclang-cpp` and
  `libLLVM`. The rpath option stores the library directory in the program, so it
  finds the libraries without environment variables.
- **Builtin headers:** clang-based tools look for the compiler's own headers
  (`stddef.h`, ...) in `../lib/clang` beside the program; the script links that
  directory to the installed clang's.
- **The self-check:** the script runs the new tool on two tiny generated sources,
  the crash's reproduction; the unpatched MacPorts tool exits with 139 there.
- **grep-edit mode (Emacs 31):** a grep result buffer can be switched to editing;
  each change to a result line is copied into the file's buffer at once. The
  command writes the list itself, lets font-lock mark each line as a match (what
  grep-edit needs), switches to editing and replaces each line's text, so the
  changes reach the buffers; nothing is saved.
- **Which `old::` counts:** a regular expression that takes `old::` only at the
  start of a name: not `myold::`, not `outer::old::` (another namespace of the same
  name inside `outer`), but `::old::`, the global one.

## Key files walked
- `packaging/clang-change-namespace/build.sh` - sources (download or tarball),
  checksums, patch, compile, self-check, install.
- `packaging/clang-change-namespace/0001-...patch` - the fix, as in the upstream
  report draft.
- `lisp/emacs-cpp-refactor.el` - `emacs-cpp-refactor-change-namespace` (the tool's
  command line), `--namespace-uses` (the list), `--qualified-use`, `--ere-quote`
  (the project root as the tool's file pattern).
- `test/emacs-cpp-refactor-test.el` - command line, refusals, the root quoted, the
  list on real files with the tool stubbed.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** Arch's llvm and clang 23 packages provide `llvm-config`,
  `libclang-cpp` and the clang headers, as their file lists say. **Would break
  if:** the script stops there; it names what is missing. Not run on Arch.
- **Assumed:** the sources of 23.1.1 build against MacPorts' 23.1.3 libraries (same
  major release; done here). **Would break if:** LLVM 24: the script refuses any
  LLVM but 23; a new version needs new checksums and a look at the patch.
- **Known:** the tool formats what it moved in LLVM style, not the project's
  `.clang-format` (its `-style` doubles as its fallback style, where `file` is
  refused). `C-c l f` reformats.
- **Known:** `using namespace old;` and `namespace a = old;` are not changed; MANUAL
  8's route by hand covers them.
- **Found:** `-style=file` made the tool skip its clean-up (an empty `namespace
  geom {}` was left in each file); caught on the generated project, removed.

## How to verify
- `make test`: 108 tests, 106 pass, 2 skipped.
- Done here (Mac): `build.sh --tarball packaging/llvm-project-23.1.1.src.tar.xz` and
  without it (download), each into a scratch prefix: checksums, patch, self-check
  pass, 31 s. A generated project (`include/geom/shapes.h`, `src/shapes.cc`,
  `src/main.cc`, preset `debug`), `C-c l N` `geom` `shapes` through the shipped
  config: tool in 0.08 s; header and source in `namespace shapes`; the list showed
  main.cc's `shapes::Circle` and `::shapes::Square`; saved, `cmake --build` passed,
  the program printed `3.14 4.00`.
- Owner: `packaging/clang-change-namespace/build.sh` on each machine (installs into
  `~/opt/clang-change-namespace`); then `C-c l N` in a project of yours, `git diff`.
