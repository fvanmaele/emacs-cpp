# 0101 - S20 Arch runs 1 - 3: PASS, Mac left

- **Date:** 2026-11-02
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-148 (gated on S20), D-149 (auto-revert off until the verdict)
- **Done when:** S20's criteria confirmed and three runs of `fswatch-queued` on each
  machine pass them (`spikes/s20-fswatch-reverter/RUN.md`); this entry covers Arch.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
T-128 wants one `fswatch` process per project to tell Emacs which files a `git
checkout` changed, so that buffers without unsaved edits show the new text at once,
instead of `global-auto-revert-mode`, which froze Emacs for about 6 s on the Mac
(O-78). Spike S20 measures this on a generated repository where a checkout changes
190 open files. The owner confirmed the five pass criteria on 2026-11-02 as written;
the session, which runs on the Arch machine this time, ran the spike three times.
All three runs pass all five criteria; details and numbers in
`spikes/s20-fswatch-reverter/RESULTS.md`. The Mac's three runs are H-20.

## Concepts (Emacs Lisp) explained
- A process filter is the function Emacs calls with a chunk of a subprocess's output.
  Emacs does nothing else while it runs, so its duration is time the user is blocked.
- A timer step that handles one buffer and re-arms itself spreads work out: Emacs
  reads keys between steps. `fswatch-queued` does this for VC state (the branch in the
  mode line); the contrast mode `fswatch` does it all inside the filter and blocks
  about 3 s on Arch.

## Key files walked
- `spikes/s20-fswatch-reverter/s20-run.el` - the modes; `fswatch-queued` is judged.
- `spikes/s20-fswatch-reverter/arch-run1.log` .. `arch-run3.log` - the runs.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 190 files is the size that matters (the 2026-10-29 report). **Would
  break if:** larger checkouts are common: Arch's revert pass is one filter call of
  105 - 116 ms at 190 files and grows with the file count (UNVERIFIED). The reverter
  for T-128 should queue reverts too. **DESIGN bet:** D-148.
- **Assumed:** load about 1 with the owner's desktop open counts as idle. **Would
  break if:** the Mac's busy-machine 0.80 s VC step (dry run) shows up when idle;
  that is criterion 3's open risk. **DESIGN bet:** D-148.
- **Assumed:** pkgrel 2 on Arch measures what pkgrel 3 would (0005 is macOS code
  only, S18 run 7). **Would break if:** pkgrel 3 changed inotify code. **DESIGN bet:**
  D-144.

## How to verify
`sh spikes/s20-fswatch-reverter/run.sh </dev/null` on an idle machine; read the
`fswatch-queued` block of `spikes/s20-fswatch-reverter/s20.log` against `RUN.md`.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: real-data rule, the session ran the Arch half itself instead of waiting on
  H-19, because it ran on the machine.
- Hurt: none.
