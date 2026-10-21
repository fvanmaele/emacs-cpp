# 0098 - The Mac run of H-15; fswatch 0005: `Created` once per file

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-125"`
- **Tier:** 2
- **Decisions:** D-144 (new), D-127, D-133
- **Done when:** T-125's line (TASKS.md), from the owner's ruling 2026-10-21: "fswatch
  patch 0005, verify per-path time map memory usage on larger projects"

> Plain English for someone who does not read C++ or Emacs Lisp fluently.

## What + why
The session ran H-15's Mac steps itself (it runs on the Mac): `make test`, S18's
`shipped` mode, the tree's removal. S18 run 6 passed all five criteria (2 ms of
Emacs's CPU per 1000 records). `make test` failed one test,
`emacs-cpp-eglot-fswatch-real`: after a file was created and reported, writing to it
again was reported to the language server as "created" (type 1), not "changed" (2).

Probes with the patched fswatch alone showed why: macOS's FSEvents keeps the
`Created` flag on a recently created file, so every later change of it arrives as
`Created,IsFile,Updated,...`, even for a file created before fswatch started. A file
born hours earlier reports `IsFile,Updated` only. Arch (inotify) is not affected.

The owner chose a fix in fswatch (patch 0005) and asked for its memory to be checked
on a large project. The first version remembered, per path, when it was last
reported; `check.sh`'s memory check failed with it (about 250 bytes per changed
path, so a 267000-file tree touched once would hold tens of MB). The patch as built
remembers only the inode numbers of files created while fswatch runs: a file born
before the stream started is never `Created`; a file born after keeps `Created` on
its first report only; its inode is forgotten when it is reported removed.

Also on the Mac: the patched clangd rebuilt (`build-macos.sh`) so `clangd-indexer`
is installed beside it (D-133; the 0086 build predates pkgrel 10); T-023's row,
still saying the owner's run was left, closed.

## Concepts (C++) explained
- `st_birthtimespec`: macOS's `stat` reports when a file was created ("birth time"),
  besides the usual change times. Linux's `stat` has no such field in the same place,
  which is one more reason the patch lives in the FSEvents monitor only.
- `std::unordered_set<unsigned long>`: a hash set of numbers. `insert(x).second` is
  true when `x` was not there yet, so one call both checks and records.
- An inode is the file system's number for a file; a new file gets a new one, a
  rename keeps it. FSEvents hands it over with each event (its "extended data").

## Key files walked
- `packaging/fswatch-no-loss/0005-fsevents_monitor-keep-Created-only-for-a-file-not-re.patch`
  - `fsevents_callback`: next to patch 0003's `lstat`, drops `Created` for a file born
  before the stream's `started` time or whose inode is already in `created_reported`.
- `packaging/fswatch-no-loss/check.sh` - check 5: a change of a file created before
  the start, a new file, its change, a file created again after removal.
- `packaging/fswatch-no-loss/PKGBUILD` - pkgrel 3, the patch and checksums.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** FSEvents's sticky `Created` is the only cause of the mislabel; the
  file's birth time is set from the same clock as `CLOCK_REALTIME`. **Would break
  if:** a file born after the start is reported first without `Created` and later
  with it (it would then be reported created once, late). **DESIGN bet:** D-144.
- **Assumed:** inode numbers are not reused within one fswatch run on APFS (APFS
  numbers grow). **Would break if:** a volume reuses them (HFS+, some network file
  systems): a new file with an old number would be reported changed, not created.
  **DESIGN bet:** D-144.
- **Assumed:** a removed file is reported removed, so its inode leaves the set.
  **Would break if:** FSEvents drops events (patch 0002 reports that as an overflow;
  the set then keeps a few stale numbers, a little memory). **DESIGN bet:** D-144.
- **Assumed:** the config's startup check (`--queue-limit` in the binary) is enough;
  it does not tell pkgrel 2 from 3. **Would break if:** a Mac keeps pkgrel 2: edits
  of new files reach servers as created, and `make test` fails there, as it did.
  **DESIGN bet:** D-127.
- Measured on S18's tree (287398 files, 100000 created): old files changed cost the
  same as pkgrel 2; created files about 48 bytes each (+4.8 MB for 100000).

## How to verify
- `sh packaging/fswatch-no-loss/check.sh` - 11 PASS lines (one SKIP without a
  decimal-comma locale).
- `EMACS_CPP_PATCHED_CLANGD=~/opt/clangd-index-nav/bin/clangd make test </dev/null` -
  on the Mac 150 tests, 147 passed, 3 skipped (the gdb tests, ty).
- `ls ~/opt/clangd-index-nav/bin` - `clangd` and `clangd-indexer`.
- Arch: nothing to rebuild; `fsevents_monitor.cpp` is built only with FSEvents
  (`libfswatch/src/Makefile.am`, `if USE_FSEVENTS`).

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: real-data work is a conversation; the session ran the owner's Mac steps
  itself and found the mislabel the spike's fake server could not see.
