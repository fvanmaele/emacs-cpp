# 0086 - llm_vibecoding_standard 2.14.0; O-70 and O-71 revisited

- **Date:** 2026-10-20
- **Commits:** see `git log -1 --grep "standard 2.14.0"`
- **Tier:** 1 (process and docs; no code)
- **Decisions:** none; O-70 and O-71 rewritten for the owner's ruling
- **Done when:** `make docs-check` of 2.14.0 passes; the template text merged; every owner
  run is an `H-n` item; O-70 and O-71 state options with their cases against
- **Tag:** none

> Plain English record of a process upgrade and two revisited questions.

## What + why
The owner asked to upgrade to the latest llm_vibecoding_standard (1.0.0 -> 2.14.0) and to
revisit O-70 and O-71 with a new goal: "on both Mac and Arch, watches should work on very
large projects, which was the initial point of fswatch". The upgrade followed the
standard's own `templates/handoff-upgrade.md`:
- `make -C <standard> upgrade DEST=<this repo>` replaced `standard.mk`,
  `scripts/check-standard.sh` and added `scripts/commit-msg.sh`; its stamp step failed on
  macOS's BSD sed while the target still said "stamp bumped", so the `Standard:` line was
  bumped by hand (handoff `emacs-cpp_handoff.md` left in the standard's checkout).
- `check` is now `docs-check` (docs only); its default width is 128, this repository keeps
  92 (`STANDARD_WIDTH = 92` in the Makefile). References in CLAUDE.md, README, HANDOFF and
  DESIGN's conventions renamed.
- The new check fails a spike with RUN.md and no RESULTS.md unless spikes/README says
  `ready`: S7, S10, S16, S17 are `ready` (the owner's runs).
- CLAUDE.md merged with the 2.14.0 template, keeping this repository's rules (the
  use-package rule, D-058 and D-104 for tests, the ccls reason): a handoff step at session
  start, a Self-test, plan checklists with estimates, real-data work as a conversation,
  `TODO_human.md` as the owner's queue, sibling handoffs, options with their cases
  against, two postmortem sizes, no first-person authorship, STATUS.md never tracked, no
  kill by name, the longer close block, compact instructions. Where the template's reason
  was the standard owner's own incident, the rule cites the standard instead of claiming
  it here.
- `TODO_human.md` (NEW): H-1 .. H-7 to run (Arch clangd, S16, the review's bench, the
  Mac's clangd and fswatch rebuilds, S10, four Emacs bug reports), H-8 parked (the
  deferred upstream sends), H-9 .. H-11 to decide (O-70, O-71, removing `lib/eglot/`).
- POSTMORTEM's two sizes, the journal template's `Standard feedback`, TASKS' source column,
  spikes/README's status words.
- Steps 5 - 7 of the handoff: no dependency manifest, no STATUS.md, and no class D-row
  (the owner keeps this repository's class).

Run here on the Mac (the new rule: the session runs what it can reach): the patched
fswatch's `check.sh` passes 7 of 7 on the installed binary, which is pkgrel 1; the
rebuild at pkgrel 2 downloads and is H-5. The Mac's clangd predates patch 0013 (H-4).

## Concepts explained
- `sed -i` differs: GNU sed takes `-i` alone, BSD sed (macOS) needs `-i ''`; a script
  meant for both writes to a temporary file and moves it.

## Key files walked
- `CLAUDE.md` - the merged rules; `TODO_human.md` - the owner's queue.
- `DESIGN.md` O-70, O-71 - the revisited options.

## O-70 and O-71, revisited
- O-70: with the owner's goal on both machines, (b) an fswatch backend over the built-in
  eglot on both is recommended, spike S18 first; the premises were checked in the
  sources: the Mac's 975-watch kqueue ceiling and 500 cap (`lisp/init-lsp.el:59`),
  Arch's 10000 cap after which the built-in eglot fails the registration and pyright
  exits, fswatch's inotify monitor reporting `IN_Q_OVERFLOW` and watching new
  directories (`inotify_monitor.cpp:443`, `:369`). The review's "park fswatch on a
  branch" is withdrawn with the goal. Not ruled.
- O-71: (c) recompile a stale module at startup, its failure stopping startup as (a)
  would, recommended and to be checked in S17 run 2. Not ruled.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 2.14.0's rules fit a one-owner repository with two machines. **Would break
  if:** the plan-checklist rule's overhead outweighs small sessions; the feedback below
  says so first.
- **Assumed:** the kernel's default `max_user_watches` on the owner's Arch machine is near
  318000 (31 GB). **Would break if:** `/etc/sysctl.d` lowers it; O-70 (b) then binds there
  too. UNVERIFIED until the owner's `sysctl fs.inotify.max_user_watches`.

## How to verify
`make docs-check` (ok, three notes on spikes whose RUN.md holds commands from before the
rule); `make test` unaffected (no code changed).

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: the upgrade handoff's steps, followed in order, made the merge mechanical.
- Hurt: `make upgrade` on macOS: the stamp step fails under BSD sed and the target reports
  success (handoff left in the standard's checkout).
- Hurt: the default width moved from 92 to 128 silently for an adopter that relied on the
  old check's 92; `STANDARD_WIDTH` restores it, but nothing in the upgrade said so.
- Never applied yet: the plan-checklist rule (no plan file this session).

## Addendum, the same day: rulings and Mac rebuilds
- Owner: "O-70 (b) agree, O-71 (c) agree. Rebuild clangd and fswatch". O-70 resolved
  as D-127 (fswatch backend on both machines, spike S18 first, T-116); O-71 as D-128
  (stale modules recompiled at startup, with D-125, checked in S17 run 2).
- fswatch rebuilt at pkgrel 2 (`packaging/fswatch-no-loss/build-macos.sh`), `check.sh`
  7 of 7: T-098 done on both machines.
- clangd rebuilt (`packaging/clangd-index-nav/build-macos.sh`): patches 0001 - 0013 on
  23.1.3, both hidden flags; `EMACS_CPP_PATCHED_CLANGD=~/opt/clangd-index-nav/bin/clangd
  make test`: 135 tests, 133 passed, 2 skipped (the gdb tests, no gdb on the Mac).
  T-108's Mac half done; the Arch install is H-1.
