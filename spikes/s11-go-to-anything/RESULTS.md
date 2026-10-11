# S11 - go to anything: results

Verdict: FAIL in one part (run 1, 2026-10-11). Filtering a one-letter input over the
deal.II tree's files took 31.8 ms (criterion: 20 ms). Every other number passes,
most by a wide margin: file listing 51 / 66 ms (100 ms), every input over RMO's
files 1.5 - 6.7 ms, symbols median 5.5 ms, slowest 16.3 ms (100 / 300 ms). Criteria
as proposed in RUN.md; the owner ran without changing them.

## Environment
Owner machine (Arch), 2026-10-11 15:17, load 0.11 at start, 0.25 after. Patched clangd
23.1.1 (`/opt/clangd-index-nav/bin/clangd`, pkgrel 7). RMO in place, active preset
from `emacs-cpp-presets.eld`, its stored index. deal.II checkout
`~/source/repos/dealii`. Raw output: `results-run1.log`.

## Measurements (medians of 5)
| What | RMO | deal.II tree | Criterion |
|---|---|---|---|
| files | 2765 | 34602 | |
| `projectile-project-files` | 51.2 ms | 65.9 ms | <= 100 ms |
| filter `m` (all static items) | 6.7 ms | 31.8 ms | <= 20 ms |
| filter `ma` | 4.2 ms | 13.1 ms | <= 20 ms |
| filter 3+ letters, `fe val`, `tria h` | 1.5 - 1.8 ms | 5.8 - 10.3 ms | <= 20 ms |

Static items beside the files: 4330 commands (listed in 8.7 ms), 0 bookmarks (none
saved), 4 buffers, 0 recent files (a script bug, see Gotchas; the owner has 42, which
adds about 0.1 % to the items).

`workspace/symbol` on RMO (patched clangd):
| Query | at once | after 20 s |
|---|---|---|
| `Tri` | 0 | 100 symbols, 16.3 ms |
| `Triangulation` | 0 | 79, 3.9 ms |
| `vec` | 0 | 100, 11.3 ms |
| `main` | 0 | 100, 5.9 ms |
| `assemble` | 0 | 33, 2.4 ms |
| `Sol` | 0 | 100, 5.5 ms |
| `SolutionTransfer` | 0 | 0, 1.1 ms |
Median after 20 s: 5.5 ms. eglot managed `src/main.cc` 516 ms after the open.

## Findings
1. Opening is cheap: listing deal.II's 34602 files takes 66 ms, no cache needed.
2. Cost grows with hits, not items: `m` over deal.II matches 24881 of 38936 items
   (31.8 ms); `mai` matches 166 (6.2 ms). Only the first key over a deal.II-sized
   tree misses the criterion; RMO's files pass at every input.
3. Symbols come from the index in milliseconds, but not in the first moments after
   eglot connects: every query returned 0 until the stored index had loaded (20 s
   later all answered; when in between is not measured; O-21 measured 0.4 s for
   loading RMO's 3950 shards).
4. clangd's 100-symbol cap is reached by three-letter queries (`Tri`, `vec`, `Sol`);
   longer queries stay below it.
5. deal.II's own classes are not in RMO's index (`SolutionTransfer`: 0); only names
   RMO's code declares. Library symbols wait on the deal.II sources index (O-12, S10).

## Not measured
- vertico's sort and display of the hits (it sorts the 24881 hits of `m` too); the
  whole prompt is checked by hand in T-049.
- Typing while clangd builds a preamble.

## Decision
Owner rules O-32 (how to handle finding 2). T-049's done-when follows.

## Gotchas
- Run 1's script looked for `~/.emacs.d/recentf`; Emacs 31 saves `recentf.eld`
  (and bookmarks to `bookmarks.eld`). Fixed after the run (the names now come from
  `recentf-save-file` and `bookmark-default-file`), checked on the toy.
