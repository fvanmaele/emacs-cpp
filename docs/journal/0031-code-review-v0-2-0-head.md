# 0031 - Code review v0.2.0..HEAD folded in

- **Date:** 2026-10-08
- **Commits:** see `git log -1 --grep "code review fold-in"`
- **Tier:** 1 (fixes) / review fold-in
- **Decisions:** D-045, D-048 amended; T-020 opened
- **Done when:** every finding verified against the code and either fixed with a test
  or recorded as not taken with a reason
- **Tag:** none

> Plain English record of what the review found and what was done with it.

## What + why
Before tagging v0.4.0 the owner asked for a code review. A Claude Code review agent
(`/code-review high`) read the 21 commits since v0.2.0, the config, the scripts and
clangd patches 0006 / 0007, and reported 10 candidates. Each was checked against the
code before acting.

## Review fold-in
Source: Claude Code `/code-review high v0.2.0..HEAD`, 2026-10-08. No transcript kept
(the findings are listed here).
- **Taken: the Python project markers did nothing.** `project-vc-extra-root-markers`
  set buffer-locally is ignored: project.el reads it only from dir-locals or its
  global value (`project--value-in-dir`, checked: with projectile's finder removed a
  pyproject-only directory is no project). The test passed through projectile, which
  already treats `pyproject.toml` and `setup.py` as roots. Dead line removed; D-045
  and 0030 corrected.
- **Taken: `measure-startup.sh` could use the real `~/.emacs.d`.** With a tmux server
  already running, a new session gets the server's environment, so `HOME=...` before
  `tmux` was lost (reproduced: the session saw `/home/alad`). Now a private tmux
  server (`-L`) and `env HOME=...` inside the command; checked with another server
  running: the variant's early-init.el in the throwaway HOME was loaded, the owner's
  files untouched. T-008's numbers stand: its variant measured differently, which
  only the throwaway early-init.el can explain.
- **Taken: the debugpy hardening could fail silently.** If dape renamed or reshaped its
  `debugpy` entries, `plist-put` on nil would do nothing and the adapter would listen
  on every interface again. Startup now stops with an error naming the entry.
- **Taken: a commit message opened the tree.** with-editor visits
  `.git/COMMIT_EDITMSG` like any file; files under `.git/` no longer count (test).
- **Taken: one failure stopped the tree for the session.** The "opened" flag is now set
  after the tree is shown.
- **Taken: two manuals with one base name** would overwrite each other in `lib/info/`;
  `make packages` now stops with both paths (test).
- **Taken as a documented limit: remote Python debugging.** Naming `host` stops dape's
  TRAMP handling from filling in the remote host; more basically, the adapter now
  listens on the remote machine's loopback, which dape cannot reach. Remote files are
  outside DESIGN 2; recorded in D-045.
- **Opened as T-020 (owner rules when): clangd waits for the database on every
  lookup.** `includerOf` calls `blockUntilIdle` even when the includer is known; that
  stalls only while the broadcast thread is busy (another project being announced),
  up to 5 s. Same task: the load counter's `++` (enqueue) and `--` (loadProject) are
  in two functions now, and 0007's doc comment is longer than 80 columns. Needs patch
  0008 and a rebuild.
- **Not taken: frame type under `emacs --daemon`.** diff-hl picks fringe or margin
  from the selected frame when it turns on; that matters only with mixed GUI and
  terminal frames of one server. Emacs is not run as a server (D-022).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the review's reading of upstream code (project.el, tmux, dape's TRAMP
  path) was checked here by running or reading the code, not taken on trust; each
  "Taken" names the check.

## How to verify
`make test` (45 tests, the tree and build-packages tests extended); `sh
scripts/measure-startup.sh 1 '(write-region (getenv "HOME") nil "/tmp/h")'` inside
tmux writes the throwaway HOME.
