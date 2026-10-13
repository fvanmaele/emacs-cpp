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

## Run 2: the whole prompt in a terminal Emacs (D-077)
Risk: run 1 timed the parts in batch, where no garbage collection runs; a terminal
Emacs showed collections are most of a key's time (`RESEARCH_go_to_anything.md` 8).
Question: with D-077's four changes, how fast is the prompt on RMO with the patched
clangd, listing the project's files at each opening as T-049 will?

`prompt.el` builds the prompt as D-074 .. D-077 rule it (buffers, recent files,
bookmarks, project files from `projectile-project-files` at each opening, clangd
symbols from the third key, no request for `""`, `:sort nil`, the first 100 hits
highlighted, 0.05 s refresh and symbol throttle, `gc-cons-threshold` 64 MB while
open) and logs, for each key, every screen update after it: time since the key,
input, candidates, collections since the key. `prompt.sh` runs two passes in a
detached tmux session, each a fresh `emacs -nw`: the prompt lists RMO's files, then
the deal.II checkout's (a stand-in for a deal.II-sized project); each pass opens the
prompt for `main`, `vec`, `Tri`, `assemble`, `Sol`, twice, one key per 300 ms.

Prerequisites: as run 1, and tmux (`pacman -S tmux` if missing). The tmux session
is invisible; leave the machine idle for the 3 - 4 minutes.
```
cd ~/source/repos/emacs-cpp
sh spikes/s11-go-to-anything/prompt.sh ~/source/repos/RMO-gross-pitaevskii \
    ~/source/repos/dealii src/main.cc
```
Hand back `spikes/s11-go-to-anything/results-run2.log`.

Pass criteria (proposed 2026-10-11; T-049's done-when reuses them), RMO pass:
- Opening: the first screen within 150 ms of `M-o`, file listing included.
- Each key: the first screen showing that key's input within 100 ms.
- Symbols: on screen within 200 ms of the key that asked for them.
The deal.II pass is recorded, not judged (D-075).

Dry run (2026-10-11; toy project, 34583 empty files named after the LLVM stand-in
in a scratch git directory, patched clangd): no collection while typing. Toy:
opening 20 - 42 ms, keys 2 - 11 ms, symbols on screen about 110 ms after the key.
Stand-in tree: listing 68 - 79 ms, opening 108 - 150 ms, keys 26 - 59 ms (first
letter worst), symbols 126 - 148 ms (clangd 1 - 9 ms). The prompt starts with `#`:
consult's `perl` split style marks async input that way (`#vec#filter`); T-049
decides whether to keep it.

## Run 3: the shipped command (T-049)
`prompt.sh` with `S11_SHIPPED=1` binds `M-o` to the shipped `emacs-cpp-go-to-anything`
and keeps run 2's logging; RMO pass only (the command lists the open file's project).
```
cd ~/source/repos/emacs-cpp
S11_SHIPPED=1 sh spikes/s11-go-to-anything/prompt.sh \
    ~/source/repos/RMO-gross-pitaevskii ~/source/repos/dealii src/main.cc
```
Hand back `spikes/s11-go-to-anything/results-run3.log`. Criteria: run 2's, RMO.
Dry run (toy, 2026-10-11): opening 18 - 34 ms, keys 7 - 23 ms, symbols on screen
about 120 ms after the key, no `#`, no collection.

## Run 4: narrowed to symbols, a deal.II project (D-079, T-054)
Owner request 2026-10-11 after D-079: compare `M-o` narrowed to symbols (`<` `s`) with
`C-c l s` in a deal.II-sized project, at one key per 100 ms (`S11_KEY_DELAY`).
`S11_NARROW=1` opens `M-o`, types `<` `s` and the word, closes it, then types the same
word in `C-c l s`; it logs every screen update and clangd's `workspace/symbol`
requests and replies. Two passes: the project's own files, then the large tree's
files listed by `M-o` (clangd stays the project's).

Two setups; the second needs the owner's choice (see the session of 2026-10-11):
- deal.II's files with RMO's clangd (no deal.II build needed):
  ```
  cd ~/source/repos/emacs-cpp
  S11_NARROW=1 sh spikes/s11-go-to-anything/prompt.sh \
      ~/source/repos/RMO-gross-pitaevskii ~/source/repos/dealii src/main.cc
  ```
- deal.II as the project with its own clangd: the checkout needs a
  `CMakePresets.json` writing `compile_commands.json`, a configure, and one session
  in which clangd builds its background index of deal.II (not measured here; RMO's
  index took minutes for 38 sources, deal.II has thousands of heavily templated
  translation units). Then the same command with the deal.II checkout as the
  project and a deal.II source file as the file, for example
  `~/source/repos/dealii ~/source/repos/dealii source/grid/tria.cc`.
Hand back `spikes/s11-go-to-anything/results-run4.log`. Recorded, not judged; the
question is whether `M-o` narrowed feels as calm as `C-c l s` there.

Dry run (2026-10-11; toy, 34583-file stand-in, patched consult, 100 ms per key):
stand-in pass narrowed 1.4 - 3.3 ms per update; `C-c l s` 2.8 - 3.5 ms per key, one
request after the pause.

## Run 5: project symbols among clangd's workspace symbols (O-37, T-059)
Owner request 2026-10-13: `C-c l s` and `M-o` `<` `s` list every symbol of clangd's
index, deal.II's and the standard library's too; wanted: the project's alone, as
CLion's Symbols tab without "Include non-project items". Research first. clangd
23.1.1 takes a `limit` per `workspace/symbol` request (0: none) and ranks without
regard to where a symbol is defined, so a client that keeps only symbols under the
project root loses those that ranked below the limit. `scope.el` asks each query
with limit 100 (today's default), 1000 and 0 and logs the time, the reply's size
and how many symbols lie under the project root. Queries: the project's C++ file
base names as seeds, then the 3- and 5-letter prefixes and full names of the project
symbols they find (at most 40). Own seeds: `S11_SEEDS="Solver Lac ..."`.
```
cd ~/source/repos/emacs-cpp
sh spikes/s11-go-to-anything/scope.sh ~/source/repos/RMO-gross-pitaevskii src/main.cc
```
A few minutes; wait for the stored index to load (`S11_SETTLE`, default 20 s). Hand
back `spikes/s11-go-to-anything/results-run5.log`. Recorded, not judged: per limit,
the median and slowest time and how many project symbols are lost against no limit.

Dry run (2026-10-13, Mac, toy project with `<vector>` and `<string>`, patched
clangd): 8 queries, 0.1 - 0.6 ms each, none lost at any limit; `ans` gave 15
symbols, 2 of them the project's.
