# 0046 - T-044: fixes to vendored packages as patch files

- **Date:** 2026-10-10
- **Commits:** the commit that adds this entry (`scripts/build-packages.el`,
  `.gitmodules`, `patches/treemacs/`, `lisp/init-project.el`, tests)
- **Tier:** 2
- **Decisions:** D-069 (built here); replaces D-067's stand-in timer
- **Done when:** a repeatable `.gitmodules` key `patch`; `make packages` applies each
  series before compiling, a second run is safe, a patch that does not apply stops the
  build with git's message; a missing listed patch and an unlisted patch file are
  errors; T-041's fix moves into `patches/treemacs/0001` and the Lisp workaround goes;
  tests fail on the old code; DESIGN 12, README, journal (agreed 2026-10-10).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
The packages are git submodules pinned to upstream commits (D-006). When one has a bug
upstream has not fixed yet, there was no place for a fix: a commit inside the
submodule exists on no remote, so a fresh clone could not check it out; a fork means
a GitHub repository to keep in step; a workaround in `lisp/` leans on the package's
internals (the treemacs timer of D-067 was one).

Now a fix is a patch file in this repository, `patches/<package>/NNNN-*.patch`, made
with `git format-patch` against the pinned commit and listed in `.gitmodules` with a
`patch = ...` line. `make packages` applies the patches before byte-compiling, so the
compiled package carries the fix. The first one is the treemacs fix drafted for
upstream (T-041); its Lisp workaround is gone.

## Concepts explained
- **`git apply` is all or nothing.** It checks every hunk of every patch given and
  changes no file unless all fit. A patch that no longer fits the code (after a pin
  bump, or a hand edit in `lib/`) leaves the files untouched and stops the build.
- **A second run.** After the first `make packages` the patches are already in, and
  applying them again would fail. So each submodule's series is first taken back out,
  whole and in reverse order (`git apply --reverse`); if that works, the files are back
  at the pin, and the series is applied again. If it does not (the patches were not
  in), nothing changed and the series is applied once.
- **Why not `git apply --check` to ask "already in?".** Found by the new test:
  `--check` looks at each patch against the files on disk, not against the result of
  the patches before it, so two patches touching the same lines always look as if they
  did not fit. A real reverse chains them correctly.
- **Unlisted patch files are errors.** A patch file with no `patch` line would
  silently not be applied; the build refuses instead, like a stale `build-exclude`.

## Key files walked
- `scripts/build-packages.el` - `build-packages-patch-files` (listed, must exist),
  `build-packages-check-unlisted-patches`, `build-packages-apply-patches` (the series
  logic); called first in `build-packages-build`.
- `.gitmodules` - the treemacs section's `patch` line.
- `patches/treemacs/0001-Don-t-cancel-a-missing-timer-...patch` - the T-041 fix.
- `lisp/init-project.el` - `emacs-cpp-tree--apply-follow` without the stand-in timer.
- `test/build-packages-test.el` - `build-packages-patches-apply-once-and-fail-loudly`:
  a throw-away repository with two stacked patches; apply, apply again, a moved pin,
  a missing and an unlisted patch.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** patches stay few and small, each with an upstream report. **Would break
  if:** a package collects many long-lived changes; then a fork is the better home.
  **DESIGN bet:** D-069.
- **Risk:** `git submodule update` after a pin bump may refuse because of the patched
  files; README says to run `git -C lib/<name> checkout -- .` first.
- **Risk:** a patch upstream has taken, left in after a pin bump, no longer applies
  (the change is already there) and stops the build. That is the signal to delete it
  and its `.gitmodules` line.
- **Risk:** hand edits in a patched submodule's files make the series fail to reverse
  and to apply; the build stops rather than mixing them.

## How to verify
`make packages` twice: both print "1 patches in force". `git -C lib/treemacs diff`
shows the fix. `make test`. Negative control (done): the patch taken out and the file
recompiled, `init-treemacs-follow-options` fails with `(wrong-type-argument timerp
nil)`; `make packages` puts it back.
