# 0096 - T-122: gaps inside a word; `M-o` matches file names

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-122"`
- **Tier:** 2
- **Decisions:** D-141 (built), D-120 (its tier 3 now also the filter)
- **Done when:** T-122's four items (TASKS.md, agreed by the owner 2026-10-21)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner saw `ect` in `M-o` match `~/source/repos/RMO-gross-pitaevskii/include/rmo/
gpe/metric.h`: the `e` of `source`, the `c` of `include`, the `t` of `metric`.
orderless's `orderless-flex` let a match's gaps run anywhere, across words and `/`,
although D-120 defines its loosest tier as gaps inside a word; recent files carry
the whole path, so almost every one matched (`met`: 420 of 437 RMO files). D-141
fixes both: gaps stay inside a word in every prompt, and in `M-o` a word matches the
file name, as CLion's Go to File does (IntelliJ's `GotoFileItemProvider` splits the
input at its last `/`).

## Concepts (Emacs Lisp) explained
- **An orderless matching style** is a function from a typed word to a regexp
  (written as an `rx` form). `emacs-cpp-orderless-in-word` puts `(zero-or-more alnum)`
  between the letters where `orderless-flex` put "anything but the next letter"; its
  `group`s mark the letters for highlighting.
- **Anchoring a match to the file name.** `M-o` builds each word's regexp itself:
  the word's match, then `[^/]*\'`, so the match must end in the last path
  component; none of its styles crosses `/`, so it lies wholly in the file name.
  The word's match is group 99, so the highlighter can show it when no letter groups
  exist (a literal match).
- **Backtracking.** A first version of the `dir/name` regexp nested `\(?:[^/]*/\)*`
  and took 103 ms a key on 8804 paths; `\(?:.*/\)?` between the parts takes 10.6 ms.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-orderless-in-word` (NEW) in
  `orderless-matching-styles`; `emacs-cpp--match-compile`'s fourth regexp and tier 3
  of `emacs-cpp-match-tier` (a candidate only a typed regexp matches is tier 4).
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--word-regexp`,
  `emacs-cpp-go--initialism` (initials that never cross `/`), `emacs-cpp-go--highlight`.
- `test/init-go-to-anything-test.el` - `init-go-to-anything-file-names`,
  `init-go-to-anything-gaps-inside-a-word` (NEW).

## Results
Batch, Arch, RMO's projectile list (4402 files) and the same as abbreviated absolute
paths (the recent-file worst case), 10 runs per input:

| input | matches before (project / recent) | after (both) | ms per key before / after |
|---|---|---|---|
| `ect` | 701 / 4402 | 33 | 15.4 / 14.0 |
| `met` | 2899 / 4402 | 33 | 10.1 / 13.3 |
| `gpe` | 1178 / 4402 | 1 | 43.0 / 10.5 |
| `rmo` | 3172 / 4402 | 0 | 6.8 / 22.9 |
| `gpe/met` | 39 / 2899 | 1 | 57.0 / 10.6 |
| `e` | 4297 / 4402 | 3417 | 1.2 / 16.4 |

All under S11's 100 ms for a key's first screen. `make test` 149 of 149; startup
0.182 s, as before.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** words typed in `M-o` name files, as in CLion. **Would break if:** the
  owner types a directory's name alone and expects its files (`gpe`): it now needs
  `gpe/`. **DESIGN bet:** D-141.
- **Assumed:** gaps across words were noise, not a habit. **Would break if:** inputs
  like `vtcc` for VectorTools.cc were in use: initials still work (`vt`), letters
  spread over several words without being their initials no longer match.
- **Assumed:** a typed regexp in `M-o` is rare; it is still allowed and may match
  across `/` inside its own pattern.
- One-letter inputs cost more (1.2 -> 16.4 ms): the end anchor is tried after every
  hit of the letter. Under the budget; symbols start at the third letter anyway.
  CORRECTED 2026-10-21 (RESEARCH_go_to_anything 21): that bench filtered all 4402
  paths twice and timed the filter alone; with 200 recent files a one-letter key went
  from about 23 to 25 ms, most of it the tier sort, as before.

## How to verify
- `make test </dev/null` - 149 tests on Arch.
- In Emacs, a project: `M-o ect` no longer lists every recent file; `M-o gpe/met`
  finds `include/rmo/gpe/metric.h`.
