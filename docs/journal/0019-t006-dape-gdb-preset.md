# 0019 - T-006: dape `gdb-preset` debugs a preset program

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/init-debug.el`
- **Tier:** 2
- **Decisions:** D-031, D-032 (new); implements D-002, D-030
- **Done when:** in RMO with the `debug` preset, `C-x C-a d gdb-preset RET`, picking
  `main`, builds it and stops at a breakpoint in `src/main.cc` with stack, Locals
  (incl. `opts`) and a watch shown; step over, step in and quit work, no gdb left;
  with `emacs-cpp-debug-lazy-symbols` t the first stop takes about 2 s instead of
  17 s; ERT covers program choice, gdb arguments, refusals and a toy session; make
  check / make test pass. (Proposed by the LLM, agreed by the owner 2026-10-08 with
  three rulings: build first, printers by option off by default, breakpoints manual.)
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
Debugging is milestone v0.3; S2 showed dape driving gdb's own DAP mode on RMO. This
change makes it a one-command start: dape's list of configurations gets an entry
`gdb-preset` that knows the project's active CMake preset. It asks which program of
the preset's build directory to debug, builds that target, and only then starts gdb, so
a stale binary is never debugged. gdb is told never to download symbols (D-014). The
two gdb choices of O-14 became options: shared-library symbols on demand (D-030) and
extra gdb scripts such as deal.II's printers (D-032), both off by default.

## Concepts explained
- **dape configuration:** a property list in `dape-configs`. A value that is a function
  is called when the session starts (so `:program` can ask in the minibuffer); the
  `fn` property is a function that rewrites the whole configuration just before start;
  `compile` is a shell command dape runs first, starting the session only on success.
  dape calls `fn` again after the build, which is why `emacs-cpp-debug--prepare` sets
  the arguments rather than appending to them.
- **`:bind-keymap`:** a use-package keyword that binds `C-x C-a` to a small loader;
  the first press loads dape, which then binds its own map there. dape thus stays
  unloaded at startup (DESIGN 11).
- **`set script-extension off`:** gdb normally decides by the file extension how to
  read a `source`d file, so `dotgdbinit.py` would be run as Python and fail (checked:
  `SyntaxError`). With "off" it is read as gdb commands, which it is.
- **ELF check:** a file counts as a program when it is executable and starts with the
  four bytes `\177ELF`; shell scripts and `.so` libraries are left out.

## Key files walked
- `lisp/init-debug.el` - `emacs-cpp-debug--gdb-preset-config` copies dape's own `gdb`
  entry (so upstream fixes reach us) and adds `:program`, `:cwd` and `fn`;
  `emacs-cpp-debug-read-program` is the prompt; `emacs-cpp-debug-gdb-arguments` turns
  the options into `-iex` arguments.
- `test/init-debug-test.el` - unit tests on a fake build directory, and a real session
  on a toy CMake project: the source is changed after its build, so the watch reading
  `value * 2 = 42` proves `gdb-preset` rebuilt it; then step in (`twice`), step out,
  step over (line 5), quit, gdb process gone.
- `init.el` - `init-debug` loads after `init-cpp` (it uses the presets library).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a CMake executable's target name is its file name. **Would break if:**
  a target sets `OUTPUT_NAME` or `RUNTIME_OUTPUT_NAME`; cmake then says "unknown
  target" and no session starts (loud, not wrong). **DESIGN bet:** D-031.
- **Assumed:** gdb's "No source file named ... Breakpoint 1 pending" line in the
  session output is harmless: breakpoints are sent before the program is loaded and
  resolve when it is (the toy test stops there). **Would break if:** RMO's breakpoint
  stays pending; the owner's check shows it.
- **Assumed:** scanning the build directory for programs is quick enough. **Would
  break if:** a deal.II-sized build tree makes the prompt slow; then read CMake's file
  API instead.
- **Risk:** dape's `gdb` entry gains its own `fn` in a later version; startup then
  stops with an error asking to review `emacs-cpp-debug--prepare` (deliberate).
- **Risk:** the test drives dape internals (`dape--stack-trace`, `dape--scopes`) as S2
  did; a dape update may need the test adjusted, not the config.
- **Not done:** dape's repeat map needs `repeat-mode`, which is off: O-15.

## How to verify
`make test` (30 tests, the toy session included; needs cmake, ninja, c++, gdb >= 14.1).
Owner, on RMO (real data):
1. Open `src/main.cc` of `~/source/repos/RMO-gross-pitaevskii`, `C-x C-a b` on the
   line `ProgramOptions opts`, then `C-x C-a d`, type `gdb-preset RET`, pick `main`.
   Expect a compilation buffer, then the stop (about 17 s), the stack and Locals
   (with `opts`) in dape's info buffers; `C-x C-a w` adds a watch on `argc`.
2. `C-x C-a n` (step over), `C-x C-a s` (step in), `C-x C-a q` (quit); then
   `pgrep -x gdb` prints nothing.
3. `M-x customize-set-variable RET emacs-cpp-debug-lazy-symbols RET t`, repeat step 1:
   the stop comes after about 2 s.
4. Optional: set `emacs-cpp-debug-gdb-scripts` to
   `("~/source/repos/dealii/contrib/utilities/dotgdbinit.py")` and look at a
   `dealii::Vector` local.

## Open questions
O-15 (`repeat-mode` for dape's repeat map).
