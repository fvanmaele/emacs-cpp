# emacs-cpp

An Emacs 31 configuration that gives one owner a CLion-like C++ environment on an Arch
Linux workstation: navigation, refactoring and diagnostics through eglot and clangd,
builds from CMake presets, debugging through dape and gdb, git through magit, and
jump-to-anything through vertico and consult. Python rides along (D-045).

It is not an Emacs distribution, not a multi-OS configuration and not a CLion keymap
emulation (DESIGN 2). This file never claims more than `DESIGN.md` backs; the feature
list with its gaps against CLion is DESIGN 1. Everyday use is `docs/MANUAL.md`, every
key is in `docs/CHEATSHEET.md`.

## Install on Arch Linux (supported)

### 1. System packages
```sh
sudo pacman -S --needed emacs git make texinfo \
    cmake ninja gcc clang gdb lldb \
    tree-sitter-python pyright python-debugpy \
    fd ripgrep
```
- **Emacs 31** with native compilation and tree-sitter (the Arch `emacs` package).
- **tree-sitter-cpp** must also be installed as a pacman package. On the owner machine
  it is built locally (DESIGN 3). Startup stops if the C++ or Python grammar is
  missing (D-008, D-045).
- **cmake** ships `cmake-mode.el` in `/usr/share/emacs/site-lisp`, which the config
  loads (D-013). **clang** provides clangd, clang-tidy and clang-format.
- **texinfo** provides `makeinfo` and `install-info`; `make packages` fails without
  them (D-039).

### 2. Clone and build the packages
All packages are git submodules pinned in `lib/` (D-006). Nothing is downloaded when
Emacs starts (D-014).
```sh
git clone --recurse-submodules git@github.com:fvanmaele/emacs-cpp \
    ~/source/repos/emacs-cpp
cd ~/source/repos/emacs-cpp
make packages    # byte-compile lib/, write lib/load-path.el, lib/autoloads.el, lib/info/
make test        # optional: the ERT suite, loads init.el in batch
```
Bare `make` only lists the targets.

### 3. Link the config into ~/.emacs.d
The repository is loaded through two symlinks (D-003). An existing `~/.emacs` shadows
`~/.emacs.d/init.el`, so move it aside first.
```sh
mv ~/.emacs ~/.emacs.retired                       # only if it exists
mkdir -p ~/.emacs.d
ln -s ~/source/repos/emacs-cpp/init.el       ~/.emacs.d/init.el
ln -s ~/source/repos/emacs-cpp/early-init.el ~/.emacs.d/early-init.el
```
Start Emacs. A missing package, grammar or generated file stops startup with an error
that names the fix (DESIGN 4).

### 4. Optional: the patched clangd
`packaging/clangd-index-nav` builds clangd 23.1.1 with local patches. It answers
go-to-definition and find-usages from its index before a file is parsed, and gives a
header the flags of a source file that includes it (D-026 .. D-028, D-046, D-047). It
installs to `/opt/clangd-index-nav`, next to the system clangd, and pins `llvm-libs`
and `clang` to 23.1.1 exactly (D-027).
```sh
cd ~/source/repos/emacs-cpp/packaging/clangd-index-nav
makepkg -si
```
Then set `emacs-cpp-clangd-program` to `/opt/clangd-index-nav/bin/clangd` with
`M-x customize-variable`. Nil, the default, uses the system clangd. A configured
program that is missing or lacks the patched flags refuses to start, it never falls
back silently. An LLVM upgrade needs a rebuild of this package.

### 5. What a C++ project needs
- **A git root and a `CMakePresets.json`.** eglot starts only for C++ files of such a
  project (D-005, D-019). The first non-hidden configure preset is active until
  `C-c l P` picks another (D-017).
- **A `binaryDir` per preset** with `CMAKE_EXPORT_COMPILE_COMMANDS=ON`. clangd reads
  `compile_commands.json` from there (D-016).
- **`set(CMAKE_CXX_EXTENSIONS OFF)`** in the project, so every compile command carries
  `-std=`. Without it eglot refuses to start (D-011, D-018).
- **The Ninja generator** if you want `gdb-preset` to list the debuggable programs
  (D-033).

Configure once with `cmake --preset <name>` or `C-c p c o`, then open a source file.

### Updating
Package upgrades are commits that move a submodule (D-006). After a pull:
```sh
git submodule update --init
make packages
```

## macOS (not supported)
macOS is a non-goal (DESIGN 2). On the owner's Mac (Apple silicon, MacPorts, Emacs
31.1) on 2026-10-09, the config **does not start as shipped**. The steps below get as
far as the known blockers; they are a record, not a promise.

