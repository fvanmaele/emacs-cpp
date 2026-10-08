# emacs-cpp cheat sheet

Keys as bound by this configuration (checked 2026-10-08 with `where-is` in the shipped
config). `M-x cmd` means: no key yet, run the command by name (`M-x`, then type part of
the name; completion is fuzzy). Notation: `C-` = Control, `M-` = Meta (Alt; Option on
macOS), `RET` = Enter.

## Code navigation (clangd through eglot)
| Key | Does |
|---|---|
| `M-.` | go to definition (on a name or an `#include` line) |
| `M-?` | find usages (references) |
| `M-,` | go back to where you were before `M-.` / `M-?` |
| `C-M-,` | go forward again |
| `C-M-.` | search symbols in the whole project by name |
| `M-x consult-eglot-symbols` | the same, with live preview |
| `M-g i` | symbols of this file (functions, classes); `M-g I`: of all open files |
| `M-x eglot-find-implementation` | implementations / overrides |
| `M-x eglot-find-declaration` | declaration (header) of a definition |
| `M-x eglot-find-typeDefinition` | definition of the type of the thing at point |
| `C-c p a` | switch between header and source (`.h` <-> `.cc`) |

Several results open as a list with preview: move with the arrows, `RET` jumps.

## Refactoring and code actions
| Key | Does |
|---|---|
| `M-x eglot-rename` | rename the symbol in the whole project |
| `M-x eglot-code-actions` | fixes and refactorings clangd offers here |
| `M-x eglot-format-buffer` | clang-format the file (`eglot-format`: the region) |
| `M-;` | comment / uncomment the region or line |

## Errors and warnings (flymake)
| Key | Does |
|---|---|
| `M-g f` | list this file's diagnostics, jump with preview |
| `M-x flymake-goto-next-error` | next diagnostic (`...-prev-error`: previous) |
| `M-x flymake-show-project-diagnostics` | all diagnostics of the project |
| `M-g e` | jump to an error in the `*compilation*` buffer |
| `M-g n` / `M-g p` | next / previous compilation error |

## Completion
| Key | Does |
|---|---|
| `TAB` or `C-M-i` | complete at point (no popup while typing, D-020) |
| `M-n` / `M-p` (or arrows) | next / previous candidate in the popup |
| `RET` | insert the candidate; `C-g` cancels |
| `M-h` | documentation of the candidate; `M-g`: its location |

## Jump to anything / search
| Key | Does |
|---|---|
| `C-x b` | buffers, recent files, bookmarks in one list |
| `C-x p b` | buffers of this project |
| `C-c p f` | find a file in the project |
| `C-c p d` | find a directory in the project; `C-c p e`: recent project files |
| `M-s r` | ripgrep the project (live results) |
| `M-s G` | git grep; `M-s g`: grep |
| `M-s d` | find files by name (fd) |
| `M-s l` | lines of this buffer; `M-s L`: of all buffers |
| `M-g g` | go to line |
| `M-y` | choose from the kill ring (paste history) |

In any list: words separated by space match in any order (`vec tria` finds
`tria_vector.h`). `M-r` in the minibuffer: history.

## Act on things (embark)
| Key | Does |
|---|---|
| `C-.` | actions on the thing at point or the selected candidate |
| `C-;` | the default action at point |
| `C-.` then `E` | export a candidate list to a buffer (e.g. grep results to edit) |
| `C-h B` | search all key bindings |
| prefix then `C-h` | list what a prefix (e.g. `C-c p`) offers |

## Projects, CMake presets, building
| Key | Does |
|---|---|
| `C-c p p` | switch project |
| `C-c l P` | choose the active CMake preset (clangd restarts with its build dir) |
| `C-c p c c` | compile the project (asks for the command) |
| `C-c p c o` / `c t` / `c r` | configure / test / run (also ask) |
| `C-c p t` | toggle between implementation and test |
| `C-c p !` | shell command in the project root |
| `C-c p r` | replace text in the whole project |
| `C-c p k` | kill all buffers of the project |

For a preset build, answer the compile prompt with e.g.
`cmake --build --preset debug` (the prompt remembers it).

## Git (magit)
| Key | Does |
|---|---|
| `C-x g` | status (stage `s`, unstage `u`, commit `c c`, push `P`, pull `F`, log `l l`) |
| `C-x M-g` | all magit commands |
| `C-c M-g` | commands for the current file (blame, log, diff) |
| `?` in magit | help for the current buffer |

## Project tree (treemacs)
No key yet: `M-x treemacs` opens / closes it. Inside the tree:

