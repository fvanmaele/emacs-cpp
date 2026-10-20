# S18 - an fswatch backend for eglot

## Risk
D-127 (owner 2026-10-20, O-70 (b): "O-70 (b) agree"): watches must work on very large
projects on both machines. Emacs's own watches cannot: on the Mac kqueue takes one
descriptor per directory and Emacs stops at 975; on Arch eglot stops at 10000 and then
fails the whole registration, and pyright exits (RESEARCH_platform_differences 3.1,
3.3, 3.14). Question: does one patched fswatch (D-109) per registration and root, read
by Lisp over the built-in eglot (1.24.31), deliver every change of a large burst on an
LLVM-sized tree to the server, while Emacs is blocked, at a CPU cost Emacs can carry?
Spike code is never promoted; a PASS leads to DESIGN 7.1 rewritten for the built-in
eglot and the backend written fresh in `lisp/`.

## What the spike builds
- `gen_tree.py`: 15408 directories, 187395 small `.c` / `.h` files (3.12's size, LLVM's
  checkout has 16993 / 187428), `git init` and one commit.
- `burst.py`: 20000 new `.py` files over 200 directories, as fast as Python writes.
- `fake_server.py`: a language server that registers pyright's kind of watchers
  (`**/*.{py,pyi}`, `**/*.{c,h}`, `**/pyrightconfig.json`) and logs every change it
  is told about: the count is exact.
- `s18-backend.el`: overrides `eglot--watch-globs` (one fswatch per registration and
  root, `-0 -r -x -l 0.1 --allow-overflow -e /.git/`, the real path mapped back to the
  root's spelling), wraps `eglot-unregister-capability` and `eglot--on-shutdown` (the
  processes end with the registration), matches each record by eglot's compiled glob
  predicates (`eglot`) or by one regexp per glob (`regexp`), and sends one
  `workspace/didChangeWatchedFiles` per filter call.
- `s18-run.el`: one run in an interactive `emacs -nw -Q` (batch Emacs does not deliver
  `file-notify` events, so the baseline could not be measured there): connect, the
  registration's answer, readiness (a probe file reported back), then the burst with
  Emacs blocked for its first 5 s (no output read), the count at the server, the records
  read, Emacs's CPU after the block per 1000 records, the processes left after
  shutdown. With pyright: the registration on the tree and pyright alive 30 s later.
- `run.sh`: the tree once (kept under TMPDIR for reruns), then four runs in a private
  tmux server with a throwaway HOME: `baseline` (Emacs's own watches), `eglot`, `regexp`
  against the fake server, `regexp` against pyright.

## Pass criteria (proposed 2026-10-20; owner to confirm)
On the generated tree, idle machine, each of the Mac and Arch:
1. Registration: the fswatch modes answer it with success and no warning; pyright is
   alive 30 s after its registrations.
2. Delivery: 20000 of 20000 created files reach the fake server with Emacs blocked for
   the burst's first 5 s; no Overflow record.
3. Cost: Emacs's CPU after the block at most 50 ms per 1000 records with the faster
   matcher (the 2026-10-15 prototype: about 190 ms).
4. Ready: a probe change reported within 5 s of the registration (inotify adds one
   watch per directory at start on Arch).
5. Shutdown: no fswatch process of the run left.
The baseline is recorded for contrast, not judged.

## Prerequisites
The patched fswatch (`packaging/fswatch-no-loss`, pkgrel 2): `~/opt/fswatch-no-loss`
on the Mac, `/opt/fswatch-no-loss` on Arch; tmux; python3; pyright; Emacs 31.1 with
eglot 1.24.31. About 2 GB free under TMPDIR for the tree.

## Commands
The session runs it on the Mac. The owner on Arch (`TODO_human.md`):
```sh
cd ~/source/repos/emacs-cpp
sh spikes/s18-fswatch-backend/run.sh 20000 </dev/null
```
The log is `spikes/s18-fswatch-backend/s18.log`; results go to `RESULTS.md` once both
machines have run (`DRY-RUN.md` holds the Mac run).
