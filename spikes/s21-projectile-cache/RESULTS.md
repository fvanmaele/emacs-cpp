# S21 results

Verdict: PASS (2026-11-05, session, hp-elitedesk) for modes `m2` and `m3`, criteria 1 - 4;
`m1` (D-177's plain check) FAILS criterion 2. By RUN.md, `m2`'s PASS lets T-133 be
built as D-177 with `m2`'s check; `m3` would first need the owner's ruling on moving
Emacs's lock and auto-save files out of project directories.

## Setup
Host hp-elitedesk (i5-6500, 4 cores, Arch), GNU Emacs 31.1 in batch, the pinned
projectile 3.4.0. `s21.el` (an `:around` advice on `projectile-project-files`);
the correctness test in a temporary git repository; the editing test on `rsync`
copies of emacs-cpp (without `indexes/` and the LLVM tree, both ignored) in the
session's scratch directory, one fresh copy per mode, backups enabled for `/tmp`
and auto-save on as in an interactive session; the timing test reading the real
trees (emacs-cpp, RMO-drafts, the deal.II checkout), each run started at load below
0.6.

## Criteria
| # | criterion | m1 | m2 | m3 | limit |
|---|---|---|---|---|---|
| 1 | served list equals a fresh listing after: file created, removed, renamed outside Emacs; new directory with a file; file in a directory that held none; `git checkout` adding and removing files | same, all | same, all | same, all | - |
| 2 | 20 files of emacs-cpp modified, auto-saved and saved in turn, a listing after each step (60 calls): listings anew | 60 | **0** | **0** | at most 1 |
| 3 | a call with the list current, median of 7: emacs-cpp / RMO-drafts / deal.II | - | 4.10 / 0.90 / 27.70 ms | 4.10 / 0.85 / 32.40 ms | 10 / - / 50 ms |
| 4 | nothing written into the projects beyond Emacs's own files | yes | yes | yes, fewer (lock and auto-save files elsewhere) | - |
Also checked: a file written into an existing ignored directory (`build/`) lists
nothing anew (its directory is not checked); creating `build/` itself does (a new
entry in the root).

## Findings
- Emacs changes directory times while editing: a buffer's lock file (`.#name`, a
  symlink to a missing target) at its first modification, the auto-save file
  (`#name#`) at auto-save, both removed at save. A plain check (`m1`) lists anew on
  every call while a file is being edited; `m2` re-reads only the changed
  directory's names and keeps the list when only those names moved.
- No backup files (`name~`) appear for files under version control
  (`vc-make-backup-files` nil); for other files, `m2` treats them as Emacs's own.
- The check is one `file-attributes` per directory: the first version read each
  directory twice (`file-directory-p`, then its time) and took 56.3 ms on deal.II;
  one read per directory 27.7 ms.
- Directories checked: those holding listed files, their ancestors, and their
  subdirectories that hold none and are not ignored (`git check-ignore --stdin`,
  one process per listing), so a file landing in an empty directory is seen and a
  build tree never counts.
- Limit: the times are read right after the listing; a change in between (a few
  milliseconds) goes unseen until the next change of structure in that directory.
  A `.gitignore` edit that moves no file is seen only at the next change of
  structure (D-177).
- The first call per root costs a listing as today (444 - 493 ms on emacs-cpp) plus
  reading the directories; every call after a change of structure the same.

## Logs
The test runs' lines are quoted above; `s21.el` reproduces each:
`REPO=... S21_MODE=m2 S21_TEST=correct|edit|time [S21_ROOT=...] emacs -Q --batch -l
spikes/s21-projectile-cache/s21.el`.
