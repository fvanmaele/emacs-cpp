# 0099 - R and LaTeX removed

- **Date:** 2026-10-25
- **Commits:** see `git log --grep T-126`
- **Tier:** 2
- **Decisions:** D-145 (supersedes D-090, D-101, D-102, D-103 and D-072's R part;
  closes O-39)
- **Done when:** `lisp/init-r.el` and `lisp/init-latex.el` deleted; `lib/ess`,
  `lib/auctex` and `patches/auctex` removed; R cells dropped (Python cells stay);
  `C-c l b`, LaTeX yasnippet hooks, pdf-viewer defaults and the MacTeX PATH entry gone;
  tests adjusted, `make test` passes on the Mac; D-145 supersedes D-072 (R part), D-090,
  D-101, D-103; O-39 closed; T-079 dropped; README, MANUAL, CHEATSHEET updated,
  `docs/CHEATSHEET-AUCTEX.md` and `docs/upstream/texlab-*` deleted (agreed 2026-10-25).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner asked to keep only C/C++ and Python (2026-10-25). R (ESS, `# %%` cells in R)
and LaTeX (AUCTeX, texlab, `C-c l b` builds, `C-c l f` through latexindent) had ridden
along since D-072 and D-090; they cost two submodules, one patch, a quarter of
DESIGN 12's decisions and their tests, and never drove the design. Removing them is a
deletion: no C++ or Python behaviour changes. `.R` and `.tex` files now open in Emacs's
own built-in modes with no language server.

Two removals were not named word for word in the agreed line. D-102 (no LyX keys) only
said which keys LaTeX buffers keep, so it goes with D-090. `/usr/local/bin` was in
D-089's startup PATH list only for CRAN's R; on the Mac it now holds Ghostscript, Julia
and the `emacs` wrapper, none of which the config calls, so it left the list with R.

Kept: code-cells for Python, `lisp/init-writing.el` (markdown-mode, org-journal; the
owner's call), and the two RESEARCH files as findings, marked superseded.

## Concepts (Emacs Lisp) explained
- **Submodule removal.** `git submodule deinit -f` empties the checkout, `git rm`
  deletes the gitlink and its `.gitmodules` section, and `.git/modules/lib/<name>` is
  deleted by hand; `make packages` then writes `lib/load-path.el` and
  `lib/autoloads.el` without the two packages.
- **`locate-library`.** Returns the file `load` would read for a library name, or nil.
  The init test asserts nil for `init-r`, `init-latex`, `ess-r-mode` and `tex-site`, so
  a stale `lib/` checkout or a forgotten module would fail the suite.

## Key files walked
- `init.el` - the two `require` lines are gone; the module order is otherwise the same.
- `lisp/init-cells.el` - only Python's eval function and hook remain.
- `lisp/defaults-darwin.el`, `lisp/defaults-gnu-linux.el` - `emacs-cpp-default-pdf-viewer`
  removed; the Mac's PATH list is MacPorts' two directories.
- `lisp/init-completion.el` - yasnippet hooks `prog-mode` only.
- `test/init-test.el` - the module list and the `locate-library` check.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** nothing outside `init-r` / `init-latex` used ESS or AUCTeX.
  **Would break if:** a module called them lazily; `make test` (142 tests) and the
  load-alone test would show a void function only if a test exercises it.
  **DESIGN bet:** D-145.
- **Assumed:** no tool the config calls lives only in `/usr/local/bin` on the Mac.
  **Would break if:** the owner installs one there (e.g. a hand-built clangd); from the
  Dock it would not be found. **DESIGN bet:** D-089 as amended by D-145.
- **Assumed:** an owner's existing clone keeps empty `lib/ess`, `lib/auctex`
  directories after `git pull` until `git submodule update` / removal.
  **Would break if:** untracked leftovers confuse `make packages`; it reads
  `.gitmodules`, so they are ignored.

## How to verify
`make packages` then `make test` (Mac 2026-10-25: 142 tests, 139 passed, 3 skipped:
gdb x2, ty). Open a `.tex` file: Emacs's own `latex-mode`, no eglot. On Arch the
owner runs `make test` after pulling.
