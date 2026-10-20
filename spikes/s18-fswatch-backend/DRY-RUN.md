# S18 dry run - Mac, 2026-10-20

Not the verdict: D-127 asks for both machines; `RESULTS.md` follows the owner's Arch run.
On the Mac all five proposed criteria hold.

## Environment
The owner's Mac (Apple silicon, 11 cores), MacPorts Emacs 31.1 (eglot 1.24.31), the
patched fswatch 1.22.0 pkgrel 2 (`~/opt/fswatch-no-loss`, rebuilt the same day), pyright
from MacPorts, load 2.2 - 3.5. Tree from `gen_tree.py` under TMPDIR: 15625 directories
(15408 generated plus the parents), 187395 files, committed. Logs:
`dry-run-mac-run1.log` (all four runs), `dry-run-mac-run2.log` (the two fswatch runs
again, counting distinct files).

## Measurements
| run | registration | ready | burst at the server | overflow | Emacs CPU / 1000 records | left after shutdown |
|---|---|---|---|---|---|---|
| baseline (Emacs's watches) | error: "no file descriptor left" 975 | no | 0 of 20000 | - | - | 0 |
| fswatch, eglot's matcher | ok, 0.00 s in Emacs | 0.05 - 0.06 s | 20000 of 20000 (1 repeat) | 0 | 9 ms | 0 |
| fswatch, regexp matcher | ok, 0.00 s in Emacs | 0.05 - 0.06 s | 20000 of 20000 (0 - 4 repeats) | 0 | 6 - 7 ms | 0 |
| fswatch, pyright | ok; pyright alive after 30 s; 4 fswatch processes | - | - | - | - | 0 |

The burst took 11 - 13 s from its start to the last change at the server, Emacs blocked
for the first 5 s: the records waited in fswatch's queue (patch 0001), none lost.

## Reading
- Criteria 1 - 5 hold on the Mac; the baseline fails as RESEARCH 3.1 predicts (kqueue's
  975 descriptors), with eglot answering the registration with an error.
- The 2026-10-15 prototype's 190 ms per 1000 records does not recur: eglot's own glob
  predicates cost 9 ms per 1000 here, the regexps 6 - 7. The app code can keep eglot's
  predicates and drop the advice on `eglot--glob-compile` (one internal fewer).
- FSEvents reports a few files as created twice (0 - 4 in 20000): the backend should
  drop a repeated (URI, type) inside one batch.
- pyright's three registrations made 4 processes: with `-Q`,
  `eglot-watch-files-outside-project-root` is t, so roots outside the project were
  watched too. The shipped config sets it to nil (D-121); one process per server and
  root, shared by its registrations (as D-121's directory sharing), is the app shape.
- Internals the backend touches: `eglot--watch-globs` (overridden), `eglot--on-shutdown`
  (wrapped), `eglot--project`; the version pin of `lisp/emacs-cpp-eglot-watch.el`
  (D-121) covers them.

## Gotchas
- Batch Emacs delivers no `file-notify` events (neither `accept-process-output` nor
  `sit-for`): Emacs's own watches can only be measured in an interactive Emacs, so the
  harness runs `emacs -nw` in tmux. The config's existing watch tests check
  registrations, never deliveries.
- A throwaway HOME changes `~`: the fswatch path is passed in absolute (S18_FSWATCH).
- The burst files stay in the tree (247398 files after two runs); `gen_tree.py` refuses
  an existing root, so delete the tree to start afresh.
