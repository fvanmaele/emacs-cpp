# 0007 - S5 run 1: warm-up is tenfold faster, but FAIL

- **Date:** 2026-10-08
- **Commits:** see `git log -- spikes/s5-preamble-warmup` (committed with this)
- **Tier:** 3 (spike S5)
- **Decisions:** none yet (Q-5 open)
- **Done when:** RESULTS.md carries a verdict for run 1 and run 2 is ready
- **Tag:** none

> Plain English. No configuration code changed; this records a measurement.

## What + why
clangd answers `M-.` and rename in a file only after parsing everything the file
includes ("preamble"); for RMO that is about 11 s per file and cannot be cached across
sessions. CLion hides this by analysing files ahead of time. S5 measured the Emacs
equivalent on a copy of RMO: open all project sources in the background first. The
first `M-.` dropped from 10.9 s to 1.1 s, at 4.8 GB more clangd memory and a 40 s
background warm-up. The spike's criterion (under 0.5 s, within a budget) was not met.
The run was skewed by an empty index and a busy machine, so run 2 repeats it with the
index persisted and adds a 3-source variant.

The owner also asked about clangd's background index and about putting source files in
the compile database. Both are already in place: the index is on and persisted, and
the sources are in the database. Neither removes the per-file parse (DESIGN 11).

## Concepts explained
- **Preamble vs index:** the index is a persisted list of where every symbol is
  declared, defined and used. The preamble is the parsed form of one file's includes,
  needed to know which symbol is under the cursor. The first can be cached on disk;
  clangd keeps the second only while the file is open.

## Key files walked
- `spikes/s5-preamble-warmup/warmup.el` - opens files through the shipped config's hook
  path, waits for clangd with `documentSymbol`, times `M-.`, reads clangd's RSS.
- `spikes/s5-preamble-warmup/RESULTS.md` - numbers and caveats.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** most of run 1's memory and the remaining 1.1 s come from the concurrent
  background indexing of an empty index. **Would break if:** run 2 (persisted index)
  shows similar numbers. **DESIGN bet:** none yet.
- **Risk:** the owner's simulations and clangd compete for 31 GB RAM; warm-up of all
  sources may not fit (Q-5).
- **Incident:** the run 2 dry run overwrote the owner's `results.log`; restored from
  the owner's paste, and `run.sh` now refuses to overwrite.

## How to verify
Read `spikes/s5-preamble-warmup/RESULTS.md`; run 2 per `RUN.md`.

## Open questions
Q-5 (RAM budget for clangd) in the DESIGN ledger.
