# 0087 - S18: an fswatch backend for eglot, Mac dry run

- **Date:** 2026-10-20
- **Commits:** see `git log -1 --grep "S18"`
- **Tier:** 3 (spike S18, D-127)
- **Decisions:** D-127 (spike first); no new decision
- **Done when:** RUN.md with pass criteria for the owner to confirm; the Mac run done
  here; the Arch run handed over (H-12)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner ruled (D-127) that watches must work on very large projects on both machines
through fswatch, spike first. The spike replaces the function of Emacs's own eglot
that sets up watches (`eglot--watch-globs`) by one that starts one patched fswatch per
registration and root and turns its records into `workspace/didChangeWatchedFiles`
notifications. A fake language server counts every change it is told about, so
"every change arrives" is a count, not an impression. On the Mac, on a tree of
LLVM's size: Emacs's own watches fail (kqueue stops at 975 directories, eglot answers
the server with an error); the fswatch backend delivers 20000 of 20000 new files
while Emacs is blocked for 5 s, at 7 - 9 ms of Emacs's CPU per 1000 records, and
leaves no process behind. pyright stays up on the tree.

## Concepts (Emacs Lisp) explained
- `advice-add ... :override` replaces a function's body for the session; the spike
  does that to one eglot internal, as `lisp/emacs-cpp-eglot-watch.el` does today.
- A process filter is a function Emacs calls with whatever text a subprocess wrote;
  the backend keeps an unfinished record between calls and splits the rest on NUL.
- Batch Emacs (`--batch`) runs no command loop, and file-watch events arrive through
  it: so Emacs's own watches report nothing in batch, and the spike measures in an
  interactive Emacs inside tmux.

## Key files walked
- `spikes/s18-fswatch-backend/s18-backend.el` - `s18--watch-globs`, `s18--filter`.
- `spikes/s18-fswatch-backend/s18-run.el` - one measured run; `run.sh` - all four.
- `spikes/s18-fswatch-backend/DRY-RUN.md` - the numbers and what they mean for the app.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the fake server's watcher globs stand for pyright's and texlab's.
  **Would break if:** a server registers globs eglot's predicates match slowly;
  the regexp matcher stays measured as the fallback. **DESIGN bet:** D-127.
- **Assumed:** Arch behaves like the Mac with inotify (one kernel watch per directory,
  15625 here, far below the kernel's limit). **Would break if:** fswatch's inotify
  start on 15625 directories is slow, or the owner's `max_user_watches` is low;
  criterion 4 and H-12 decide.
- **Risk:** the app code overrides an eglot internal under D-121's version pin; every
  Emacs release means re-reading `eglot--watch-globs`.

## How to verify
`sh spikes/s18-fswatch-backend/run.sh 20000 </dev/null` on an idle machine (about 10
minutes the first time, the tree included).

## Open questions (optional)
None new; the owner confirms the five criteria with H-12.
