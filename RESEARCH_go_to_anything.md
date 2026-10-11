# RESEARCH - one "go to anything" prompt (T-047)

Findings only; verdicts go to DESIGN (O-30 -> D-074, O-31 -> D-076, O-32 -> D-075,
performance: O-33). Owner request
2026-10-11: a "go to anything" key in Emacs that works like CLion's (the owner calls it
`M-M`): symbols, project files, bookmarks and more from one prompt. Arch, Emacs 31.1,
2026-10-11. Package facts from the vendored sources at their pins (consult 3.10,
consult-eglot v0.5.0, projectile, embark 1.2); CLion facts from JetBrains' help pages
(CLion 2026.2); one hands-on check in `emacs -Q --batch` with a script in a scratch
directory.

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

Other keys (owner request 2026-10-11, with D-074). Checked 2026-10-11: `init.el`
loaded in batch, each key looked up in the global map and in the maps of the modes
the config uses (C++, Python, ESS and its REPL, org, markdown, dired, compilation,
magit, treemacs, code-cells, eglot, projectile, corfu, diff-hl); the Mac's own
bindings read from `term/ns-win.el` (Emacs 31.1). Emacs's conventions (elisp manual,
"Key Binding Conventions"): `C-c` plus a letter, and `<f5>` to `<f9>` without
modifiers, are the only keys reserved for users; no package may bind them.

| Key | Bound now | Terminal | Mac | Notes |
|---|---|---|---|---|
| `M-M` | no mode | yes (ESC M) | Option-Shift-m | `M-m` stays |
| `M-o` | no mode | yes | Option-o | one chord, no Shift |
| `C-c j` / `g` / `s` / `SPC` | no mode | yes | yes | two keys; letters reserved |
| `<f5>` .. `<f9>` | no mode | yes | Fn on laptop keys | one key; reserved |
| `C-S-n` | no mode | no | Ctrl-Shift-n | CLion's Linux "Go to file" |
| `s-O` (Cmd-Shift-O) | no mode | no | yes | Arch: Super is the WM's |
| `M-g a`, `M-g SPC` | no mode | yes | yes | in the `M-g` jump prefix |
| `C-,`, `C-'` | org | - | - | org cycles agenda files |
| `C-x C-b` | `list-buffers` | yes | yes | replaces a default |
| `C-x b` | `consult-buffer` | yes | yes | option (a), section 3 |

- `C-c SPC` is not a letter: by the conventions it falls to minor modes, not users.
- `<f5>` .. `<f9>`: CLion steps the debugger with F7 / F8 / F9; dape uses its own
  prefix (D-004), so they are free, but they are the natural keys if debugger keys
  ever move there.
- `C-S-n` and `s-O` exist only in graphical frames; a terminal cannot send them.
  `s-O`'s Mac neighbours are taken (`s-o` open file, `s-p` print, `s-t` fonts);
  CLion's macOS keymap uses Cmd-Shift-O for files (not checked against its page).
- Double Shift outside Emacs: a key remapper can turn a double tap of Shift into a
  key Emacs binds (for example `<f9>`). Arch packages keyd 2.6.0 and xcape 1.2
  (xcape: X11 only, a single tap); Karabiner-Elements on the Mac does double taps
  with a variable and a delayed action (community examples). Not checked here; it
  is a file outside this repository, so it needs its own D-nnn.

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

## 7. Measurements
Moved to spike S11 (D-074): `spikes/s11-go-to-anything/RUN.md`. Dry run on a toy
project and this repository: projectile lists every git submodule on its own (30
here: 742 ms, against 7 ms for `git ls-files` at the top); filtering 6470 items
takes 1 - 5 ms per input. Run 1 on RMO and deal.II: `spikes/s11-go-to-anything/
RESULTS.md` (journal 0048).

