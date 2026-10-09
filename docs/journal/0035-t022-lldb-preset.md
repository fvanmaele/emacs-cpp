# 0035 - T-022: lldb-preset next to gdb-preset

- **Date:** 2026-10-09
- **Commits:** see `git log -- lisp/init-debug.el`
- **Tier:** 2
- **Decisions:** D-051 (built here), D-053, D-031, D-033
- **Done when:** `C-x C-a d lldb-preset RET` picks a target of the active preset,
  builds it, stops at a breakpoint and steps, on Arch and on the Mac; a missing
  lldb-dap refuses the session with the fix; an ERT test like
  `init-debug-gdb-preset-builds-stops-and-steps` covers it; the gdb tests are
  unchanged; make test passes on Arch (agreed 2026-10-09).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
Apple silicon has no gdb, so on the Mac `gdb-preset` cannot debug (D-050). The owner
ruled that lldb is supported in addition to gdb (D-051). `lldb-preset` is the same
workflow as `gdb-preset`: pick one of the active preset's executable targets (read
from build.ninja), build it, start the debugger in the project root. Only the
debugger differs: lldb-dap, LLVM's debug adapter, which speaks the same protocol (DAP)
that dape uses for gdb.

On the Mac the session test passes: it stops at the breakpoint in `main`, shows the
local `value` = 21, evaluates the watch `value * 2` = 42, steps into `twice`, out
again and over line 4, and ends the session.

## Concepts explained
- **A dape configuration** is a property list in `dape-configs`. dape ships one named
  `lldb-dap`; `lldb-preset` is a copy of it with four entries replaced: `fn` (adds the
  build command before the session), `:program` (asks for the target), `:cwd` (the
  project root) and `command` (which lldb-dap to start).
- **A function as a value:** dape calls a function it finds as a value when it
  evaluates the configuration. `command` is the function `emacs-cpp-debug-lldb-dap`,
  so the program is looked up when a session starts, and a missing one stops with a
  message naming the fix instead of dape's bare "not found".
- **Why it hides itself:** at the `C-x C-a d` prompt dape suggests only the
  configurations whose `ensure` check passes, ignoring errors. Without lldb-dap,
  `lldb-preset` is simply not suggested; typed by hand, it is refused with the fix.
- **One shared helper:** the gdb and lldb sessions are the same test,
  `init-debug-test--session`, given the configuration name. gdb names the stepped-into
  frame `twice`, lldb `twice(int)`; the test accepts both.

## Key files walked
- `lisp/init-debug.el` - `emacs-cpp-debug-lldb-dap-program` (the option),
  `emacs-cpp-debug-lldb-dap` (look up or refuse), `emacs-cpp-debug--preset-config`
  (shared by both presets), `emacs-cpp-debug--prepare-lldb` (the build only).
- `test/init-debug-test.el` - the lldb configuration's shape, the refusal (an absolute
  path and a name that do not exist), the session.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** MacPorts keeps lldb-dap in `/opt/local/libexec/llvm-23/bin`.
  **Would break if:** the port moves it or a newer port (lldb-24) replaces it; the
  session is refused naming the path, and the option takes the new one.
  **DESIGN bet:** D-053.
- **Assumed:** no codesigning is needed. MacPorts' post-install note asks to codesign
  lldb-server; on the owner's Mac (Developer Mode off) lldb-dap launched and stopped
  a program without it, through its own ad hoc signed debugserver. LLVM's build docs
  say code signing concerns LLDB's own debug server only. **Would break if:** a macOS
  update tightens debugging rights; the symptom would be "attach failed / not allowed
  to attach". The fallback then is the Command Line Tools' signed debugserver
  (`LLDB_DEBUGSERVER_PATH`), as JetBrains advised for CLion (CPP-26019); not set up.
- **Observed:** the port's `lldb` command-line binary has an invalid code signature
  and is killed at start (exit 137). lldb-dap does not use it.
- **Risk:** under a build on all cores the session test failed once after 162 s (a
  wait in the test ran out; the condition was not captured) and passed in 34 s on the
  next try; idle it takes 9 s and passed 5 of 5.
- **Not checked here:** lldb-preset on Arch (needs the owner's machine).

## Arch verification (2026-10-09)
lldb 23.1.1 with `/usr/bin/lldb-dap`: `make test` 54 / 54;
`init-debug-lldb-preset-builds-stops-and-steps` passed 3 of 3 runs (2.3 - 3.2 s), the
refusal test and both gdb tests pass. The session test drives `lldb-preset` the way
`C-x C-a d` does; no interactive session was run. T-022 done.

## How to verify
On the Mac: `make test` (the lldb session test runs; the gdb tests skip).
Interactively: in a preset project, `C-x C-a b` on a line, `C-x C-a d lldb-preset
RET`, pick the target; it builds, stops, and `C-x C-a n` steps.
On Arch (owner): `sudo pacman -S --needed lldb`, then `make test`; both the gdb and the
lldb session tests run.
