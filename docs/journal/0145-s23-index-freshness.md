# 0145 - S23: stale answers from index navigation, and what a check costs

- **Date:** 2026-11-23 (runs 2026-11-22)
- **Commits:** this entry's commit (spike files only, no code)
- **Tier:** 3 (spike S23: FAIL against D-026's premise, a criterion set after the runs;
  cost recorded, not judged)
- **Decisions:** none; O-95 opened for the owner
- **Done when:** not set (owner asked to measure the cheap fixes and weigh cost against
  benefit, 2026-11-22)

> Plain English. The patched clangd answers go-to-definition and find-references from a
> stored index file ("shard") instead of parsing the file, which is ten times faster.
> This entry asks when that stored answer is wrong, and what it costs to notice.

## What + why
Patches 0001 - 0004 and 0014 - 0017 (D-026) answer `M-.` / `M-?` from the open file's
shard when the file's own content still matches it. The owner asked when that loses
accuracy, then to measure the cheap fixes. Three parts ran in parallel (owner asked for
background agents): a code reading of clangd's freshness state, a live reproduction of
each suspected case against three servers (patched with the flag, patched without,
MacPorts' unpatched 23.1.5), and a cost measurement over deal.II's include closures.

Findings (details in `spikes/s23-index-freshness/RESULTS.md` and `reproduce/RESULTS.md`):
- Case 1a, a header changed on disk while the main file did not: reproduced, a
  regression. The index answered the removed `f(int)` and the old `A::run`; both other
  servers were right. It stays wrong after the reindex: the reindex writes only shards
  whose digest changed, so main.cpp's shard is never rewritten.
- Case 3, a header opened directly after a `-D` change: reproduced, a regression. The
  answer came from the inactive `#ifdef` branch. Header shards store no command, so
  0017's check always passes.
- Case 2, a definition moved in another file, and unsaved header edits: wrong in stock
  clangd too (inherited).
- clangd never reindexes during a session: `ClangdServer::onFileEvent` is an empty
  FIXME upstream; stale files are queued only when shards load.
- A shard records only its direct includes, without their digests, so "check every
  included header" needs new stored data.
- Cost, Mac, warm cache, G DATA's scan on: open + read + hash of 2629 - 3902 files
  3.4 - 15.1 s per request (2.4 - 3 ms per open, also at load 3); `stat` only 2.6 -
  15.4 ms; hashing from memory 0.7 - 4.4 ms. The open is the cost, likely the scanner
  (UNVERIFIED without a run with the scan off).

## Concepts explained
- **Shard:** one stored index file per source or header under `.cache/clangd/index`,
  with symbols, references, the file's digest and its direct includes.
- **Digest:** an xxh3 hash of the file's content (`SourceCode.cpp`), used to tell
  whether the stored data still describes the file.
- **Include closure:** every header a source file pulls in, directly or not; for a
  deal.II example about 3000 files.

## Key files walked
- `spikes/s23-index-freshness/measure-cost/closurecost.c` - times hash / open / stat /
  in-memory hash over a list of files.
- `spikes/s23-index-freshness/reproduce/freshness.py` - builds each case's project and
  drives clangd over LSP through three sessions (index, change, restart).

## Assumptions + risks
- **Assumed:** the Mac's open cost comes from the on-access scanner, not the machine.
  **Would break if:** a run with the scan off still shows ms per open; then (c) in O-95
  is dearer than measured. **DESIGN bet:** O-95.
- **Assumed:** the hand-made projects stand for real ones. **Would break if:** real
  headers change in ways the cases do not cover (templates, generated headers).
- **Assumed:** stock clangd's behavior is the bar ("regression" means worse than stock).

## How to verify
```
cd spikes/s23-index-freshness/measure-cost && sh run.sh > results.log 2>&1 </dev/null
cd spikes/s23-index-freshness/reproduce && sh run.sh </dev/null
```
Arch and a Mac run with the scan off are the owner's, after the ruling on O-95.

## Open questions
O-95 (which fixes). The cost agent stopped on an API error before writing its table; the
session filled the table from its log and ran the split rerun (run 3).

## Standard feedback
- Never applied: rule 31, no tool was chosen; only the own patches were measured.
