# S2 - dape gdb launch

## Risk
DESIGN 9, D-002: dape is the debugger front-end, gdb's DAP mode (`gdb -i dap`) the
default adapter, lldb-dap the alternate. Question: can dape start gdb on a binary built
by the reference project's debug preset, stop at a source breakpoint, step, and show
the stack, locals and a watch expression? Also DESIGN 9's open points: where the
program path comes from, and whether breakpoints survive a session. Gates T-006 (v0.3).

## Prerequisites
gdb (18.1 at the dry run), lldb-dap (optional), cmake, ninja, rsync; dape vendored
(`lib/dape`, 0.27.1) and built (`make packages`). deal.II's pretty-printers are read
from `~/source/repos/dealii/contrib/utilities/dotgdbinit.py` (override:
`S2_DEALII_PRINTERS`). The copy goes to `/tmp/s2/work/rmo`; the build there compiles
the `main` target (a few minutes). Best on an idle machine.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s2-dape-gdb/run.sh ~/source/repos/RMO-gross-pitaevskii main
```
Breakpoint: the first line of `src/main.cc` containing `ProgramOptions opts`
(`S2_BREAK`); watch expression `argc` (`S2_WATCH`). The program is stopped at the
start of `main` and killed; it never runs to its end.

## What it measures
- `gdb alone`: plain gdb from start to the breakpoint (no DAP, no Emacs): the floor.
- Per variant (gdb as dape configures it; gdb with deal.II's printers; the same with
  shared-library symbols loaded on demand, `set auto-solib-add off`; lldb-dap): time
  from `dape` to the stop, the stack, the first scope's variables and one level into
  the first composite one, the watch value, the line after "next", the frame after
  "step in", whether the session ended and no debugger process is left, and whether
  a saved breakpoint comes back after "remove all" and "load".

## Pass criteria
PASS if, for at least one gdb variant: the stop is at the breakpoint line of
`src/main.cc` with `main` as the top frame; the scope lists at least one variable; the
watch `argc` gives a number; "next" stops on a later line of `src/main.cc`; "step in"
stops in a different frame or line; the session ends with no debugger process left;
the breakpoint comes back after load. Times are recorded, not judged (they feed
DESIGN 11 and T-006's choice of variant).

## Dry run (synthetic deal.II project, 2026-10-08)
gdb 18.1, dape 0.27.1, breakpoint at `main.cc:4`, all four variants pass the criteria:

| variant | stop after | locals | step in |
|---|---|---|---|
| gdb (dape default) | 16.0 s | class values empty, members one level down | tria.cc ctor |
| gdb + deal.II printers | 16.1 s | `v=Vector<double>(10){values = ...}` | libstdc++ |
| gdb + printers + lazy symbols | 1.0 s | scope empty (watch works) | libstdc++ |
| lldb-dap | 28.1 s, later 15.2 s | type names as values | tria.cc ctor |

Plain gdb to the same breakpoint: 16.0 s; `set auto-solib-add off`: 0.8 s. The time is
gdb reading `libdeal_II.g.so` (1.3 GB with debug info, 16.1 s alone); gdb's
`index-cache` does not shorten it (18.5 s warm). The script embedded in
`libdeal_II.g.so` holds Boost.Unordered printers (declined by gdb's auto-load
safe-path), not deal.II's; deal.II's `dotgdbinit.py` is a gdb command script and
fails when sourced under its `.py` name. The toy's compile commands carry both `-O0`
and `-O2` (deal.II's flags); `flags:` in the log shows RMO's.

## Optional: the interactive UI
Not driven by the script. In Emacs with the copy built: open `src/main.cc`, put point
on a line, `M-x dape-breakpoint-toggle`, then `M-x dape RET gdb :program
/tmp/s2/work/rmo/build/debug/main RET`; the REPL and info windows open and stepping
keys are under `C-x C-a`. Report anything that looks wrong.

## Hand back
`spikes/s2-dape-gdb/results.log` (run 1 kept as `results-run1.log`); delete
`/tmp/s2` afterwards.
