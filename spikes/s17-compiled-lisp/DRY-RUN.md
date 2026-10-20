# S17 dry run - Mac, 2026-10-20

Not a verdict: budgets bind on Arch (D-057); the owner's Arch run gives `RESULTS.md`.
The finding below does not look machine-dependent and should be checked first there.

## Environment
The owner's Mac (Apple silicon, 11 cores), MacPorts Emacs 31.1 with native
compilation, load 4.9 - 6.0 (not idle). Tree after 4683f20. `run.sh 10 2`; log
`dry-run-mac.log`. Diagnostics by hand afterwards (below), same trees.

## Measurements
- Compile: 19 files, 0 failed, 36 warning lines (the review's list, C-10).
- Startup, `measure-startup.sh` median of 10, rounds 1 / 2:

| tree | JIT on | JIT off |
|---|---|---|
| interp | 0.397 / 0.407 s | 0.363 / 0.374 s |
| byte | 0.915 / 0.909 s | 0.360 / 0.372 s |

- Form after startup: `interp` interpreted either way; `byte` native with the JIT
  on, bytecode with it off (`emacs-cpp-match-tier`, `emacs-cpp-presets-resolve`).
- Diagnosis (one start each, kill-emacs-hook): `interp` 214 features, nothing queued;
  `byte` JIT off 211 features, no magit, no `comp`; `byte` JIT on 304 features with
  magit loaded (its ~50 files, transient, with-editor, url, eieio, cape, server,
  shell, gud, info, ...) plus `comp` and `byte-opt` for 2 trampolines, and 45 files
  still queued for native compilation at exit.

## Reading
- Criterion 1 holds; 2 fails by about 510 ms; 3 holds.
- The bytecode itself costs nothing (JIT off: within noise of interpreted). The cost
  comes when the modules run as native code: something in them then loads magit
  at startup, which the interpreted and byte-compiled modules defer, and the newly
  loaded libraries are compiled again in the background at every start (the
  warm-up never loaded them, so no `.eln` exists).
- So the review's "compiled starts 108 ms slower" was real in direction and its
  cause is native code, not bytecode; its 108 ms against 510 here is the harness and
  the machine.
- Next step (S17 run 2, before the Arch run's verdict): find the form that loads
  magit under native code (candidates: `init-git.el`'s `treemacs-magit` with
  `:demand t :after (treemacs magit)`; a `declare-function` resolved by an autoload;
  a trampoline for an advised primitive), e.g. `(debug-on-entry 'require)` style
  logging of `(require 'magit)`'s caller in the `byte` tree with the JIT on.

## Gotchas
- `measure-startup.sh` gives each call a fresh HOME, so every call native-compiles
  all packages in its warm-up (minutes); `run.sh 10 2` took about 25 minutes here.
- A function `void` inside `kill-emacs-hook` is silently dropped at exit: probes
  must use only bound variables.
