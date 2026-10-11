# 0048 - S11 run 1: a go-to-anything prompt is cheap but for one letter over deal.II

- **Date:** 2026-10-11
- **Commits:** see `git log -- spikes/s11-go-to-anything`
- **Tier:** 3 (spike S11)
- **Decisions:** D-074 (measured first); O-32 opened
- **Done when:** RUN.md pass criteria (file listing <= 100 ms, filtering <= 20 ms per
  input, symbols median <= 100 ms and each <= 300 ms)
- **Tag:** none

> Plain English summary of the spike result.

## What + why
D-074 chose one prompt that lists buffers, project files, recent files, bookmarks,
clangd symbols and commands, and the owner asked for numbers before code. The spike
measured each part on RMO and on the deal.II checkout. Listing every file of a project
when the prompt opens is fast even for deal.II (66 ms for 34602 files). clangd answers
a symbol search from its index in a few milliseconds. The one slow spot is the first
letter typed in a deal.II-sized project: about 25000 of 39000 entries match, and
marking every match costs 32 ms, over the 20 ms limit. From the second letter on it is
13 ms or less, and in RMO every input stays under 7 ms. Details:
`spikes/s11-go-to-anything/RESULTS.md`.

## Concepts explained
- **Static and async sources:** a static source hands consult its whole list once (files,
  buffers); an async source is asked again for every input (clangd's symbols). Once one
  source is async, consult filters the static lists itself at every key, with its own
  word regexps instead of orderless. That is the per-key cost measured here.
- **Why one letter costs most:** the time goes into the matches (each is copied and
  highlighted), so a letter that matches most entries is the worst case and every
  further letter makes it cheaper.
- **Index loading:** clangd reads its stored index shortly after it starts; until then a
  symbol search returns nothing, without an error.

## Key files walked
- `spikes/s11-go-to-anything/measure.el` - `filter` repeats what consult's
  `consult--async-static` does per input; `symbol-round` sends `workspace/symbol`.
- `spikes/s11-go-to-anything/run.sh` - runs it with the shipped config on the project
  in place; writes only `results.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the measured `filter` is the per-key cost of the real prompt. **Would
  break if:** vertico's sorting of the hits adds as much again (not measured; T-049's
  hand check). **DESIGN bet:** D-074.
- **Assumed:** RMO and deal.II stand for the owner's projects. **Would break if:** a
  project with many git submodules: projectile lists each separately (dry run: 742 ms
  for this repository's 30).
- **Risk:** in the first moments after a start the symbol part of the prompt is empty
  without saying why.

## How to verify
`spikes/s11-go-to-anything/results-run1.log`; rerun with the command in RUN.md (move
the log away first).

## Open questions
O-32 (one-letter filtering over a deal.II-sized tree), O-31 (the key).
