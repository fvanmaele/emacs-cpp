# emacs-cpp cheat sheet

Keys as bound by this configuration (checked 2026-10-08 with `where-is` in the shipped
config). `M-x cmd` means: no key yet, run the command by name (`M-x`, then type part of
the name; completion is fuzzy). Notation: `C-` = Control, `M-` = Meta (Alt; Option on
macOS), `RET` = Enter. Everyday Emacs (windows, tabs, editing) and the common
tasks step by step: `docs/MANUAL.md`.

## Code navigation (clangd through eglot)
| Key | Does |
|---|---|
| `M-.` | go to definition (on a name or an `#include` line) |
| `M-?` | find usages (references) |
| `M-,` | go back to where you were before `M-.` / `M-?` |
| `C-M-,` | go forward again |
| `C-M-.` | search symbols in the whole project by name |
| `C-c l s` | the same, with live preview (`consult-eglot-symbols`) |
| `M-g i` | symbols of this file (functions, classes); `M-g I`: of all open files |
| `C-c l i` | implementations / overrides |
| `C-c l d` | declaration (header) of a definition |
| `C-c l h` / `C-c l t` | call hierarchy / type hierarchy |
| `M-x eglot-find-typeDefinition` | definition of the type of the thing at point |
| `C-c l o` or `C-c p a` | switch between header and source (`.h` <-> `.cc`) |

Several results open as a list with preview: move with the arrows, `RET` jumps. The
header line shows the file's path in the project and the function at point; click a
part to jump (D-043).

## Refactoring and code actions
| Key | Does |
|---|---|
| `C-c l r` | rename the symbol in the whole project |
| `C-c l a` | fixes and refactorings clangd offers here |
| `C-c l f` | clang-format the region, or the file without a region |
| `C-c l I` | hide / show inlay hints (parameter names, deduced types) |
| `M-;` | comment / uncomment the region or line |

`C-c l f` follows the project's `.clang-format` (LLVM style without one); `TAB`
follows `.dir-locals.el`. Writing both from a file that has the project's style:
`docs/MANUAL.md` 8.

## Errors and warnings (flymake)
| Key | Does |
|---|---|
| `M-g f` | list this file's diagnostics, jump with preview |
| `M-x flymake-goto-next-error` | next diagnostic (`...-prev-error`: previous) |
| `C-c l e` | all diagnostics of the project |
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
| `C-h i` | manuals: Emacs, magit, embark, orderless, dash, with-editor |
| `C-x C-r` | open a recently visited file (`C-x b` lists them too) |

Theme: `M-x customize-themes`, pick one, "Save Theme Settings"; it stays after a
restart. Without a saved choice the theme is `modus-vivendi-tritanopia`.

After any prefix (`C-c p`, `C-x C-a`, `C-c l`), wait a second: which-key shows the keys
that can follow (D-034). `C-h` in that popup pages through them.

## Projects, CMake presets, building
| Key | Does |
|---|---|
| `C-c p p` | switch project |
| `C-c p m` | menu of all projectile commands, grouped |
| `C-c l P` | choose the active CMake preset (clangd restarts with its build dir) |
| `C-c p c c` | build the active preset (`cmake --build build/debug`), from any buffer |
| `C-c p c o` / `c t` | configure / test the active preset (`cmake --preset`, `ctest`) |
| `C-c p c r` | run (asks for the command) |
| `C-c p t` | toggle between implementation and test |
| `C-c p !` | shell command in the project root |
| `C-c p r` | replace text in the whole project |
| `C-c p k` | kill all buffers of the project |

The commands show at the prompt: add `--target main` to build one target. `M-g n` /
`M-g p` jump to the next / previous compiler error. An edited command is remembered
for the project; `M-x projectile-discard-command-cache` returns to the preset's.

## Debugging (dape + gdb or lldb)
| Key | Does |
|---|---|
| `C-x C-a b` / click the fringe | toggle a breakpoint on the line (red mark) |
| `C-x C-a d` `gdb-preset RET` | pick a target of the active preset, build it, debug it |
| `C-x C-a d` `lldb-preset RET` | the same with lldb (macOS; on Arch too, D-051) |

The prompt starts with `gdb-preset` on Arch and `lldb-preset` on macOS until one of
them was used; then with your last input (D-055).
| `C-x C-a n` `s` `o` `c` | step over / into / out / continue; then just `n` `s` `o` `c` |
| `C-x C-a w` | watch an expression |
| `C-x C-a i` | info buffers: stack, locals, breakpoints, threads |
| `C-x C-a q` | end the session |

Program arguments: type them after the configuration name, as a vector of strings:
`gdb-preset :args ["--levels" "5"]`. The prompt starts with your last input (kept
across restarts), so RET repeats it. Not `gdb-preset - --levels 5`: dape takes the
first word after `-` as the program. For fixed arguments per project, a
`.dir-locals.el` in the project:
`((c++-ts-mode . ((dape-command . (gdb-preset :args ["--levels" "5"])))))`.

Emacs's older debugger front-end (`M-x gdb`, `M-x pdb`, `M-x perldb`) uses `C-x M-a`
as its prefix (D-044), so it does not take dape's `C-x C-a`.

