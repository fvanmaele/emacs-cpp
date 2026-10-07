# 0002 - T-002: config skeleton and pinned packages

- **Date:** 2026-10-07
- **Commits:** see `git log -- init.el scripts/build-packages.el` (committed with this)
- **Tier:** 2
- **Decisions:** D-003, D-006, D-014 (supersedes D-007)
- **Done when:** `make packages && make test` pass, the owner symlinks per the
  handed-over commands and retires `~/.emacs`, and Emacs starts with no errors and the
  same theme, projectile, treemacs and magit behaviour as before
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The configuration now lives in this repository (D-003). `~/.emacs.d/init.el` and
`early-init.el` will be symlinks to the files here. The 17 packages the old `~/.emacs`
setup used (projectile, treemacs, magit, markdown-mode, org-journal and their
dependencies) are git submodules under `lib/`, each pinned to the exact commit the
owner was already running (D-006), so moving over changes no behaviour. package.el is
switched off. A small build script turns the submodules into something Emacs can load
quickly, and tests prove the result loads and matches the old setup.

## Concepts (Emacs Lisp) explained
- **load-path and require:** Emacs finds a library by name by searching the
  directories in `load-path`. `(require 'init-project)` loads `init-project.el` once
  and fails loudly if it is not found; that is how module order is enforced.
- **Autoloads:** a package marks entry points with `;;;###autoload`. Collecting those
  marks into one file lets Emacs know that `magit-status` exists, and which file
  defines it, without loading magit. The file is loaded on first use. This is why
  startup stays fast while all commands are available.
- **Byte-compilation:** `.el` source is compiled to `.elc` for faster loading. Emacs 31
  additionally compiles to native code in the background the first time a file loads.
- **use-package:** a macro that groups one package's setup. With
  `use-package-always-defer` nothing loads at startup unless a form asks (projectile
  does, through `:hook (after-init . projectile-mode)`). With
  `use-package-expand-minimally` an error in a form stops startup instead of being
  turned into a warning.
- **Symlinks and `file-truename`:** Emacs loads the symlink `~/.emacs.d/init.el`;
  `file-truename` resolves it to the repository, which is how `init.el` finds `lib/`.

## Key files walked
- `early-init.el` - turns package.el off and hides the tool bar before the first frame.
- `init.el` - loads the generated load path and autoloads, then the modules in order.
- `lisp/init-ui.el`, `init-project.el`, `init-git.el`, `init-writing.el` - one module
  per area; every directly used package has exactly one `use-package` form.
- `scripts/build-packages.el` - `build-packages-build`: reads `.gitmodules`, deletes old
  `.elc`, byte-compiles, writes `lib/load-path.el` and `lib/autoloads.el`.
- `.gitmodules` - besides url and path, per package: `load-path`, `build-exclude`,
  `ignore = untracked`.
- `test/build-packages-test.el` (9 unit tests on temporary trees) and
  `test/init-test.el` (loads the real config in batch; checks theme, projectile and
  `C-c p`, `C-x g`, markdown mode, treemacs commands, fresh `.elc` files).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** pinning the installed commits reproduces the old behaviour. **Would
  break if:** something the old setup got from package.el activation (not autoloads)
  is missing. **DESIGN bet:** D-006.
- **Assumed:** concatenating per-directory autoload files is equivalent to package.el's
  per-package autoload files. **Would break if:** a package's autoloads rely on
  `load-file-name` pointing at its own directory. **DESIGN bet:** DESIGN 12.
- **Assumed:** just-in-time native compilation is enough; startup measured 0.21-0.30 s
  against a 0.5 s budget (terminal frame). **Would break if:** the graphical frame or
  the later packages push startup past budget. **DESIGN bet:** D-010.
- **Assumed:** the treemacs, hydra, posframe and projectile files excluded from the
  build are never needed. **Would break if:** the owner uses evil, mu4e, perspective,
  persp-mode or all-the-icons with treemacs. **DESIGN bet:** DESIGN 12.
- **Risk:** the build script (183 code lines) is past the borg threshold; O-6,
  resolved by the owner the same day: keep it (D-015).
- **Risk:** Info manuals (magit, projectile) are not built yet; T-010.

## How to verify
```
cd ~/source/repos/emacs-cpp
git submodule update --init      # only on a fresh clone
make packages && make test       # expect: 17 packages built, 11 tests pass
```
Owner switch-over (real `~/.emacs.d`):
```
mv ~/.emacs ~/.emacs.retired-2026-10-07
ln -s ~/source/repos/emacs-cpp/early-init.el ~/.emacs.d/early-init.el
ln -s ~/source/repos/emacs-cpp/init.el ~/.emacs.d/init.el
emacs
```
Then check: no `*Warnings*` buffer about init, same theme, `C-c p p` lists projects,
`M-x treemacs` opens the tree, `C-x g` opens magit. The old `~/.emacs.d/elpa/` is no
longer used; delete it only after T-002 is confirmed.

## Open questions
None left from this entry; O-6 resolved as D-015.
