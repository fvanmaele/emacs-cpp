# S20 results

Verdict: FAIL (2026-11-02). PASS on Arch (runs 1 - 3); FAIL on the Mac on criterion
3 (runs 4 - 6, idle): one VC refresh step blocks Emacs 0.30 - 0.35 s. Criteria 1, 2,
4 and 5 hold on both machines, and the reverter without VC refresh (`fswatch-novc`)
blocks at most 0.09 s on the Mac. Criteria 1 - 5 of `RUN.md` confirmed by the owner
2026-11-02, after the Arch runs and as written. D-148 and D-149: O-78 reopens.

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
  on Arch. The Mac dry run's 0.80 s step stays the open risk for criterion 3 (it
  held: Mac runs below).
- Ready takes 0.54 - 0.55 s on Arch (inotify watches 2000 directories one by one)
  against 0.02 s on the Mac (FSEvents).
- `auto-revert-handler`'s per-buffer VC refresh blocks Arch for about 3 s (the
  `fswatch` row), as on the Mac (O-78): the defect is not the Mac's polling alone.

## Mac runs 1 - 6 (session, 2026-11-02)
Darwin 27.0.0 arm64, GNU Emacs 31.1, `~/opt/fswatch-no-loss`. Logs:
`mac-run1.log` .. `mac-run6.log`. Runs 1 - 3 on a busy machine (load 2.4 - 3.4,
Emacs.app open, Spotlight and G DATA's scanner active; run 1 on a freshly generated
repository, see below); the owner ruled them evidence only and asked for idle reruns.
Runs 4 - 6 are judged: Emacs.app quit, 60 s to settle, load 2.2 - 2.7 (this Mac's
floor with the desktop open; Arch: 0.9 - 1.2).

`fswatch-queued`, worst of runs 4 - 6, both checkouts each:

| criterion | limit | Mac worst | holds |
|---|---|---|---|
| 1 buffers current after `git` | 1.0 s, no Overflow | 0.31 s, 0 overflows | yes |
| 2 edit kept, unchanged buffers reverted | kept, 0 | kept, 0 | yes |
| 3 Emacs blocked, VC included | 0.25 s | 0.35 s (VC step, run 6) | no |
| 3 VC states current | 15 s | 9.51 s | yes |
| 4 idle fswatch | 16 descriptors, 12 MB | 6, 6.1 MB | yes |
| 5 ready; process gone | 5 s; gone | 0.02 s; gone | yes |

Emacs blocked at most, per run and checkout (`b`, `a`): until the buffers were
current, then including the VC queue (`s20-stall` is one `accept-process-output`
call, so a VC step that falls before the last revert counts in the first column too):

| run | load | until current | with VC | judged |
|---|---|---|---|---|
| 1 | 3.12 | 0.44, 0.11 s | 0.44, 0.15 s | no (busy) |
| 2 | 3.42 | 0.33, 0.17 s | 3.24, 0.21 s | no (busy) |
| 3 | 2.63 | 0.16, 0.12 s | 0.25, 0.16 s | no (busy) |
| 4 | 2.19 | 0.22, 0.12 s | 0.30, 0.25 s | yes: fails |
| 5 | 2.68 | 0.12, 0.12 s | 0.20, 0.32 s | yes: fails |
| 6 | 2.27 | 0.16, 0.07 s | 0.35, 0.22 s | yes: fails |

Contrast modes (recorded, not judged), range over runs 1 - 6:

| mode | buffers current after `git` | Emacs blocked at most |
|---|---|---|
| fswatch (VC at once) | 6.70 - 7.92 s | 4.08 - 4.88 s |
| fswatch-novc | 0.14 - 0.15 s | 0.06 - 0.09 s |
| poll (D-147's Mac setting) | 9.37 - 13.03 s | 6.42 - 9.04 s |

Findings:
- The failing part is VC's state, not the reverter: without VC refresh the whole
  checkout blocks Emacs at most 0.09 s and the longest filter call is 86 ms (Arch:
  0.15 s, 116 ms). In `emacs -Q` only: diff-hl adds 0.019 s per revert (follow-up).
- One `vc-refresh-state` starts 8 `git` processes and takes 35 - 45 ms on a quiet
  checkout of this repository (50 buffers, measured 2026-11-02 in a batch Emacs).
  The queued steps right after a checkout take 0.20 - 0.35 s, once 3.24 s on the busy
  machine; why a step takes up to 8 times the quiet cost is UNVERIFIED. (Superseded
  by the follow-up below: a block is several steps in one wait, not one slow step.)
- Mac VC steps (0.20 - 0.35 s idle) are about twice Arch's (0.11 - 0.20 s); costlier
  process starts on the Mac would explain it (UNVERIFIED, as in O-78).
- The Mac delivers a checkout as 380 records in 2 - 3 filter calls (FSEvents: two per
  file), at most 107 ms per call; Arch as one call of 760 records.
- `poll` blocks the Mac 6.4 - 9.0 s per checkout, more than O-78's 5.9 - 6.5 s from
  the dry run.
- Run 1 met a repository emptied by macOS: files under TMPDIR unused for 3 days are
  deleted, the directories kept, and `run.sh` took the husk as kept; the first mode
  failed at its first `git checkout` and `run.sh` stopped. The husk was removed by
  hand and `run.sh` now stops on it (db30ea7). Run 1's numbers are from the
  regenerated repository.

## Follow-up on the Mac (session, 2026-11-02, O-78 revisited)
Load 3.6 - 8.1 during these (not the session's), so absolute times run high.
- Several steps per wait: `wait-trace.el` runs S20's `fswatch-queued` unchanged and
  breaks its slowest waits down. Each holds 2 - 4 VC timer steps back to back (0.10 -
  0.16 s that run); single `vc-refresh-state` calls take 0.040 s median, 0.095 s at
  most, no GC in them. The repeating 0.05 s timer is due again when a 40 ms step
  ends. The runs' 0.30 - 0.35 s fit 7 - 8 steps. A bare repeating timer with a busy
  42 ms step ran one step per wait (`timer-max-repeats` 10), so the stacking needs
  S20's surroundings (fswatch's process); why is UNVERIFIED.
- `git` is not slower after a checkout: 190 sequential refreshes right after one
  took 0.034 s median, 0.043 s at most, no GC (`gc-cons-threshold` 800000).
- One `vc-refresh-state` runs `symbolic-ref`, `rev-parse`, `status` and `ls-files`,
  each twice: 8 processes, 0.041 - 0.044 s median, quiet or right after a checkout
  (`vc-cost.el`, 50 buffers).
- diff-hl, as the config loads it in every file buffer, runs `diff-hl-update` from
  `after-revert-hook` when modes are preserved, synchronously (`diff-hl-update-async`
  nil): `diff-index` and `rev-parse` per revert, 0.019 s median against 0.0006 s
  without diff-hl. S20 ran `emacs -Q`; with diff-hl, 189 reverts in one filter call
  would block about 3.6 s.
- eglot sends didClose and didOpen on every revert (Emacs 31.1 `eglot.el`); not
  measured here, the generated repository has no compile database.
