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

`launchctl limit maxfiles` on the Mac: soft 256, hard unlimited. That is the limit an
app started by launchd (Dock, Finder, Spotlight) inherits; the 256 row simulates it
with `ulimit -n 256` in a shell (a Dock start itself was not tried, to keep windows off
the owner's screen). An Emacs started from a terminal inherits the shell's limit, so
975. `kern.maxfilesperproc` is 61440, far above both.

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
- **eglot:** the watch request fails inside a timer ("Error running timer"); pyright
  then exited and eglot restarted it in a loop (0034). D-054 stops eglot at 500
  watches with a warning, but 500 is above the 207 of an Emacs started from the Dock.
- **auto-revert:** catches the error and quietly switches that buffer to polling
  (every `auto-revert-interval`, 5 s). Reverts still happen, later.
- **treemacs:** ignores only "No file notification program found"; this error would
  surface when a directory is expanded.

## 4. Effects on C++ work
- clangd asks for no watches, so the size of the source tree (deal.II's 1813
  directories included) does not matter for the language server.
- What grows with use is auto-revert (open files) and treemacs (expanded
  directories). From a terminal start that leaves 975; from the Dock 207, which a day
  with many open headers plus an expanded tree can reach. Then auto-revert polls and
  treemacs reports errors on expanding.
- A Python buffer in the same Emacs shares the budget: pyright's project watches count
  against the same 207 or 975.

## 5. Options for D-054 (for the owner; not a verdict)
- (a) Lower `eglot-max-file-watches` on macOS from 500 to 100, so a language server
  can never take more than half of a Dock start's 207. Cost: a Python project with
  more than 100 directories is watched in part (eglot warns).
- (b) Raise launchd's soft limit for apps to 1024 (`sudo launchctl limit maxfiles 1024
  unlimited`, lost at reboot; or a LaunchDaemon plist). Then Dock starts get 975 as
  terminal starts do. A system change outside this repository (needs its D-nnn).
- (c) Start Emacs from a terminal (the `/usr/local/bin/emacs` wrapper on this Mac):
  975 without any change; a habit, not enforceable.
- (d) Turn off magit's auto-revert or treemacs's file watching on macOS. Not
  proposed: both are daily features, and auto-revert already degrades to polling.
