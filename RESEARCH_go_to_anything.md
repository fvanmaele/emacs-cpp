# RESEARCH - one "go to anything" prompt (T-047)

Findings only; verdicts go to DESIGN (O-30). Owner request 2026-10-11: a "go to
anything" key in Emacs that works like CLion's (the owner calls it `M-M`): symbols,
project files, bookmarks and more from one prompt. Arch, Emacs 31.1, 2026-10-11.
Package facts from the vendored sources at their pins (consult 3.10, consult-eglot
v0.5.0, projectile, embark 1.2); CLion facts from JetBrains' help pages (CLion 2026.2);
one hands-on check in `emacs -Q --batch` with a script in a scratch directory.

Starting point: DESIGN 1, row "Search everywhere": "Gap: no single combined popup."

## 1. What CLion does
- **Search Everywhere** (Navigate menu; default key: Shift pressed twice). One popup
  for classes, files, symbols, actions, settings and git items. Empty input lists
  recent files. Tab moves between scopes (All, Classes, Files, Symbols, Actions);
  each scope also has its own key (`Ctrl+N` class, `Ctrl+Shift+N` file,
  `Ctrl+Alt+Shift+N` symbol, `Ctrl+Shift+A` action). Shift twice again, or `Alt+N`,
  adds items outside the project (libraries).
- Bookmarks are not one of its scopes; CLion lists them in its own Bookmarks window.

## 2. What this config has today
Each CLion scope already has a command; they are separate prompts.

| CLion scope | Command here | Key |
|---|---|---|
| recent files, buffers | `consult-buffer` | `C-x b` |
| files | `projectile-find-file` | `C-c p f` |
| classes, symbols | `consult-eglot-symbols` (clangd `workspace/symbol`) | `C-c l s` |
| symbols of this file | `consult-imenu` | `M-g i` |
| actions | `execute-extended-command` | `M-x` |
| text | `consult-ripgrep` | `M-s r` |
| bookmarks | `bookmark-jump`; also in `consult-buffer` | `C-x r b`, `C-x b m SPC` |

`consult-buffer` is already a combined prompt. Its default `consult-buffer-sources`
(consult 3.10, `consult.el` line 239): buffers, hidden buffers (`SPC`), modified
buffers, other buffers, recent files, buffer and file registers, bookmarks (narrow
`m`), and hidden project buffers, project recent files and project roots (narrow `p`).
What it lacks against CLion: project files that were never opened (only recent ones),
symbols from clangd, and commands.

