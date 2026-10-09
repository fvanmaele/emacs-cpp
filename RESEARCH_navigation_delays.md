# RESEARCH - delays on M-. for names (owner question 2026-10-09)

Findings only; verdicts go to DESIGN (O-27). Measured on the owner's Mac (MacPorts
Emacs 31.1, the patched clangd 23.1.1 from `~/opt/clangd-index-nav`, the owner's
`CLionProjects/step-1` (RMO) with preset `mac-debug` and its stored index of 4538
shards), batch Emacs with the shipped config, 2026-10-09, load 6 - 7.

## 1. Where an M-. spends its time
Ten names in `src/main.cc` (project functions and types, deal.II `Vector`,
`std::visit`, `std::string`, `fmt::format`, `po::store`), split into the server's
answer and Emacs visiting the target file:

| Moment | Server | Visiting the target |
|---|---|---|
| first M-. right after a restart | 9.5 s (stock clangd: 11.6 s) | 0.1 - 0.2 s |
| further names, same file | 5 - 55 ms | 0.1 - 0.25 s each new file |
| after the file was parsed | 1 - 50 ms (one 0.4 - 1.0 s outlier) | 0.04 - 0.25 s |
| target already open | 0 - 2 ms | 0 ms |

So the long delays are the first M-. in a file, when the server waits for clangd's
parse (deal.II's preamble: 21.6 s in `clangd --check`, 7 - 13 s in a session). The
patched clangd should answer that first M-. from the stored index instead.

## 2. Why the patched clangd fell back to the parse
Its verbose log (`CLANGD_FLAGS=--log=verbose`) names the reason per file. First M-.
after a restart, one session per source file (all 11 sources of `mac-debug`):

| Reason | Sources | First M-. |
|---|---|---|
| from the index | `main.cc` (rebuilt), `operator`, `arpack`, `main_m_matrix` | 4 ms-2.9 s |
| with errors | `main_bench`, `main_coarse`, `energy`, `gradient`, `lumping` | 7.4-12.6 s |
| file changed since | `main_sparsity`, `m_matrix` (being edited) | parse |

`main.cc` itself was in the first group too (9.5 s); after its shard was deleted and
rebuilt by clangd, its first M-. took 2.8 s, then 4 - 19 ms. `clangd --check` finds no
compile error in any of the five "with errors" files today.

Mechanism, from clangd 23.1.1's `index/Background.cpp`:
- The background indexer sets a shard's `HadErrors` flag when the translation unit
  had errors (`Clang->hasDiagnostics()` with errors) at indexing time; patch 0004
  then refuses to answer from that shard (its references may be incomplete).
- At startup clangd re-indexes only stale shards (`shardIsStale`: content digest of a
  file differs from disk), and for a stale header only the one source chosen as its
  `DependentTU`. A flag alone never triggers re-indexing; a re-index that happens for
  other reasons replaces a flagged shard (`HadErrors && !HadErrors`).
- A header that did not exist at indexing time ("file not found" is the error) is not
  in the include graph, so creating it later makes nothing stale. Here: the shards were
  written 18:39 - 18:41 while the owner edited the project; `include/rmo/fe/util.h`
  (new in the working tree, reached from `main.cc` through `gpe/model.h` and
  `gpe/gpe.h`) is one such case. A session of 240 s did not rewrite `main.cc`'s shard.

So a file indexed once while the code did not compile can keep the slow first M-.
across restarts, although it compiles now.

## 3. Emacs's own share when it opens the target
Per new target file 0.04 - 0.25 s. Measured on two headers (`gpe/model.h`, 104
lines: 172 ms; `fmt/format.h`, 4407 lines: 145 ms): `vc-refresh-state` on
`find-file-hook` 70 - 73 ms (git subprocesses; process start is slow on this Mac, see
DESIGN 11 on the antivirus), `c++-ts-mode` setup 48 - 88 ms; every mode-hook function
of this config under 2 ms (breadcrumb, dape's breakpoint mode, eglot's activation).

## 4. What heals a flag by itself (checked in clangd 23.1.1, owner questions)
- Inside a session clangd never re-runs the background indexer for an edit: a save
  only re-parses open files (`onDocumentDidSave`), file events are ignored
  (`onFileEvent`: "Do nothing for now"); new work is queued only when compile commands
  change (`CDB.watch` -> `enqueue`). Open files are answered from the in-memory index
  meanwhile, so the flag matters at the first M-. after the next restart.
- At the next start a source is re-indexed if its own content changed (its digest), or
  if it is the one `DependentTU` chosen for a header whose content changed. So:
  editing the flagged source itself heals its flag at the next start; fixing the
  header that broke it heals only one of the sources including it; creating a missing
  header heals none. Here the five flagged sources were untouched; their errors came
  from headers being edited or not existing yet.
- One clangd serves the whole project; eglot stops it when the last buffer of the
  project closes (`eglot-autoshutdown` t, T-004) and on a preset switch. The per-file
  restarts in section 2 came from the measurement closing each file before the next.

## 5. Options (for the owner; not a verdict)
- (a) Now, by hand: delete the index (or the flagged shards) and let clangd rebuild it
  (about a minute for RMO); the fast path then works for every source that compiles.
  Recurs whenever indexing happens during an edit that breaks the build.
- (b) Patch 0009 for the local clangd: at startup also re-index sources whose own shard
  has `HadErrors` (low priority, background). It re-runs the indexer; it does not
  trust flagged shards. A source that compiles now gets a clean shard and the fast
  path back; one that still has errors gets a flagged shard again (clangd writes it
  only if the content changed or the errors are gone), and the fast path keeps
  refusing it, so answers stay correct (from the parse). Cost: indexing CPU for each
  still-broken source at every start. Candidate for an upstream report as well.
- (c) Record missing headers as dependencies so their creation makes shards stale
  (deeper change in clangd's include graph; not proposed first).
- (d) Emacs side: `vc-refresh-state` on every visit costs about 70 ms here; diff-hl
  (D-042) relies on VC state, so dropping it is not free. Not proposed without a
  measurement in a GUI session.

Ruled 2026-10-09: (b), D-060, built as patch 0009 (T-033, 0042). Result on the same
project: the five flagged sources answered their first `M-.` after a restart in 5 ms
- 2.7 s (was 7.4 - 12.6 s); two sources that still do not compile stay flagged.
