# 0129 - T-134: ty on the Mac, MacPorts' and the user's packages found

- **Date:** 2026-11-05
- **Commits:** see `git log -- lisp/init-python.el` (this entry's commit)
- **Tier:** 2 (T-134; also closes T-121)
- **Decisions:** D-180, D-181, D-182 (with (c2))
- **Done when:** T-134, agreed 2026-11-05 ("T-134 agree"): the Mac names ty, installed
  by `make macos-ports`; ty starts with `python3`'s true directory first on PATH;
  the user site-packages go to ty only under D-182 (u)'s conditions and while
  `emacs-cpp-ty-user-site-packages` is on; ERT tests for each case; `make test`
  passes on the Mac; Arch unchanged. Met on the Mac (154 run, 0 unexpected).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The Mac ran pyright because ty had no MacPorts port (D-140). With the local port
(D-180, D-181) ty is installed; measured against pyright it answers `M-?` sooner and
completely (RESEARCH_python_ty 4c). Two gaps were left (4d): ty mistakes MacPorts'
`python3`, a symlink into the framework, for an interpreter under `/opt/local` and
then ignores it, and it never looks at the user site-packages, where `pip install
--user` puts numpy and the like.

Now, on the Mac only, eglot starts ty through `env` with the framework's `bin/`
first on PATH. ty's own search finds that interpreter only when the project has no
environment of its own, so a `.venv` or a `python` in the project's ty settings still
wins (4e showed that the obvious alternative, sending `environment.python`, overrode
both). The user site-packages are sent as an extra path only where Python itself
would use them: the base interpreter, no `.venv`, no active virtual or Conda
environment, no `python` in the project's ty settings, user site enabled; and a
project can switch this off in its `.dir-locals.el`.

## Concepts (Emacs Lisp) explained
- **A function as eglot's server command**: `eglot-server-programs` may hold a
  function instead of a list; eglot calls it each time it starts the server, so the
  PATH is read then, not at startup.
- **`env VAR=VALUE program`**: runs the program with one variable changed, without
  changing Emacs's own environment. Code that names a server by the first word of its
  command (`M-o`'s headings) now skips `env` and its assignments.
- **A once-per-session cache**: `emacs-cpp-python--user-site` starts as the symbol
  `unknown`; the first ask runs `python3` (about 21 ms) and stores the answer, nil
  included, so it is never asked again.
- **A line-wise TOML check**: ty's configuration is TOML; Emacs has no TOML reader
  here, so `emacs-cpp-python--toml-names-python-p` follows `[table]` headers line
  by line and looks for a `python` key in the forms ty documents. Other forms are
  missed (D-182's case against); the option is the per-project way out.

## Key files walked
- `lisp/defaults-darwin.el` - `emacs-cpp-default-python-server` ty,
  its install command `make macos-ports`.
- `lisp/init-python.el` - `emacs-cpp-python--interpreter-dir`,
  `emacs-cpp-python--server-contact`, `emacs-cpp-ty-user-site-packages` (NEW),
  `emacs-cpp-python--user-site`, `emacs-cpp-python--toml-names-python-p`,
  `emacs-cpp-python--user-site-for-ty`, the `:ty` settings function.
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--server-name` skips `env`.
- `test/init-python-test.el` - `init-python-ty-package-directories` (four projects:
  plain, `.dir-locals.el` off, own `python`, `.venv`), `init-python-ty-toml-names-python`,
  the per-platform test; `test/init-go-to-anything-test.el` -
  `init-go-to-anything-server-name-through-env`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** ty keeps PATH as its last way to find an interpreter. **Would break
  if:** a ty release puts PATH ahead of `.venv` or of a project's setting; the venv
  and pinned cases of `init-python-ty-package-directories` fail then.
  **DESIGN bet:** D-182.
- **Assumed:** inline `extra-paths` keeps adding to a project's own list (4e).
  **Would break if:** ty starts replacing it; a project's `extra-paths` would be
  lost silently. Not covered by a test (UNVERIFIED for later releases).
  **DESIGN bet:** D-182.
- **Assumed:** the test's mutation checks generalise: with the PATH part off the
  plain case fails (MacPorts' `debugpy` unresolved), with the gate off the
  `.dir-locals.el` case fails (the user package seen). Both run once by hand, not
  kept as tests. **DESIGN bet:** D-182.
- **Assumed:** a project's environment does not change during a session.
  **Would break if:** a `.venv` is created after ty started; `M-x eglot-reconnect`
  re-reads it. **DESIGN bet:** D-182.

## How to verify
On the Mac: `make test </dev/null`; by hand, open a Python file of a git project
without `.venv` that imports a `pip install --user` package and `M-.` on it.
