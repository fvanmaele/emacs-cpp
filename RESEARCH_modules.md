# RESEARCH - Turning modules on and off, as Doom Emacs does

Question (owner, 2026-10-14): research a separate configuration for enabling and
disabling modules, similar to Doom Emacs. Findings only; verdicts go to DESIGN.

Sources: Doom Emacs's repository (github.com/doomemacs/doomemacs, shallow clone of
59cdaa3, 2026-10-02: `static/init.example.el`, `lisp/doom-modules.el`,
`docs/getting_started.org`) and its module repository (github.com/doomemacs/modules,
42a0479, 2026-10-02: `modules/lang/cc/`); Prelude's `sample/prelude-modules.el` and
Spacemacs's `core/templates/dotspacemacs-template.el` (develop), read 2026-10-14; this
repository's `init.el`, `lisp/`, `lib/autoloads.el`, measured on the Mac.

## 1. Doom Emacs
- **Where the choice lives:** the user's `$DOOMDIR/init.el` (outside Doom's own
  directory) holds one `(doom! ...)` form: category keywords (`:completion`, `:ui`,
  `:editor`, `:tools`, `:lang`, `:config` and more), under each the modules. A module
  is on when its name is there, off when its line is commented out (`;;company`);
  options are flags, `(corfu +orderless)`, `(cc +lsp)`, `(lsp +eglot)`. Load order is
  Doom's, not the order of the lines (each module has a depth).
- **A module** is a directory `modules/<category>/<name>/` with `packages.el`
  (`package!` with a pinned commit per package), `config.el` (loaded at startup, in
  interactive sessions), `init.el` (earlier, always), `autoload.el` or `autoload/`,
  `doctor.el` (checks run by `doom doctor`) and `README.org`. Since the v3 work the
  modules sit in their own repository (`doomemacs/modules`), a git submodule of
  Doom's (`sources/doom+`).
- **Code asks what is on:** `(modulep! :tools lsp)`, `(modulep! +lsp)` inside a
  module, negated flags `(modulep! :tools lsp -eglot)`. `lang/cc` takes `ccls` only
  `(when (and (modulep! +lsp) (modulep! :tools lsp -eglot)))`; its `doctor.el`
  asserts "This module requires (:tools lsp)" when `+lsp` is given without it.
- **After a change:** "any changes to your `doom!` block won't take effect until you
  run `doom sync` on the command line", which installs the packages of the modules
  now on, removes orphaned ones and regenerates Doom's autoloads and caches.
- **Mistakes:** "Flags that a module does not recognize will be silently ignored";
  a removed or moved module prints a warning and is ignored or remapped
  (`doom-module-mplist-map`), warnings hidden at startup by default
  (`doom-inhibit-module-warnings`); `doom doctor` reports duplicated or misspelled
  modules and flags.
- **Size:** 13 categories, 160 modules (67 under `lang`).

## 2. Prelude and Spacemacs
- **Prelude:** `sample/prelude-modules.el`, copied by the user to `personal/`, is a
  list of `(require 'prelude-...)` lines, the unwanted ones commented out:
  "Uncomment the modules you'd like to use and restart Prelude afterwards". It warns
  that some cannot be used together (`prelude-ido` and `prelude-ivy`). No flags, no
  package step: modules install their packages when loaded.
- **Spacemacs:** `~/.spacemacs` sets `dotspacemacs-configuration-layers`, a list of
  layer names, some with variables (`(shell :variables shell-default-height 30)`);
  `SPC f e R` reloads. `dotspacemacs-install-packages` `used-only` (default)
  "installs only explicitly used packages and deletes any unused packages".

## 3. This config today
`init.el` requires 13 modules in a fixed order, the contract of DESIGN 5 ("a module
may only use modules above it"); each package is in exactly one module (principle
3); a missing module or package stops startup (principle 1). DESIGN 2 lists "an
Emacs distribution (no Doom / Spacemacs layer)" as a non-goal.

**What the modules need** (their `require`s and the functions they call):
- `init-cpp`: init-lsp, `emacs-cpp-presets`, `emacs-cpp-refactor`.
- `init-latex`: init-lsp (`emacs-cpp-lsp-server`, `emacs-cpp-code-map`).
- `init-python`: init-lsp's `emacs-cpp-lsp-server`, without a `require`: it works
  only because init-lsp loads before it.