| Key | Does |
|---|---|
| `TAB` | expand / collapse |
| `RET` | open file |
| `o v` / `o h` | open in a vertical / horizontal split |
| `c f` / `c d` | create file / directory |
| `R` / `m` / `d` | rename / move / delete |
| `y r` / `y a` | copy relative / absolute path |
| `C-c C-p a` | add a project to the workspace |
| `t h` | show / hide dotfiles |
| `?` | help |
| `q` | close the tree |

## Not there yet
- Debugger and breakpoints (dape, gdb): milestone v0.3, spike S2.
- The `C-c l` code-action keys (rename, format, implementation, ...): T-007. Until then
  use the `M-x` commands above. `which-key` is not enabled; `C-h` after a prefix lists
  its keys.

## Setup on the supported machine (Arch Linux)
1. Clone with submodules; `~/.emacs.d/init.el` and `early-init.el` are symlinks to this
   repository (D-003). `make packages` byte-compiles the pinned packages.
2. Patched clangd (D-026, D-027):
   `cd packaging/clangd-index-nav && makepkg -si` (about 30 min), then
   `M-x customize-variable RET emacs-cpp-clangd-program` =
   `/opt/clangd-index-nav/bin/clangd`, "Save for future sessions". Leave it nil for
   the system clangd.
3. A project needs a `CMakePresets.json` with `CMAKE_EXPORT_COMPILE_COMMANDS` on and
   `CMAKE_CXX_EXTENSIONS OFF` (D-011), configured once (`cmake --preset debug`).
4. Verbose clangd log, for diagnosis: `M-: (setenv "CLANGD_FLAGS" "--log=verbose")`
   before opening the project, then `M-x eglot-stderr-buffer`.

## macOS (outside DESIGN 2, untested)
DESIGN 2 scopes this configuration to one Arch Linux machine; nothing below has been
run. Known differences:

1. Emacs 31.1 with tree-sitter (and preferably native compilation), e.g. from Homebrew
   or built from source. Meta is Option; if Option types special characters, set
   `ns-alternate-modifier` to `meta`.
2. Same clone, symlinks and `make packages` as above (needs git and make from the
   Xcode command line tools).
3. C++ grammar: there is no system package. Run
   `M-x treesit-install-language-grammar RET cpp RET` once (Emacs 31 knows the source;
   needs git and a C compiler). Without it the config stops at startup (D-008).
4. Presets that use `${hostSystemName}` are refused: the config only expands it on
   Linux (`lisp/emacs-cpp-presets.el`). Other presets work as on Linux.
5. Unpatched clangd: `emacs-cpp-clangd-program` nil runs `clangd` from Emacs's
   `exec-path`. Homebrew's `llvm` is keg-only, so its `bin` must be added to the
   `PATH` Emacs sees (an Emacs started from the Dock does not read the shell profile).
   Pointing the variable at Homebrew's clangd is refused: it lacks the patched flags.
6. Patched clangd: the PKGBUILD is Arch-only. A self-contained build from the same
   release and patches (about 30 - 60 min):
   ```
   U=https://github.com/llvm/llvm-project/releases/download/llvmorg-23.1.1
   curl -LO $U/llvm-project-23.1.1.src.tar.xz
   shasum -a 256 llvm-project-23.1.1.src.tar.xz   # ebe9be46fe8756d5...7888ee6, see PKGBUILD
   tar xf llvm-project-23.1.1.src.tar.xz && cd llvm-project-23.1.1.src
   for p in ~/source/repos/emacs-cpp/packaging/clangd-index-nav/000*.patch; do
     patch -Np1 -i "$p"; done
   cmake -S llvm -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
     -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" -DLLVM_TARGETS_TO_BUILD=host \
     -DLLVM_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF \
     -DCLANGD_ENABLE_REMOTE=OFF
   cmake --build build --target clangd clang-resource-headers
   build/bin/clangd --help-hidden | grep -e navigation-from-index -e header-flags-from-index
   mkdir -p ~/opt/clangd-index-nav/bin ~/opt/clangd-index-nav/lib
   cp build/bin/clangd ~/opt/clangd-index-nav/bin/
   cp -R build/lib/clang ~/opt/clangd-index-nav/lib/
   ```
   (needs `cmake` and `ninja`, e.g. from Homebrew), then set
   `emacs-cpp-clangd-program` to `~/opt/clangd-index-nav/bin/clangd` (expanded path).
   clangd finds its builtin headers in `../lib/clang` next to the binary.
7. If clangd reports standard headers (`<vector>`) as not found, let it ask Apple's
   compiler for its include paths, e.g. in `custom.el`:
   ```
   (setenv "CLANGD_FLAGS"
           "--query-driver=/Library/Developer/CommandLineTools/usr/bin/*")
   ```
8. Libraries (deal.II, Boost) must be installed so that CMake finds them; that is the
   project's business, not this configuration's.
