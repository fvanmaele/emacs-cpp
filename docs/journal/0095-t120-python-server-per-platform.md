# 0095 - T-120: the Python server per platform, ty on Arch

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-120"`
- **Tier:** 2
- **Decisions:** D-140 (built), D-132 (superseded), D-045 (superseded in part), D-055
- **Done when:** T-120's four items (TASKS.md, agreed by the owner 2026-10-21)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
Python's language server is now chosen per machine: Astral's ty on Arch, pyright on
the Mac, where ty has no MacPorts port and is untested (T-121). The owner ruled it
(D-140) after RESEARCH_python_ty 4b: ty answers the first `M-.` in 20 - 72 ms against
pyright's 300 - 617 ms, and a 5600-reference `M-?` in 82 ms against 1.09 s in the
server, with half the memory. The choice lives in the platform defaults files, as the
debugger and the search program do (D-055).

## Concepts (Emacs Lisp) explained
- **A `defconst` per platform.** `init.el` loads `defaults-gnu-linux.el` or
  `defaults-darwin.el` before the modules; both define the same names, so
  `init-python.el` reads `emacs-cpp-default-python-server` without asking which
  machine it is on.
- **`executable-find` at load time.** The module checks the server's program when it
  loads, so a missing ty stops startup with the install command instead of failing
  quietly the first time a Python file opens (principle 1, as D-081 does for the
  search program).

## Key files walked
- `lisp/defaults-gnu-linux.el`, `lisp/defaults-darwin.el` - the server and the command
  that installs it.
- `lisp/init-python.el` - the check, then `emacs-cpp-lsp-server` with the platform's
  server.
- `test/init-python-test.el` - `init-python-server-per-platform` (NEW) and the
  navigate-and-rename test on the platform's server; it waits for published
  diagnostics only with pyright (ty pulls its diagnostics and has analysed the file
  when it answers).
- `test/init-lsp-test.el` - the fswatch test, now on the platform's server.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** ty 0.0.x keeps answering what the config uses. **Would break if:** a ty
  release changes its LSP behaviour; pacman updates it with the system. **DESIGN bet:**
  D-140.
- **Assumed:** ty's weaker inference of unannotated code is acceptable (RESEARCH_python_ty
  4a). **Would break if:** the owner misses pyright's reports on unannotated code.
- **Seen:** in `init-python-eglot-only-in-projects` ty connects and is shut down within
  3 s, and eglot's own autoreconnect timer (set at connect, 3 s) then fires on the
  finished process: "Error running timer: ... not running: finished". eglot's
  behaviour, not the config's; with pyright the test ran the same way without it
  (UNVERIFIED why). In use it shows only when a server is shut down within 3 s of
  connecting.

## How to verify
- `make test </dev/null` - 146 tests pass on Arch.
- `sh scripts/measure-startup.sh 10` - 0.182 s against 0.183 s before.
- In Emacs on Arch, a Python file of a project: `M-x eglot-events-buffer` names `ty`.
