# S20 results

Verdict for `fswatch-shown` (D-153): PASS on the Mac (runs 1 - 3, 2026-11-03), Arch
runs on H-22; eglot's share E1 - E3 PASS on the Mac (2026-11-03), a checkout during
clangd's reparse blocks 0.36 - 0.98 s (O-79); sections at the end. Earlier verdict
for `fswatch-queued`:

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

## Mode `fswatch-shown`, Mac runs 1 - 3 (session, 2026-11-03; D-153)
Darwin 27.0.0 arm64, GNU Emacs 31.1, `~/opt/fswatch-no-loss`, diff-hl from
`lib/diff-hl`. Logs: `mac-shown-run1.log` .. `mac-shown-run3.log`. Load 2.54 - 4.32
at the start (Emacs.app open; 0102's idle with it quit was 2.2 - 2.7). A dry run
before them passed the same checks and found the message saying "1 buffers" (fixed).

| criterion | `fswatch-shown`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.13 - 0.19 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.07 - 0.13 s (the filter's longest call 87 - 95 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.28 - 0.33 s after `git`; VC names the branch in 3 of 3; 1 diff-hl update each; steps 0.040 - 0.085 s | 15 s | yes |
| 3 showing a hidden buffer | 0.043 - 0.054 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 6.1 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.02 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c` | - | yes |
| 7 wiring (`wiring.sh`) | the hook runs after all four actions; the control (a `message`) NOT RUN | - | yes |

Contrast `fswatch-diffhl` (diff-hl's revert hook live, no VC refresh): buffers current
3.56 - 3.97 s after `git`, Emacs blocked 2.20 - 2.49 s, the filter 3.56 - 3.96 s per
checkout. The follow-up's 3.6 s estimate holds live.

Verdict: PASS on the Mac, criteria 1 - 7. Arch runs: H-22.

Limits:
- Batch Emacs runs no window change functions (checked 2026-11-03), so the run calls
  `s20--on-show` itself after `set-window-buffer`; `wiring.sh` shows the hook runs in
  a terminal Emacs (the Mac, one run).
- 186 - 187 hidden buffers stay stale until shown (D-153's design); one is shown per
  checkout.
- A step (`vc-refresh-state`, then `diff-hl-update`) took 0.040 - 0.048 s median,
  below the follow-up's 0.06 s estimate; why is UNVERIFIED.
- eglot's work per revert is not in it (no compile database); RMO before T-128 ships
  (D-153).

## eglot's share, Mac runs 1 - 3 (session, 2026-11-03; D-153)
A clone of `~/source/repos/RMO-drafts` at aad752e (39 files, deal.II from
`/Applications/deal.II.app`, preset `mac-debug`); patched clangd 23.1.3 with the
config's flags; Emacs 31.1's eglot with the config's settings. Logs:
`mac-eglot-run1.log` .. `mac-eglot-run3.log`. Load 3.7 - 4.7 at the start (clangd
of the run before; 60 s pause between runs). Two dry runs before: the first timed
out on `documentSymbol` (10 s) and lost its log (both fixed); the second found that
"settled" as first approved (diagnostics plus 5 s quiet) leaves clangd reparsing, so
the owner added the CPU condition and the back-to-back contrast.

| criterion | `eglot`, judged checkouts, runs 1 - 3 | limit | pass |
|---|---|---|---|
| E1 buffers current after `git` | 0.08 - 0.18 s | 1.0 s | yes |
| E2 Emacs blocked, `git` to settled | 0.075 - 0.183 s (the filter's longest call 18 - 183 ms) | 0.25 s | yes |
| E3 symbols on their lines | 60 of 60 in each checkout, 0 offset by 19 | - | yes |

Also per judged checkout: 39 didOpen, diagnostics after didOpen in 39 of 39, settled
42.0 - 45.7 s after `git` (clangd reparsing the 39 files), shown buffers' queue done
0.35 - 0.40 s after `git`, showing a hidden buffer 0.100 - 0.130 s.

Contrast, recorded:
- Back to back (the second checkout once clangd is quiet, not idle): Emacs blocked
  0.361 - 0.736 s (the second dry run 0.978 s), one filter call 356 - 736 ms for 39
  reverts; queue steps up to 0.275 s; settled 64 - 70 s after `git`. The same in
  `no-eglot`: blocked 0.125 - 0.128 s, the filter's longest call 19 - 36 ms, but with
  no clangd running, so no CPU contention: about 10 - 25 ms per revert during the
  reparse against under 1 ms idle, whether from eglot's sends or every revert slowed
  by the busy machine is UNVERIFIED (corrected 2026-11-03; D-154 measures the split).
- `no-eglot`, the same checkouts: blocked 0.115 - 0.163 s; its queue steps (median
  0.085 - 0.122 s) ran slower than with eglot (0.044 - 0.069 s); why is UNVERIFIED.

Verdict: E1 - E3 PASS on the Mac. Open: the back-to-back block, O-79.
