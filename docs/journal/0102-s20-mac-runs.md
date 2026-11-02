# 0102 - S20 Mac runs 1 - 6: FAIL on VC refresh steps

- **Date:** 2026-11-02
- **Commits:** db30ea7 (`run.sh` stops on an emptied repository); see `git log --
  spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-148, D-149 (S20 failed, so O-78 reopens)
- **Done when:** S20's criteria confirmed and three runs of `fswatch-queued` on each
  machine pass them (`spikes/s20-fswatch-reverter/RUN.md`); this entry covers the Mac.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The Mac's half of spike S20 (H-20), run by the session on the Mac. The reverter
itself works on the Mac as on Arch: every unedited buffer of a 190-file checkout is
current within 0.31 s, the edited buffer keeps its edit, the idle fswatch is small
and stops cleanly. What fails is criterion 3: after the reverts, the judged mode
refreshes each buffer's VC state (the branch in the mode line) one buffer per timer
step, and on the Mac a single step blocks Emacs 0.20 - 0.35 s, over the 0.25 s
limit, in all three judged runs. Without the VC refresh, the whole checkout blocks
Emacs at most 0.09 s. Numbers per run in `spikes/s20-fswatch-reverter/RESULTS.md`.

Runs 1 - 3 ran with Emacs.app open at load 2.4 - 3.4 (H-20 asked for Emacs quit);
the owner ruled them evidence only and asked for idle reruns. Runs 4 - 6 ran with
Emacs.app quit after 60 s to settle, at load 2.2 - 2.7, and are the judged ones.
D-148 and D-149 say O-78 reopens if S20 fails; DESIGN's O-78 now lists options (e) -
(i), and H-21 asks the owner to rule.

Before run 1 every run died after the log's header: macOS had emptied the kept
repository under TMPDIR (files unused for 3 days are deleted, directories kept), and
`run.sh` only checked that the directory exists. The empty directory was removed and
the repository regenerated; `run.sh` now stops with a message on such a directory
(db30ea7).

## Concepts (Emacs Lisp) explained
- `vc-refresh-state` recomputes a buffer's version-control state for the mode line.
  It runs `git` synchronously: Emacs waits for each process before doing anything
  else. Measured in a batch Emacs on this repository: 8 `git` processes per call,
  35 - 45 ms when nothing changed; right after a checkout the queued calls take up to
  8 times that (cause UNVERIFIED). (Superseded by the follow-up below: one call stays
  at 34 - 95 ms; a block is several calls in one wait.)
- `accept-process-output` lets Emacs read subprocess output and run due timers. The
  spike's "blocked" figure is the longest single such call, so a VC timer step that
  fires during the reverts counts in the reverts' figure too (runs 1 and 2: 0.44 s
  and 0.33 s while the buffers were still being reverted).
- `window-buffer-change-functions` (Emacs 27 and later, present in 31.1) runs when a
  window starts showing another buffer; option (e) of O-78 would refresh VC state
  there instead of for every reverted buffer.

## Key files walked
- `spikes/s20-fswatch-reverter/s20-run.el` - `s20--queue-vc`, the timer that refreshes
  one buffer's VC state every 0.05 s; `s20--wait`, which records the longest block.
- `spikes/s20-fswatch-reverter/run.sh` - the new check after the repository step.
- `spikes/s20-fswatch-reverter/mac-run1.log` .. `mac-run6.log` - the runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** load 2.2 - 2.7 with Emacs.app quit is this Mac's idle. **Would break
  if:** a quieter Mac (no G DATA scanner, Spotlight done) passes criterion 3; the
  verdict is still the one daily use sees, as Emacs runs on this machine as it is.
  **DESIGN bet:** D-148.
- **Assumed:** the VC refresh, not the reverter, is what fails. **Would break if:**
  larger checkouts make the revert pass itself exceed 0.25 s (Arch: 105 - 116 ms at
  190 files, 0101). **DESIGN bet:** O-78 (e). (Broken the same day for the shipped
  profile: diff-hl adds 19 ms per revert, about 3.6 s for 189; follow-up below.)
- **Assumed:** the cost is `git`'s process starts. **Would break if:** the slow
  steps come from `git` refreshing its index after the checkout (UNVERIFIED; the
  quiet-tree cost is 8 times lower). **DESIGN bet:** O-78. (Broken the same day:
  neither; the queue's timer runs several steps in one wait; follow-up below.)

## How to verify
On the Mac with Emacs quit: `sh spikes/s20-fswatch-reverter/run.sh </dev/null` and
read the `fswatch-queued` block of `spikes/s20-fswatch-reverter/s20.log`: the
`VC states ... Emacs blocked at most` line against criterion 3's 0.25 s.

## Follow-up: O-78's options revisited (same day)
On the owner's request the session checked the premises under options (e) - (i)
before the ruling; numbers in `RESULTS.md`, follow-up. Three changed the options:
the 0.20 - 0.35 s blocks are S20's repeating timer running 2 - 4 VC steps in one
wait (`wait-trace.el`), not slow `git`; the config's diff-hl runs 2 `git` processes
synchronously on every revert, 19 ms each time, which S20's `emacs -Q` never saw
(`vc-cost.el`), so the reverter itself would block about 3.6 s in the shipped profile;
and `magit-auto-revert-mode` turns itself on once magit loads, reverting with the
same per-buffer VC cost (read from the source). DESIGN's O-78 now carries the
revised (e) - (i); every option but (i) needs a new S20 mode with diff-hl loaded.
The lesson for the next spike: run it in the profile the config ships (CLAUDE.md,
Tests), or list what `-Q` leaves out.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: the choice rule; asking whether busy runs count turned up the idle reruns,
  which removed the doubt from the FAIL.
- Hurt: none.
