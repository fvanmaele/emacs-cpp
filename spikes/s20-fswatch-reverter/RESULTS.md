# S20 results

Verdict for `fswatch-shown` (D-153): PASS on the Mac (runs 1 - 3, 2026-11-03); FAIL on
Arch on criterion 3 (D-166, 2026-11-04: the session's run 6 blocked 0.30 s; the
owner's runs 1 - 3 passed, kept as evidence); mode `shipped` FAIL on Arch too (run 3,
0.25 s); mode `fswatch-chunked` (D-167) PASS on Arch (0116), the Mac on H-25;
eglot's share E1 - E3 PASS on the Mac (2026-11-03), a checkout during clangd's
reparse blocks 0.36 - 0.98 s (O-79); sections at the end. Earlier verdict
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

## Mode `fswatch-shown`, Arch runs 1 - 3 (owner, 2026-11-03; H-22, D-153)
Linux x86_64, GNU Emacs 31.1 (GTK 3.24.52), the session's commits through b9e2146,
diff-hl from `lib/diff-hl`. Logs: `arch-shown-run1.log` .. `arch-shown-run3.log`
(`s20.log` is run 3). Load 0.85 - 1.31 at the start, runs 23:05 - 23:07Z.

| criterion | `fswatch-shown`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.13 - 0.14 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.12 - 0.14 s (the filter's longest call 124 - 141 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.33 - 0.36 s after `git`; VC names the branch in 3 of 3; 1 diff-hl update each; steps 0.037 - 0.051 s | 15 s | yes |
| 3 showing a hidden buffer | 0.020 - 0.047 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 5.2 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.54 - 0.55 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c` | - | yes |
| 7 wiring | the Mac only (criterion 7) | - | - |

Contrast `fswatch-diffhl`: buffers current 1.55 - 2.43 s after `git`, Emacs blocked
1.55 - 2.40 s, one filter call per checkout of the same length.

Verdict (2026-11-04, superseded by D-166): PASS on Arch, criteria 1 - 6; runs 4 - 6
below fail criterion 3.

Findings:
- Arch's block is the one filter call (761 - 763 inotify records, 124 - 141 ms), up
  from the Mac's 87 - 95 ms: inotify delivers the checkout in one call, the reverts
  then run back to back. 0.11 s of margin at 190 files; T-128's note "queue reverts
  too" (0101) stands for larger checkouts.
- Ready stays 0.54 s (inotify watches the directories one by one), as in runs 1 - 3
  of 2026-11-02.
- The queue steps (0.037 - 0.051 s) match the Mac's (0.040 - 0.085 s); the
  contrast's diff-hl cost is lower than the Mac's (1.6 - 2.4 s against 2.2 - 2.5 s).

## Mode `fswatch-shown`, Arch runs 4 - 6 (session, 2026-11-04; D-166)
The same commands as runs 1 - 3, on `main` at a077521 (the spike's mode unchanged).
Logs: `arch-shown-run4.log` .. `arch-shown-run6.log`. Load 1.32 - 1.87 at the start,
runs 18:04 - 18:06Z; this session's Claude Code process was running.

| criterion | `fswatch-shown`, runs 4 - 6 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.12 - 0.31 s, no Overflow | 1.0 s | yes |
| 2 edits kept | as in runs 1 - 3 | - | yes |
| 3 Emacs blocked (`c`, `a`) | run 4: 0.23, 0.14 s; run 5: 0.11, 0.15 s; run 6: 0.30, 0.25 s (filter's longest call 232, 145, 302 ms) | 0.25 s | no (run 6) |
| 3 shown buffers | queue done 0.31 - 0.50 s; VC names the branch 3 of 3; steps 0.018 - 0.051 s | 15 s | yes |
| 3 showing a hidden buffer | 0.018 - 0.047 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 5.2 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.54 - 0.55 s; gone | 5 s | yes |
| 6 messages | as in runs 1 - 3 | - | yes |

Contrast `fswatch-diffhl`: Emacs blocked 1.56 - 2.81 s.

Verdict (owner, D-166): FAIL on Arch, criterion 3. `git` itself took 0.11 - 0.13 s in
run 6 (0.05 - 0.07 s in runs 1 - 3): something else used the disk or CPU, at a
desktop's ordinary load. The block is the one filter call (761 - 763 records); its
spread over six runs, 124 - 302 ms, leaves no margin at 190 files.

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

## D-154: the parts of a revert during clangd's reparse (session, 2026-11-03)
`eglot-share.el` times each revert's `revert-buffer`, eglot's didClose and didOpen,
and every `process-send-string` to clangd (with its bytes). Logs:
`mac-split-run1.log` .. `mac-split-run3.log`, mode `eglot`, load 4.4 - 6.1 at the
start; a dry run before (its log not kept) gave the same picture.

| checkout | Emacs blocked | `revert-buffer`, 39 calls | sends to clangd | longest send | revert without didClose / didOpen |
|---|---|---|---|---|---|
| judged (clangd idle) | 0.078 - 0.168 s | 32 - 168 ms | 0.5 - 112 ms | 0.0 - 112 ms | 25 - 53 ms |
| back-to-back 2 (reparse) | 0.281 - 0.707 s (dry run 1.120 s) | 538 - 1061 ms | 463 - 1314 ms | 262 - 568 ms (dry run 1039 ms) | 68 - 151 ms |

About 463 KB go to clangd per checkout (39 whole files). During the reparse the
sends are most of the block, and one single write stalls 0.26 - 1.04 s: clangd does
not read its input for that long. The rest of a revert slows 2 - 4 times. In clangd
23.1.1's source, closing a file does not wait for its worker (`TUScheduler::remove`,
`ASTWorker::stop` only take locks and notify), so what keeps clangd from reading is
UNVERIFIED. Verdict for D-154: the sends are the cost; O-79 rules next.

## T-129: why the writes stall (session, 2026-11-03; D-155)
`eglot-share.el` gained `S20_CLANGD_FLAGS` (patched, stock, navigation,
header-flags), `S20_CLANGD_LOG` (clangd's `--log=verbose` to a file, through sh's
exec), the stalled writes (over 50 ms) with their local time, clangd's output and
diagnostics handled while a send runs, and the timers run while a send runs. Logs:
`mac-t129-patched-verbose.log`, `mac-t129-stock-verbose.log`, `mac-t129-stock.log`
(round 1; its stock run overlapped a `make test`), `mac-t129-r2-*.log` (round 2, one
per flag set), `mac-t129-r3-patched.log`, `mac-t129-r4-patched.log` (timers). clangd's
verbose logs stayed in the session's scratch directory (6837 lines); excerpts below.

| flags | stalled writes, any checkout | reparse after a checkout | back-to-back 2 blocked |
|---|---|---|---|
| patched (both) | yes: 65 - 302 ms | 41 - 48 s | 0.157 - 0.747 s |
| `--header-flags-from-index` alone | yes: 323 ms | 42 - 44 s | 0.432 s |
| `--navigation-from-index` alone | none (sends 0.5 - 0.6 ms in all) | 21 - 22 s | 0.168 s |
| stock | none (sends 0.6 - 0.7 ms in all) | 21 - 22 s | 0.104 - 0.114 s |

Placed, in two parts:
1. clangd (corrected 2026-11-03: the includer lookup runs on the worker thread,
   `TUScheduler.cpp:871`, so the gaps below are not the lookup; cause UNVERIFIED,
   CPU starvation suspected, DESIGN O-79): with `--header-flags-from-index`
   (D-028) the main thread handles a header's didOpen in up to about 12 ms during
   the reparse (verbose log: `<<<` at 13.665, `<--` at 13.677, its "Compile
   command for ... which includes it (index)" lines in those gaps) and does not
   read meanwhile; before residual.h's didOpen it
   read nothing for 81 ms (13.721 - 13.802) while Emacs's 7 KB write took 84 ms. The
   pipe fills and Emacs's write gets EAGAIN. Without the flag no write stalls.
2. Emacs: on EAGAIN `send_process` waits in `wait_reading_process_output`, which
   runs due timers. Inside the stalled sends of back-to-back 2 ran the reverter's
   queue step (2 runs, 415 - 446 ms, up to 280 ms each: VC and diff-hl during the
   reparse) and 44 - 47 runs of one byte-compiled closure, nested: timers that send
   to clangd again (62-byte writes) stall on the same pipe and run more timers.
   clangd's output read inside sends 0.2 - 0.3 ms, its diagnostics 1.0 - 1.1 ms: not
   the cost. Wall time is the block (0.595 - 0.747 s); the timer totals overlap.

## D-157: CPU contention test (session, 2026-11-03)
`eglot-share.el` gained `S20_GAP` (the first back-to-back checkout returns that many
seconds after `git`, not settled) and `S20_CLANGD_JOBS` (clangd's `-j`). Logs:
`mac-d157-stock-gap1.log`, `mac-d157-patched-gap1.log`, `mac-d157-patched-j5.log`;
load 1.6 - 6.6 at the start.

| run | stalled writes, back-to-back 2 | Emacs blocked | settled after |
|---|---|---|---|
| stock, second checkout 1 s after the first | none (sends 0.8 ms in all) | 0.211 s | 27.1 s |
| patched, the same 1 s gap | 251 ms, 168 ms | 0.284 s | 104.0 s |
| patched, `-j=5` (6 of 11 cores free), usual pair | 209 ms, 137 ms | 0.254 s | 71.9 s |

CPU contention alone does not stall clangd's reading: stock flags inside the reparse
never stall, and with 6 cores left free the patched flags still do. clangd's
verbose log at the 81 ms gap (0106): the main thread logs `>>>` of the empty
publishDiagnostics it sends on residual.h's didClose at 13.721, then nothing until
it reads the next didOpen at 13.802, so the write of that message may be what
blocks (Emacs, inside the reverter's filter, reads no output meanwhile). But stock
clangd writes more (652 KB of publishDiagnostics in its verbose run against 99 KB
patched) and never stalls, so the volume does not explain it. Cause UNVERIFIED.

## D-158: clangd's threads sampled; D-156 (e) in the spike (session, 2026-11-03)
`eglot-share.el` gained `S20_SAMPLE` (macOS `sample` on clangd, 3 s, 1 ms apart,
attached before the back-to-back pair's second `git`), garbage collection counts
per checkout and per stalled send, and `S20_STEP_WAITS` (D-156 (e): a queue step
that finds the reverter's filter running arms its timer again). Logs:
`mac-d158-patched.log`, `mac-d158-stock.log` (sampled), `mac-d158-patched-gc.log`,
`mac-d158-patched-stepwaits1.log` .. `3.log`. The samples (28 MB, 11 MB) stayed in
the session's scratch directory.
- Sampled stall (patched, a 200-byte didClose waiting 264 ms): clangd's main
  thread was in `fgets`, then `read`, in `JSONTransport::loop` in all 831 samples. It
  waited for input; it was not blocked on a write, a lock or the index.
- No garbage collection inside any stalled send (0 GCs; 1 GC of 16 - 32 ms per
  checkout elsewhere).
- Without (e), patched: back-to-back 2 blocked 1.123 s; inside its stalled sends
  ran the reverter's queue step (2 runs, 862 ms, up to 501 ms each, VC and diff-hl
  during the reparse) and 43 nested runs of one closure around it.
- With (e), patched, runs 1 - 3: back-to-back 2 blocked 0.253, 0.282, 0.224 s; the
  queue step deferred 1 - 2 times and ran 0 ms inside sends; the nested closure 38 -
  42 runs, 5 - 6 ms in all; one write still stalls 159, 173, 74 ms (transport.h's
  didOpen, 56 KB) with no timer time in it. Judged checkouts blocked at most 0.075 -
  0.091 s. Load 5.7 - 7.0 at the start.

So the freeze during a reparse was Emacs's own timers, mainly the reverter's queue
step, run inside a write that hit a full pipe; (e) removes that part. What makes the
one large write wait 74 - 173 ms with the patched flags only is UNVERIFIED (the
sampled run's stall was a timer one).

## D-159: the residual write stall sampled (session, 2026-11-03)
Two patched runs with D-156 (e) on and `sample` during back-to-back 2: logs
`mac-d159-run1.log`, `mac-d159-run2.log`; samples in the session's scratch
directory. Each caught the residual stall: transport.h's didOpen (56 KB) waited 170
and 162 ms; back-to-back 2 blocked 0.257 and 0.259 s; the queue step deferred twice
in each. A second patched clangd, not the spike's (pid 65628, on RMO-drafts' own
build, running for over an hour), ran beside every run of the day; its load is in
all absolute numbers.

clangd's main thread was in `read` (`JSONTransport::loop`, `fgets`,
`__read_nocancel`) in 845 of 845 and 773 of 777 samples (the other 3 waiting on
its logger's mutex). A sample cannot tell a thread waiting for data from one woken
but not yet on a CPU, so two readings fit: Emacs's `send_process` waits up to 20 ms
in `wait_reading_process_output` after each blocked write, woken early only by
another process's output, not by the pipe draining (Emacs `process.c`); or clangd's
reader is woken but waits for a CPU while the reparse runs. Either way the cost is
neither the includer lookup nor anything T-128 controls. Why the stock runs never
hit it is UNVERIFIED.

## D-160: Emacs's side of clangd's pipe traced (session, 2026-11-03)
New in the spike: `pipetrace.c`, loaded into the batch Emacs only (`DYLD_INSERT_LIBRARIES`,
built by `eglot-share.sh` when `S20_PIPETRACE` names a trace file), records each write
to a pipe (bytes asked, written or EAGAIN, the pipe's fill from `fstat` on the write
end), each `pselect` while a write waits, and the fill polled about every 0.1 ms
until it drains; `pipetrace.py` summarizes it per checkout into the log. The filter's
calls with wall time, Emacs's CPU (`current-cpu-time`) and clangd's CPU; the reverts'
file reads (`insert-file-contents`) wall against CPU; `S20_SAMPLE_EMACS` samples this
Emacs. Logs: `mac-d160-patched1.log`, `-patched2`, `-stock1` (traced), `mac-d160-cpu-*`,
`mac-d160-io-*`; traces and samples in the session's scratch directory. Load 2.0 - 5.9
at the start; the owner's second clangd was gone; G DATA's antivirus ran throughout.

Checks first. Emacs 31.1 (MacPorts' distfile): after a write gets EAGAIN,
`send_process` waits in `wait_reading_process_output (0, 20 ms, ...)` (`process.c`
6886 - 6913), which wakes on process output only, never on the pipe draining; batch
Emacs reaches plain `pselect` (`nsterm.m` 5214). A macOS pipe holds 64 KB. A 168 KB
send to `cat`: 25 + 25 ms waiting with the pipe empty 50.1 of 50.6 ms (the 20 ms
timeout sleeps 20.2 - 25.0 ms here). Emacs 31.1's `process-attributes` CPU times are
41.7 times too small on Apple silicon (a 1 s burner read 0.027 s; DESIGN O-80), so
this spike's settle test was "under about 4.2 s of clangd's CPU over 5 s" on the Mac
until the io runs, which scale it (41.7, measured at load); the judged checkouts
only got harder by it. clangd figures below are corrected by the factor.

Back-to-back 2, patched flags with (e):
| run | blocked | the pipe: blocked sends (span), full / with room | longest send seen in Lisp | filter calls |
|---|---|---|---|---|
| traced 1 | 0.291 s | 56 KB 9.8 ms, 22 KB 23.3 ms; 15.2 / 17.9 ms | 181 ms | 289.6 ms, the second (181.3 ms) nested inside it |
| traced 2 | 0.250 s | 56 KB 15.1 ms, 22 KB 20.0 ms; 10.4 / 24.7 ms | 39 ms | 249.6 and 3.4 ms |
| cpu 1, 2 | 0.209, 0.214 s | - | 21, 23 ms | wall 56 - 186 ms at 15 - 26 ms of Emacs's CPU; clangd 8.1 - 9.2 cores |
| io 1, 2 | 0.593, 0.226 s | - | 34, 22 ms | reverts' file reads 241, 161 ms at 17, 14 ms of CPU |
Stock flags (traced, cpu): blocked 0.106, 0.132 s; no EAGAIN, sends under 2 ms in
all; filter calls at 2 - 5 times their CPU while clangd ran 7.3 - 9.6 cores, already
in the first checkout. In the patched runs' first two checkouts (clangd ramping up,
2.6 - 3.6 cores) the filter calls run at 1.2 - 1.6 times their CPU and the 39 reads
take 20 - 33 ms.

Open test (no clangd, 39 files written as git writes them, 12 - 20 KB; `opentest.py
DIR`, its rename and size variants were scratch), first `open`:
| where | idle: median, total | 11 CPU burners: median, max, total |
|---|---|---|
| scratch, `/private/tmp` | 2.1 - 5.8 ms, 85 - 244 ms | 30 - 395 ms, 2.6 s, 2.0 - 19.2 s |
| beside the clone, `$TMPDIR` | 0.4 - 1.0 ms, 16 - 39 ms | 0.2 - 16 ms, 0.69 s, 0.1 - 6.7 s |
| this repository's tree | 0.2 - 0.3 ms, 9 - 12 ms | 0.3 - 86 ms, 0.70 s, 0.8 - 5.7 s |
A second open: 0.02 - 0.09 ms everywhere. Idle, the first open grows with the file
(2 KB 1.6 ms, 20 KB 4.1 ms, 200 KB 18.7 ms in scratch), waiting 1 - 2 s after the
write does not shorten it, and PCH-sized writes beside it change nothing.
`gdesclientd` (G DATA's real-time service) holds
`com.apple.developer.endpoint-security.client`.

So:
- The residual "write stall" (74 - 181 ms, D-158, D-159, traced 1) was a nested filter
  call: in all six runs with one, the stalled send equals the filter's total less its
  longest call to within 2 ms. Waiting on the full pipe, Emacs read fswatch's next
  records and ran the reverter's filter inside the send (traced 1: 22 reverts in it).
  At the pipe the 56 KB write waited 9.8 and 15.1 ms.
- The pipe part, patched flags only: clangd took bytes 2.6 - 9.8 ms after the pipe
  filled (a write drains in 0.3 ms median, 13 - 15 ms at the 90th percentile, up to
  57 ms, against at most 4 ms elsewhere), then Emacs waited out its 20 ms with room
  in the pipe: two blocked sends per checkout, 10 - 23 ms each.
- The block itself is the reverts, mostly off the CPU, in their file reads: the first
  open of each just-checked-out file waits for G DATA's on-access scan, and the scan
  is starved while clangd keeps 7 - 9 of 11 cores busy (the open test shows the same
  with CPU burners alone). UNVERIFIED with real-time protection paused (owner's).
- clangd's load: D-159's sample re-read shows about 21 threads wanting a CPU with the
  patched flags (11 PreambleWorkers among the 15 busiest), about 9 with stock; `-j`
  caps AST builds only (`TUScheduler.cpp` 1448); the binary sets no
  `PreambleThrottler`, so preambles build unthrottled.
- The Emacs sample (io 1) missed the checkout: its window began after the reverts,
  cause UNVERIFIED (self-sampling a small batch Emacs works).

## D-161: O-79 (s), G DATA's real-time protection off (session, 2026-11-04)
The owner turned G DATA's real-time protection off ("for now"); its service processes
kept running. Logs: `mac-d161-rtp-off1.log`, `mac-d161-rtp-off2.log` (patched flags,
D-156 (e), the D-160 lines, the strict settle test). Load 5.2 and 9.7 at the start.

Open test (`opentest.py`), first open of 39 just-written files:
| where | idle: median, total | 11 CPU burners: median, max, total |
|---|---|---|
| scratch, `/private/tmp` | 0.03 - 0.05 ms, 1.3 - 2.6 ms | 0.02 - 0.03 ms, 0.15 ms, 1.1 - 1.2 ms |
| beside the clone, `$TMPDIR` | 0.02 - 0.03 ms, 0.9 - 1.5 ms | 0.03 ms, 0.15 ms, 1.1 - 1.2 ms |
| this repository's tree | 0.02 - 0.08 ms, 0.9 - 2.8 ms | 0.01 - 0.02 ms, 0.59 ms, 0.5 - 1.5 ms |
A second open takes 0.01 - 0.04 ms: first and second opens no longer differ.

Back-to-back 2:
| run | blocked | filter calls: wall / Emacs CPU (reverts); clangd | reverts' 39 reads: wall / CPU | sends |
|---|---|---|---|---|
| off 1 | 0.116 s | 19.9 / 17.1 ms (16), 36.3 / 18.4 ms (23); 5.3, 7.9 cores | 23.6 / 11.8 ms | none blocked |
| off 2 | 0.075 s | 23.8 / 19.0 ms (16), 50.1 / 22.3 ms (23); 3.0, 6.4 cores | 21.7 / 13.1 ms | one blocked, 20.6 ms |
With protection on (D-160): blocked 0.21 - 0.29 s (once 0.59 s), the reads 161 - 241
ms at 14 - 17 ms of CPU, filter calls at 3 - 7 times their CPU.

So the scan was the residual: without it the back-to-back block is in the range of
the other checkouts, under E2's 0.25 s. Differences besides the scan:
- clangd published for 32.7 - 33.3 s after back-to-back 1 (on: 5.1 s quiet), so the
  pair's second checkout landed later in the reparse; clangd still ran 3 - 8 cores
  during its filter calls.
- The reparse is shorter: settled 35.1 - 41.3 s after back-to-back 2's `git` (on:
  60.9 - 77.8 s), 37.0 - 40.7 s after the first checkouts (on: 41.2 - 51.6 s).
- The first checkouts block a little more, 0.100 - 0.125 s (on: 0.067 - 0.090 s):
  clangd starts its reparse sooner and runs up to 7.2 cores during them (on: 2.6 -
  3.6); one 16 ms blocked send in run 1's first checkout.

## Mode `shipped`, Mac runs 1 - 3 (session, 2026-11-04; T-128, D-162 (d))
The config's `lisp/emacs-cpp-reverter.el` at 5316f49 in place of the spike's reverter
(RUN.md, mode `shipped`). Logs: `mac-shipped-run1.log` .. `mac-shipped-run3.log`. Load
4.0 - 5.2 at the start; G DATA's real-time protection off (D-161; on during 0103).

| criterion | `shipped`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.11 - 0.12 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.03 - 0.06 s (the filter's longest call 50 - 55 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.24 - 0.26 s after `git`; VC names the branch in 3 of 3; 1 diff-hl update each; steps 0.028 - 0.036 s | 15 s | yes |
| 3 showing a hidden buffer | 0.029 - 0.034 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 6.1 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.01 - 0.02 s; gone after the buffers were killed (the module stops it) | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c` | - | yes |

Verdict: PASS on the Mac, criteria 1 - 6; FAIL on Arch (below). Against `fswatch-shown`'s
Mac runs (0103: blocked 0.07 - 0.13 s, filter 87 - 95 ms) the shipped module blocks less;
the scan's absence accounts for part of it (UNVERIFIED how much).

## Mode `shipped`, Arch runs 1 - 3 (session, 2026-11-04; T-128, D-166)
H-23's steps 3 - 6, run by the session on Arch at a077521: `make test` 151 of 151 as
expected (46.9 s); logs `arch-shipped-run1.log` .. `arch-shipped-run3.log`. Load 3.10 -
3.37 at the start (`make test` had just run; H-23 asked for an idle machine).

| criterion | `shipped`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.13 - 0.26 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.13 - 0.25 s (the filter's longest call 194, 148, 250.6 ms) | 0.25 s | no (run 3) |
| 3 shown buffers | queue done 0.33 - 0.47 s; VC names the branch 3 of 3; steps 0.020 - 0.055 s | 15 s | yes |
| 3 showing a hidden buffer | 0.020 - 0.054 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 5.2 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.01 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c` | - | yes |

Verdict: FAIL on Arch, criterion 3 (run 3, 250.6 ms), at a load above H-23's idle
condition; by D-166 the shipped module's reverts at once are what changes (O-81).
Ready 0.01 s against the spike's 0.54 s: the module does not wait for fswatch's
watches the way the spike's `ready` does (UNVERIFIED which part of the 0.54 s that
is).

## Mode `fswatch-chunked`, Arch runs 1 - 3 (session, 2026-11-04; D-167)
The new mode at the default budget (0.05 s), `fswatch-shown` after it in each run as
contrast. Logs: `arch-chunked-run1.log` .. `arch-chunked-run3.log`; a dry run before
them passed the same checks (not kept). Load 1.91 - 2.27 at the start, this session
running.

| criterion | `fswatch-chunked`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.23 - 0.51 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.09 - 0.14 s (filter's longest call 5.1 - 7.7 ms; revert steps 3 - 5 per checkout, longest 50.3 - 52.6 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.25 - 0.37 s after `git`; VC names the branch 3 of 3; 1 diff-hl update each; steps 0.015 - 0.063 s | 15 s | yes |
| 3 showing a hidden buffer | 0.016 - 0.045 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 5.2 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.55 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c`, once the queue was empty | - | yes |

Contrast `fswatch-shown`, the same three runs: Emacs blocked 0.13 - 0.21 s, the
filter's longest call 169 - 215 ms, buffers current 0.14 - 0.22 s after `git`.

Verdict: PASS on Arch, criteria 1 - 6. The Mac: PASS (below, 0117).

Findings:
- The block no longer grows with the checkout: the filter only queues (at most
  7.7 ms for 763 records), and each revert step stops within 2.6 ms of its budget
  (14 - 82 reverts per step, 0.6 - 3.6 ms each). Buffers become current 0.1 - 0.3 s
  later than at once, well inside criterion 1.
- Emacs's largest block (0.14 s) is more than one step (52.6 ms): `s20-stall` counts
  one `accept-process-output` call, in which the revert step and a shown buffer's
  refresh step (up to 63 ms) can both fall due, plus its 0.02 s wait. The module
  should keep the two from running in one pass (the refresh step waits while reverts
  are queued, or both share one budget); UNVERIFIED which costs less.
- Shown buffers are current first (their queue done 0.25 - 0.37 s, before the last
  revert in 4 of 6 checkouts).


## Mode `fswatch-chunked`, Mac runs 1 - 3 (session, 2026-11-04; D-167, H-25)
H-25's steps 3 - 5, run by the session on the Mac at a4304ce, `fswatch-shown` after
the new mode in each run as contrast. Logs: `mac-chunked-run1.log` ..
`mac-chunked-run3.log`. Load 4.40 - 4.55 at the start, not idle: `mediaanalysisd`
(macOS, about 120 % CPU) ran through all three; the judged `fswatch-shown` Mac runs
(0103) were at 2.54 - 4.32.

| criterion | `fswatch-chunked`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.32 - 0.60 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.12 - 0.18 s (filter's longest call 1.0 - 1.1 ms; revert steps 3 - 5 per checkout, longest 50.2 - 51.1 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.36 - 0.49 s after `git`; VC names the branch 3 of 3; 1 diff-hl update each; steps 0.051 - 0.127 s | 15 s | yes |
| 3 showing a hidden buffer | 0.046 - 0.083 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 6.1 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.02 - 0.56 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c`, once the queue was empty | - | yes |

Contrast `fswatch-shown`, the same three runs: Emacs blocked 0.11 - 0.16 s, the
filter's longest call 115 - 126 ms, buffers current 0.21 - 0.29 s after `git`.

Verdict: PASS on the Mac, criteria 1 - 6; with Arch (above) `fswatch-chunked` passes
on both machines. Next, per D-167: `lisp/emacs-cpp-reverter.el` written fresh from
these numbers, then `shipped` on both machines.

Findings:
- FSEvents delivers the checkout in 2 - 3 filter calls (Arch: one), so `fswatch-shown`'s
  block on the Mac stays below the limit; the chunked filter cuts the call from
  115 - 126 ms to about 1 ms.
- The block did not shrink on the Mac (0.12 - 0.18 s against 0.11 - 0.16 s): the
  largest block is a revert step plus a shown buffer's refresh step in one
  `accept-process-output` call, as on Arch (0116). The largest (0.18 s, run 3, `a`)
  is the call with the longest refresh step (0.127 s). The module's rule that only
  one of the two runs per pass (0116) is what lowers it; UNVERIFIED by a run.
- Reverts cost 0.5 - 1.6 ms each here (2 - 95 per 50 ms step); 0.05 s fits the Mac.

## Mode `shipped` after the rewrite, Mac runs 1 - 3 (session, 2026-11-04; D-167, D-168)
`lisp/emacs-cpp-reverter.el` rewritten from `fswatch-chunked` (D-168: one timer, a
step reverts or refreshes, never both), `fswatch-chunked` after it in each run as
contrast; `make test` 151 run, 0 unexpected, 3 skipped (gdb, ty: as before the
rewrite). Logs: `mac-shipped-chunked-run1.log` .. `mac-shipped-chunked-run3.log`.
Load 7.78 - 8.15 at the start (not the session's; not idle).

| criterion | `shipped`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.22 - 0.29 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.07 - 0.13 s (filter's longest call 1.4 ms; revert steps 3 - 4 per checkout, longest 50.3 - 61.7 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.49 - 0.58 s after `git`; VC names the branch 3 of 3; 1 diff-hl update each; steps 0.046 - 0.102 s | 15 s | yes |
| 3 showing a hidden buffer | 0.047 - 0.056 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 6.1 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.10 - 0.11 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c`, once the queue was empty | - | yes |

Contrast `fswatch-chunked`, the same three runs: Emacs blocked 0.11 - 0.13 s, buffers
current 0.28 - 0.44 s, shown buffers' queue done 0.33 - 0.38 s after `git`.

Verdict: PASS on the Mac, criteria 1 - 6. Arch: PASS (below, 0119).

Findings:
- One kind of work per step lowers the block from 0.11 - 0.13 s to 0.07 - 0.08 s in
  5 of 6 checkouts; the sixth (0.13 s, run 3, `a`) is one refresh step alone
  (0.102 s), which a budget cannot split.
- Reverts finish sooner (0.22 - 0.29 s against 0.28 - 0.44 s): no refresh step runs
  between them. The shown buffers' VC state and marks come later (0.49 - 0.58 s
  against 0.33 - 0.38 s), D-168's cost.
- One revert step ran to 61.7 ms (run 1, `c`, the first step, 58 reverts): a single
  revert of about 12 ms at a load of 7.8.

## Mode `shipped` after the rewrite, Arch runs 1 - 3 (session, 2026-11-04; D-168, H-26)
H-26's steps 3 - 6 run by the session on Arch at 4bf8f6d: `make test` 151 of 151 as
expected (44.1 s). Logs: `arch-shipped-chunked-run1.log` .. `run3.log`,
`fswatch-chunked` after `shipped` in each as contrast. Load 2.24 - 2.50 at the start
(`make test` 20 s before, this session running).

| criterion | `shipped`, runs 1 - 3 | limit | pass |
|---|---|---|---|
| 1 buffers current after `git` | 0.21 - 0.30 s, no Overflow | 1.0 s | yes |
| 2 edits kept | edit kept; 0 unchanged files' buffers reverted; the deleted file's buffer live, not reverted on `c`, no filter error | - | yes |
| 3 Emacs blocked | 0.07 - 0.09 s (filter's longest call 10.8 - 11.0 ms; revert steps 3 - 4 per checkout, longest 50.3 - 65.1 ms) | 0.25 s | yes |
| 3 shown buffers | queue done 0.45 - 0.54 s after `git`; VC names the branch 3 of 3; 1 diff-hl update each; steps 0.040 - 0.047 s | 15 s | yes |
| 3 showing a hidden buffer | 0.033 - 0.046 s; VC names the branch | 0.25 s | yes |
| 4 idle fswatch | 6 descriptors, 5.2 MB RSS | 16, 12 MB | yes |
| 5 ready, shutdown | 0.01 s; gone | 5 s | yes |
| 6 messages | the edited buffer named on `c` and `a`, the deleted file on `c`, once the queue was empty | - | yes |

Contrast `fswatch-chunked`, the same three runs: Emacs blocked 0.08 - 0.11 s, buffers
current 0.21 - 0.32 s, shown buffers' queue done 0.24 - 0.33 s after `git`.

Verdict: PASS on Arch, criteria 1 - 6; with the Mac's (above) the rewritten module
passes on both machines.

Findings:
- One kind of work per step (D-168) lowers Arch's block from the spike's 0.08 - 0.11 s
  to 0.07 - 0.09 s; the shown buffers' refresh comes about 0.2 s later, as on the Mac.
- On checkout `a` one revert step ran 63.1 - 65.1 ms in each run (on `c` at most
  50.6 ms; the spike's `a` at most 50.5 ms): one revert of 13 - 15 ms that the budget
  cannot split. Which buffer, and whether it is the deleted file's buffer coming back
  to a readable file, is UNVERIFIED.
- The module's filter takes 10.8 - 11.0 ms against the spike's 3.9 - 4.6 ms for the
  same 761 - 763 records; UNVERIFIED where the module spends it (its root and
  opt-out checks per path are the likely part).

