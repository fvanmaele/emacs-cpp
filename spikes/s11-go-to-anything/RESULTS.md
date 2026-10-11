# S11 - go to anything: results

Verdict: PASS (run 2, 2026-10-11). The whole prompt with D-077's settings on RMO in a
terminal Emacs, patched clangd: opening 89 - 96 ms (criterion 150), every key's
results 6 - 24 ms (100), symbols on screen 122 - 150 ms after the key (200), no
garbage collection while typing. Run 3 (the shipped command, T-049): PASS on the
same criteria. Run 1 below.

## Run 3 (2026-10-11 16:04, load 5.46 at start, 6.47 after: not idle)
Raw output: `results-run3.log`. `S11_SHIPPED=1`: `M-o` runs the shipped
`emacs-cpp-go-to-anything`, RMO pass only; 10 openings, 42 keys.
| | Run 3, shipped | Run 2, spike copy | Criterion |
|---|---|---|---|
| files listed at opening | 2673, 42 - 60 ms | 2767, 66 - 74 ms | |
| opening, first screen | 54 - 74 ms | 89 - 96 ms | <= 150 ms |
| key to its results (median) | 2 - 30 ms (18) | 6 - 24 ms (20) | <= 100 ms |
| symbols on screen after third key | 122 - 150 ms | 122 - 150 ms | <= 200 ms |
| collections while typing | 0 | 0 | |
No input started with `#` (D-078). The shipped command does not log clangd's replies;
symbols on screen is the first update after the third key whose count grew. For
longer inputs the count only shrinks, so the arrival of their new symbols is not
visible in this log. The file count differs from run 2 (2673 against 2767, 20
minutes apart); not investigated.

## Run 2 (2026-10-11 15:48, load 2.38 at start, 1.46 after)
Raw output: `results-run2.log`. `prompt.sh`: two passes, each a fresh `emacs -nw`
in tmux; 10 openings per pass (`main`, `vec`, `Tri`, `assemble`, `Sol`, twice), 42
keys, one per 300 ms. Summary by a parser of the log (scratch, not kept).
| | RMO's files | deal.II's files (recorded) | Criterion |
|---|---|---|---|
| files listed at opening | 2767, 66 - 74 ms | 34602, 50 - 172 ms | |
| opening, first screen | 89 - 96 ms | 86 - 178 ms | <= 150 ms |
| key to its results (median) | 6 - 24 ms (20) | 20 - 139 ms (34) | <= 100 ms |
| collections while typing | 0 | 3 (49 - 64 ms each) | |
| symbols on screen after key | 122 - 150 ms | 129 - 171 ms | <= 200 ms |
| clangd reply after request | 4.4 - 20.5 ms | 3.5 - 19.9 ms | |
The first screen after each key already showed that key's results (the count did
not change before the symbols arrived). deal.II's three slowest keys were the first
letters `a` (139 ms), `m` (118 ms), `v` (94 ms), each with a collection.

### Findings (run 2)
1. D-077's settings hold on RMO with the real clangd: every key well inside the
   criteria, the slowest part is the 0.05 s refresh and throttle (by design).
2. clangd's 100-symbol cap is reached up to `asse`; from `assem` it lists 49 or
   fewer.
3. In the deal.II pass, 6 of 10 openings listed the files twice (16 listings, 10
   openings; RMO: 10 / 10). consult computes a static source inside
   `while-no-input` and, when interrupted, computes again 0.2 s later
   (`consult--async-dynamic`); with 34602 files the listing and formatting take long
   enough to be interrupted. What interrupted it is not known (no key was sent
   then). The second listing took 154 - 172 ms. Listing the files before
   `consult--multi`, outside that machinery, avoids the repeat.
4. With 34602 files the 64 MB threshold was reached on 3 of 10 first letters: a
   collection inside the prompt, 49 - 64 ms.

## Run 1

Run 1 result: FAIL in one part (2026-10-11). Filtering a one-letter input over the
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
Run 1: O-32 -> D-075 (accepted). Run 2: D-077's settings confirmed; T-049's
done-when reuses run 2's criteria. Run 3: the shipped command meets them (0051).

## Gotchas
- Run 1's script looked for `~/.emacs.d/recentf`; Emacs 31 saves `recentf.eld`
  (and bookmarks to `bookmarks.eld`). Fixed after the run (the names now come from
  `recentf-save-file` and `bookmark-default-file`), checked on the toy.
