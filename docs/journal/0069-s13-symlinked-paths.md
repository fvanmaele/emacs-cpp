# 0069 - S13: clangd's index through a symlinked path, PASS on Arch

- **Date:** 2026-10-14
- **Commits:** here: `git log -- spikes/s13-symlinked-paths`
- **Tier:** 3 (spike S13)
- **Decisions:** none (O-50 (c) to the owner)
- **Done when:** RESULTS.md carries a verdict against the pass criteria proposed in
  RUN.md (T-077); the owner confirms the criteria and runs criterion 5 on the Mac
- **Tag:** none

> Plain English. No configuration code changed; everything lives in the spike's
> directory and in a scratch clangd under `~/.cache/emacs-cpp-s13`.

## What + why
When a project's compile database names its files through a symlink, clangd's
background index loses what each `.cpp` file contributes itself: S12's project gives
3 references to `combine` instead of 201 (O-50). `RESEARCH_platform_differences.md`
2.8 found the reason in clangd's code and proposed a small patch. The spike built that
patch on top of the local patches and ran S12's project twice: once configured at its
real path, once through a symlinked directory.

With the patch, the symlinked project gives 201 references in 26 files, the same as
the real one; without it, 3. A restart indexes nothing (the stored index files are
found again), and a header opened first still gets the compile flags of a `.cpp`
that includes it (patches 0005 - 0008). Moving from an unpatched clangd costs one
full re-index of the project. The Mac run under `/tmp` is the owner's.

## Concepts explained
- **Background index, shards:** clangd parses every file of the database in the
  background and stores what it found per file (a "shard") under
  `build/<preset>/.cache/clangd/index`. On a restart it loads the shards instead of
  parsing again.
- **The two spellings:** clangd asked for each file's command by the database's
  spelling (`link/p/src/use_00.cpp`), so it compiled the file under that name. Its
  list of files used that name too, but the symbols it recorded used the real path
  (`linked/p/src/use_00.cpp`). Only files in the list are stored, so the `.cpp`
  file's own symbols and references were dropped.
- **The patch:** before loading or indexing, clangd now names each database file by
  its directory's real path, looked up once per directory, plus the file's own name.
  It also makes the compile command carry that name. Both spellings then agree.
- **Standalone build:** the spike builds only clang and clangd against Arch's
  installed LLVM libraries, as the package does, so the first build takes about 25
  minutes and a change to one file about a minute.

## Key files walked
- `spikes/s13-symlinked-paths/0001-real-main-files.patch` - `realMainFiles` in
  clangd's `index/Background.cpp`, called from `changedFilesTask`; `indexFileTask`
  sets `Cmd->Filename`.
- `spikes/s13-symlinked-paths/client.py` - a minimal LSP client: open a file, wait for
  the index to go quiet, ask for references, count the files indexed.
- `spikes/s13-symlinked-paths/run.sh` - both projects, three runs each.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** resolving only the directory matches what the symbol collector does
  (`getCanonicalPath`). **Would break if:** a `.cpp` file is itself a symlink; then
  the include graph may resolve it fully while the patch does not. Not tested.
  **DESIGN bet:** O-50 (c).
- **Assumed:** clangd's JSON database finds a command by the real path
  (`findEquivalent`). **Would break if:** two files share their last path components
  and the lookup becomes ambiguous. Not tested.
- **Assumed:** the Mac behaves as Arch once both spellings agree. **Would break if:**
  `/tmp`'s firmlinks or CMake 3.31's rewriting add a third spelling. The owner's run
  (criterion 5).

## How to verify
```
bash spikes/s13-symlinked-paths/build.sh --baseline
cp ~/.cache/emacs-cpp-s13/build/bin/clangd ~/.cache/emacs-cpp-s13/clangd-baseline
bash spikes/s13-symlinked-paths/run.sh ~/.cache/emacs-cpp-s13/clangd-baseline baseline
bash spikes/s13-symlinked-paths/build.sh
bash spikes/s13-symlinked-paths/run.sh ~/.cache/emacs-cpp-s13/build/bin/clangd patched
```
Look for `link run 1 ... references 201 files 26` with the patched build and `3
files 2` with the baseline; `indexed 0` on runs 2 and 3.
