# 0034 - T-021: the config starts on macOS

- **Date:** 2026-10-09
- **Commits:** see `git log -- lisp/init-cmake.el`
- **Tier:** 2
- **Decisions:** D-050, D-053, D-054 (new, owner to confirm), D-013, D-033
- **Done when:** Emacs starts on the Mac with no errors; `make test` passes there
  except tests that need gdb or the patched clangd, which skip with a reason until
  T-022 / T-023 land; `make test` still passes on Arch (agreed 2026-10-09).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
macOS became a supported platform (D-050), with MacPorts as the only package source
(D-053). On the owner's Mac the config stopped at startup and 17 of 45 tests failed.
Startup now succeeds in a throwaway home with the two symlinks (theme loaded, no
error, no warning from the config). The test suite passes on the Mac except the gdb
tests, which skip because Apple silicon has no gdb, and the patched-clangd test, which
skips until that clangd is installed.

Six causes, found one after another:
1. **cmake-mode's directory** was the Arch path. It is now chosen by platform
   (`/opt/local/share/emacs/site-lisp` on macOS), and an unknown platform stops with an
   error instead of guessing.
2. **`${hostSystemName}`** in presets was refused outside Linux. CMake's value on macOS
   is `Darwin`; that is what the config now expands.
3. **CMake 3.31's build.ninja.** The debugger's target list reads the build type from
   each link block's `CONFIG` line. CMake 4 (Arch) writes one; CMake 3.31 (MacPorts)
   writes the build type only once, as `CONFIGURATION` near the top of the file. The
   block's line still wins; the file's line is the fallback.
4. **pyright and file watching** (D-054). pyright asks eglot to watch Python's whole
   library and site-packages, about 2000 directories. Linux's inotify watches them
   all through one file descriptor; macOS's kqueue needs one descriptor per directory,
   and Emacs ran out at 975. pyright then exited, and eglot restarted it in a loop,
   which hung the test run. On macOS eglot now watches only the project and at most
   500 directories.
5. **Temporary directories.** On macOS `/var` is a symbolic link to `/private/var`.
   The config works with true names, the tests compared them with the link's name.
   The tests' temporary projects now start from the true name.
6. **Test assumptions:** the standard library lives in the SDK, not under `/usr/`
   (the test now asks "outside the project"); and eglot's start can return before the
   handshake ends (below), so the tests wait for it. The recentf test used the real
   `~/.emacs.d/.cache`, which the owner's Mac no longer has; it now uses its own home.

## Concepts explained
- **`pcase` on `system-type`:** `system-type` is a symbol naming the platform
  (`gnu/linux`, `darwin`). `pcase` picks the branch whose pattern matches; the last
  branch `_` matches anything and here signals the error, so a new platform is noticed.
- **Why eglot "connects" early:** eglot waits up to 3 s for the server's first answer
  with `accept-process-output`, which returns as soon as *any* process produces
  output, a log line of clangd on stderr too. eglot then takes the start as done, and
  the buffer becomes managed only when the real answer arrives, milliseconds later.
  Interactive use does not notice; a test that checks at once does, about one run in
  four on the Mac. `init-test--wait-managed` waits up to 10 s for it.
- **`file-in-directory-p`** compares true names and answers nil when the directory
  does not exist. The recentf exclusion relies on `~/.emacs.d/.cache/` existing, which
  it does as soon as treemacs has written its state there.

## Key files walked
- `lisp/init-cmake.el` - `emacs-cpp-cmake-mode-directory` by platform.
- `lisp/emacs-cpp-presets.el` - `${hostSystemName}` in the macro expansion.
- `lisp/init-debug.el` - `emacs-cpp-debug-programs`: `CONFIG`, else `CONFIGURATION`.
- `lisp/init-cpp.el` - the two eglot watch settings on macOS, in eglot's one form.
- `scripts/measure-startup.sh` - load average from `sysctl` on macOS; C locale, so
  `sort -n` and awk read and print decimal points (the German locale printed
  "median 1,000 s").
- `test/init-test.el` - `init-test--wait-managed`; recentf test in its own home.
- `test/init-debug-test.el` - a CMake 3.31 fixture; gdb parts skip without gdb.
- `test/*-test.el` - temporary roots by their true name.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** MacPorts' prefix is `/opt/local`. **Would break if:** MacPorts is
  installed elsewhere; startup then stops naming the directory (D-053).
  **DESIGN bet:** D-053.
- **Assumed:** 500 watched directories leave enough descriptors on macOS.
  **Would break if:** a project has more directories than that; eglot warns and some
  changes on disk go unnoticed by the server until it restarts. **DESIGN bet:** D-054.
- **Assumed:** a build directory is configured by one CMake, so the file's
  `CONFIGURATION` matches every link rule. **Would break if:** Ninja Multi-Config
  (not supported by the debug presets; the suffix check then stops with an error).
- **Risk:** the debugpy test failed twice on the Mac ("Unable to connect to server"),
  both times with the machine busy (first cold run; a clangd build on all cores).
  dape gives the adapter a fixed 3 s to listen (30 tries of 0.1 s, not configurable);
  debugpy on Python 3.14 can take longer. Idle runs pass. Not changed; folded into
  the research task on Python tools on macOS.
- **Risk:** startup on the Mac measured 0.77 - 1.23 s against 0.15 s on Arch, on a
  busy machine (load 4). Which machine the budgets bind is open (O-24 b).

## Arch verification (2026-10-09)
`make packages && make test` on Arch: 54 / 54, none skipped (the gdb and the
patched-clangd tests run there). T-021 done.

## How to verify
On the Mac: `make packages && make test` (gdb tests skip; the patched-clangd test
skips unless `~/opt/clangd-index-nav/bin/clangd` exists).
`sh scripts/measure-startup.sh 3` starts Emacs in a throwaway home.
On Arch (owner): `make packages && make test` must pass as before.