### What was tried
```sh
sudo port install emacs-app +nativecomp +treesitter
sudo port install cmake ninja clang-23 tree-sitter-cpp tree-sitter-python \
    texinfo ripgrep fd pyright py314-debugpy
sudo port select --set clang mp-clang-23   # /opt/local/bin/clangd -> clangd 23
xcode-select --install                     # lldb-dap from the Command Line Tools
```
The MacPorts Emacs lives in `/Applications/MacPorts/Emacs.app`; pass its binary when
it is not on `PATH` as `emacs`:
```sh
make packages EMACS=/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs
```
Clone and symlink as in steps 2 and 3 above. With these ports, Emacs finds both
tree-sitter grammars and `make packages` builds all packages and manuals.

### Known blockers
- **Startup stops in the CMake module.** It expects `cmake-mode.el` in
  `/usr/share/emacs/site-lisp`; MacPorts installs it in
  `/opt/local/share/emacs/site-lisp`. The error, wrapped here:
  ```
  emacs-cpp: no cmake-mode.el in /usr/share/emacs/site-lisp;
  install the cmake package (D-013)
  ```
- **No gdb on Apple silicon.** `gdb-preset` (D-031) drives gdb only; lldb-dap is
  reachable only through dape's own configurations.
- **The patched clangd is Arch-only.** Its PKGBUILD needs makepkg and the Arch LLVM
  packages; leave `emacs-cpp-clangd-program` nil to use the MacPorts clangd.
- **`${hostSystemName}` in a preset is an error** outside GNU/Linux.
- **`make test` fails 17 of 45 tests** on that machine, the first cause being the CMake
  module above.

Homebrew was not tried.

## Repository layout

### The Emacs configuration
`init.el` requires the modules in the order of this table, then loads `custom.el`.
Load order is the contract: a module may only use modules loaded before it (DESIGN 5).

| Path | Role |
|---|---|
| `early-init.el` | before the first frame: startup GC threshold, no package.el |
| `init.el` | loads the generated files, sets up use-package, requires the modules |
| `lisp/init-ui.el` | theme, which-key, Info manuals of the packages |
| `lisp/init-completion.el` | vertico, orderless, marginalia, consult, embark, corfu, cape |
| `lisp/init-project.el` | projectile, treemacs (`C-c t`) |
| `lisp/init-cpp.el` | `c++-ts-mode`, eglot and clangd, breadcrumb, the `C-c l` map |
| `lisp/emacs-cpp-presets.el` | presets: active preset, clangd command, build commands |
| `lisp/init-cmake.el` | `cmake-mode` from the system cmake package |
| `lisp/init-debug.el` | dape, `gdb-preset`, breakpoints in the fringe |
| `lisp/init-python.el` | `python-ts-mode`, pyright, debugpy |
| `lisp/init-git.el` | magit, treemacs-magit, diff-hl |
| `lisp/init-writing.el` | markdown-mode, org-journal |
| `lib/<package>/` | the 28 pinned package submodules (DESIGN 12) |
| `lib/load-path.el`, `lib/autoloads.el` | generated by `make packages`, git-ignored |
| `lib/info/` | package manuals, generated by `make packages`, git-ignored |

Outside the repository, in `~/.emacs.d/`: `custom.el` (Customize writes here, D-003,
D-040), `emacs-cpp-presets.eld` (the active preset per project, D-017), and Emacs's own
history and caches.

### Build, tests, packaging
| Path | Role |
|---|---|
| `Makefile`, `standard.mk` | `make packages`, `test`, `check`; bare `make` prints help |
| `scripts/build-packages.el` | builds `lib/` from the `.gitmodules` entries |
| `scripts/check-standard.sh` | docs consistency (`make check`) |
| `scripts/measure-startup.sh` | startup time measurement (DESIGN 11) |
| `test/*-test.el` | ERT tests, one file per module |
| `packaging/clangd-index-nav/` | PKGBUILD and patches of the patched clangd |
| `spikes/` | throwaway prototypes with PASS / FAIL verdicts, listed in their README |

### Documents
| Path | Role |
|---|---|
| `docs/MANUAL.md` | user manual: the screen, how the parts fit, everyday tasks |
| `docs/CHEATSHEET.md` | every key the configuration binds |
| `docs/journal/` | one teaching entry per change or spike result, from `TEMPLATE.md` |
| `docs/upstream/` | bug reports prepared for upstream projects |
| `DESIGN.md` | what this is and why: decisions ledger (D-nnn), open questions |
| `TASKS.md` | work derived from DESIGN rulings |
| `JOURNAL.md` | index of `docs/journal/` |
| `POSTMORTEM.md` | lessons from the git history |
| `RESEARCH_*.md` | findings behind a decision; verdicts live in DESIGN |
| `CLAUDE.md` | working rules for LLM sessions in this repository |