## 8. Performance (owner request 2026-10-11, T-050)
Question: after D-075 (accept S11's one-letter cost), what makes the prompt faster?
S11 timed the filter in batch; this section times the whole prompt in a terminal
Emacs. Method: a prototype command in a scratch directory (never promoted), the
shipped config loaded (`init-test--load`), `emacs -nw` driven by `tmux send-keys`
(one prompt per word, 300 ms between keys), advice on `vertico--exhibit` logging the
time from each key to each screen update with the GC count and GC time since the
key, and on `jsonrpc-async-request` for `workspace/symbol`. Sources: buffers, recent
files, bookmarks, 34602 project files (every fifth file of the LLVM 23.1.1 sources
under `packaging/`, a stand-in for deal.II's 34602; 28381 contain `m`), clangd
symbols of the toy project (system clangd, index loaded). Arch, 2026-10-11, idle.

**Batch breakdown** (39124 items with the commands, input `m`, 30763 hits, median of
7): matching 4.2 ms, copying the hits 1.7 ms, highlighting every hit 31 ms (S11's
31.8 ms is mostly this), vertico's `vertico-sort-history-length-alpha` 11.7 ms on
top (not in S11), vertico's own empty-filter pass 5.4 ms. No GC in batch.

**Profile** (CPU profiler, 1 ms samples, prompt open, `m`, `C-g`): 69 % "Automatic
GC". After startup the config restores `gc-cons-threshold` to Emacs's 800 KB
(`early-init.el`); each key over tens of thousands of candidates allocates
megabytes, and each collection walks the whole heap (50 - 100 ms each here).

**Variants, time from the key to the screen showing that key's results:**
| Variant | first letter | later letters | symbols after 3rd key |
|---|---|---|---|
| A: D-074 with consult's defaults | 310 - 900 ms, 5 - 11 GCs | 30 - 290 ms | 440 - 670 ms |
| D: A, GC threshold 64 MB in the prompt | 108 ms, no GC | 25 - 107 ms | 440 - 630 ms |
| B: A, `:sort nil`, 100 marked, delays | 290 - 370 ms, 3 - 5 GCs | 60 - 200 ms | 140 ms |
| C: B and D together | 55 - 67 ms, no GC | 30 - 60 ms | 138 ms |
A's first letter varied between runs (310 and 810 - 900 ms) with the number of
collections. In A, B and D the screen often first shows the previous key's list and
catches up when consult's refresh timer fires (`consult-async-refresh-delay`, 0.2 s).

**What each change does:**
- **GC threshold while the prompt is open** (`gc-cons-threshold` let-bound to 64 MB
  around `consult--multi`; restored on exit): removes every collection while typing.
  The one collection after the prompt closes took 65 - 110 ms. Cost: up to 64 MB more
  memory before that collection.
- **`:sort nil`**: candidates in source order (buffers, recent files, bookmarks,
  files, symbols), as `consult-buffer` does; saves vertico's sort (11.7 ms for
  `m`). Loses vertico's history order: a file chosen before does not move up.
- **Highlight only the first 100 hits**: a regexp compiler whose highlighter stops
  after 100 strings per input, let-bound as `consult--regexp-compiler` (an internal
  variable; `consult-ripgrep`'s docstring tells users to adjust it). With
  `:sort nil` the first 100 hits are the visible ones; scrolling past 100 shows
  unmarked lines. Batch: 37.1 -> 9.4 ms for `m`.
- **Shorter delays for this prompt**: `consult-async-refresh-delay` 0.05 s instead of
  0.2 s (let-bound), the symbol source's throttle and debounce 0.05 s instead of
  consult's 0.5 s / 0.2 s (consult-eglot's own command keeps them). clangd answers
  in 6 - 8 ms here, 5.5 ms median on RMO (S11); the delays were the whole wait.
  Cost: up to one `workspace/symbol` request per 50 ms while typing.

**Side findings:**
- consult-eglot's source asks clangd for `""` when the prompt opens (its `setup`
  action), so the empty prompt lists 100 arbitrary symbols. Our own symbol source
  can skip that request.
- Not covered: the 51 - 66 ms of listing project files at each opening (S11; the
  prototype listed them once); a cache across openings would remove it.
  `consult-async-refresh-delay` 0 not tried. The real clangd on RMO, and the Mac.

## Sources
- JetBrains, CLion help "Search everywhere":
  https://www.jetbrains.com/help/clion/searching-everywhere.html
- consult 3.10: `lib/consult/consult.el`, `README.org` ("Multiple sources", "Project
  support"), `NEWS.org` (version 2.0).
- consult-eglot v0.5.0: `lib/consult-eglot/consult-eglot.el`.
- consult-project-extra: https://github.com/Qkessler/consult-project-extra
- consult-omni: https://github.com/armindarvish/consult-omni
