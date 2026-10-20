# S18 results

Verdict: FAIL on Arch (owner's run 1, 2026-10-20): criteria 1, 2, 4 and 5 hold,
criterion 3 (cost) does not: 194 ms per 1000 records against at most 50. The Mac's
runs pass all five (`DRY-RUN.md`, `owner-mac-run3.log`). D-127 is not gated through;
run 2 is proposed below.

## Environment
Owner's Arch workstation, Linux x86_64, GNU Emacs 31.1; patched fswatch pkgrel 2 in
`/opt/fswatch-no-loss`; generated tree of 15625 directories, 187395 files; load 0.88 at
the start. Log: `owner-arch-run1.log`.

## Measurements (owner's run 1)
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

## Reading
The matcher is not the cost: both matchers cost two orders of magnitude more than on
the Mac, per record. Suspect, UNVERIFIED: on Linux fswatch's inotify monitor writes
each event as it comes, so the process filter runs about once per record and sends one
`workspace/didChangeWatchedFiles` per call (`s18-backend.el`, `s18--filter`), where
FSEvents on the Mac hands over batches. The log does not count filter calls, so this is
not shown.

## Run 2 (proposed)
- Count filter calls and notifications sent, and time the filter itself, so the cost is
  placed.
- The filter only collects; a timer (0.1 s, fswatch's own latency) sends what has
  collected in one notification, deduplicated per path.
- Criteria unchanged. The session runs it on Arch itself (tree about 2 GB under /tmp,
  a few minutes), then the Mac rerun is the owner's.
