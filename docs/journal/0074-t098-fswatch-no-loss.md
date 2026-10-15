# 0074 - T-098: fswatch built without event loss

- **Date:** 2026-10-15
- **Commits:** see `git log --grep T-098` (the package and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-109 (O-61 (h1) (ii))
- **Done when:** `packaging/fswatch-no-loss/` with a `PKGBUILD` (Arch, /opt) and
  `build-macos.sh` (~/opt) building fswatch 1.22.0 with patches 0001 writer thread
  and queue cap (configurable, owner), 0002 drops as overflow, 0003 present state,
  0004 C locale for numbers; `check.sh` testing the installed binary; Mac build and
  check here, Arch by the owner; nothing in the config uses it yet.

> Plain English for someone who does not read C++ fluently.

## What + why
eglot can only watch a few hundred directories on macOS (one descriptor each), so a
tree watcher that uses one FSEvents stream is the way to large repositories (O-61
(h)). fswatch is such a watcher, but it lost changes when its reader fell behind and
reported a file created and removed again with both flags (research 3.12, 3.13).
This package builds fswatch with four fixes, on both machines, as clangd is built
(D-026, D-052). The eglot side that would read it is not designed yet.

## Concepts (C++) explained
- **A writer thread and a queue.** fswatch's callback runs on the thread macOS
  delivers events to. It used to write each record to standard output itself; when
  the pipe was full that write waited, the callback did not return, and macOS
  dropped what arrived meanwhile. Now the callback only appends the formatted
  records to a `std::deque` guarded by a `std::mutex`, and signals a
  `std::condition_variable`; a second thread (`std::thread`, detached) takes them
  off and writes them. The callback never waits for the reader.
- **The cap.** `--queue-limit=N` (default 200000, 0: none) counts waiting records.
  Past it the queue is emptied and one `Overflow` record per watched path is queued
  instead, which tells the reader to look again; without `--allow-overflow` fswatch
  stops instead, as libfswatch does for its own overflows.
- **A deadlock found while testing.** The first version printed the overflow
  message with `std::cerr`. `std::cerr` is tied to `std::cout` and flushes it first;
  that needs the lock on standard output, which the writer thread held while blocked
  on the full pipe, so fswatch hung instead of exiting. The message now goes to the
  file descriptor directly (`write(STDERR_FILENO, ...)`).
- **`lstat` for the present state.** FSEvents adds up the flags of a path; asking
  the file system whether the path exists when the event arrives tells removed from
  created.
- **`setlocale(LC_NUMERIC, "C")`.** With translations on, fswatch adopts the user's
  locale, and `strtod` then expects "0,1" under German; setting the numeric part
  back to C keeps "-l 0.1" working.

## Key files walked
- `packaging/fswatch-no-loss/0001-...patch` .. `0004-...patch` - the fixes, made with
  `git format-patch` from commits on the 1.22.0 tag (a9ab579).
- `packaging/fswatch-no-loss/PKGBUILD` - Arch: the release tarball and the patches,
  checksummed; `./configure --disable-shared` (libfswatch linked in, so the extra
  package's library is never loaded); `check()` runs `check.sh`; installs
  /opt/fswatch-no-loss/bin/fswatch.
- `packaging/fswatch-no-loss/build-macos.sh` - macOS: the same sources read from the
  PKGBUILD, Xcode's compiler, `check.sh` before installing to ~/opt/fswatch-no-loss.
- `packaging/fswatch-no-loss/check.sh` - runs a binary in a temporary tree: 10000
  creations while the reader pauses, created-then-removed, the cap (one `Overflow`,
  memory growth, the error without `--allow-overflow`), `-l 0.1` under de_DE.UTF-8.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a reader that stops for good is rare; the cap bounds the memory then
  (1.4 MB growth for 50000 unread events at a cap of 1000). **Would break if:** the
  reader's pauses outlast the cap during normal bursts: then `Overflow` records come
  often and eglot must rescan. **DESIGN bet:** D-109.
- **Assumed:** the 0003 `lstat` races only within the event latency (0.1 s).
  **Would break if:** a file changes state between the event and the `lstat`; the
  record then shows the later state, which is what a reader wants.
- **Risk:** patch 0002 is only exercised when the system drops events, which 0001
  prevents; it was checked by hand with a build lacking 0001 (research 3.13).
- **Risk:** on Arch, inotify serves fswatch; patches 0002 and 0003 are macOS-only
  code, 0001 and 0004 apply there. Not run on Arch here.
- **Risk:** the Mac build has translations off (no libintl found), so check 4 passes
  there without exercising 0004; the Arch build (glibc gettext) exercises it.

## How to verify
- Mac: `packaging/fswatch-no-loss/build-macos.sh` (about a minute), or
  `packaging/fswatch-no-loss/check.sh` against an installed binary.
- Arch (owner): `cd packaging/fswatch-no-loss && makepkg -si`; `check()` runs
  `check.sh`.
