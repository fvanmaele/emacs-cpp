# S17 - compiled lisp/

## Risk
D-125 (owner 2026-10-20, review 0084 C-7, C-10, M-6: "Design for compile-lisp.patch
and spike"): `lisp/` loads as source and runs interpreted. Compiling it should make
per-candidate loops cheap (S16: D-124's function needs it), but review 0084 measured
compiled modules starting 108 ms slower with a harness it then withdrew for this
configuration. Questions: does byte-compiled `lisp/` change startup as the budget
measures it (`scripts/measure-startup.sh`, DESIGN 11), with Emacs's JIT native
compiler on and off, and do the modules' functions run native after startup? Spike
code is never promoted; a PASS leads to DESIGN 11.1's shape written fresh.

## What the spike builds
`run.sh` copies `init.el`, `early-init.el`, `lib/`, `lisp/` and
`scripts/measure-startup.sh` into two trees under a temporary directory: `interp`
as shipped, `byte` with `lisp/*.elc` from `compile.el` (init.el's prelude, the
review's patch's order, warnings counted; temporary HOME). Each round runs
`measure-startup.sh RUNS` on both trees with the JIT on and off (`(setq
native-comp-jit-compilation nil)` as its ELISP); then one start per tree and JIT
setting records the form of `emacs-cpp-match-tier` (init-completion, loaded at
startup), `emacs-cpp-presets-resolve` and `consult-buffer`: native, byte,
interpreted, autoload or unbound.

## Pass criteria (proposed 2026-10-20; confirmed by the owner 2026-10-21)
Arch, idle (load below 1), `run.sh 10 2`:
1. The compile: 0 failures.
2. Startup: `byte` with the JIT on has a median within 10 ms of `interp` with the JIT
   on, in both rounds.
3. Form: in `byte` with the JIT on, `emacs-cpp-match-tier` is native after startup.

## Prerequisites
`make packages` done; tmux (measure-startup.sh); Emacs 31.1 with native compilation.

## Commands (owner, Arch)
```sh
cd ~/source/repos/emacs-cpp
sh spikes/s17-compiled-lisp/run.sh 10 2 | tee spikes/s17-compiled-lisp/s17.log
```
Results go to `RESULTS.md` (`DRY-RUN.md` holds the Mac dry run).
