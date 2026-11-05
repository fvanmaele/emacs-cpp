# 0130 - T-133: one fd listing per project, projectile's submodule pass off

- **Date:** 2026-11-05
- **Commits:** see `git log -- lisp/init-project.el` (this entry's commit)
- **Tier:** 2 (owner 2026-11-05: "(h) as tier 2")
- **Decisions:** D-183 (O-85 (h)); within D-179 (no call slower than today)
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** T-133's seven points (TASKS.md, agreed 2026-11-05); 1 - 6 met on Arch
  (5: see below), 7 on the Mac 2026-11-06 (below).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c p f` and `M-o` waited for projectile to list the project on every call, 426 -
493 ms in this repository. The time was not the listing itself: projectile lists a
git project with one `fd` over its root, which already walks into every submodule,
and then listed each of the 31 submodules again, adding every submodule file a second
time (7235 entries for 3903 files; `M-o` showed both). The config now turns that
second pass off (`projectile-git-submodule-command` nil) and keeps `fd` for git
listings. A call costs 15.5 ms here, 10.9 ms in RMO-drafts, and the same as before in
trees without submodules. There is still no cache: every call lists anew, so a file
created by a checkout or a shell shows at once.

Without `fd`, projectile would fall back to `git ls-files`, which does not enter
submodules; with the pass off their files would vanish without a word. So startup
stops with an error naming `fd` when it is not found, as it does for ripgrep (D-081).

Point 5 (Arch, batch Emacs, the pinned projectile, medians of 7, load below 0.6):
| tree | entries today | today | entries now | now | files |
|---|---|---|---|---|---|
| emacs-cpp (31 submodules) | 7235 | 434.0 ms | 3903 | 15.5 ms | same |
| RMO-drafts (1 submodule) | 973 | 22.2 ms | 845 | 10.9 ms | same |
| deal.II checkout | 34556 | 75.0 ms | 34556 | 62.0 ms | same |
| LLVM 23.1.4 sources | 180522 | 350.4 ms | 180522 | 325.0 ms | same |
| 10 repositories without submodules | 10 - 853 | 8.5 - 16.8 ms | the same | 8.5 - 14.8 ms | same |
"same": today's list without its duplicates. Two of the ten small trees measured
above the 5 % margin in the first run (aurum 8.5 -> 9.6 ms, Multigrid_Astra_Python
12.2 -> 13.4 ms); three reruns each gave 8.3 / 8.8, 8.4 / 8.3, 8.3 / 8.3 and 8.9 /
8.9, 10.2 / 10.3, 8.5 / 9.1 ms. Neither tree has a `.gitmodules`, and without one
projectile returns before it reads the setting (`projectile--git-submodules`,
`lib/projectile/projectile.el:3707`): both settings run the same code there, so the
spread (8.5 - 12.2 ms for the same setting) is noise, not a cost.

Point 7 (the Mac, H-30, the owner 2026-11-06): `command -v fd` gives
`/opt/local/bin/fd` (MacPorts, 10.5.1); `make test` ran 156 tests, 154 as expected,
0 unexpected, 2 skipped (`init-debug-gdb-arguments-follow-the-options`,
`init-debug-gdb-preset-builds-stops-and-steps`: no gdb on Apple silicon, D-051).

## Concepts (Emacs Lisp) explained
- `use-package`'s `:init` runs at startup, before the package loads; projectile is
  loaded later (`after-init`). A `setq` there sets a variable before projectile's
  `defcustom` runs, and `defcustom` keeps a value that is already set. That is also
  why the check sits in `:init`: an error there stops startup, as D-081's does.
- `executable-find` searches `exec-path`, the directories Emacs runs programs from;
  on the Mac init.el puts MacPorts' directory there first (D-089).

## Key files walked
- `lisp/init-project.el` - `emacs-cpp-project-fd-check` and the three settings in
  projectile's `use-package` form.
- `test/init-project-test.el` - `init-project-files-once-with-submodules` (a
  temporary repository with a local submodule, untracked and ignored files in both),
  `init-project-fd-check`.
- `docs/MANUAL.md` 6 - one paragraph.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** fd honours each submodule's own ignore rules as git does. **Would
  break if:** a submodule ignores files through a mechanism fd does not read (git's
  `info/exclude` in the submodule's git directory); those would be listed. The 14
  trees gave the same files. **DESIGN bet:** D-183.
- **Assumed:** a projectile update keeps listing git roots with one fd. **Would break
  if:** it changes `projectile-git-use-fd`'s meaning; the submodule test fails.
  **DESIGN bet:** D-183.
- **Assumed:** MacPorts' fd behaves as Arch's 10.5.0. **Would break if:** an older fd
  skips submodules; the Mac's `make test` (H-30) shows it. Held 2026-11-06: MacPorts'
  fd 10.5.1 passes `init-project-files-once-with-submodules`. **DESIGN bet:** D-057.

## How to verify
`make test` (`init-project-files-once-with-submodules`, `init-project-fd-check`); in
Emacs, `C-c p f` in this repository lists each file of `lib/` once.
