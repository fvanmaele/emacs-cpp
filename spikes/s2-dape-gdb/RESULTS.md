# S2 - dape gdb launch: results

Verdict: PASS (run 1, 2026-10-08). On RMO's debug build of `main`, dape started gdb's
DAP mode, stopped at the source breakpoint `src/main.cc:76` with `main` as the top
frame, listed variables, evaluated the watch `argc` (= 1), stepped over (to line 80)
and in (a new frame), ended the session with no debugger process left, and restored a
saved breakpoint. All three gdb variants and lldb-dap meet every criterion.

## Run 1 (2026-10-08 06:28, load 0.89)
Raw output: `results-run1.log`. gdb 18.1, dape 0.27.1, lldb-dap (LLVM 23).

| variant | stop after | first scope | step in |
|---|---|---|---|
| gdb alone (no DAP, no Emacs) | 17404 ms | - | - |
| gdb (dape default) | 17264 ms | Arguments: argc=1, argv | libstdc++ allocator |
| gdb + deal.II printers | 17407 ms | Arguments: argc=1, argv | libstdc++ allocator |
| gdb + printers + lazy symbols | 2331 ms | Arguments: argc=1, argv | libstdc++ allocator |
| lldb-dap | 15440 ms | Locals: argc, argv, opts | boost options ctor |

## Findings
- dape adds no measurable time: gdb through dape stops as fast as gdb alone (17.3 vs
  17.4 s). The time is gdb reading the shared libraries' debug information
  (`libdeal_II.g.so`, 1.3 GB; dry run: 16.1 s for it alone).
- Loading shared-library symbols on demand (`set auto-solib-add off`) cuts the stop
  to 2.3 s. Cost: no symbols for deal.II code until loaded (`sharedlibrary`); in the
  dry run the Locals scope came back empty in this mode, while watches worked.
- gdb's first scope for RMO's `main` is "Arguments" (argc, argv); the script reads
  only the first scope, so "Locals" (e.g. `opts`) was not printed for gdb on RMO.
  The deal.II printers were shown working through dape in the dry run (`Vector<double>`
  with its values), not on RMO, whose `main` has no deal.II local at line 76.
- lldb-dap: 15.4 s, full stack down to `_start`, a "Locals" scope with all three
  variables, values given as type names for classes.
- RMO's debug compile command is `-g -O2 -O0 -ggdb`: the last `-O0` wins, the build
  is unoptimised (deal.II's flags add `-O2` first).
- Program path: the preset's `binaryDir` plus the CMake target name
  (`build/debug/main`), the same rule `run.sh` uses.
- Breakpoints across sessions: `dape-breakpoint-save` / `dape-breakpoint-load` keep
  source breakpoints (1 saved, 0 after remove-all, 1 after load) in every variant.

## Not covered
The interactive windows (REPL, info buffers, fringe marks, `C-x C-a` keys) were not
driven; RUN.md's optional manual check covers them.
