# 0071 - T-080: `make test` in a temporary HOME

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`Makefile`, DESIGN, CLAUDE.md,
  README, TASKS, POSTMORTEM)
- **Tier:** 2
- **Decisions:** D-104 (built here), O-54 (b)
- **Done when:** `make test` creates an empty temporary HOME (mktemp -d), runs ERT
  with HOME set to it, deletes it afterwards, keeps ERT's exit status. The runner
  checks first, in that Emacs, that HOME is not the real home (`~` vs `~USER`) and
  stops with an error otherwise. `make test REAL_HOME=1` runs in the real HOME as
  before, no check. Test files unchanged; the 7416ce8 project-list-file redirect
  stays. Evidence: make test on the Mac leaves the real home unchanged (snapshot
  before/after, ~/.python_history included), REAL_HOME=1 still passes, the check
  refuses when the temporary HOME is bypassed. Arch run by the owner. Met on the Mac.
- **Tag:** none

> Plain English for someone who does not read make or shell fluently.

## What + why
Twice a test run wrote into the owner's home: the startup measurements through tmux
(2026-10-07) and `make test` appending temporary projects to
`~/.emacs.d/projects.eld` (7416ce8). Each leak was fixed where it was found; the
POSTMORTEM entry of 2026-10-14 asked for a fix that covers the next one too (O-54).
`make test` now gives the whole run an empty home of its own. Programs find files
such as `~/.emacs.d`, `~/.python_history` or `~/.config` through HOME, so whatever a
test or a package writes lands in the temporary directory, which is deleted
afterwards. The run that measured this found one more leak no one had noticed: a
real-HOME run rewrites `~/.python_history` (a Python test's interpreter).

## Concepts explained
- **`HOME=dir command`** sets the variable for that one command. Emacs, Python, git
  and the shell read it to find the user's files.
- **`~USER` versus `~`:** `~` follows HOME; `~fvanmaele` is looked up in the user
  database and stays the real home. The runner compares the two in the test Emacs
  itself, so it notices if HOME did not reach it (as tmux once swallowed it).
- **`trap ... EXIT`** runs the clean-up when the recipe's shell ends, however the
  tests end; the shell's exit status stays ERT's. `trap 'exit 130' INT TERM` makes
  Ctrl-C end the shell, so the clean-up runs then too.
- **`ifeq ($(REAL_HOME),)`** chooses the recipe when make reads the Makefile:
  `make test REAL_HOME=1` gets the old command, without the check.

## Key files walked
- `Makefile` - `HOME_CHECK` (the comparison), `ERT` (the run, shared by both modes),
  the `test` recipe.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** nothing in the suite needs the owner's home: measured, 113 tests give
  the same results in an empty HOME on the Mac. **Would break if:** a tool reads its
  setup from the home on Arch: gdb's `~/.config/gdb/gdbinit` (debuginfod answers,
  auto-load paths) is not read now; the gdb tests skip on the Mac, so the owner's Arch
  run is the check. **DESIGN bet:** D-104.
- **Assumed:** paths handed in from outside are absolute
  (`EMACS_CPP_PATCHED_CLANGD=$HOME/...` is expanded by the calling shell). **Would
  break if:** one is given as a literal `~/...` and expanded inside the test Emacs: it
  would then point into the temporary home.
- **Risk:** writes outside HOME (`/tmp`, a project's own directory) are not covered;
  the tests already create their projects in temporary directories.

## How to verify
- `make test`: the first line names the temporary HOME; the directory is gone after.
- `make test REAL_HOME=1`: the old behaviour.
- On the Mac, 2026-10-14: snapshots of `~/.emacs.d` and HOME's top level before and
  after `make test`: no change from the tests. Two runs showed changes from the
  owner's running Emacs (`history`, `auto-save-list/`, `projectile-bookmarks.eld`);
  the same changes appeared in 60 s without any test, and no test file run alone in a
  temporary HOME touched the real home.
