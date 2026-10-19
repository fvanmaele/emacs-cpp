# 0078 - T-105: `make packages` resets patched files

- **Date:** 2026-10-19
- **Commits:** see `git log --grep T-105` (the code and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-116 (amends D-069)
- **Done when:** ERT on throw-away repositories: an earlier version of a patch in the
  working tree gives way to the current one, a file the series creates is made again
  on a second run, a hand edit in an untouched file stays; a submodule at another
  commit and one not checked out each stop the build with the `git submodule update`
  command that fixes it (both tests fail with the old script); on the repository
  consult-eglot's earlier 0001 applied by hand is replaced, and a deinitialised
  `lib/s` stops the build; `make test` on Arch.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The Arch run of 2026-10-19 hit two failures in `make packages`. consult-eglot's
patch 0001 had grown on the Mac (d06e07e); Arch still had the older version applied.
D-069 took a series out by applying it in reverse, but the reverse of the new patch
does not fit the old one's changes, the failure was ignored, and applying the new
patch over the old stopped the build with "patch does not apply". Second, `lib/eglot`
(added on the Mac, D-108) was an empty directory on Arch, and the build stopped much
later with a missing-file error from autoload generation. Now the files a series
touches are reset to the pinned commit first (D-116), and every submodule is checked
to be checked out at its pin before anything is built.

## Concepts (Emacs Lisp) explained
- **`git apply --numstat -z`** reads patches without applying them and lists each
  file with its added / removed line counts, fields ending in a NUL byte; a renamed
  file comes as an empty name then the old and the new one. `split-string` on `"\0"`
  gives the fields; a `while` loop with `pop` walks them, taking two more for a
  rename.
- **`git checkout HEAD -- FILES`** gives FILES the content of the commit checked out;
  `git cat-file -e HEAD:PATH` tells whether the commit has PATH at all (exit status
  0), so a file a patch creates is deleted instead.
- **`git submodule status`** prints a line per submodule whose first character says
  its state: a space when it is at the pinned commit, `-` not initialised, `+` at
  another commit, `U` in a merge conflict. The build only reads that character.
- **`nreverse`** reverses a list in place; the variable afterwards points into the
  middle of it, so the result is assigned back (`setq`) before the list is used again.

## Key files walked
- `scripts/build-packages.el` - `build-packages-check-submodules` (called first in
  `build-packages-build`), `build-packages-patched-paths`, `build-packages-reset-paths`;
  `build-packages-apply-patches` now resets, then applies, no reverse step.
- `test/build-packages-test.el` - `build-packages-patches-reset-files-first`,
  `build-packages-submodules-checked-out-at-the-pin` (a superproject with a `.gitmodules`
  and a gitlink made in a temporary directory); the pin-bump step of the older test now
  commits the bump, since a working-tree edit is reset.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** nobody keeps hand edits in a file a patch series touches. **Would break
  if:** someone tries a fix there by hand; `make packages` now discards it without a
  word. Such a fix belongs in a patch file (D-069). **DESIGN bet:** D-116.
- **Assumed:** the commit checked out is the pinned one, which the status check makes
  sure of. **Would break if:** someone tries a pin bump without `git add`; the build
  stops and says so, which is the intent.
- **Risk:** a submodule `git submodule status` reports as not initialised although its
  files are there (no `submodule.<name>.url` in `.git/config`, a hand-made clone) now
  stops the build; `git submodule init` fixes it.

## How to verify
- `make packages` twice: "8 patches in force" both times.
- Stale patch: `git show d06e07e^:PATCH > /tmp/old.patch`, PATCH being
  `patches/consult-eglot/0001-Keep-each-server-s-workspace-symbol-reply-in-the-ord.patch`,
  `git -C lib/consult-eglot checkout -- consult-eglot.el`,
  `git -C lib/consult-eglot apply /tmp/old.patch`, then `make packages`: passes, and
  `git -C lib/consult-eglot diff` is the current patch.
- Not checked out: `git submodule deinit lib/s && make packages` stops with
  "submodule(s) not checked out: lib/s" and the command; `git submodule update --init
  lib/s` restores it (from `.git/modules`, no network).
- `make test`: 125 tests, 0 unexpected (Arch, 2026-10-19).
