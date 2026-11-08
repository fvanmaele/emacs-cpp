# 0103 - S20 `fswatch-shown`: PASS on the Mac, Arch left

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit);
  0a11d93 (D-153)
- **Tier:** 3 (spike S20)
- **Decisions:** D-153 (O-78 (e)), D-151, D-152 (its edge cases)
- **Done when:** three runs of `fswatch-shown` on each machine pass the criteria in
  `spikes/s20-fswatch-reverter/RUN.md` (confirmed with the session's plan
  2026-11-03); this entry covers the Mac.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
S20 failed on the Mac (0102): refreshing every reverted buffer's version-control state
from a repeating timer blocked Emacs up to 0.35 s, and diff-hl, which the shipped
profile loads, would have added about 3.6 s. The owner ruled O-78 (e) (D-153): revert
every unedited buffer at once, but refresh VC state and diff-hl's fringe marks only
for buffers a window shows; the others wait until a window shows them. The new mode
`fswatch-shown` measures that, with diff-hl loaded as the config loads it, plus the
edge cases the owner ruled the same day: a buffer with unsaved edits is skipped and
named in one message (D-151), a deleted file's buffer is skipped and named too
(D-152).

On the Mac all seven criteria hold in three runs. A 190-file checkout leaves every
unedited buffer current 0.13 - 0.19 s after `git`, Emacs is blocked at most 0.13 s,
the three shown buffers have the new branch and fresh marks 0.28 - 0.33 s after `git`,
and showing one of the 186 hidden ones costs about 0.05 s. The contrast mode, with
diff-hl's own revert hook left in place, blocks Emacs 2.2 - 2.5 s per checkout:
holding that hook back is what makes the difference. Numbers per run in
`spikes/s20-fswatch-reverter/RESULTS.md`.

## Concepts (Emacs Lisp) explained
- Holding a hook back for one call: `after-revert-hook` is buffer-local in diff-hl's
  buffers. `(let ((after-revert-hook (remq 'diff-hl-after-revert after-revert-hook)))
  (revert-buffer t t t))` binds the buffer's own value without diff-hl's function for
  the duration of the revert only; the global part (`t` in the list) still runs.
  Measured: one revert 0.9 ms instead of 23 ms.
- A one-shot timer armed again after each step: `(run-with-timer 0.05 nil fn)` runs
  `fn` once; `fn` arms the next one when it has finished. A repeating timer is due
  again on a fixed schedule and catches up after a slow step, which ran several steps
  back to back in 0102; the one-shot form always leaves 0.05 s between steps.
- `window-buffer-change-functions` runs during redisplay when a window shows another
  buffer. Batch Emacs never redisplays, so the spike calls the handler itself;
  `wiring.el` checks the real hook in a terminal Emacs started under `script(1)`, with
  a control action (a message) that must not run it.
- `file-readable-p` before `revert-buffer`: reverting a buffer whose file is gone
  signals `"File %s no longer exists!"`; inside a process filter that error ends the
  call and the rest of the batch stays stale (D-152).

## Key files walked
- `spikes/s20-fswatch-reverter/s20-run.el` - `s20--revert` (the guard, the held-back
  hook, queue or stale mark), `s20--shown-step` and `s20--queue-shown` (the queue),
  `s20--on-show` (the show handler), `s20--message-skipped`, `s20--shown-report`.
- `spikes/s20-fswatch-reverter/run.sh` - branch `c` added in place, diff-hl's path.
- `spikes/s20-fswatch-reverter/wiring.el`, `wiring.sh` - criterion 7.
- `spikes/s20-fswatch-reverter/mac-shown-run1.log` .. `mac-shown-run3.log` - the runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the handler called directly in batch costs what the hook's call costs
  in a running Emacs. **Would break if:** redisplay adds work per show beyond the
  handler (the hook's dispatch is Emacs's C code; unmeasured). **DESIGN bet:** D-153.
- **Assumed:** 3 shown buffers stand for daily use. **Would break if:** many windows
  or frames show reverted buffers at once; the queue then runs one step of about
  0.05 s per buffer, still one at a time. **DESIGN bet:** D-153.
- **Assumed:** load 2.5 - 4.3 with Emacs.app open is representative. **Would break
  if:** heavier load stretches one step past 0.25 s (longest seen 0.085 s).
  **DESIGN bet:** D-153.
- **Assumed:** eglot's didClose / didOpen per revert stays small. **Would break if:**
  RMO shows it stretches the filter; then D-151 (1b) and the filter's cost are
  revisited. **DESIGN bet:** D-151, D-153.

## How to verify
On the Mac: `S20_MODES="fswatch-shown fswatch-diffhl" sh
spikes/s20-fswatch-reverter/run.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/s20.log` against `RUN.md`'s criteria 1 - 6;
`sh spikes/s20-fswatch-reverter/wiring.sh` prints criterion 7. Arch: H-22.
