# 0144 - T-160: debug arguments per project for both machines

- **Date:** 2026-11-22
- **Commits:** the commit carrying this entry
- **Tier:** 2
- **Decisions:** D-216 (resolves O-94 with (c))
- **Done when:** both presets pass `emacs-cpp-debug-args` as `:args`, it is safe as a
  directory-local value, a missing gdb names the project's `dape-command`; tests for
  each; `make test` passes (a real lldb session on the Mac). The session wrote this
  line from O-94 (c), which the owner took with "option 3".

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
On H-39 the debugger did not start on the Mac: the owner's projects set `dape-command`
to `gdb-preset` with their program's arguments in `.dir-locals.el` (the cheat sheet's
own example), and the Mac has no gdb. A project now gives only its arguments, in
`emacs-cpp-debug-args`, and each machine starts its own debugger (gdb on Arch, lldb on
the Mac, D-055). A `gdb-preset` without gdb now says why it was asked for.

Also in this round (tier 1, the same commit's neighbour): H-39 on the Mac passed (the
debugger's buttons work with `lldb-preset`); the git button's icon is Lucide's
`git-commit-vertical`, as the owner asked, since `git-branch`'s open stroke end read as
cut off.

## Concepts (Emacs Lisp) explained
- **Directory-local variables.** `.dir-locals.el` sets variables for the files of a
  project. Emacs asks before applying a value it does not know to be safe; the option's
  `:safe` predicate (a list of strings) lets it apply without asking.
- **Functions in a dape configuration.** dape calls a function it finds as a value in a
  configuration when a session starts, in the source buffer; so `:args` is a function
  that reads the buffer's `emacs-cpp-debug-args`, and `command` of `gdb-preset` is one
  that finds gdb or refuses.

## Key files walked
- `lisp/init-debug.el` - `emacs-cpp-debug-args`, `emacs-cpp-debug--args`,
  `emacs-cpp-debug--gdb`, `emacs-cpp-debug--gdb-preset-config`.
- `test/init-debug-test.el` - `init-debug-project-args-without-a-debugger`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** dape evaluates `:args` and `command` in the source buffer, where the
  directory-local value is set (as for `:program` already). **Would break if:** a dape
  update evaluates elsewhere; the arguments would be empty. The lldb session in
  `make test` runs through the function; H-41 checks real arguments. **DESIGN bet:** D-216.
- **Assumed:** dape's `gdb` configuration keeps a plain command name. **Would break
  if:** it becomes a function; the config then stops at startup naming this file.

## How to verify
- `make test </dev/null`.
- H-41: the owner's projects switched, `C-x C-a d` RET on the Mac.
