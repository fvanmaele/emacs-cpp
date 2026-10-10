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
  line numbers: left of the text in files of code, text and configuration;
                not in the tree or in tool buffers (magit, compilation, help)
  left fringe:  B breakpoint (red), > line the debugger stopped at
  right fringe: lines changed since the last commit (green / blue / red)
```

| Emacs word | Plain meaning |
|---|---|
| frame | an operating-system window |
| window | a pane inside the frame |
| buffer | an open file (or other text) |
| minibuffer | the line at the bottom where Emacs asks and you answer |
| region | the selected text |
| kill / yank | cut / paste |
| point | the cursor position |

## 2. How it fits together
```
 CMakePresets.json --(active preset: C-c l P, kept per project)--> build/<preset>/
                                                                      |
      +----------------------------+----------------------------------+------+
      |                            |                                         |
 compile_commands.json      .cache/clangd/index                   .cmake/api (reply)
 flags of every source      what is defined and used where             all targets
      |                            |                                         |
      +-------------+--------------+                                         |
                    v                                                        v
                 clangd <--eglot--> Emacs <--dape--> gdb <------- gdb-preset: picks a
                                      |                           target, builds it,
                         C-c p c c: cmake --build build/<preset>  then starts gdb
```
- **One preset drives everything.** The build command, the flags clangd parses with
  and the list of programs to debug all come from the active preset's build
  directory. Switching the preset restarts clangd with the other directory. Emacs
  keeps no build settings of its own.
- **A project is the folder with `.git`.** Project commands (`C-c p ...`), the tree
  and clangd all use that folder. A C++ file outside a project, or in a project
  without `CMakePresets.json`, gets no clangd.
- **clangd needs the flags of each file.** It reads them from
  `compile_commands.json`, which `cmake --preset` writes. A header has no entry of its
  own; it borrows the flags of a source file that includes it. When it cannot, the
  header shows many false errors.
- **The index is clangd's memory of the whole project.** It is built in the
  background the first time, kept in the build directory and reused after a restart:
  that is why "find usages" sees every file, and why `M-.` answers at once even before
  the file is parsed (the locally patched clangd). Each preset has its own index, so a
  first switch to a new preset indexes again.
- **Buffers outlive windows.** Closing a window, or switching it to another buffer,
  keeps the file open; `C-x b` brings it back. `**` in the mode line means unsaved
  changes.
- **The minibuffer is the one picker.** Files, buffers, symbols, commands, search
  results: all appear as a list there. Type words in any order to narrow it (`ite gpe`
  finds `include/rmo/gpe/iteration.h`), the arrows move, a preview shows the selected
  item, notes on the right describe it, and `C-.` offers other actions on it. Lists put
  what you chose recently first.
- **Prefix keys are grouped.** `C-x ...` is Emacs itself; `C-c` + a letter is this
  configuration (`C-c p` projects, `C-c l` code, `C-c t` tree); `C-x C-a` the debugger.
  Some keys repeat with a single letter after the first use.
- **Two fringes, two jobs.** The left fringe belongs to the debugger (breakpoints,
  current line), the right fringe to git (changed lines), so the marks never cover each
  other.
- **What lives where.** The configuration and its packages are in this repository
  (packages pinned as git submodules; `make packages` builds them; nothing is
  downloaded at startup). Your own settings (`custom.el`), history, recent files and
  bookmarks are in `~/.emacs.d/` and survive updates.
- **It fails loudly.** When something is missing, Emacs stops with a message that
  says what to do (for example `no compile_commands.json ... run cmake --preset
  debug`) instead of half working with wrong results.

## 3. Ten keys to start with
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

After a prefix key (`C-x`, `C-c p`, `C-c l`, `C-x C-a`) wait 3 seconds: a popup lists
the keys that can follow.

## 4. Moving and editing
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

## 5. Windows, tabs, frames
```
 C-x 2 (split below)    C-x 3 (split right)    C-x 1 (keep only this)
 +-----------+          +-----+-----+          +-----------+
 |     A     |          |     |     |          |           |
 +-----------+          |  A  |  B  |          |     A     |
 |     B     |          |     |     |          |           |
 +-----------+          +-----+-----+          +-----------+
 C-x 0 closes the window you are in.
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

## 6. Files and projects
| Key | Does |
|---|---|
| `C-c p p` | switch project |
| `C-c p f` | find a file of the project |
| `C-x C-r` | open a recently visited file; `C-c p e`: of this project |
| `C-c l o` | switch between header and source (`.h` <-> `.cc`) |
| `C-c t` | show / hide the project tree |
| `C-x d` | browse a directory (dired) |
| `C-x r m` / `C-x r b` | set / jump to a bookmark |
| `C-c p m` | menu of all project commands |

