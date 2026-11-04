# S21 - projectile's lists checked by directory times

## Risk
D-177 (O-85 (f)), T-133 tier 3 (owner 2026-11-05: "Tier 3 with short spike"): the
projectile setup keeps each root's list and serves it while its directories'
modification times hold. Found before the spike (2026-11-05, batch Emacs, the config's
defaults): Emacs's own lock file (`.#name`, made at a buffer's first modification,
removed at save) changes the directory's time on every edit and save cycle, so a
plain check would list anew after every edit. Question: which check keeps the list
correct, fast, and cached through ordinary editing?

## What the spike builds
`s21.el` (NEW), batch Emacs with the pinned projectile, an `:around` advice on
`projectile-project-files` in three modes:
- `m1`: the plain check (D-177 as written): any changed directory time, list anew.
- `m2`: a changed directory's entry names read again (`directory-files`); a difference
  of Emacs's own names only (lock `.#`, auto-save `#...#`, backup `~`, as
  `auto-save-file-name-p` and `backup-file-name-p` tell them) keeps the list and the
  new time; any other difference lists anew.
- `m3`: `m1` with Emacs's lock, auto-save and backup files written outside project
  directories (`lock-file-name-transforms`, `auto-save-file-name-transforms`,
  `backup-directory-alist` to the spike's temporary directory).
Run against a temporary git repository and copies of emacs-cpp, RMO-drafts and the
deal.II checkout (in the session's scratch directory).

## Pass criteria (proposed 2026-11-05, for the owner)
On Arch (hp-elitedesk), for the mode that passes:
1. Correct: after each of a file created, removed and renamed outside Emacs, a new
   directory with a file, a file added to a directory that held no listed file, and
   a `git checkout` that adds and removes files, the served list equals a fresh
   uncached projectile listing (as sets).
2. Cached through editing: modifying and saving 20 files of the emacs-cpp copy in
   turn (lock, auto-save and backup files as the mode leaves them) lists anew at most
   once.
3. Fast: a call with the list current at most 10 ms on emacs-cpp and at most 50 ms on
   deal.II (medians of 7; today 444 - 493 and 68 - 75 ms).
4. Nothing written into the projects but what Emacs writes today (`m3`: less).
A PASS of `m2` builds T-133 as D-177 with `m2`'s check; a PASS of `m3` only needs the
owner's ruling on moving Emacs's files out of project directories first.
