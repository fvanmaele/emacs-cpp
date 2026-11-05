# 0127 - T-133: projectile's lists kept while their directories hold

> Superseded 2026-11-05 by D-179 (0128): the feature and its option were reverted.

- **Date:** 2026-11-05
- **Commits:** see `git log -- lisp/init-project.el` (this entry's commit)
- **Tier:** 3 (owner 2026-11-05: "Tier 3 with short spike"; S21 PASS, 0126)
- **Decisions:** D-177 (O-85 (f)), with S21's `m2` check
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** T-133's four points (TASKS.md); 1, 2 and 4 (Arch) met, 3 met for a
  current call, the first call above today's on deal.II (below); the Mac's
  `make test` on H-28.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c p f` and `M-o` waited for projectile to list the project's files on every call:
444 - 493 ms in this repository. `lisp/init-project.el` now keeps each project's list
with the modification times of the directories it depends on, and hands the list
back as long as none changed. When one changed, it reads that directory's names
again; if only Emacs's own lock, auto-save or backup files came or went (they do on
every edit, S21), the list stands, otherwise the project is listed again.

A current call now costs 1.9 ms here (limit 10), 10.2 ms in deal.II's checkout
(limit 50), 0.4 ms in RMO-drafts. The first call, and the first after a file is
created, removed or renamed, costs the listing plus reading the directories: 420 ms
here (today 444 - 493), 29 ms for RMO-drafts (25 - 50), 190 ms for deal.II (68 - 75).
That last one is above today: done when 3 asked for "the first call as today". The
extra time is reading deal.II's 1805 directories and 36366 names, which is how a
file landing in a directory without listed files is noticed (S21's criterion 1).

Writing it fresh from S21 found three things the spike had hidden:
- git refuses `check-ignore` for a path inside a submodule when asked from the
  repository above; the spike ignored git's exit status and so never noticed. The
  module asks each submodule's own git, and stops with git's message on any other
  failure.
- The first version took 975 ms (here) and 1073 ms (deal.II) for a first call:
  `file-directory-p` on every name, every directory read twice, and
  `expand-file-name` and `file-name-directory` on 70000 paths, whose file-name
  handler lookup alone took about 150 ms. Now names that are listed files are not
  tested, each directory is read once, paths are concatenated, and the pass runs with
  the handlers off. A remote project (TRAMP) is listed every time, as before.
- A `let` binding of `projectile-enable-caching` was lexical in this file until the
  variable was declared special; the byte compiler's warning showed it.

## Concepts (Emacs Lisp) explained
- `:around` advice wraps a function: `emacs-cpp-project-files` answers from its table
  and calls projectile's own `projectile-project-files` only when the list is stale.
- `file-name-handler-alist` lets Emacs treat remote and compressed files specially;
  every file-name function looks it up first. Bound to nil, plain local paths skip
  that lookup.
- `(defvar NAME)` without a value declares NAME special in one file, so `let` binds
  it dynamically and code elsewhere (projectile) sees the binding.

## Key files walked
- `lisp/init-project.el` - `emacs-cpp-project-files` and its helpers, the two advices
  in projectile's `use-package` form.
- `test/init-project-test.el` - `init-project-files-kept`.
- `docs/MANUAL.md` 6 - one paragraph.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** S21's editing run covers the files Emacs and packages write next to
  edited ones. **Would break if:** another package writes files there (each would
  list anew; still correct). **DESIGN bet:** D-177.
- **Assumed:** 190 ms for deal.II's first call after a change is acceptable (68 ms
  today). **Would break if:** the owner judges it slower than before in a project
  that changes structure often (generated files); the owner rules. **DESIGN bet:**
  D-177.
- **Assumed:** the Mac's file system answers `stat` about as fast. **Would break if:**
  APFS is much slower; H-28 checks correctness, not time. **DESIGN bet:** D-057.

## How to verify
`make test` (`init-project-files-kept`); in Emacs, `C-c p f` twice in this
repository (the second returns at once), `touch newfile`, `C-c p f` lists it.