## 7. Searching
| Key | Does |
|---|---|
| `M-s l` | lines of this buffer, with preview |
| `M-s r` | search the whole project (ripgrep), live results |
| `M-s d` | files by name |
| `C-c p r` | replace in the whole project |
| `C-.` then `E` | in a result list: copy it to a buffer; there `e` edits the files |

## 8. Working on C++
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

### Renaming a namespace
`C-c l r` renames functions, classes, variables and the like, but not a namespace:
clangd refuses ("Cannot rename symbol: symbol is not a supported kind"), by design,
as it refuses macros and overloaded operators. `M-?` on a namespace does not help
either: clangd lists its uses but not the `namespace name { ... }` lines in other
files. Rename it as text, seeing every place first (checked 2026-10-10):

1. `M-s r` and `\bgpe\b` (the old name as a whole word): ripgrep lists every hit.
2. `C-.` then `E`: the list goes into a buffer; `e` there makes it editable.
3. `M-%` old name `RET` new name `RET`: `y` / `n` at each hit, `!` for all the rest.
4. `C-c C-c` writes the edits into the files' buffers; `C-x s` saves them.

Whole-word search also finds the name in `#include <rmo/gpe/...>` paths (`/` ends a
word): answer `n` there unless the directory is renamed too, or search for
`\bgpe::|namespace gpe\b` instead. `} // namespace gpe` comments are found as well.
`C-c p r` (replace in the whole project) does the same one hit at a time, without the
list.

### Indentation settings for a project
`TAB`, `RET` and the electric characters (`}`, `;`, ...) indent by Emacs's rules,
set per project in `.dir-locals.el` in the project root (D-062, D-065). It applies
to every `.cc` and `.h` file below it, takes plain values only, and Emacs applies them
without asking. Files already open keep their old settings until reopened
(`C-x C-v RET`).

```
((c++-ts-mode . ((c-ts-indent-offset . 2)
                 (indent-tabs-mode . nil)
                 (emacs-cpp-indent-namespace-body . nil)
                 (emacs-cpp-indent-case-labels . t))))
```

