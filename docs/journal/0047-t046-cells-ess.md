# 0047 - T-046: `# %%` cells in Python and R, ESS for R

- **Date:** 2026-10-10
- **Commits:** the commit that adds this entry (`lisp/init-r.el`, `lisp/init-cells.el`,
  `lib/code-cells`, `lib/ess`, `scripts/build-packages.el`, tests)
- **Tier:** 2
- **Decisions:** D-072 (built here), O-29 (a), (b)
- **Done when:** `lib/code-cells` (b99013b) and `lib/ess` (v25.01.0, `load-path = lisp`,
  `info = doc/ess.texi`) are submodules and `make packages` builds them without errors;
  `.R` files open in `ess-r-mode`, no eglot for R; in `python-ts-mode` and `ess-r-mode`
  buffers `code-cells-mode` is on: `C-c C-c` runs the cell at point in the buffer's REPL
  (`run-python` or R, started if needed, R in the project root without a question),
  `M-n` / `M-p` move between cells, `C-c % s` runs and steps, Python's send-buffer stays
  on a key; ERT: Python and R cells share state (R tests skipped with a message where R
  is missing), the keys, `ess-r-mode` for `.R`, R's start directory; `make test` passes
  on Arch; MANUAL, cheat sheet, README, DESIGN 12 updated; startup median on Arch within
  D-057's budget; owner: an RMO R script and a plotting script with `# %%` cells run
  cell by cell (agreed 2026-10-10).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
A script can now be run in pieces. A line starting with `# %%` begins a cell (the
format jupytext, VS Code and Spyder use); `C-c C-c` sends the cell under the cursor to a
shell that keeps its variables, `M-n` / `M-p` move between cells. In Python files the
shell is Emacs's own `run-python`; R files now open in ESS (Emacs Speaks Statistics),
which runs R and sends code to it. Both shells start on the first `C-c C-c`; R starts
in the project root without asking. `C-c % b` runs the whole file, in place of Python's
own `C-c C-c` (send buffer), which the cell key now covers.

Three things did not work out of the box:
- **ESS could not find itself.** ESS computes its own directory from the file its
  autoloads are read from. package.el keeps one autoloads file per package, in the
  package's directory; this configuration writes all of them into `lib/autoloads.el`
  (D-006), so ESS looked for its `etc/` directory in `lib/` and every R file failed to
  open ("stringp nil"). `lisp/init-r.el` names ESS's real directory before ESS loads.
  Changing the build to fake a per-package file name was ruled out: magit's autoloads
  also use that name, differently, and would have broken.
- **ESS's manual did not build.** `doc/ess.texi` includes `../VERSION`, a path from its
  own directory; the build ran `makeinfo` from the repository root. It now runs it from
  the manual's directory, for every package.
- **Python's shell lost the first cell.** Code sent before the shell's first prompt is
  dropped; the cell command waits for that prompt (up to 10 s, then an error).

ESS's style checks (flymake through the R package lintr) are off: lintr is a CRAN
package, packaged neither on Arch nor in MacPorts, and without it every check logged
"lintr package not installed" as an error. R's start in the project root needed no
code: ESS does that itself through `project-current`; the config only stops the
question.

## Concepts (Emacs Lisp) explained
- **Autoloads.** Small stubs, read at startup, that load a package the first time one of
  its commands or modes is used. A stub can also contain plain code, which then runs at
  startup with `load-file-name` set to the autoloads file: that is where ESS's guess went
  wrong.
- **`:init` versus `:config` in `use-package`.** `:init` runs at startup, before the
  package loads (here: name ESS's directory); `:config` runs once it has loaded (here:
  code-cells' keys and backends).
- **Minor-mode keymaps.** `code-cells-mode` is a minor mode; its keymap takes precedence
  over the major mode's, which is how `C-c C-c` means "run cell" in both Python and R
  without touching either mode's own map.

## Key files walked
- `lisp/init-r.el` - ESS: its directory, no question at R's start, flymake off.
- `lisp/init-cells.el` - `emacs-cpp-cells--python-eval` (start the shell, wait for the
  prompt, send), `emacs-cpp-cells--r-eval`, `emacs-cpp-cells-eval-buffer`; code-cells'
  hooks and keys.
- `scripts/build-packages.el` - `build-packages-write-info`: makeinfo from the manual's
  directory.
- `test/init-cells-test.el` - modes and keys; Python cells share state with no shell
  running; R cells share state and R starts in the project root (skipped without R).
  `test/build-packages-test.el` - a manual's `@include` relative to the manual.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** python.el keeps `python-shell--first-prompt-received` (internal, since
  25.1) as the sign that the shell is ready. **Would break if:** it is renamed; the wait
  would then time out loudly after 10 s. **DESIGN bet:** D-072.
- **Assumed:** ESS keeps reading its directory from `ess-lisp-directory` if it is set
  before ESS loads (a defcustom keeps an existing value). **Would break if:** ESS
  computes it differently; the modes-and-keys test checks `ess-etc-directory`.
- **Risk:** an ESS upgrade past v25.01.0 could add other autoloaded code that assumes
  its own directory; the same test would catch the common case.
- **Risk (not checked):** ESS names its R process per project
  (`ess-gen-proc-buffer-name:project-or-simple`), so two R files of one project likely
  share one R, and their variables mix.

## How to verify
`make packages`, then `make test` (Arch: R installed, so the R test runs). Startup
median 0.161 s on Arch (budget 0.5 s, D-057). Owner, on RMO: add `# %%` lines to
`R/plot_ml.R` and `staging/plot_convergence.py`, open each, and press `C-c C-c`, `M-n`,
`C-c C-c`: the shell starts, the second cell sees the first one's variables, plots show.
