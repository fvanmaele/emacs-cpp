# S12 - change signature as a clangd code action

## Risk
O-43 (b), owner 2026-10-13: CLion's Change Signature has no counterpart in clangd 23.1.1
(`RESEARCH_refactoring.md` 2, 3). Question: can a clangd tweak, built like the local
navigation patches (D-026, `packaging/clangd-index-nav`), change a function's
parameters and every call to it across the project's files, from the index, correctly
and fast enough? Spike code is never promoted; a PASS leads to a patch written fresh.

## What the spike builds (built 2026-10-14; RESULTS.md: FAIL, runs 1 and 2)
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
```
bash spikes/s12-change-signature/build.sh        # clangd + tweak in /tmp/s12/clangd
sh spikes/s12-change-signature/run.sh [FILES]    # 9 operations, results.log here
```
`build.sh` needs the patched tree of `packaging/clangd-index-nav/src` (left by
makepkg or build-macos.sh). `run.sh` works in `~/.cache/emacs-cpp-s12` (`S12_WORK`),
not under `/tmp`: on macOS `/tmp` is a symlink and the index then loses its
cross-file references (RESULTS.md, finding 6); remove that directory before a rerun.
Files: `clangd/` the tweak and its patch, `gen_project.py` the project, `changesig.el`
the batch session, `prompt.el` the Emacs side (asks for the new list).

Owner's hand check (optional): `bash build.sh`, then in Emacs `M-x load-file RET
spikes/s12-change-signature/prompt.el`, set `emacs-cpp-clangd-program` to
`/tmp/s12/clangd/build/bin/clangd` for the session, `M-x eglot-reconnect`, and on a
function's name `C-c l a`, "Change signature", answer for example `(b, a)`. The
summary of edited and reported calls is shown as clangd's message.