| Setting | Values (default first) | clang-format option |
|---|---|---|
| `c-ts-indent-offset` | 2, or any step | `IndentWidth` |
| `indent-tabs-mode` | `t` (tabs where possible), `nil` (spaces) | `UseTab` (`Never` = `nil`) |
| `tab-width` | 8, or any width | `TabWidth` (only with tabs) |
| `c-ts-mode-indent-style` | `gnu`, `bsd`, `k&r`, `linux` | `BreakBeforeBraces` (below) |
| `emacs-cpp-indent-namespace-body` | `t`, `nil` | `NamespaceIndentation` (`All` / `None`) |
| `emacs-cpp-indent-case-labels` | `nil`, `t` | `IndentCaseLabels` |
| `emacs-cpp-indent-access-offset` | `nil` (class's column), integer | `AccessModifierOffset` |
| `emacs-cpp-indent-initializer-offset` | `nil` (the step), integer | `ConstructorInitializerIndentWidth` |
| `emacs-cpp-indent-continuation-offset` | `nil` (the step), integer | `ContinuationIndentWidth` |
| `emacs-cpp-indent-align-arguments` | `t`, `nil` | `AlignAfterOpenBracket` (`DontAlign` = `nil`) |

The numbers mean what they mean in `.clang-format`, so they can be copied from it:
`AccessModifierOffset: -1` with a step of 2 puts `public:` one column in from the
class.

`c-ts-mode-indent-style` matters only for a `{` on its own line after `if`, `for`,
`while`: `gnu` indents it one step (clang-format's `GNU` style), `bsd` keeps it at the
`if`'s column (`Allman`, `Microsoft`). `k&r` and `linux` indent like `gnu` except
labels. A `{` on the `if` line indents the same in every style.

Always done in C++ buffers, whatever the settings:
- a `{` on its own line after `namespace`, `class` or `struct` stays at the keyword's
  column; class members are one step in, also after a blank line;
- arguments after a `(` that ends its line go in by the continuation offset;
  arguments after the first on the `(` line align with the first (unless
  `emacs-cpp-indent-align-arguments` is `nil`);
- a constructor's `: member(...)` goes in by the initializer offset; later
  initializers align with the first, or stay under the `:` when the lines start with
  `,`;
- a `requires` clause on its own line goes one step in.

Settings for clang-format's built-in styles, all with `(indent-tabs-mode . nil)`
(`...` stands for `emacs-cpp-indent`):

| Setting | LLVM | Google | Chromium | Mozilla | WebKit | Microsoft | GNU |
|---|---|---|---|---|---|---|---|
| `c-ts-indent-offset` | 2 | 2 | 2 | 2 | 4 | 4 | 2 |
| `c-ts-mode-indent-style` | `gnu` | `gnu` | `gnu` | `gnu` | `gnu` | `bsd` | `gnu` |
| `...-namespace-body` | `nil` | `nil` | `nil` | `nil` | `nil` | `nil` | `nil` |
| `...-case-labels` | `nil` | `t` | `t` | `t` | `nil` | `nil` | `nil` |
| `...-access-offset` | -2 | -1 | -1 | -2 | -4 | -2 | -2 |
| `...-initializer-offset` | 4 | 4 | 4 | 2 | 4 | 4 | 4 |
| `...-continuation-offset` | 4 | 4 | 4 | 2 | 4 | 4 | 4 |
| `...-align-arguments` | `t` | `t` | `t` | `t` | `nil` | `t` | `t` |

Each column was checked 2026-10-10: a sample (namespaces, `switch`, an `if` / `else`,
long argument lists broken after the `(` and after the first argument, a template with
`requires`, classes with access specifiers and initializers) formatted by clang-format
23.1.1 in that style, stripped of all indentation, and re-indented by Emacs with the
column's values gives clang-format's text back exactly; WebKit only without nested
namespaces (below). The test `init-cpp-indent-like-clang-format-styles` keeps LLVM,
Google and WebKit that way. A project with its own `.clang-format` starts from the
column of its `BasedOnStyle` and copies the options it changes; RMO (WebKit with
own-line braces, aligned arguments and indented case labels) uses offset 4, `bsd`,
namespace body `nil`, case labels `t`, and the defaults for the rest.

What the settings cannot express:
- `NamespaceIndentation: Inner` (WebKit: only nested namespaces indented);
- `<<` chains aligned under the first `<<`, macro bodies, and lines inside code
  tree-sitter cannot parse.

Where `TAB` and clang-format differ, `C-c l f` on the lines (a region) gives
clang-format's result.

To move a line by hand, by the project's step (`c-ts-indent-offset`), with spaces or
tabs as `indent-tabs-mode` says (D-066):

| Key | Does |
|---|---|
| `M-i` | white space up to the next step, at point (`M-m` first: to the line's text) |
| `C-x TAB`, then `S-<right>` / `S-<left>` | move the selected lines one step right / left; `<right>` / `<left>`: one column; any other key ends it |
| `C-u 4 C-x TAB` | move the selected lines 4 columns right; `C-u -4` left |

`TAB` itself does not add a step: it puts the line where the rules say (a second `TAB`
completes). `C-q TAB` inserts a literal tab character.

### A project's code style, taken from a file
Two files in the project root decide how code looks, and they must agree:
- `.clang-format`: what `C-c l f` produces (clangd reads it). Without one clangd
  formats in LLVM style, so `C-c l f` rewrites the file in a style nobody chose.
- `.dir-locals.el`: what `TAB` and `RET` indent to, and the line after typing `}`,
  `;` and the like. Emacs indents by its own rules (D-065); it does not read
  `.clang-format`, and changes nothing on a line but its indentation.

Open a file that already has the project's style, then:

1. Note the indent step (2, 4 or 8 columns), tabs or spaces (`M-x whitespace-mode`
   marks tabs; run it again to hide the marks), whether the `{` of an `if` or
   `for` stands on the `if` line or on its own line, and the same for `namespace`
   and `class`.
2. Find the closest of clang-format's built-in styles. `M-!` runs a shell command in
   the file's directory; replace `FILE` by the file's name:
   ```
   for s in LLVM GNU Google Chromium Microsoft Mozilla WebKit; do
     printf '%-10s %s\n' $s "$(clang-format --style=$s FILE | diff FILE - | grep -c '^>')"
   done
   ```
   Each number is how many lines that style would change; take the smallest.
3. Write `.clang-format` in the project root with that style, e.g.
   `BasedOnStyle: Microsoft`, and show what it still changes:
   `M-! clang-format --style=file FILE | diff FILE -`. Each difference is one option to
   add. `clang-format --style=Microsoft --dump-config` lists the options with their
   values; https://clang.llvm.org/docs/ClangFormatStyleOptions.html explains them.
   Repeat until the diff is empty. Example: a file with `public:` at the class's
   column and one-line getters needs
   ```
   BasedOnStyle: Microsoft
   AccessModifierOffset: -4
   AllowShortFunctionsOnASingleLine: Inline
   ```
4. Write `.dir-locals.el` in the project root to match (settings: "Indentation
   settings for a project" above). RMO's:
   ```
   ((c++-ts-mode . ((c-ts-indent-offset . 4)
                    (indent-tabs-mode . nil)
                    (c-ts-mode-indent-style . bsd)
                    (emacs-cpp-indent-namespace-body . nil)
                    (emacs-cpp-indent-case-labels . t))))
   ```
   - `c-ts-indent-offset`: the indent step (clang-format's `IndentWidth`).
   - `indent-tabs-mode`: `nil` for spaces (`UseTab: Never`); `t` for tabs, then add
     `(tab-width . 4)` with the tab width.
   - `c-ts-mode-indent-style`: `bsd` when the `{` of an `if` stands on its own line
     under the `if`. Leave it out for the default `gnu`, which indents such a `{` one
     step further; for `{` on the `if` line any style indents the same.
   - `emacs-cpp-indent-namespace-body`: `nil` when namespace contents are not
     indented (clang-format's `NamespaceIndentation: None`).
   - `emacs-cpp-indent-case-labels`: `t` when `case` labels are one step in from
     their `switch` (clang-format's `IndentCaseLabels: true`).

   Arguments after a `(` that ends a line go one step in, later ones align with the
   first, constructor initializers and `requires` clauses one step in, as
   clang-format does them.

   A `{` on its own line after `namespace` or `class` stays at the keyword's column
   in every style. Both this and the style line work only through this
   configuration (D-062): Emacs 31.1 itself indents such a `{`, and ignores a style
   set in `.dir-locals.el`; reports for both are drafted for upstream (T-036, T-037).
5. Files already open keep their old settings: reopen them with `C-x C-v RET` (save
   them first). To check, `TAB` on a few lines should leave them where they are, and
   `C-c l f` with a region should change nothing in it (the mode line shows `**`
   when the buffer changed; `C-/` undoes). Emacs's rules cover less than
   clang-format: on RMO, Emacs and clang-format still differ on 62 lines (`<<`
   chains, macros, a few template and alias continuations; T-040). Format
   the lines you edit (`C-c l f` on a region) rather than whole files: hand-aligned
   code and boost `add_options()` chains do not survive a whole-file format.

## 9. Building
```
 C-c l P          C-c p c o          C-c p c c          M-g n / M-g p
 pick preset ---> configure    ---> build        ---> next / previous error
 (debug, ...)     cmake --preset     cmake --build      jumps to the source line
```
`C-c p c t` runs the tests (`ctest`). The command is shown before it runs: add
`--target main` to build one target. All of these work from any file of the project.

## 10. Debugging
```
 C-x C-a b         C-x C-a d gdb-preset RET   C-x C-a n s o c     C-x C-a q
 breakpoint  --->  pick target: builds it --> step over / into  -> end
 (or click the     then stops at the          / out / continue
 left fringe)      breakpoint                 C-x C-a w watch
                                              C-x C-a i stack, locals
```
After the first step key (`C-x C-a n`), plain `n` `s` `o` `c` keep going. Program
arguments: `gdb-preset :args ["--levels" "5"]` at the `C-x C-a d` prompt; the prompt
starts with your last input. `lldb-preset` does the same with lldb: on macOS, where
there is no gdb, use it in place of `gdb-preset`.

Python files work the same way with pyright (navigation, rename, `C-c l` keys);
`C-x C-a d debugpy RET` debugs the current file.

## 11. Git
| Key | Does |
|---|---|
| `C-x g` | status: `s` stage, `u` unstage, `P` push, `F` pull, `l l` log |
| `c c` | in the status buffer: commit; write the message, `C-c C-c` to finish |
| `C-c M-g` | this file: blame, log, diff |
| `?` | in a magit buffer: all its keys |

## 12. Help
| Key | Does |
|---|---|
| `C-h k` then a key | what that key does |
| `C-h f` / `C-h v` | describe a command / setting |
| `C-h m` | the current mode and all its keys |
| `C-h B` | search all key bindings |
| `C-h i` | manuals (Emacs, magit, embark, ...) |
| prefix then `C-h` | list the keys after that prefix |

## 13. Settings that stay
`M-x customize-variable` (or `M-x customize-themes` for the colours), change, then
"Save for future sessions". Saved settings win over the configuration's defaults.