The line the program stopped at is highlighted. Options: `emacs-cpp-debug-lazy-symbols`
(faster first stop, D-030), `emacs-cpp-debug-gdb-scripts` (deal.II printers, D-032).

## Python (rides along, D-045)
`.py` files open in `python-ts-mode`; in a project (git, `pyproject.toml` or
`setup.py`) pyright starts, and `M-.`, `M-?`, `C-c l r` and the other `C-c l` keys work
as for C++. `C-x C-a d debugpy RET` debugs the current file (`debugpy-module`: the
current directory as a module).

## Git (magit)
| Key | Does |
|---|---|
| `C-x g` | status (stage `s`, unstage `u`, commit `c c`, push `P`, pull `F`, log `l l`) |
| `C-x M-g` | all magit commands |
| `C-c M-g` | commands for the current file (blame, log, diff) |
| `?` in magit | help for the current buffer |

Lines changed since the last commit are marked in the right fringe (green added, blue
changed, red deleted), after each save and each magit action (D-042).

## Project tree (treemacs)
`C-c t` opens / closes the tree. It shows only the project of the buffer you are in and
switches when you move to a file of another project (D-029). Inside the tree:

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

## Setup on the supported machine (Arch Linux)
1. Clone with submodules; `~/.emacs.d/init.el` and `early-init.el` are symlinks to this
   repository (D-003). `make packages` byte-compiles the pinned packages and builds
   their manuals for `C-h i` (needs the `texinfo` package, D-039).
2. Patched clangd (D-026, D-027):
   `cd packaging/clangd-index-nav && makepkg -si` (about 30 min), then
   `M-x customize-variable RET emacs-cpp-clangd-program` =
   `/opt/clangd-index-nav/bin/clangd`, "Save for future sessions". Leave it nil for
   the system clangd.
3. A project needs a `CMakePresets.json` with `CMAKE_EXPORT_COMPILE_COMMANDS` on and
   `CMAKE_CXX_EXTENSIONS OFF` (D-011), configured once (`cmake --preset debug`).
4. Verbose clangd log, for diagnosis: `M-: (setenv "CLANGD_FLAGS" "--log=verbose")`
   before opening the project, then `M-x eglot-stderr-buffer`.

## macOS (MacPorts, D-050, D-053)
macOS is supported since 2026-10-09 (D-050), with tools from MacPorts only (D-053).
`README.md` has the install steps. Differences from Linux:

1. Emacs 31.1: the MacPorts `emacs-app` port with the `nativecomp` and `treesitter`
   variants. Meta is Option; if Option types special characters, set
   `ns-alternate-modifier` to `meta`.
2. Same clone, symlinks and `make packages` as above (needs git and make from the
   Xcode command line tools). The port's Emacs is
   `/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs`; pass it as
   `make packages EMACS=...` when `emacs` is not on the `PATH`.
3. Grammars: the ports `tree-sitter-cpp` and `tree-sitter-python`; Emacs finds them
   without configuration (checked 2026-10-09). Without them the config stops at
   startup (D-008, D-045).
4. `${hostSystemName}` in presets expands to `Darwin`, as in CMake.
5. Unpatched clangd: `emacs-cpp-clangd-program` nil runs `clangd` from Emacs's
   `exec-path`. The `clang-23` port provides it once selected with
   `sudo port select --set clang mp-clang-23`. `/opt/local/bin` must be on the `PATH`
   Emacs sees (an Emacs started from the Dock does not read the shell profile).
   Pointing the variable at the MacPorts clangd is refused: it lacks the patched flags.
6. Patched clangd (D-052): `packaging/clangd-index-nav/build-macos.sh` builds the same
   release with the same patches as the Arch package, checks them against the
   PKGBUILD, and installs to `~/opt/clangd-index-nav` (about 15 min on the owner's
   Mac; `--help` lists the options). Then set `emacs-cpp-clangd-program` to
   `~/opt/clangd-index-nav/bin/clangd` (expanded path). clangd finds its builtin
   headers in `../lib/clang` next to the binary.
7. Untested: if clangd reports standard headers (`<vector>`) as not found, let it ask
   Apple's compiler for its include paths, e.g. in `custom.el`:
   ```
   (setenv "CLANGD_FLAGS"
           "--query-driver=/Library/Developer/CommandLineTools/usr/bin/*")
   ```
8. Libraries (deal.II, Boost) must be installed so that CMake finds them; that is the
   project's business, not this configuration's.
9. Debugger: there is no gdb for Apple silicon; use `lldb-preset` (D-051). It starts
   `lldb-dap` from the PATH: `sudo port select --set lldb mp-lldb-23` links the lldb-23
   port's as `/opt/local/bin/lldb-dap`. Or set the program, a path or a name:
   `M-x customize-variable RET emacs-cpp-debug-lldb-dap-program`, e.g.
   `/opt/local/bin/lldb-dap-mp-23`, then "Save for future sessions". The gdb options (lazy symbols, gdb scripts)
   do not apply to it.
