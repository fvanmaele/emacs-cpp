# RESEARCH - file watches on macOS (T-029)

Findings only; verdicts go to DESIGN (D-054, O-26). Owner question 2026-10-09: the file
descriptor per watched directory on macOS, and what it means for C++ work in Emacs.
Measured on the owner's Mac (Apple silicon, macOS Darwin 27, MacPorts Emacs 31.1,
`emacs-app` with kqueue), 2026-10-09.

## 1. Mechanism
- Emacs on macOS watches files with kqueue (`file-notify--library` is `kqueue`;
  `system-configuration-features` lists KQUEUE, not inotify). Linux uses inotify,
  where one descriptor carries any number of watches.
- `kqueue-add-watch` (Emacs `src/kqueue.c`, master, read 2026-10-09) opens the watched
  file or directory itself (`O_EVTONLY`, non-blocking, not following a final symlink):
  one descriptor per watch. A watched directory takes one descriptor; files inside it
  are not opened, changes are found by comparing directory listings.
- The same function refuses a new watch when `watches > soft RLIMIT_NOFILE - 50`
  ("File watching not possible, no file descriptor left"); 50 descriptors are kept
  for the rest of Emacs. Without `getrlimit` it assumes 256.
- Emacs keeps its own soft limit at `FD_SETSIZE` (1024) when the inherited one is
  higher (the `nofile_limit` comment in `src/process.c`; the code itself was not
  read, the measurement below agrees).

Measured: watches on empty temporary directories until Emacs refuses
(`emacs -Q --batch`, `file-notify-add-watch` in a loop):

| Soft limit Emacs started with | Watches before the refusal |
|---|---|
| 1048576 (the owner's shell) | 975 |
| 4096 | 975 |
| 256 | 207 |

`launchctl limit maxfiles` on the Mac reports soft 256, hard unlimited. That is NOT
what a started app gets (corrected 2026-10-09, revisit of O-26): Emacs.app started
through Launch Services (`open -a`, as the Dock and Finder do), with `-Q` and a script
that counts, held 975 watches, and its child processes saw `ulimit -n` 1024; the same
when `open` was run from a shell lowered to 256, so the caller's limit does not carry
over. The 256 row above is a shell with `ulimit -n 256`, not a case met in use. An
Emacs started from a terminal also gets 975. `kern.maxfilesperproc` is 61440.

## 2. Who watches in a C++ session
Measured in batch with the shipped config, the patched clangd, a copy of RMO
(`CLionProjects/step-1`, 13 sources, 77 directories with the build tree), files
committed to git so magit's auto-revert applies, `magit-auto-revert-mode` turned on as
an interactive session does:

| Moment | Watches | From |
|---|---|---|
| after startup | 0 | - |
| `main.cc` open, eglot connected | 1 | auto-revert (magit) |
| 25 project files open | 24 | auto-revert, one per tracked file |
| clangd's own requests | 0 | clangd registers no file watchers with eglot |

Not measured, from the code:
- treemacs (`treemacs-filewatch-mode`, on by default): one watch per directory shown
  expanded in the tree.
- projectile: watches only with `projectile-auto-update-cache-with-watches`, off by
  default and not set here.
- pyright (Python, D-045): one watch per directory of the project and, unless D-054
  applies, of Python's library and site-packages: about 2000 on this Mac (0034).

## 3. What happens at the limit
- **eglot:** a server's watch request (`client/registerCapability` for
  `workspace/didChangeWatchedFiles`) fails as a whole in two ways: kqueue refuses a
  watch ("no file descriptor left", 0034), or eglot reaches `eglot-max-file-watches`;
  then it warns, removes the watches it already added and answers the request with an
  error (`eglot--watch-globs`, Emacs 31 eglot; its own comment notes that keeping the
  partial watches would be possible). pyright exits after either. Measured
  2026-10-09 with D-054 (project files only, cap 500) on a generated project of 600
  directories: eglot's warning "Reached `eglot-max-file-watches' limit of 500", then
  pyright exited. On 50 directories it stays up.
- **auto-revert:** catches the error and quietly switches that buffer to polling
  (every `auto-revert-interval`, 5 s). Reverts still happen, later.
- **treemacs:** ignores only "No file notification program found"; this error would
  surface when a directory is expanded.

## 4. Effects on C++ work
- clangd asks for no watches, so the size of the source tree (deal.II's 1813
  directories included) does not matter for the language server.
- What grows with use is auto-revert (open files) and treemacs (expanded
  directories), out of 975 whether Emacs was started from a terminal or the Dock.
  Then auto-revert polls and treemacs reports errors on expanding.
- A Python buffer in the same Emacs shares the budget: pyright's project watches count
  against the same 975.

## 5. pyright with and without eglot's watches
Measured 2026-10-09 in a terminal Emacs (tmux, real command loop): `main.py` imports
`newmod`, which does not exist; `newmod.py` is then written from outside Emacs; after
an edit, is the "could not be resolved" diagnostic gone? A control watch on the
project root saw the change in every run.

| Setting | 50 directories | 600 directories |
|---|---|---|
| A: D-054 (project only, cap 500) | sees the change; up | exits at the cap |
| B: cap 500, library watched too | exits (library about 2000 dirs) | not run |
| D: eglot offers no file watching | up; never sees the change | up; never sees the change |

So "project files only" is what keeps pyright running at all on the Mac; without
eglot's watches pyright does not watch by itself and goes stale silently.

Method note: batch Emacs (`emacs --batch`) delivers no file notification events (a
control watch saw 0 events while `accept-process-output` and `sit-for` ran), so such
tests need a command loop; the descriptor counts of section 2 are unaffected.

## 6. Options for D-054 (for the owner; not a verdict)
- (a) Keep D-054 as it is: works for Python projects up to about 500 directories
  (the owner's so far: one directory); above that pyright exits, after eglot's
  warning.
- (b) Raise the cap towards the real limit, e.g. 800: larger projects; leaves about
  175 watches for auto-revert and treemacs before they poll or fail.
- (c) Offer no file watching on macOS: pyright never exits, but misses every change
  made outside Emacs (checkout, generated files) until it restarts, without a sign.
- (d) Ask eglot upstream to keep the partial watches at the cap instead of failing
  the request (its own comment says so); a local override would copy an internal
  function. Combinable with (a) or (b).
- Withdrawn: lowering the cap for a 207 limit, and raising launchd's limit; the 207
  case does not occur (section 1).
