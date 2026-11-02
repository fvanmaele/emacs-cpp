# S20 results

Verdict: PASS on Arch (runs 1 - 3, the session's, 2026-11-02); the Mac's three runs
wait (H-20). Criteria 1 - 5 of `RUN.md` confirmed by the owner 2026-11-02, after the
Arch runs and as written. T-128 stays gated until the Mac passes too.

## Arch runs 1 - 3 (session, 2026-11-02)
Linux x86_64, GNU Emacs 31.1, `/opt/fswatch-no-loss` (pkgrel 2 installed; H-17's
pkgrel 3 differs only in macOS code, S18 run 7), load 0.89 - 1.23 (the owner's
desktop open, no build). Logs: `arch-run1.log`, `arch-run2.log`, `arch-run3.log`
(`run.sh` overwrites `s20.log`; each copied after its run).

`fswatch-queued`, worst of the three runs, both checkouts each:

| criterion | limit | Arch worst | holds |
|---|---|---|---|
| 1 buffers current after `git` | 1.0 s, no Overflow | 0.15 s, 0 overflows | yes |
| 2 edit kept, unchanged buffers reverted | kept, 0 | kept, 0 | yes |
| 3 Emacs blocked, VC included | 0.25 s | 0.20 s (VC step, run 3) | yes |
| 3 VC states current | 15 s | 9.50 s | yes |
| 4 idle fswatch | 16 descriptors, 12 MB | 6, 5.2 MB | yes |
| 5 ready; process gone | 5 s; gone | 0.55 s; gone | yes |

Contrast modes (recorded, not judged), range over the three runs:

| mode | buffers current after `git` | Emacs blocked at most |
|---|---|---|
| fswatch (VC at once) | 2.71 - 3.13 s | 2.71 - 3.13 s |
| fswatch-novc | 0.11 - 0.15 s | 0.11 - 0.15 s |
| poll (D-147's Mac setting) | 4.48 - 8.78 s | 3.03 - 3.83 s |

Findings:
- Arch delivers the checkout as one filter call of 760 records (inotify: four per
  file), 105 - 116 ms; the Mac dry run had 380 records in 2 - 3 calls, at most 73 ms.
  The revert pass itself is then the largest single block on Arch, half the 0.25 s
  limit at 190 files. It grows with the checkout (UNVERIFIED beyond 190 files: linear
  would be about 0.6 s at 1000), so the reverter written for T-128 should queue its
  reverts as it queues VC states, not only the VC refresh.
- VC states take 9.5 s on both machines because the queue paces one buffer per
  0.05 s (189 x 0.05 = 9.45 s), not because of `git`; one step blocks 0.11 - 0.20 s
  on Arch. The Mac dry run's 0.80 s step stays the open risk for criterion 3.
- Ready takes 0.54 - 0.55 s on Arch (inotify watches 2000 directories one by one)
  against 0.02 s on the Mac (FSEvents).
- `auto-revert-handler`'s per-buffer VC refresh blocks Arch for about 3 s (the
  `fswatch` row), as on the Mac (O-78): the defect is not the Mac's polling alone.
