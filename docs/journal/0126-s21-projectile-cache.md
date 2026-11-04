# 0126 - S21: projectile's lists checked by directory times, PASS with m2

- **Date:** 2026-11-05
- **Commits:** see `git log -- spikes/s21-projectile-cache` (this entry's commit)
- **Tier:** 3 (spike S21, T-133)
- **Decisions:** D-177 (O-85 (f)); S21's criteria confirmed by the owner 2026-11-05
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** S21's criteria 1 - 4 in `spikes/s21-projectile-cache/RUN.md` judged.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c p f` and `M-o` waited for projectile to list the project's files on every call
(444 - 493 ms in emacs-cpp, whose 31 submodules projectile lists one by one). The
owner ruled to keep each project's list and trust it while none of its directories'
modification times has changed (D-177), and asked for a short spike first.

Before the spike the session found that editing itself changes directory times:
Emacs creates a lock file next to a file when its buffer is first modified, and an
auto-save file later, and removes both at save. So the plain check (`m1`) threw the
list away on every call while editing: 60 new listings for 60 calls. Reading only
the changed directory's file names again and ignoring Emacs's own names (`m2`), or
moving those files out of the project (`m3`), kept the list through the whole
editing run with no new listing.

Both `m2` and `m3` pass all four criteria: the list is right after every kind of
outside change tested, a current call costs 4.1 ms in emacs-cpp and 27.7 - 32.4 ms in
deal.II's checkout (limits 10 and 50), and nothing new is written into the
projects. `m2` needs no other change to the config, so T-133 is built with it.

## Concepts (Emacs Lisp) explained
- A directory's modification time changes when an entry in it is created, removed
  or renamed, not when a file's contents change, which is exactly what a file list
  depends on.
- `file-attributes` reads a file's metadata in one system call and returns nil for
  a file that is gone; calling `file-directory-p` first doubled the cost.
- `auto-save-file-name-p` and `backup-file-name-p` are Emacs's own predicates for
  its auto-save and backup names; lock files start with `.#`.
- `:around` advice wraps a function: the cache answers first and calls projectile's
  own listing only when the list is stale.

## Key files walked
- `spikes/s21-projectile-cache/s21.el`, `RUN.md`, `RESULTS.md`.
- `lib/projectile/projectile.el` - `projectile-project-files` (read, unchanged).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** batch Emacs with auto-save turned on and backups allowed stands for an
  interactive session's files. **Would break if:** a mode or package writes other
  files next to edited ones (an undo-tree history, a `.dir-locals` cache); each
  would list anew until treated as Emacs's own. **DESIGN bet:** D-177.
- **Assumed:** the few milliseconds between listing and reading the times hold no
  change worth missing. **Would break if:** a tool writes a file exactly then; the
  file shows at the directory's next change or `C-c p i`. **DESIGN bet:** D-177.
- **Assumed:** Arch's numbers stand for the Mac's (APFS, no measurement yet).
  **Would break if:** `file-attributes` is much slower there; T-133's Mac `make test`
  does not time it. **DESIGN bet:** D-057, D-177.

## How to verify
`REPO=$PWD S21_MODE=m2 S21_TEST=correct emacs -Q --batch -l
spikes/s21-projectile-cache/s21.el`; `S21_TEST=edit S21_ROOT=<a copy>` and
`S21_TEST=time S21_ROOT=<a tree>` likewise.
