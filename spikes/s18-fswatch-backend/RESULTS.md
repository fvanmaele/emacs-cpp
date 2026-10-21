# S18 results

Verdict: PASS on both machines in mode `dedup` (2026-10-21): criteria 1 - 5 hold on
Arch (run 2, the session's: 37 - 39 ms per 1000 records in three runs, limit 50) and
on the Mac (run 4, the owner's: 2 ms). Run 1 (owner, Arch, 2026-10-20) failed
criterion 3 in the modes then built (194 ms). D-127 is gated through (T-119).
The shipped backend (mode `shipped`) passes on Arch (run 5) at 48 - 49 ms, a thin
margin, and on the Mac (run 6) at 2 ms.

## Run 6 (session, Mac, 2026-10-21): the shipped backend (T-119, H-15 step 4)
`S18_RUNS=shipped:fake,shipped:pyright`, Darwin arm64, load 2.09 - 2.27; the tree
reused, 15625 directories, 267398 files. Log: `mac-run6-shipped.log` (its curly
quotes made ASCII).
- Criteria 1 - 5 hold: registration ok, pyright alive after 30 s with 1 fswatch;
  20000 of 20000, overflow 0 (20002 records); **2 ms** per 1000 records (0.03 s
  after the block, 46 filter calls); ready after 0.07 s; no process after shutdown.
- The fake server counts created files only, so it did not see what `make test` did
  the same day: a change of a recent file reported as created (D-144, fswatch 0005).

## Run 5 (session, Arch, 2026-10-21): the shipped backend (T-119)
Mode `shipped` loads `lisp/emacs-cpp-eglot-fswatch.el` itself, counted by advice in
`s18-run.el` (records at the merge, changes at the send). A fresh tree, load 1.63 then
0.70. Logs: `arch-run5a.log` (`shipped:fake,dedup:fake,shipped:pyright`),
`arch-run5b.log` (`shipped:fake,dedup:fake,shipped:fake`).
- Criteria 1 - 5 hold in all three `shipped` runs: registration ok, pyright alive
  after 30 s with 1 fswatch; 20000 of 20000, no overflow; **48, 49, 48 ms** per 1000
  records (limit 50); ready after 0.34 - 0.36 s; no process after shutdown.
- `dedup` in the same runs: 50 and 52 ms (run 2: 37 - 39 ms). Today's machine costs
  about a third more than run 2's for the same code, cause UNVERIFIED; the shipped
  backend costs a little less than `dedup` under the same conditions. The margin to
  the limit is 1 - 2 ms, so a slower day can fail criterion 3 on Arch.

## Run 4 (owner, Mac, 2026-10-21)
`S18_RUNS=dedup:fake,dedup:pyright`, Darwin arm64, load 3.83 - 4.29 (the Mac is not
idle, as in runs 1 - 3); the tree reused from run 3 and grown by its bursts (247398
files). Log: `owner-mac-run4-dedup.log` (its curly quotes made ASCII).
- Registration ok, no warning; pyright alive after 30 s, 4 fswatch processes.
- 20000 of 20000 created files at the server, overflow 0 (20003 records, one per
  file: FSEvents, so merging per path changes little, 20002 after it).
- Emacs's CPU after the block 0.04 s: 2 ms per 1000 records; 45 filter calls.
- Probe change reported 0.06 s after the registration; no fswatch process after
  shutdown.

## Run 2 (session, Arch, 2026-10-21)
Backend changes (`s18-backend.el`, `s18-run.el`): counters for filter calls and
notifications and the time inside the filter; three modes over the regexp matcher:
- `fast`: a change's URI is the root's URI (computed once) plus the hexified relative
  path, not `eglot-path-to-uri`, which calls `file-truename` on every path although
  fswatch reports true names already.
- `batch`: `fast`, changes collected per URI and sent from a 0.1 s timer.
- `dedup`: `fast`, the records of one filter call merged per path first (inotify
  writes three records for a written file: `Created`, `Updated`, `CloseWrite`).

Cause of run 1's cost, measured in batch Emacs over 20000 burst paths (us per path):
`eglot-path-to-uri` 95 (with `:truenamep t` 17; `file-truename` alone 77),
`file-exists-p` 8, `get-file-buffer` 6, the regexp 2. The suspect of run 1 (one
notification per record) was wrong: about 60 filter calls carry the 60004 records.

Fresh tree (15625 directories, 187395 files), load 1.07 - 1.42 (logs `arch-run2c.log`,
`arch-run2d.log`; `arch-run2a.log` and `arch-run2b.log` are the runs before, on a tree
grown by earlier bursts, `batch` in 2a with a bug that sent created files as changed):

| mode | per 1000 records | filter time | notifications | burst done |
|---|---|---|---|---|
| eglot | 433 ms | 25.75 s | 62 | 35.0 s |
| regexp | 265 ms | 15.83 s | 60 | 23.5 s |
| fast | 57 / 60 ms | 3.36 s | 56 | 9.1 / 9.9 s |
| batch | 81 ms | 4.54 s | 22 | 11.0 s |
| dedup | 37 / 39 / 38 ms | 2.14 s | 60 | 8.0 - 8.1 s |

Every mode: 20000 of 20000 created files at the server, no overflow, ready 0.31 -
0.39 s, no fswatch process left; `dedup` against pyright: alive after 30 s, 8 fswatch
processes. The `eglot` and `regexp` modes vary between runs (eglot 297, 360, 433 ms);
`fast` and `dedup` within 5 ms. The send times the log prints for the per-call modes
overlap (a send can run the filter again while it waits to write) and are not used.

## Reading (run 2)
The cost is per record, in the URI and the file tests, not in the matcher or the
sends. Batching the sends by a timer costs more than it saves (a hash per record);
merging a call's records per path removes two thirds of the work on inotify. On the
Mac FSEvents gives one record per file (20002 for the burst), so `dedup` should change
little there.

## Run 1 (owner, Arch, 2026-10-20)
Run 1 verdict: FAIL on Arch (owner, 2026-10-20): criteria 1, 2, 4 and 5 hold,
criterion 3 (cost) does not: 194 ms per 1000 records against at most 50. The Mac's
runs pass all five (`DRY-RUN.md`, `owner-mac-run3.log`). D-127 is not gated through;
run 2 is proposed below.

### Environment
Owner's Arch workstation, Linux x86_64, GNU Emacs 31.1; patched fswatch pkgrel 2 in
`/opt/fswatch-no-loss`; generated tree of 15625 directories, 187395 files; load 0.88 at
the start. Log: `owner-arch-run1.log`.

### Measurements (owner's run 1)
| Criterion | eglot matcher | regexp matcher | Mac, regexp (run 3) |
|---|---|---|---|
| 1. registration ok, no warning; pyright alive 30 s later | ok | ok; pyright alive, 8 fswatch | ok |
| 2. created files reaching the server, overflow | 20000 of 20000, 0 | 20000 of 20000, 0 | 20000 of 20000, 0 |
| 3. Emacs CPU after the block per 1000 records | 297 ms | **194 ms** | 6 ms |
| 4. probe change reported after registration | 0.33 s | 0.33 s | 0.06 s |
| 5. fswatch processes after shutdown | 0 | 0 | 0 |

Records read on Arch: 60004 / 60005 (three per created file); on the Mac 20002. Emacs
CPU after the block: 17.85 s (eglot) and 11.66 s (regexp), against 0.12 s on the Mac.
Baseline (Emacs's own watches, not judged): eglot answers the registration with
"Reached `eglot-max-file-watches' limit of 10000" after 120 s, no change reaches the
server.

### Reading
The matcher is not the cost: both matchers cost two orders of magnitude more than on
the Mac, per record. Suspect, UNVERIFIED (wrong, run 2):
on Linux fswatch's inotify monitor writes
each event as it comes, so the process filter runs about once per record and sends one
`workspace/didChangeWatchedFiles` per call (`s18-backend.el`, `s18--filter`), where
FSEvents on the Mac hands over batches. The log does not count filter calls, so this is
not shown.

### Run 2 as proposed then
- Count filter calls and notifications sent, and time the filter itself, so the cost is
  placed.
- The filter only collects; a timer (0.1 s, fswatch's own latency) sends what has
  collected in one notification, deduplicated per path.
- Criteria unchanged. The session runs it on Arch itself (tree about 2 GB under /tmp,
  a few minutes), then the Mac rerun is the owner's.
