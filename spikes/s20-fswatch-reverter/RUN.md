# S20 - one fswatch per project root reverting buffers

## Risk
T-128 (tier 3, owner 2026-10-29), D-147: a buffer without unsaved edits should follow
its file at once on both machines when a program outside Emacs changes it (`git
checkout` in a shell). D-147 ships `global-auto-revert-mode`, polled every 5 s on the
Mac. Question: does one patched fswatch (D-109) on the project root, read by Lisp,
revert every unedited buffer of a large checkout within a second, keep edited buffers,
and keep Emacs responsive, at the cost of one idle fswatch? Spike code is never
promoted; a PASS leads to a DESIGN section and the reverter written fresh in `lisp/`.

## What the spike builds
- `gen_repo.py`: a git repository of 2000 directories and 20000 small `.h` / `.cc`
  files on branch `a`; branch `b` puts 19 lines in front of 190 files spread over the
  tree (the shift of the 2026-10-29 report), its first line naming the branch.
- `s20-run.el`: one batch Emacs (`-Q`) per mode. Batch reads process output and runs
  timers inside `accept-process-output`, which is all fswatch and polling need. It
  opens the 190 files `b` changes and 10 it does not, edits one changed buffer, then
  checks out `b` and `a` again, waiting up to 15 s each time for every unedited
  changed buffer to show the file's first line. Per checkout: `git`'s time, when the
  buffers were current, the reverts (none expected in unchanged files' buffers), the
  edited buffer, the longest single wait step (Emacs blocked), the filter's calls and
  time. Per run: readiness (a probe file reported), the idle fswatch's descriptors and
  RSS, the longest filter call, overflows, the process gone after `delete-process`.
- Modes. The reverter (`-0 -r -x -l 0.1 --allow-overflow -e /.git/` on the root's
  real path) reverts each unedited buffer visiting a reported path whose file is
  newer than the buffer, as `auto-revert-handler` does; they differ in VC's state
  (the mode line's branch), which `auto-revert-handler` refreshes per buffer, one
  `git` process each:
  - `fswatch-queued` (judged): VC states from a queue, one buffer per 0.05 s timer
    step;
  - `fswatch`: VC state at once per buffer, as `auto-revert-handler` (contrast);
  - `fswatch-novc`: no VC refresh (contrast, the reverter's own cost);
  - `poll`: D-147's Mac setting, `global-auto-revert-mode` polling every 5 s
    (contrast).
- `run.sh`: the repository once (kept under TMPDIR for reruns), then the four modes;
  `S20_MODES` picks some.

## Pass criteria (proposed 2026-10-29 after the Mac dry run; owner confirmed 2026-11-02)
On the generated repository, idle machine, each of the Mac and Arch, three runs of
`fswatch-queued`:
1. Current: in each checkout, all 189 unedited changed buffers show the file's text
   within 1.0 s of `git` returning; no Overflow record.
2. Edits kept: the edited buffer keeps its edit and stays modified; no unchanged
   file's buffer is reverted.
3. Responsive: Emacs blocked at most 0.25 s in any checkout, VC refresh included;
   VC states current within 15 s.
4. Cost: the idle fswatch holds at most 16 descriptors and 12 MB RSS (twice D-127's
   8 and 6 MB).
5. Ready within 5 s; no fswatch of the run left after `delete-process`.
The contrast modes are recorded, not judged.

## Prerequisites
The patched fswatch (`packaging/fswatch-no-loss`): `~/opt/fswatch-no-loss` on the Mac,
`/opt/fswatch-no-loss` on Arch; git; python3; Emacs 31.1 (`EMACS` names it when
`emacs` is not on PATH); `lsof` on the Mac. About 200 MB free under TMPDIR.

## Commands
The session runs it where it runs; the other machine is the owner's (`TODO_human.md`):
```sh
cd ~/source/repos/emacs-cpp
sh spikes/s20-fswatch-reverter/run.sh </dev/null
```
The log is `spikes/s20-fswatch-reverter/s20.log`; results go to `RESULTS.md` (Arch
runs 1 - 3 there, the Mac's wait on H-20; `DRY-RUN.md` holds the Mac dry run).
