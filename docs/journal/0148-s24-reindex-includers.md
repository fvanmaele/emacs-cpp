# 0148 - S24: reindex every includer of a stale file

- **Date:** 2026-11-23
- **Commits:** this entry's commit (spike files; criteria committed before the runs in
  2d8ace5)
- **Tier:** 3 (spike S24: PASS, criteria 1 - 3; criterion 4 recorded)
- **Decisions:** D-218; O-97 opened
- **Done when:** S24's RUN.md criteria

> Plain English for a reader who does not read C++ fluently.

## What + why
At startup clangd checks each stored file against the disk. For a changed header it
queues one source file for reindexing: the first whose include walk reached the header.
Every other source including that header keeps its old stored index and, with
navigation from the index, answers from it. Upstream knows this (clangd/clangd#1104; a
draft fix, llvm-project PR #140651, stalled on exactly this cost question).

The prototype turns the stored include edges around ("who includes this file?") and
walks from each changed file up to every source file that reaches it, then queues them
all. On a 1000-source test project the walk takes 8 ms. It fixes the stale answers
(criterion 1). Its price shows when a header that every source includes changes: all
1000 are reindexed, about as long as indexing the project the first time (6 minutes
here), and while that runs those files answer through the slower full parse.

## Concepts (C++) explained
- `llvm::StringMap<size_t>`: a hash map from a path to its position in the loaded list,
  used to turn include names into graph nodes.
- A reverse graph walk with a work list (`std::vector` as a stack) and a `Seen` flag
  per node: each file is visited once, so the cost is linear in files plus edges.

## Key files walked
- `spikes/s24-reindex-includers/prototype.patch` - the walk in `loadProject` (spike
  code, not to be promoted; T-164 writes it fresh).
- `spikes/s24-reindex-includers/many.py` - the correctness and cost driver.

## Assumptions + risks
- **Assumed:** each stored source shard's include edges are complete (they are its
  direct includes from its last indexing). **Would break if:** a header included under
  an `#ifdef` that the indexed command did not take; then a TU is missed until its own
  reindex, as today.
- **Assumed:** the test project stands for a real one in graph shape. A deal.II TU has
  about 2700 stored files, mostly shared; the walk stays linear.
- **Risk:** a common-header change makes the index path decline for minutes in every
  includer. O-97 asks whether to cap it.

## How to verify
```
cd spikes/s24-reindex-includers
python3 -I many.py correct proto <clangd with prototype.patch> work </dev/null
python3 -I many.py cost proto <clangd with prototype.patch> work 1000 </dev/null
```
