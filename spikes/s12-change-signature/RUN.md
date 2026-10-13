# S12 - change signature as a clangd code action

## Risk
O-43 (b), owner 2026-10-13: CLion's Change Signature has no counterpart in clangd 23.1.1
(`RESEARCH_refactoring.md` 2, 3). Question: can a clangd tweak, built like the local
navigation patches (D-026, `packaging/clangd-index-nav`), change a function's
parameters and every call to it across the project's files, from the index, correctly
and fast enough? Spike code is never promoted; a PASS leads to a patch written fresh.

## What the spike builds (not yet started)
A tweak "Change signature" in a scratch copy of clangd 23.1.1 (the tree the patched
clangd is built from), offered on a function's declaration or definition:
- add a parameter (type, name, default value), the default value written into every
  existing call;
- reorder parameters, and remove one, at the declaration, the definition and every
  call;
- the calls found through the index's references (`SymbolIndex::refs`), each call's
  argument list rewritten from the file's tokens (no parse of every calling file
  unless the spike shows it is needed), the edits returned as one workspace edit
  across files (as DefineOutline does for two).
Driven from Emacs through `C-c l a` (code actions) with the shipped config and that
clangd as `emacs-cpp-clangd-program`.

## Pass criteria (agreed 2026-10-13)
On a generated CMake project with calls in 20 files or more, including calls through
macros, in templates, member functions and overloads:
- the edited project compiles and its tests pass after each of: add a parameter with a
  default value, reorder two parameters, remove one;
- wrong edits: 0 (an overload not changed, a macro call either right or reported);
- the code action answers in under 2 s.
Otherwise the findings (what broke, where) go to RESULTS.md and decide.

## Prerequisites
The llvm-project 23.1.1 sources (`packaging/llvm-project-23.1.1.src`, as for T-023),
a clangd build (about 15 minutes on the Mac, `build-macos.sh`), the generated
project's script (to be written with the spike).

## Commands
To be written with the spike (T-069). See RESULTS.md when it exists.
