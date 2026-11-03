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
The contrast modes are recorded, not judged. Verdict: FAIL on the Mac (0102), PASS on
Arch (0101); O-78 then ruled (e) (D-153), measured by the mode below.

## Mode `fswatch-shown` (D-153, 2026-11-03)
O-78 (e) with its edge cases (D-151, D-152), in the shipped profile's diff-hl.
- Branch `c`: `b` plus one deleted file, `t000/l01/f000001.cc` (unchanged on `b`);
  `run.sh` adds it to an existing repository. The modes below check out `c`, then `a`.
- diff-hl from `lib/diff-hl`, turned on per visited file as `lisp/init-git.el` does
  (`find-file-hook`, depth 90).
- The reverter skips a file that is not readable (D-152); per filter call one
  `message` names the edited and deleted buffers it skipped (D-151 (2b)).
- `fswatch-shown` (judged): reverts with diff-hl's revert hook held back
  (`after-revert-hook` bound without `diff-hl-after-revert`). A buffer shown in a
  window joins a queue drained one buffer per step (`vc-refresh-state`, then
  `diff-hl-update`), by a one-shot 0.05 s timer armed again after each step; any
  other reverted buffer is marked stale and refreshed at once when a window shows it
  (`window-buffer-change-functions`). Batch Emacs runs no window change functions
  (checked 2026-11-03), so the run calls the handler itself after
  `set-window-buffer`; `wiring.el` checks the hook in a terminal Emacs.
- `fswatch-diffhl` (contrast): no VC refresh, diff-hl's revert hook live; checks the
  0102 follow-up's 3.6 s estimate.
- The run splits the frame into 3 windows showing 3 changed unedited buffers. Per
  checkout it adds: when the shown buffers' queue was done, the queue steps' median
  and longest time, whether the shown buffers' `vc-mode` names the branch, their
  `diff-hl-update` calls, showing one hidden reverted buffer (time, `vc-mode`), the
  deleted file's buffer, the messages.
- `wiring.el`: a terminal Emacs (`-nw` under `script`) records whether
  `window-buffer-change-functions` runs after `switch-to-buffer`, `pop-to-buffer`
  into another window, `xref-pop-to-location` and `tab-bar-switch-to-tab`.

Pass criteria (owner confirmed 2026-11-03 with the session's plan): on the generated
repository, each of the Mac and Arch, three runs of `fswatch-shown`:
1. Current: in each checkout, all 189 unedited changed buffers show the file's text
   within 1.0 s of `git` returning; no Overflow record.
2. Edits kept: the edited buffer keeps its edit and stays modified; no unchanged
   file's buffer is reverted; the deleted file's buffer is not reverted, raises no
   error and stays (D-152).
3. Responsive: diff-hl on in every file buffer; Emacs blocked at most 0.25 s in any
   checkout, VC and diff-hl refresh included; the 3 shown buffers' VC states (the
   mode line names the branch) and diff-hl updates current within 15 s; showing one
   hidden reverted buffer blocks at most 0.25 s and leaves its VC state current.
4. Cost: the idle fswatch holds at most 16 descriptors and 12 MB RSS.
5. Ready within 5 s; no fswatch of the run left after `delete-process`.
6. Message: per checkout the filter's message names the edited buffer, on `c` also
   the deleted file (D-151 (2b), D-152).
7. Wiring (the Mac, terminal Emacs): `window-buffer-change-functions` runs after each
   of the four actions above.

## eglot's share (D-153, 2026-11-03; the Mac)
eglot sends didClose and didOpen on every revert (Emacs 31.1 `eglot.el`), inside the
reverter's filter, and clangd reparses; the generated repository's two-line files
cannot show that. `eglot-share.sh` measures it on a clone of `~/source/repos/RMO-drafts`
(RMO's code on the Mac: 39 tracked files under `src/` and `include/`, deal.II from
`/Applications/deal.II.app`), made once under TMPDIR without touching that tree
(`fmt` from its checkout, no network), configured with `cmake --preset mac-debug`.
Branch `s20-base` is its HEAD, `s20-shift` puts 19 lines in front of all 39 files.
`eglot-share.el` opens the 39 files in `c++-ts-mode` with diff-hl, starts eglot with
the config's clangd command and settings (`lisp/emacs-cpp-presets.el`,
`lisp/init-lsp.el`; the patched clangd), waits until clangd settles, then runs
`fswatch-shown`'s reverter (3 headers shown) over checkouts of `s20-shift` and
`s20-base`. Settled: every reverted buffer had a publishDiagnostics after its didOpen,
clangd was quiet 5 s and used less than 0.1 s of CPU over 5 s (`process-attributes`),
at most 300 s; each judged checkout starts settled. The CPU condition was added by
the owner 2026-11-03 after the dry run: a quiet clangd was still reparsing (its
symbols answered in 2.1 s, the next settle took 57 s) and the next checkout blocked
Emacs 0.326 s. Contrast (recorded): the two checkouts back to back, the second once
clangd is only quiet. Modes: `eglot` (judged), `no-eglot` (contrast, recorded).

Pass criteria (owner confirmed 2026-11-03 with the session's plan), three runs:
- E1 Current: all 39 buffers show the file's text within 1.0 s of `git` returning.
- E2 Responsive: Emacs blocked at most 0.25 s in any wait from `git` until clangd
  settles, eglot's work and the VC and diff-hl refresh included.
- E3 Correct: once settled, the document symbols clangd gives for the 3 shown
  (reverted) headers sit on the buffer lines that name them; none offset by 19.

## Prerequisites
The patched fswatch (`packaging/fswatch-no-loss`): `~/opt/fswatch-no-loss` on the Mac,
`/opt/fswatch-no-loss` on Arch; git; python3; Emacs 31.1 (`EMACS` names it when
`emacs` is not on PATH); `lsof` on the Mac. About 200 MB free under TMPDIR.

## Commands
The session runs it where it runs; the other machine is the owner's (`TODO_human.md`):
```sh
cd ~/source/repos/emacs-cpp
sh spikes/s20-fswatch-reverter/run.sh </dev/null
sh spikes/s20-fswatch-reverter/wiring.sh
```
`S20_MODES="fswatch-shown fswatch-diffhl"` runs the new modes alone. `wiring.sh`
prints the wiring check's result (the Mac only, criterion 7).
The log is `spikes/s20-fswatch-reverter/s20.log`; results go to `RESULTS.md` (Arch
runs 1 - 3 there, the Mac's wait on H-20; `DRY-RUN.md` holds the Mac dry run).