- `init-project`, `init-debug`: `emacs-cpp-presets`.
- `init-git`: treemacs-magit waits for treemacs (init-project) and magit.
- `init-cells`: Python's and ESS's shells, when their buffers are used.
- `init-completion`: eglot and projectile at use only (`M-o`).
- `init-ui`, `init-lsp`, `init-cmake`, `init-r`, `init-writing`: none.

**Startup cost per module** (Mac, batch, five runs, median; time of each `require`
in init.el's order, so a later module does not pay for a library an earlier one
loaded): completion 164 ms, cpp 72, python 16, project 9.3, r 2.4, debug 1.5, cmake
1.4, ui 1.2, lsp 1.2, latex 1.0, cells 1.0, writing 1.0, git 0.8; init.el in all 352
ms, `after-init-hook` 117 ms. The modules that only ride along (python, r, latex,
cells, writing) cost 21 ms together, 16 of them Python's.

**Their packages** (submodules): latex: auctex (7.9 MB checked out, 16 MB of git
data); r: ess (3.4 / 30 MB); cells: code-cells; writing: markdown-mode, org-journal;
python: none (system packages). All of them are built by `make packages` and listed
in `lib/load-path.el` and `lib/autoloads.el` whatever `init.el` requires.

**What stays on with a module left out:** `init.el` loads `lib/autoloads.el` for every
package, and some autoloads act at once: AUCTeX's include `(require 'tex-site)`, so
`.tex` files still open in AUCTeX's `LaTeX-mode` (unconfigured, no texlab); ESS's add
`.R`, `.r`, `NAMESPACE` to `auto-mode-alist`; markdown-mode, org-journal and magit
add their own. Commenting out `(require 'init-latex)` therefore does not turn LaTeX
off, it turns its configuration off.

**Tests** load the shipped profile, all modules: `init-test` checks that every module
is loaded, `init-cpp-test` that `C-c l` has exactly its letters (`b` from init-latex
among them). A module set that differs from the shipped one is untested.

## 4. Options (for O-48)
- (a) **As now, documented:** leaving a module out is a commented `require` in
  `init.el`, a change in the repository (per machine: an uncommitted change or a
  branch). Its packages' autoloads stay (above).
- (b) **A module list outside the repository**, as Prelude: e.g.
  `~/.emacs.d/emacs-cpp-modules.el` (next to `custom.el`, D-003), read by `init.el`
  before the modules, naming the optional ones to load. `init.el` keeps the order and
  the core modules (ui, completion, project, lsp, cpp, cmake, debug, git); an unknown
  name or a module whose prerequisite is off stops startup with the reason (Doom
  only warns). Packages' autoloads stay as in (a).
- (c) **(b) plus the packages:** `make packages` reads the same list and leaves the
  packages of modules that are off out of `lib/load-path.el` and `lib/autoloads.el`
  (a module named per submodule in `.gitmodules`); `init.el` stops ("run make
  packages") when the list and the built files disagree. The equivalent of `doom
  sync`; a disabled LaTeX module then leaves `.tex` to Emacs's own `latex-mode`.
  Submodules still fetched unless `git submodule update` is told to skip them.
- (d) **Flags as Doom's** (`(cpp +patched-clangd)`, `(completion +snippets)`): this
  config's options are user options today (`emacs-cpp-clangd-program`,
  `emacs-cpp-tree-follow-file`, ...), set with Customize; flags would be a second
  way to say the same.
- (e) **None:** one owner, every module on both machines; DESIGN 2's non-goal stays as
  written.

Each of (b) - (d) touches DESIGN 2 (non-goal), DESIGN 5 (load model) and the tests
(the shipped profile is every module; another set would need its own test run).

## 5. Not checked
- Which modules the owner would turn off, and on which machine.
- Startup in a graphical Emacs and on Arch (the numbers above are Mac, batch).
- How `git submodule update` could skip the submodules of modules that are off (for
  (c)); `submodule.<name>.update = none` exists in git's configuration, not tried.
