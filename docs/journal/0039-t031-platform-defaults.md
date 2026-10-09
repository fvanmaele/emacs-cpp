# 0039 - T-031: platform defaults files

- **Date:** 2026-10-09
- **Commits:** see `git log -- lisp/defaults-darwin.el`
- **Tier:** 2
- **Decisions:** D-055 (built here), D-051
- **Done when:** `init.el` loads the file for the running platform and stops with an
  error on an unknown one; `C-x C-a d` in a C++ buffer offers `gdb-preset` on Linux and
  `lldb-preset` on macOS when dape's history has no entry (history still wins); tests
  on both platforms; make test passes (agreed 2026-10-09; tests on the machine at
  hand, D-058).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
The owner ruled (D-055) that choices differing by platform live in one file per
platform, while platform mechanics stay in the modules. The first such choice is the
debugger offered first: gdb on Arch, lldb on macOS, where Apple silicon has no gdb.

`init.el` now requires `defaults-gnu-linux` or `defaults-darwin` before the modules;
any other platform stops startup with a message naming D-055. Each file defines
`emacs-cpp-default-debug-configuration`. `init-debug.el` turns it into the option
`emacs-cpp-debug-default-configuration` (changeable in Customize) and, when dape asks
which configuration to start, puts it first while dape's history holds no preset
entry. Checked on the Mac: with an empty history the prompt starts with
`lldb-preset`.

## Concepts explained
- **Constant in the defaults file, option in the module.** The defaults file is loaded
  before the module that knows what the value is for, so it only names the value; the
  module's `defcustom` takes it as its default. Customize still overrides it.
- **How dape fills its prompt.** In order: the project's `dape-command` (from
  `.dir-locals.el`), else the first history entry valid in this buffer, else the only
  suggested configuration. The config adds its default to the history when no preset
  entry is there, so dape's own order does the rest.

## Key files walked
- `lisp/defaults-gnu-linux.el`, `lisp/defaults-darwin.el` - one constant each.
- `init.el` - `emacs-cpp-defaults-feature` maps `system-type` to the file.
- `lisp/init-debug.el` - the option and `emacs-cpp-debug--offer-default` on
  `dape-read-config-hook`.
- `test/init-test.el` - both files define the same names; unknown platform errors.
- `test/init-debug-test.el` - the default per platform; history and `dape-command` win.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** dape keeps taking the prompt's first input from `dape-history`.
  **Would break if:** dape changes `dape--read-config`; the prompt would then start
  empty, nothing worse. **DESIGN bet:** D-055.
- **Limit:** a `gdb-preset` entry in the history on a Mac (gdb missing) counts as "a
  preset was used": the default is not added, and dape skips the invalid entry, so
  the prompt starts empty. Only after `gdb-preset` was tried on the Mac.
- **Risk:** the default enters dape's history, which savehist keeps across restarts;
  that is the point, but it also means it is "the last input" from then on.

## How to verify
`make test` on either platform. Interactively, in a C++ buffer of a preset project
with no debug history: `C-x C-a d` shows the platform's preset.
