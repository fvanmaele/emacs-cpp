# S13 - clangd's background index through a symlinked path

## Risk
O-50 (c), owner 2026-10-14: "spike for (c)". A project whose compile database spells
its files through a symlink (`/tmp` on macOS, any linked directory on Arch) loses
each main file's definitions and references from clangd's background index: S12's
project gives 3 references to `calc::combine` instead of 201
(`RESEARCH_platform_differences.md` 2.1, 2.6). 2.8 traced it to the main file being
named by the database's spelling in the include graph and by its real path in its
symbols, and proposed a patch 0010 in `index/Background.cpp`. Question: does that
patch restore every reference, keep the stored shards loading on a restart, and
leave the header flags of patches 0005 - 0008 working? Spike code is never promoted;
a PASS leads to patch 0010 written fresh, with a clangd unit test.

## What the spike builds
`0001-real-main-files.patch` on the patched tree (pkgrel 7, patches 0001 - 0009):
- `changedFilesTask` hands `loadProject` the database's files named by their
  directory's real path plus their own name (`realMainFiles`, one `getRealPath` per
  distinct directory; a log line counts the renamed files);
- `indexFileTask` sets the command's `Filename` to the requested path, since the JSON
  database answers with its own spelling.

## Pass criteria (proposed 2026-10-14, owner to confirm)
On S12's generated project (24 calling files), configured once at its real path and
once through a symlinked directory, files opened by their real path (as eglot does),
with the shipped flags (`--background-index --navigation-from-index
--header-flags-from-index`):
1. Through the symlink, run 1: references to `combine` as at the real path (201 in 26
   files); the same build without the patch: 3 (the defect reproduces).
2. At the real path: the same 201 in 26 files with and without the patch.
3. Run 2 (restart, `combine.cpp` opened again): 0 translation units indexed, both
   cases (the shards load under the new spelling), still 201.
4. Run 3 (restart, `include/calc/api.h` opened first): its command comes from an
   includer (`Compile command for ... api.h from ..., which includes it (index)`),
   both cases.
5. macOS under `/tmp` (owner's run): criteria 1 - 4 with CMake 3.31.
Otherwise the findings go to RESULTS.md and decide.

## Prerequisites
Arch: the patched tree makepkg left in `packaging/clangd-index-nav/src` (pkgrel 7),
the system LLVM 23.1.1 (`llvm`, `clang`), CMake, Ninja, Python 3. The build copies
about 560 MB and takes about 30 minutes on 16 cores the first time.

## Commands
```
bash spikes/s13-symlinked-paths/build.sh --baseline   # without the spike patch
cp ~/.cache/emacs-cpp-s13/build/bin/clangd ~/.cache/emacs-cpp-s13/clangd-baseline
bash spikes/s13-symlinked-paths/run.sh ~/.cache/emacs-cpp-s13/clangd-baseline baseline
bash spikes/s13-symlinked-paths/build.sh              # applies the patch, rebuilds
bash spikes/s13-symlinked-paths/run.sh ~/.cache/emacs-cpp-s13/build/bin/clangd patched
```
macOS (criterion 5; run 2026-10-15, RESULTS.md): `build.sh` is Arch-only (GNU `cp`,
the system LLVM); `build-macos.sh` clones the tree `packaging/clangd-index-nav/
build-macos.sh` left and builds the spike there, the installed clangd is the baseline:
```
s13=spikes/s13-symlinked-paths
bash $s13/build-macos.sh
S13_BUILD=/tmp/s13 bash $s13/run.sh ~/opt/clangd-index-nav/bin/clangd baseline
S13_BUILD=/tmp/s13 bash $s13/run.sh ~/.cache/emacs-cpp-s13-mac/build/bin/clangd patched
```

Results: `RESULTS.md`.
