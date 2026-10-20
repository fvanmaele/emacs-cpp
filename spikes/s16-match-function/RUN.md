# S16 - D-120's tiers as a function

## Risk
D-124 (owner 2026-10-20, review 0084 section 3: "C, spike first"): D-120's tiers are
three regexps per input word built from one word-start rule spelled three times
(`lisp/init-completion.el`, `emacs-cpp--match-compile`). Question: does the same rule
as a function (`string-search` on the lower-case candidate, word starts tested on the
original, one pass for initials) give the regexps' tier for every candidate, keep the
spec rows, and sort a prompt's candidates no slower, and in which compilation state?
Spike code is never promoted; a PASS leads to the function written fresh in
`lisp/init-completion.el`, with D-125 (S17).

## What the spike builds
`s16.el`: the function (`s16-word-start-p`, `s16-word-tier`, `s16-match-tier`,
`s16-sort`) and, as the baseline, the six shipped definitions read from
`lisp/init-completion.el`. For one compilation state (interp, byte, native, both
matchers alike) it checks (1) the 15 rows and the sort example of
`init-completion-match-tiers`, (2) the tier of both matchers for 8 inputs (`vec`,
`tria`, `fe`, `vt`, `dofh`, `fe q`, `grid in`, `sparsematrix`) over every name of a
tree, and (3) times the sort, best of 5 after a warm-up, over all names (review
0084's method) and over the names orderless's letters-in-order filter lets through
(what a prompt sorts). `run.sh` runs the three states in three processes.

## Pass criteria (proposed 2026-10-20; owner to confirm)
On the deal.II tree (a git checkout; about 34000 names), Arch, idle:
1. Spec: 0 failures, in every state.
2. Agreement: 0 pairs where the function's tier differs from the regexps', in every
   state.
3. Speed: in the state `lisp/` ships in (byte or native if D-125 passes S17,
   interpreted otherwise), the function's sort of each filtered set takes no longer
   than the regexps', and at most D-120's 89 ms for the largest.

## Prerequisites
Emacs 31.1 with native compilation; a deal.II checkout (any recent release).

## Commands (owner, Arch)
```sh
cd ~/source/repos/emacs-cpp
sh spikes/s16-match-function/run.sh ~/source/repos/dealii
```
The log is `spikes/s16-match-function/s16.log`; results go to `RESULTS.md`
(`DRY-RUN.md` holds the Mac dry run).
