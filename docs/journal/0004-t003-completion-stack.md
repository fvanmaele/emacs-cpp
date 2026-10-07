# 0004 - T-003: completion stack

- **Date:** 2026-10-07
- **Commits:** see `git log -- lisp/init-completion.el` (committed with this)
- **Tier:** 2
- **Decisions:** D-006 (pins), D-014 (clones with owner consent: "Start T-003")
- **Done when:** `C-x b`, `C-c p f`, `consult-ripgrep` show vertico candidates with
  annotations in the reference project, and corfu pops up completions while typing in
  an Emacs Lisp buffer (eglot part moved to T-004, see TASKS)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
CLion's "search everywhere", "go to file" and completion popup come, in Emacs, from a
set of small packages that each improve one part of the built-in completion system.
They were added as pinned submodules (newest release tags) and configured in one new
module, `lisp/init-completion.el`, loaded before the project module so that projectile's
prompts use them too. While measuring startup, an error in the earlier T-002 number was
found and corrected in DESIGN 11.

## Concepts (Emacs Lisp) explained
- **completing-read:** every Emacs prompt that offers choices (`C-x b`, `M-x`,
  `C-c p f`) goes through one function. Packages that improve it improve every prompt
  at once: vertico shows the candidates as a list, orderless decides what matches
  ("mod gpe" finds `include/rmo/gpe/model.h`), marginalia adds a description column.
- **completion-at-point:** the in-buffer counterpart. Modes (later eglot with clangd)
  register functions that propose completions at the cursor; corfu shows them as a
  popup, cape adds extra sources (file names here).
- **xref:** Emacs's go-to-definition and find-references front end. Setting
  `xref-show-xrefs-function` to `consult-xref` makes multiple results appear as a
  filterable list with preview, like CLion's usage popup.
- **use-package `:bind` and `:init`:** `:bind` creates key bindings that load the
  package on first use; `:init` runs at startup (used here for the modes that must be
  on from the start).

## Key files walked
- `lisp/init-completion.el` - one `use-package` form per package; key bindings follow
  consult's and embark's READMEs at the pinned versions.
- `test/init-test.el` - now loads the configuration once; new tests check that the
  modes are on, the key bindings, and a real orderless match.
- `.gitmodules` - vertico and corfu add their `extensions` directories to the load
  path; the projectile-consult exclude is gone.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** Emacs 31's built-in `compat` stub satisfies the "compat 31" these
  packages declare. **Would break if:** a package calls a compat function Emacs 31
  lacks (would show as a void-function error). **DESIGN bet:** DESIGN 12.
- **Assumed:** turning vertico, marginalia and corfu on at startup fits the startup
  budget. **Would break if:** T-008's idle measurement exceeds 0.5 s (under load:
  0.77 - 1.21 s, not a verdict). **DESIGN bet:** D-010.
- **Assumed:** `C-.` and `C-;` (embark) work in the owner's graphical Emacs; terminals
  cannot send them. **Would break if:** the owner uses Emacs in a terminal.
  **DESIGN bet:** D-004.
- **Correction:** the T-002 startup figure (0.21 - 0.30 s) used `emacs-init-time`,
  which stops before `after-init-hook`; DESIGN 11 now defines startup to the end of
  that hook.

## How to verify
```
sudo pacman -S ripgrep           # consult-ripgrep needs the rg binary
cd ~/source/repos/emacs-cpp && make packages && make test     # 13 tests pass
```
Then in a restarted Emacs: `C-x b` (buffers with annotations), `C-c p f` in RMO then
type `mod gpe`, `M-s r` and a search term in RMO, `M-x` (commands with key bindings
and docstrings), and in `*scratch*` type `(with-` and wait for the corfu popup.

## Open questions
None.
