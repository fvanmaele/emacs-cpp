# emacs-cpp user manual

The everyday actions, by task. Every key here was checked in the shipped
configuration. The complete key list is `docs/CHEATSHEET.md`.

Notation: `C-x` = hold Control, press x. `M-x` = hold Alt (Meta), press x. `C-x 2` =
Control-x, release, then 2. `RET` = Enter, `SPC` = space. `M-x name` = run a command by
name (type part of it; the list narrows as you type).

## 1. The screen
```
+------------------+-------------------------------------------------+
| project tree     | header line: RMO-gross-pitaevskii/src/main.cc   |
| (C-c t)          +-------------------------------------------------+
|                  |B|  int main() {                               |+|
| v src/           | |    ProgramOptions opts;                     | |
|     main.cc      |>|    run(opts);                               | |
| > include/       | |  }                                          | |
|                  +-------------------------------------------------+
|                  | mode line: file, line, mode, server, git branch |
+------------------+-------------------------------------------------+
| minibuffer: prompts, completion lists, messages                    |
+--------------------------------------------------------------------+
  header line:  file within the project, then the function at point
  left fringe:  B breakpoint (red), > line the debugger stopped at
  right fringe: lines changed since the last commit (green / blue / red)
```

| Emacs word | Plain meaning |
|---|---|
| frame | an operating-system window |
| window | a pane inside the frame |
| buffer | an open file (or other text); it stays open when no window shows it |
| minibuffer | the line at the bottom where Emacs asks and you answer |
| region | the selected text |
| kill / yank | cut / paste |
| point | the cursor position |

## 2. Ten keys to start with
| Key | Does |
|---|---|
| `C-g` | cancel whatever is going on (press it when stuck) |
| `M-x` | run any command by name |
| `C-x C-f` | open a file |
| `C-x C-s` | save; `C-x s` saves all |
| `C-x b` | switch buffer (also lists recent files and bookmarks) |
| `C-x k` | close a buffer |
| `C-/` | undo; `C-?` redo (in a terminal: `C-M-_`) |
| `C-s` | search forward in the buffer (again `C-s`: next match, `RET`: stop) |
| `C-h k` | what does this key do? |
| `C-x C-c` | quit Emacs (asks about unsaved files) |

After a prefix key (`C-x`, `C-c p`, `C-c l`, `C-x C-a`) wait a second: a popup lists
the keys that can follow.

## 3. Moving and editing
| Key | Does |
|---|---|
| `C-a` / `C-e` | start / end of line |
| `M-<` / `M->` | start / end of buffer |
| `C-v` / `M-v` | page down / up |
| `C-l` | put the cursor line in the middle, then top, then bottom |
| `M-g g` | go to line number |
| `C-SPC` | start selecting; move to extend; `C-x h` selects everything |
| `C-w` / `M-w` / `C-y` | cut / copy / paste |
| `M-y` | paste from the list of earlier cuts |
| `C-k` | cut to the end of the line |
| `M-;` | comment or uncomment the line or selection |
| `M-%` | replace, asking at each match (`y` / `n`, `!` all, `q` stop) |
| `C-u C-SPC` | back to the previous position in this buffer |

After `C-x u` (undo), plain `u` undoes again.

## 4. Windows, tabs, frames
```
 C-x 2 (split below)    C-x 3 (split right)    C-x 1 (keep only this)
 +-----------+          +-----+-----+          +-----------+
 |     A     |          |     |     |          |           |
 +-----------+          |  A  |  B  |          |     A     |
 |     B     |          |     |     |          |           |
 +-----------+          +-----+-----+          +-----------+
 C-x 0 closes the window you are in; its buffer stays open.
```

| Key | Does |
|---|---|
| `C-x o` | next window; then plain `o` / `O` keeps moving forward / back |
| `C-x ^` | taller; `C-x }` / `C-x {` wider / narrower; then `^` `}` `{` `v` repeat |
| `C-x +` | make all windows the same size |
| `C-x w t` | turn the layout 90 degrees (side by side <-> stacked) |
| `C-x w o <right>` | move the buffers one window on |
| `C-x 4 f` / `C-x 4 b` | open a file / buffer in the other window |
| `C-x 4 0` | close the buffer and its window |
| `q` | in help, list and magit buffers: close it |
| `C-x t 2` | new tab (a tab is a saved window layout) |
| `C-x t o` | next tab, then `o` / `O`; `C-x t RET` picks one by name; `C-x t 0` closes |
| `C-x 5 2` / `C-x 5 0` | new / close frame |

