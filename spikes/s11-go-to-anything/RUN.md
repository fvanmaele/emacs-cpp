# S11 - go to anything: the cost of each source

## Risk
D-074, O-30 (b): one prompt on a single key lists buffers, project files, recent files
and bookmarks from the first key, clangd symbols from the third, commands behind a
narrow key (`RESEARCH_go_to_anything.md` 3, 6). Owner ruling 2026-10-11: measure
first. Question: on RMO and the deal.II source tree, is each part fast enough that
the prompt opens and narrows without a felt delay?
- Project files are listed again at every opening: projectile's `alien` indexing has
  no cache (`projectile-project-files`).
- Once a source is async, every key filters all static items with consult's regexps
  (`consult--async-static`), not orderless.
- Symbols are one `workspace/symbol` request to clangd per input.

## Prerequisites
The shipped config built (`make packages`), the patched clangd installed
(`/opt/clangd-index-nav/bin/clangd`, pkgrel 7), RMO configured with its active preset
and its clangd index on disk (any earlier Emacs session on it). The deal.II checkout
at `~/source/repos/dealii`. Best on an idle machine.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s11-go-to-anything/run.sh ~/source/repos/RMO-gross-pitaevskii \
    ~/source/repos/dealii src/main.cc
```
About one minute. RMO is used in place, as in a daily session: the script writes
nothing into it or into `~/.emacs.d`; it reads `recentf`, `bookmarks` and
`emacs-cpp-presets.eld` there. clangd may update its index under the build
directory, as it does in every session. Another clangd: `S11_CLANGD=/path/to/clangd`.

## What it measures
Each static number is the median of 5 runs (min - max in brackets).
- `projectile-project-files` on RMO and on the deal.II tree: time and file count.
- The command list as `M-x` filters it: time and count.
- The owner's recent files and bookmarks: counts.
- Filtering, as `consult--async-static` does it, over all static items (buffers,
  recent files, bookmarks, project files, commands), once with RMO's files and once
  with deal.II's, for the inputs `m`, `ma`, `mai`, `main`, `fe val`, `tria h`,
  `assemble`.
- `workspace/symbol` on RMO for seven queries (`Tri`, `Triangulation`, `vec`, `main`,
  `assemble`, `Sol`, `SolutionTransfer`): time and count, once as soon as eglot
  manages `src/main.cc` and once 20 s later (`S11_SETTLE`), with the index loaded.

## Pass criteria (proposed 2026-10-11, owner agrees before the run)
100 ms is taken as the limit of a reply that feels immediate.
- Opening: `projectile-project-files` median <= 100 ms on RMO and on the deal.II tree.
- Typing: filtering median <= 20 ms for every input, over deal.II's files.
- Symbols, with the index loaded: median <= 100 ms, every query <= 300 ms.
A FAIL names the part; the build (T-049) then caches that part or leaves it out,
and the owner rules which.

## Dry run (toy project, 2026-10-11)
A two-source CMake toy in a scratch directory, this repository as the large tree, an
empty `~/.emacs.d`, the patched clangd, `S11_SETTLE=5`:
- Toy files 20, 18 ms. This repository 2136 files, 742 ms: projectile lists each
  of its 30 git submodules separately; `git ls-files` at the top takes 7 ms for 210
  files. RMO has 1 submodule (fmt), the deal.II checkout 0.
- Commands 4330, 8.9 ms. Filtering 6470 items: 5.1 ms for `m`, 1.2 - 3.1 ms for
  longer inputs.
- eglot managed 453 ms after open. Symbols at once: 0 for every query (the index was
  not loaded yet); 5 s later 0.8 - 3.6 ms.

## Hand back
`spikes/s11-go-to-anything/results.log`.
