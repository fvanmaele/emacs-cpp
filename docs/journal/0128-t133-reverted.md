# 0128 - T-133 reverted: no call slower than today's listing

- **Date:** 2026-11-05
- **Commits:** see `git log -- lisp/init-project.el` (this entry's commit)
- **Tier:** 3 (the revert of T-133, tier 3)
- **Decisions:** D-179 (supersedes D-177, D-178); O-85 reopened
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** `lisp/init-project.el`, its tests and the manual as before b7e3692;
  `make test` passes; the decisions record why.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
T-133 (0127) kept each project's file list so `C-c p f` and `M-o` stopped listing the
project on every call. A call with the list current became fast (2 ms here, 10 ms in
deal.II's checkout), but the first call, and the first after any file is created,
removed or renamed, became slower on large trees: 178 ms against 64 in deal.II,
1366 ms against 336 in LLVM's sources (RESEARCH_go_to_anything 22). The owner first
accepted that for deal.II, then, with the wider benchmarks, ruled it not acceptable
(D-179) and asked for the feature and that acceptance to be reverted.

`lisp/init-project.el`, `test/init-project-test.el` and `docs/MANUAL.md` are back as
they were before b7e3692; the option `emacs-cpp-keep-project-files` is gone with them.
projectile lists on every call again. O-85 is open again, with the constraint that a
remedy may not make any call slower than today's listing. S21's harness and its
findings (lock files change directory times; the per-directory check) stay in
`spikes/s21-projectile-cache/` for whoever takes O-85 up again.

## Concepts explained
- A revert by restoring files, not `git revert`: the files return to their state
  before b7e3692, while the journal entry 0127 and S21's results stay as the record.

## Key files walked
- `lisp/init-project.el`, `test/init-project-test.el`, `docs/MANUAL.md` - restored.
- `POSTMORTEM.md` - the entry of 2026-11-05.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** nothing else came to depend on the kept lists between b7e3692 and the
  revert. **Would break if:** a later commit used `emacs-cpp-project-files`; none did
  (`git log b7e3692^..HEAD -- lisp/`). **DESIGN bet:** D-179.

## How to verify
`make test`; `C-c p f` in emacs-cpp shows "Projectile is indexing" on every call, as
before T-133.
