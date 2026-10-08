# 0023 - T-008: performance baseline, startup GC

- **Date:** 2026-10-08
- **Commits:** see `git log -- early-init.el scripts/measure-startup.sh`
- **Tier:** 2
- **Decisions:** D-038 (new); `read-process-output-max` 4 MB REJECTED
- **Done when:** numbers are in DESIGN 11 and each tuning setting cites one (TASKS,
  agreed 2026-10-07).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
DESIGN 11 set a startup budget of 0.5 s but had only numbers taken on a loaded
machine, and it proposed two tuning settings nobody had measured. On an idle
machine the v0.2.0 configuration starts in 0.355 s, and 0.22 s of that is spent in 22
garbage collections. Letting Emacs allocate 64 MB between collections during startup
leaves a single one: 0.151 s. After startup Emacs's default threshold comes back,
because a larger one gained nothing measurable on a large language-server reply. The
other proposal, reading process output in 4 MB chunks, made no difference and is not
adopted.

## Concepts explained
- **Garbage collection threshold:** Emacs collects unused memory each time
  `gc-cons-threshold` bytes (default 800 KB) have been allocated, or a share of the
  heap (`gc-cons-percentage`, 10 %), whichever is larger. Loading 28 packages
  allocates many megabytes, so the default meant 22 pauses. After startup the heap is
  large, the 10 % share dominates, and the threshold matters little (2 versus 1
  collections over ten 5001-symbol replies).
- **Why restore it:** a high threshold for the whole session makes each collection
  rarer but no cheaper; nothing measured asked for it (principle 7).
- **`emacs-startup-hook`:** runs once after init files, `after-init-hook` and the
  command line; the restore runs last there (depth 100).

## Key files walked
- `early-init.el` - sets 64 MB before anything loads, restores the saved value.
- `scripts/measure-startup.sh` - starts `emacs -nw` in a detached tmux session with a
  throwaway HOME (only the two symlinks), first waiting out native compilation, then
  records time to the end of `after-init-hook`, collections and their seconds; an
  optional Lisp line in front of early-init.el measures a variant.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the terminal start stands for the owner's graphical one; a frame's
  setup adds a fixed cost the threshold does not change. **Would break if:** the GUI
  start allocates much more; rerun the script's measurement in a GUI.
- **Assumed:** a 5000-function `documentSymbol` reply stands for large LSP replies
  (references on deal.II names). **Would break if:** RMO shows stalls on such replies;
  measure there with real data (owner).
- **Not measured:** typing lag (the owner reports none), `eglot-sync-connect`.

## How to verify
`sh scripts/measure-startup.sh 10` on an idle machine: median about 0.15 s, 1
collection; `sh scripts/measure-startup.sh 10 '(setq gc-cons-threshold 800000)'` is
not the old setup (early-init.el runs after the line and raises it again); for the
old number check out `v0.2.0`.
