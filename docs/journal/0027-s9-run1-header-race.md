# 0027 - S9 run 1: PASS, header opened first races the index handover

- **Date:** 2026-10-08
- **Commits:** see `git log -- spikes/s9-header-first-flags`
- **Tier:** 3 (spike S9)
- **Decisions:** none yet (O-21 stays open for patch 0006)
- **Done when:** RUN.md verdict criteria (a header-first session gets the guess with
  its decision at or before "Enqueueing", no source-first session does)
- **Tag:** none

> Plain English summary of the spike result.

## What + why
The owner saw "too many errors" in a header opened first after a restart. D-028's
patch should give such a header the flags of a source file that includes it. The
spike opened RMO's `iteration.h` first in 10 fresh sessions and `main.cc` first in 10
others. Header first: all 10 got the wrong, guessed flags; source first: all 10 got
the right ones. clangd's log shows why: the header asks for its flags in the same
millisecond in which the project is handed to the index, just before it, so the
patch finds the index not loading yet and does not wait. Details:
`spikes/s9-header-first-flags/RESULTS.md`.

## Concepts explained
- **Broadcast thread:** when clangd finds `compile_commands.json`, it tells the other
  parts (the background index among them) from a separate thread. The header's own
  request does not wait for that message.
- **The load counter:** patch 0005 waits while the index is loading, and counts loads
  from the moment the index receives the project. Before that message the count is 0,
  so "not loading" and "not started yet" look the same.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO's 10 / 10 stands for the owner's daily start; the toy showed 1 / 5,
  so timing matters, but on RMO the order was the same every time.
- **Risk:** the fix makes a header opened first wait about 0.4 s longer (the load).

## How to verify
`spikes/s9-header-first-flags/results-run1.log`.

## Open questions
O-21: patch 0006's done-when (owner).