## 3. Building blocks, checked in the source
- **`consult--multi`** (`consult.el` line 3222) combines sources. Each source is a
  plist with `:items` (a list, or a function called only when the source is visible)
  or `:async`, plus `:name`, `:narrow`, `:category`, `:hidden`, `:enabled`, `:action`,
  `:state` (preview). Asynchronous sources exist since consult 2.0 (NEWS: "`consult--
  multi`: Add support for `:async` sources"). The README documents adding sources to
  `consult-buffer-sources`; the function itself carries the internal `--` prefix.
- **Checked by hand** (batch, the vendored consult): one static source (three file
  names) and one async source (echoes the input) passed through `consult--multi-async`
  with the input `init comp` gave `lisp/init-completion.el` from the static source and
  the async source's candidate; `lisp/init-cpp.el` and `init.el` were filtered out.
- **Filtering changes once one source is async.** Then the whole prompt is async:
  static sources are filtered by consult's own regexp compiler (words in any order,
  each a regexp; `consult--async-static`, line 2299), not by orderless. Orderless still
  applies after a second separator: with `consult-async-split-style` `perl` (default),
  `#vec#push` sends `vec` to the async sources and filters the results with `push`.
  A static-only prompt (today's `consult-buffer`) uses orderless directly.
- **Symbols from clangd.** consult-eglot builds its async source from internal
  functions: `consult-eglot--make-async-source` (sends `workspace/symbol` to every
  server of the project), `consult-eglot--transformer` (candidate text: name, file,
  line), `consult-eglot--state` (preview). Only `consult-eglot-symbols` is public. A
  combined prompt has to call the internal ones, or copy about 40 lines of them.
  clangd returns at most 100 symbols per request (`--limit-results`, default 100,
  `ClangdMain.cpp` line 337); the patched clangd does not change this.
- **Minimum input.** `consult-async-min-input` is 3 and applies only where a pipeline
  contains `consult--async-min-input`; it can be put in the symbol source alone, so
  files and buffers show from the first key while clangd is asked from the third.
- **Narrowing keys clash.** consult-eglot narrows by symbol kind with `f` function,
  `m` module, `p` package, `c` class, ... (`consult-eglot-narrow`); consult-buffer uses
  `f` file, `m` bookmark, `p` project. In one prompt each source has its own keys, so
  the symbol source gets one key (e.g. `s`) and kind narrowing is lost there;
  `consult-eglot-symbols` keeps it.
- **Project files.** `projectile-project-files` (`projectile.el` line 4988) lists a
  root's files; with `projectile-indexing-method` `alien` (default off Windows) it runs
  `git ls-files` or `fd` each time, no cache (`projectile-enable-caching` defaults to
  nil for `alien`). Not measured on RMO or a deal.II-sized tree.
- **Project root.** consult's project sources use `consult-project-function`, default
  project.el (`project-current`); the config does not set it. projectile decides
  the project for `C-c p` and the tree (D-070). Both find the same root for a git
  checkout; they differ for a `.projectile`-only or `Makefile`-only directory. A
  combined prompt can take the root from projectile for all its sources.
- **Commands as a source.** No consult source exists for `M-x`; one is a few lines:
  items from `obarray` filtered by `commandp` and `read-extended-command-predicate`
  (set to `command-completion-default-include-p` in `init-completion.el`), action
  `call-interactively`.
- **Embark and marginalia** handle the `multi-category` that `consult--multi` sets,
  so `C-.` acts on a file, buffer or bookmark candidate as on its own prompt
  (consult README, "Embark integration"; not checked by hand).

## 4. The key
- Emacs receives no key event for a modifier pressed alone, so CLion's Shift twice
  cannot be bound; nothing in Emacs 31.1's NEWS changes this.
- `M-M` (Meta-Shift-m) is unbound in Emacs 31.1 and in this config (checked: `init.el`
  loaded in batch, `key-binding` nil); today Emacs drops the Shift and runs `M-m`
  (`back-to-indentation`). Binding it takes nothing away.
  `M-m` itself stays.
- On the Mac `M-M` is Option-Shift-m with Option as Meta; not checked there.

## 5. Existing packages
| Package | What | Source |
|---|---|---|
| consult-project-extra | project buffers, files, known projects in one prompt | MELPA |
| consult-omni | many sources (web, apps, notes, files) in one prompt | GitHub |

Neither has an LSP symbol source; consult-project-extra uses project.el only;
consult-omni is aimed at web and desktop search. Each would be a new submodule (D-006).

## 6. Options for the owner (O-30)
- (a) Add project files, symbols and commands to `consult-buffer-sources`, on `C-x b`.
  No new key; but the symbol source makes `C-x b` async, so buffer switching loses
  orderless matching (section 3), and every `C-x b` lists all project files.
- (b) A new command on `M-M`, about 60 to 80 lines of own Lisp in
  `lisp/init-completion.el`, built with `consult--multi`: buffers, project files
  (projectile), recent files and bookmarks shown from the first key; clangd symbols
  from the third key; commands and project roots hidden behind narrow keys. Empty
  input shows buffers and recent files first, as CLion's recent files. Uses consult's
  `consult--multi` (documented, `--` name) and consult-eglot's internal functions
  (D-069's one-line allowance does not cover this; copying them is the alternative).
  `C-x b` stays as it is.
- (c) No combined prompt: `M-M` opens a prefix map with the existing commands (`f`
  file, `s` symbol, `b` buffer, `m` bookmark, `x` command, `i` this file, `r` text),
  shown by which-key after its delay (D-071). No new Lisp beyond bindings; two keys
  instead of one prompt, as CLion's per-scope keys.
- (d) consult-project-extra as a submodule plus (c) for symbols. Adds a package for
  what (b) does in a few lines.

Questions inside (b) if chosen: which sources are visible without narrowing; whether
text search (CLion's Text scope, `consult-ripgrep`) joins as a hidden async source;
projectile or project.el for the root.

## 7. Left to measure (owner, if (a) or (b))
- `projectile-project-files` time on RMO and on the deal.II source tree:
  `M-: (benchmark-run 5 (projectile-project-files (projectile-project-root)))` from
  a file in each.
- `workspace/symbol` latency on RMO with the patched clangd: `C-c l s`, type three
  letters, note the delay before the list fills.

## Sources
- JetBrains, CLion help "Search everywhere":
  https://www.jetbrains.com/help/clion/searching-everywhere.html
- consult 3.10: `lib/consult/consult.el`, `README.org` ("Multiple sources", "Project
  support"), `NEWS.org` (version 2.0).
- consult-eglot v0.5.0: `lib/consult-eglot/consult-eglot.el`.
- consult-project-extra: https://github.com/Qkessler/consult-project-extra
- consult-omni: https://github.com/armindarvish/consult-omni