## 5. Files and projects
| Key | Does |
|---|---|
| `C-c p p` | switch project |
| `C-c p f` | find a file of the project |
| `C-x C-r` | open a recently visited file; `C-c p e`: of this project |
| `C-c l o` | switch between header and source (`.h` <-> `.cc`) |
| `C-c t` | show / hide the project tree (`?` in the tree lists its keys) |
| `C-x d` | browse a directory (dired) |
| `C-x r m` / `C-x r b` | set / jump to a bookmark |
| `C-c p m` | menu of all project commands |

In any list in the minibuffer, words separated by a space match in any order: `ite
gpe` finds `include/rmo/gpe/iteration.h`.

## 6. Searching
| Key | Does |
|---|---|
| `M-s l` | lines of this buffer, with preview |
| `M-s r` | search the whole project (ripgrep), live results |
| `M-s d` | files by name |
| `C-c p r` | replace in the whole project |
| `C-.` then `E` | in a result list: copy it to a buffer; there `e` edits the files |

## 7. Working on C++
eglot starts clangd by itself when you open a C++ file of a project that has
`CMakePresets.json`. The header line shows where you are; inlay hints show parameter
names and deduced types.

| Key | Does |
|---|---|
| `M-.` | go to definition (also on an `#include` line) |
| `M-?` | find usages |
| `M-,` | back to where you were; `C-M-,` forward again |
| `C-x 4 .` | definition in the other window |
| `C-c l s` | search symbols of the project |
| `M-g i` | symbols of this file |
| `C-c l r` | rename everywhere |
| `C-c l a` | fixes and refactorings offered here |
| `C-c l f` | format the selection, or the file |
| `TAB` | indent; on an indented line: complete (`M-n` / `M-p` choose, `RET` take) |
| `M-g f` | errors and warnings of this file |
| `C-c l e` | errors and warnings of the project |
| `C-c l I` | hide / show inlay hints |

## 8. Building
```
 C-c l P          C-c p c o          C-c p c c          M-g n / M-g p
 pick preset ---> configure    ---> build        ---> next / previous error
 (debug, ...)     cmake --preset     cmake --build      jumps to the source line
```
`C-c p c t` runs the tests (`ctest`). The command is shown before it runs: add
`--target main` to build one target. All of these work from any file of the project.

## 9. Debugging
```
 C-x C-a b         C-x C-a d gdb-preset RET   C-x C-a n s o c     C-x C-a q
 breakpoint  --->  pick target: builds it --> step over / into  -> end
 (or click the     then stops at the          / out / continue
 left fringe)      breakpoint                 C-x C-a w watch
                                              C-x C-a i stack, locals
```
After the first step key (`C-x C-a n`), plain `n` `s` `o` `c` keep going. Program
arguments: `gdb-preset :args ["--levels" "5"]` at the `C-x C-a d` prompt; the prompt
starts with your last input.

## 10. Git
| Key | Does |
|---|---|
| `C-x g` | status: `s` stage, `u` unstage, `P` push, `F` pull, `l l` log |
| `c c` | in the status buffer: commit; write the message, `C-c C-c` to finish |
| `C-c M-g` | this file: blame, log, diff |
| `?` | in a magit buffer: all its keys |

## 11. Help
| Key | Does |
|---|---|
| `C-h k` then a key | what that key does |
| `C-h f` / `C-h v` | describe a command / setting |
| `C-h m` | the current mode and all its keys |
| `C-h B` | search all key bindings |
| `C-h i` | manuals (Emacs, magit, embark, ...) |
| prefix then `C-h` | list the keys after that prefix |

## 12. Settings that stay
`M-x customize-variable` (or `M-x customize-themes` for the colours), change, then
"Save for future sessions". Saved settings go to `~/.emacs.d/custom.el`, outside the
repository, and win over the configuration's defaults.
