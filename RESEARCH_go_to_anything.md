# RESEARCH - one "go to anything" prompt (T-047)

Findings only; verdicts go to DESIGN (O-30 -> D-074, O-31 -> D-076, O-32 -> D-075,
performance: O-33 -> D-077, narrowed to symbols: O-34 -> D-079,
path filter for symbols: O-52 -> D-082, fuzzy matching and CLion: O-55 -> D-105,
CLion's extra symbol matches: O-57). Owner request
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

## 9. Narrowed to symbols (owner report 2026-10-11, T-052)
Owner: "`M-o` (`s` -> symbols) and `C-c l s`; the latter waits until no new keys are
typed, appearing more responsive; particularly noticeable in larger trees like
deal.II." Method: section 8's harness (scratch), the shipped command with the
project's files taken from the 34583-file stand-in tree, clangd symbols of the toy;
one key per 100 ms (S11 used 300 ms); `M-o`, `s`, space, a word; then `C-c l s` and
the same word.

| Per key | `M-o`, `s` space | `C-c l s` |
|---|---|---|
| screen update after the key | 15 - 35 ms (0 - 35 candidates shown) | about 3 ms |
| screen updates | 2 - 3 (key, reply, refresh) | 1, after the pause |
| clangd requests | one per key from the third | one, 0.2 s after the last |
| results after the last key | 110 - 120 ms | about 400 ms |

**Causes, read in consult 3.10:**
- Narrowing only sets `consult--narrow` and refreshes (`consult-narrow`). In a prompt
  with an async source, `consult--multi-async` gates each source with
  `consult--async-predicate`: a hidden source gets no new input, but its last
  candidates stay in the merged list (`consult--async-merge-sink`). The 34591
  candidates listed at opening stay, and vertico checks each against the narrowing
  predicate at every update: the 15 - 35 ms. A prompt with static sources only
  (`consult--multi-static`) rebuilds its list from the visible sources and has no
  such cost.
- `s` then space types an `s` first: one first-letter filter over all files (53 -
  61 ms) before the space narrows. The narrow key (`consult-narrow-key`, `<` in this
  config) narrows without input: `<` `s` took 36 ms.
- `C-c l s` keeps consult-eglot's throttle (0.5 s) and debounce (0.2 s): no request
  and no update while typing, one list after the pause. D-077 set 0.05 s for `M-o`.
- A bug in T-049, fixed (2e778ee): the files were listed before the 64 MB threshold
  was bound; opening took 302 - 311 ms with 6 collections.

**Checked change** (scratch, consult's function redefined): a hidden source that
receives input sends `flush` instead, so its candidates leave the merged list;
widening again recomputes it with the next key. With the stand-in tree, narrowed
to symbols: updates 0.6 - 4.7 ms per key (`C-c l s`: about 3 ms), symbols on screen
about 107 ms after the key. The narrowing space itself took 93 ms once (one
collection).

**Widening back** (owner asked, 2026-10-11): `<` `s`, `vec`, `<` `<`: in 3.10 and with
the change, the files for the current input are back in about 30 ms (817 files and
35 symbols for `vec`); the next key updates normally. Edge case found in batch: type
`vec`, narrow, type `t`, delete it, widen: with the `flush` alone the hidden source
stays empty, because `consult--async-dynamic` skips an input equal to its last one;
forgetting the last input on `flush` fixes it (second hunk of D-079's patch).

**Patched (D-079), shipped command, stand-in tree, 100 ms per key:** narrowed to
symbols 0.2 - 4.2 ms per update, opening 109 - 130 ms, `<` `s` 38 ms, `s` space
28 - 97 ms; `C-c l s` 0.6 - 49.7 ms (one collection).

**Not checked:** the deal.II project with its own clangd (the owner's case may have a
larger index and slower replies): S11 run 4 (T-054).

## 10. Symbols of the project only (owner question 2026-10-13, O-37)
Owner: `C-c l s` and `M-o` `<` `s` return all symbols, not the project's alone.
Read in clangd 23.1.1 (`packaging/llvm-project-23.1.1.src`, unpacked for T-023):
- `ClangdLSPServer::onWorkspaceSymbol` passes
  `Params.limit.value_or(Opts.CodeComplete.Limit)`: `WorkspaceSymbolParams` has a
  `limit` (clangd extension; 0 = no limit), else the completion limit, 100 by
  default (`--limit-results`; the config passes none).
- `getWorkspaceSymbols` (FindSymbols.cpp) runs `fuzzyFind` over the whole index
  (dynamic, background and stored shards: the project, the deal.II and standard
  headers it includes) and keeps the top `limit` by quality and name match.
  `WorkspaceRoot` arrives as `HintPath` and only resolves file URIs; nothing ranks
  or filters by location. No flag restricts the search to the project.
- So, without a clangd change: ask with a larger `limit`, keep the symbols whose
  file lies under the project root. With a finite limit, a short query whose top
  results are library symbols loses project symbols ranked below them; with 0 the
  reply holds every match.
- JSON cost in Emacs (`json-parse-string` of a synthetic `workspace/symbol` reply,
  262 bytes per symbol, Mac): 100 symbols 0.05 ms, 1000 1.6 ms, 10000 8.2 ms.
  clangd's own time for large limits, and consult-eglot's formatting of each
  symbol, not measured.
- With a clangd change (patched clangd, D-026 path): drop or rank down symbols
  outside the workspace root inside `getWorkspaceSymbols` (a new `limit`-like
  request field or flag); exact, small replies; needs patch 0010 and a rebuild.
- Toy (2026-10-13): `ans` gave 15 symbols, 2 of the project, the rest from
  `<vector>` / `<string>`.
- S11 run 5 (2026-10-13, owner's deal.II project `step-1` on the Mac, 40 queries;
  `spikes/s11-go-to-anything/RESULTS.md`): a project-root filter over today's 100
  loses project symbols in 14 queries (373 symbols; all three-letter queries, e.g.
  `opt` 12 of 66); over 1000 in 2 (30 symbols); with no limit in none, slowest reply
  15.9 ms (2458 symbols), median 0.3 ms at every limit.
- Risks checked (2026-10-13, Mac, step-1 and toy projects, patched clangd):
  - Reply size, no limit, 47 common three-letter inputs: largest `typ` 6673
    symbols, 48.9 ms; `ope` 5538, 40.4 ms; 33 of 47 under 1000. Round trip about
    7 us per symbol; the root filter adds about 0.15 us per symbol (1 ms for 6673).
    Corrected 2026-10-13 (section 11): that was one inline `string-prefix-p`; the
    shipped `emacs-cpp-go--under-root-p` (up to six prefixes through `seq-some`,
    interpreted as `lisp/` is) costs 16.7 ms per 6673 symbols, 2.5 us each.
  - Caps for `typ` / `ope` (project symbols kept of 111 / 111): 1000 -> 0 / 21,
    2000 -> 33 / 24, 5000 -> 87 / 106, 10000 -> all.
  - URI encoding: clangd 23.1.1 (`URI.cpp`, `shouldEscape`) leaves only letters,
    digits and `- _ . ~ / :` unescaped; eglot's `eglot-path-to-uri` leaves
    `url-path-allowed-chars` but `:` and `%`, so `+ ( ) @ , ; = ! $ & ' *` differ. A
    toy under `c++ (x)@y` listed no project symbols. Decoding each URI with `%`
    instead costs 33 ms per 6673 symbols; a second, clangd-encoded root costs none.
  - pyright (MacPorts), the config's Python server: leaves only letters, digits and
    `- . _ ~ /` unescaped, so `:` too (`%3A`, as eglot does; clangd leaves it); U+00E4 as
    `%C3%A4` like both; reports the directory's real case (`pytoy/` opened as `PYTOY/`).
    Its `workspace/symbol` lists the workspace's symbols only, so `s` and `l` agree
    there. A root with both `:` and `+` matched neither eglot's nor clangd's spelling
    (`py a:b c++`: no symbols); a third, pyright's, fixes it.
  - Case: the toy opened as `TOY/` (macOS, case-insensitive disk) listed none:
    projectile's root keeps the typed case, clangd's URIs the database's.
  - Vendored code: step-1's `fmt/` submodule lies under the root; `for` keeps 146
    project symbols, 144 of them fmt's; `buf` 81 of 81.
  - Generated files under `build/`: 0 symbols in 47 inputs.

## 11. Matching URIs without a table per server (owner question 2026-10-13)
Question: D-083 keeps one spelling of the project root per server encoding (eglot,
clangd, pyright); R's `languageserver` would be a fourth (`r%20a:b%20c++`,
`RESEARCH_r_language_servers.md` 2). Is there a mechanism that needs no table?

Spellings seen for the same path (`c++ (x)@y`, `a:b` + U+00E4, `py a:b c++`): every
encoder leaves letters, digits and `- _ . /` unescaped (RFC 3986's unreserved set,
less `~`, which some encoders escape); they differ in `: + ( ) @ , ; = ! $ & ' *`
and space handling beyond that. Hex digits came out upper case in all four.

Mechanisms, measured on 6673 symbol URIs (111 under the root), Mac, Emacs 31.1:
- Shipped D-083, a string prefix in each known spelling: not general (one table
  per server); 16.7 ms interpreted.
- `eglot-uri-to-path` on every URI, then compare paths: general (also
  `localhost`, remote); 56.4 ms interpreted, 54.6 compiled.
- Percent-decode every URI, then compare: general; 5.7 / 4.6 ms.
- **Safe prefix, then decode**: the root URI up to its first character outside
  letters, digits, `- _ . /` filters with one `string-prefix-p`; only URIs that pass
  are decoded (when they hold `%`) and compared with the root path. General;
  3.8 - 5.0 ms interpreted, 0.7 - 0.9 ms compiled.
- The safe prefix is the same in every spelling, so no URI under the root is lost
  at the first step; library URIs (`/usr/include`, the SDK, `~/opt/dealii`) fail it
  at once. A root with a special character early (`/Users/a b/...`) lets more URIs
  through to the second step: 5.0 ms instead of 3.8 ms.
- Checked: all four spellings under all three roots match; a sibling
  (`c%2B%2B%20%28x%29%40y-other/`) and a library URI do not; an upper-cased URI
  matches when case is ignored (macOS, D-083).
- Decoding: `url-unhex-string`, then `decode-coding-string` as UTF-8, so `%C3%A4`
  becomes U+00E4 as in Emacs's file name.
- Left open by every mechanism: Unicode normalization (a server reporting a
  decomposed U+00E4, NFD, against Emacs's composed one; not seen: clangd, pyright and
  languageserver all sent `%C3%A4`); `file://localhost/` or `file:/` forms (none of the
  four servers sends them; only `eglot-uri-to-path` handles them); `+` for space
  (form encoding, not URIs; none seen).
- Prototype: scratch only (`urimatch.el`, this session), not shipped.
- Shipped as D-085 (2026-10-13): the filter as `M-o` runs it (`seq-filter` over the
  reply vector, interpreted, 64 MB GC threshold, after one warm-up call): 3.7 - 4.2
  ms per 6673 symbols; D-083's tables the same way 13.6 - 14.2 ms. The first call
  in a session costs about 30 ms more (generic `seq-filter` dispatch set up), in
  both; the cold 16.7 ms above included it.

## 12. The first-use stall: consult's file preview (owner question 2026-10-13)
Observed while checking D-087 (terminal Emacs, toy project): the first `M-o` of a
session took no keys for about 0.5 s after the third character, with either
throttle; the second use in the same session did not. Owner: research it, images in
the project directory as a possible cause.

**Where it comes from** (CPU profile of that half second): consult previews the
selected candidate; at the third key it became a file, so
`consult--find-file-temporarily` opened it: `c++-ts-mode` set up (tree-sitter
queries compiled) and `advice-add` on `run-hooks`, a primitive, which needs a
native-compiled trampoline. The trampoline is cached (`~/.emacs.d/eln-cache`,
`subr--trampoline-...run_hooks_0.eln`), but loading it still costs 60 - 104 ms in
each new session. Only the selected candidate is previewed, after each key; with
`:sort nil` that is the first in source order (buffers, recent files, bookmarks,
project files, symbols).

**How consult previews a file** (`consult--find-file-temporarily-1`, 3.10): files of
1 MB or more (`consult-preview-partial-size`) get their first 10 KB in a plain
buffer and are refused if that holds a NUL byte (cheap). Smaller files are opened
with `find-file-noselect`, delayed mode hooks, local variables only if safe; the
binary check runs only in `fundamental-mode` or `hexl-mode`, so images
(`image-mode`) and PDFs (`doc-view-mode`, which starts gs / mutool) are previewed in
full. Excluded by default: remote and `.gpg` files only
(`consult-preview-excluded-files`).

**What step-1 lists** (`M-o`'s project files): 286 `.org`, 100 `.png`, 11 `.svg`, 12
`.gnuplot`, 8 `.R`, 13 `.py`, 39 `.h`, 12 `.cc`; every image under 1 MB, so all
fully previewed.

**First and second preview per type** (batch, shipped config, a fresh Emacs per type,
one `.cc` previewed first to take the session's first-preview cost; real step-1
files):
- first preview of a session (`.cc`): 270 - 400 ms;
- `.org`, first: 5190 ms, then 3 ms;
- `.R`, first: 910 ms (ESS loads), then 2 ms;
- `.png`, `.svg`, first: 159 / 163 ms (`image-mode` loads), then 1 ms; decoding and
  drawing the image happen only in a graphical frame, not measured;
- `.py`, first: 139 ms, then 18 ms.

**Why Org takes seconds** (corrected 2026-10-13): `(require 'org)` 1.3 s and the
first Org buffer another 3.4 s even under `emacs -Q`; 174 files load. Org *is*
native-compiled: Emacs.app ships `.eln` files for 121 of Org's 128 (a first count of
40 matched `org*` names only, and a check of `org-element-parse-buffer` before its
file had loaded saw the autoload, not native code). The CPU profile puts 90 % of the
samples in `require` itself, the C code that finds and loads files. Loading native
code is what is slow on this Mac:
- Org (`require` + `org-mode`), fresh `emacs -Q` each: native 2.9 - 3.8 s,
  byte-code (`load-no-native` t) 1.2 s.
- `org-macs` alone (2 files): native 6 - 35 ms, byte-code 1 ms.
- The shipped config loaded in batch (226 files): native 1.37 - 1.71 s, byte-code
  0.40 - 0.42 s.
- An `.eln` is a Mach-O shared object (ad-hoc signed, `codesign -dv`); each load
  goes through the dynamic loader, code-signature checks and, possibly, the GDATA
  scanner (its exceptions cover `~/source`, not Emacs.app or `~/.emacs.d/eln-cache`).
  Which of these costs the time is not measured. Reading the 174 files' bytes costs
  0.9 s cold, 0.03 s warm.
- Arch not measured; O-24's Mac startup (0.85 s against Arch's 0.15 s) may be the
  same cause.
- After the owner's GDATA exception for `/Applications/MacPorts` (2026-10-13; the
  GDATA dialog cannot select hidden directories, so `~/.emacs.d/eln-cache` has
  none): Org native 1.18 - 1.42 s, byte-code 0.27 - 0.33 s; the config in batch
  native 0.54 - 0.65 s, byte-code 0.21 s. The config's own packages are native code
  in `~/.emacs.d/eln-cache`; Emacs can keep that cache elsewhere
  (`startup-redirect-eln-cache` in early-init), e.g. a visible directory under
  `~/source`, which the exception covers (not tried).

**So images are a cause, but a small one in batch** (about 0.16 s once, plus decoding
in the GUI, not measured); the large first-use costs come from modes loading for
the first time: Org 5.2 s, ESS 0.9 s, and every session's first preview 0.3 - 0.4 s.

**Options** (not ruled, O-41):
- (a) Exclude images and PDFs from preview (`consult-preview-excluded-files`, a
  regexp of extensions): no image-mode / doc-view in the prompt; the candidate still
  opens on RET.
- (b) Debounce previews in `M-o` (consult's `:preview-key '(:debounce 0.3 any)` for
  the command): no preview while typing, one after a pause; the first-load cost
  remains, but not between keys.
- (c) Native-compile Emacs's own Org ahead of time: moot, Org is native already
  (corrected above). In its place: (c1) GDATA exceptions for Emacs.app and
  `~/.emacs.d/eln-cache`, then measure again (owner, no code); (c2) load byte-code
  instead of native code on macOS (`load-no-native`, a D-055 platform default):
  loads about 3x faster here, the Lisp then runs as byte-code (slower to run, not
  measured).
- (d) Load Org at idle after startup: moves 1.3 - 4.5 s into idle time, but a load
  cannot be interrupted; rejected unless (c) makes it short.
- Not checked: the stall in a graphical frame with real images; PDF previews (step-1
  lists none).

## 13. A server-side path filter for symbols (owner request 2026-10-12, T-075)
Written 2026-10-12, before section 10; superseded 2026-10-13 by O-37's ruling
(D-082, D-083: no patch, Emacs filters a larger reply), which measured option (a).
Owner: "Research a server-side path filter": `M-o` symbols only from the project's
files, all symbols behind a narrow key `a`. Read in the clangd sources the patched
build compiles (`packaging/clangd-index-nav/src/llvm-project-23.1.1.src/
clang-tools-extra/clangd`, LLVM 23.1.1); patches 0001 - 0009 touch none of the files
named here. Nothing built or measured.

**Path of a `workspace/symbol` request:**
- `ClangdLSPServer::onWorkspaceSymbol` passes the query and `limit`, a clangd
  extension of `WorkspaceSymbolParams` (`Protocol.h`: "Max results to return,
  overriding global default. 0 means no limit"), else the completion limit, 100.
- `ClangdServer::workspaceSymbols` calls `getWorkspaceSymbols` (`FindSymbols.cpp`)
  with the merged index; the workspace root goes in only to turn URIs into paths.
- `getWorkspaceSymbols` builds a `FuzzyFindRequest` (`index/Index.h`: query, scopes,
  `AnyScope`, `Limit`, `RestrictForCodeCompletion`, `ProximityPaths`,
  `PreferredTypes`); no field restricts by file. It ranks what the index yields and
  keeps the top `Limit`. The location shown is the definition, else the canonical
  declaration.
- `MergedIndex::fuzzyFind` (`index/Merge.cpp`) asks the dynamic index, then the
  background index, with the same request. Background and preamble symbols are in
  a `Dex` (`IndexType::Heavy`), main-file symbols in a `MemIndex` (`Light`), which
  scans every symbol.
- `Dex::fuzzyFind` (`index/dex/Dex.cpp`) intersects the query's trigram lists with
  the scopes, a proximity boost and a type boost; caps the result at `Limit * 100`
  documents (10000 for 100), which keeps the best by quality, since documents are
  numbered in quality order; fuzzy-matches the names; keeps the top `Limit`.

So a filter after the index, in `getWorkspaceSymbols` or in Emacs, sees only the
index's top `Limit`: in RMO, deal.II and std symbols can fill it. The filter has to
run inside the index, before the top-`Limit` cut and before the `Limit * 100` cap.

**What exists, and why it does not fit:**
- `ProximityPaths`: each parent directory of the given files becomes a `BOOST`
  inside a union with all symbols. It reorders, never removes.
- Dex's `ProximityURI` lists hold, per symbol, its canonical declaration's file and
  at most 4 parent directories (`generateProximityURIs`, `ProximityURILimit = 5`).
  The project root is listed only for files at most 4 levels below it:
  `include/rmo/a/b.h` yes, `include/rmo/a/b/c.h` no. Intersecting with the root's
  list would drop deeper files without a word.
- Excluding at indexing: D84811 ("exclude symbols outside of project root from
  index", for the remote index server); `Index: Background: Skip` in `.clangd`
  (checked per translation unit, `index/Background.cpp`). Both take the library
  symbols out of the index that patches 0001 - 0004 navigate with (D-026 .. D-028):
  `M-.` into deal.II would stop working.
- Upstream: no filter by path at query time found (web search 2026-10-12; clangd
  issues 1101 and 707 and discussion 1382 are about missing symbols or skipping
  files).

**Options:**
- (a) No clangd patch: Emacs sends `limit` 1000 (or 0), keeps the results under the
  root, shows the first 100. Up to 10 times the JSON per key (or all matches); a
  project symbol ranked below the limit is still missing. Not measured.
- (b) Patch 0010, filter while scoring: a new clangd extension field in
  `WorkspaceSymbolParams` (absolute directories) copied into a new
  `FuzzyFindRequest` field; `Dex::fuzzyFind` and `MemIndex::fuzzyFind` skip a
  symbol outside every directory before the name match, and `Dex` drops its
  `Limit * 100` cap while the field is set (the cap counts symbols before the
  filter). Files: `Protocol.h`, `Protocol.cpp`, `ClangdLSPServer.cpp`,
  `ClangdServer.h`, `ClangdServer.cpp`, `FindSymbols.h`, `FindSymbols.cpp`,
  `index/Index.h`, `index/Index.cpp` (field, `==`, JSON), `index/dex/Dex.cpp`,
  `index/MemIndex.cpp`. Cost: one prefix comparison per trigram match, all matches
  read; how many a 3-letter query matches in deal.II is not known.
- (c) Patch 0010, a list per directory set: the same field; `Dex` builds, at the
  first request for a set of directories, the list of its symbols under them (one
  pass over all symbols), keeps it while that `Dex` lives and intersects it like a
  scope, so the cap stays meaningful. More code; the background `Dex` is rebuilt as
  shards change and the preamble one per open file, and the pass repeats then.
- (d) Raise `ProximityURILimit` and intersect with the root's list: more lists for
  every symbol, still a fixed depth. Not pursued.

**Open for (b) and (c):**
- Which file decides: the definition (what the prompt shows) or the canonical
  declaration (what Dex's lists use); a symbol declared in a library header and
  defined in the project, or the other way round.
- The build directory under the root: its generated headers would count.
- The index stores URIs (`file:///...`, percent-encoded): the request's directories
  are converted with `URI::create` and compared up to a `/`. On the Mac `/Users` is
  case-insensitive and `/tmp` is `/private/tmp`; not checked.
- `C-c l s` (consult-eglot) sends no such field and keeps today's list unless
  wrapped.
- The remote index (`index/remote`, protobuf) would not carry the field; not used
  here.
- A new clangd patch is tier 3: a spike first, counting trigram matches of 3-letter
  queries in RMO's and deal.II's indexes and timing (b) against today.

## 14. Fuzzy matching in `M-o` and `C-c l s` (owner request 2026-10-15, T-081)
Question: how each prompt matches what is typed, and how far from fuzzy it is. Read
in consult 3.10, consult-eglot (pinned), orderless 1.8 and clangd 23.1.1
(`FindSymbols.cpp`, `FuzzyMatch.cpp`, `index/dex/Trigram.cpp`). Checked by hand,
Mac, 2026-10-15: consult's and orderless's filters in `emacs -Q --batch` over six
file names; clangd's replies with MacPorts' stock clangd 21.1.8 (the matcher files
have the same rules in 23.1.1 as read) on a one-file toy, driven by a small JSON-RPC
client in a scratch directory.

**Three matchers, one per kind of candidate:**
| Candidates | Matched by | Fuzzy? |
|---|---|---|
| `M-o` buffers, recent files, bookmarks, project files | consult's regexp compiler | no |
| `M-o` symbols, `C-c l s` | clangd's `FuzzyMatcher` | yes, by word segments |
| `C-x b`, `C-c p f`, `M-x` (static prompts) | orderless (literal, regexp) | no |

**Static sources in `M-o`.** Once a source is async the whole prompt is
(section 3): `consult--async-static` filters each static source with
`consult--compile-regexp` (here `emacs-cpp-go--highlight-first`, wrapping
`consult--default-regexp-compiler`): the input split at spaces, each word an Emacs
regexp, all words in any order, through `completion-regexp-list`. Orderless never
sees these candidates: `M-o` sets `consult-async-split-style` nil, so the split
style is `none` and the completion-style pass (`consult--split-setup`) gets an
empty filter string, which every candidate passes.
- Case: matching follows `completion-ignore-case`, nil in this config, so the
  match is case sensitive. Batch: `vectortools` misses `src/VectorTools.cc`,
  `readme` misses `README.md`; orderless finds both (`orderless-smart-case`: an
  input without capitals ignores case).
- No orderless dispatchers: `!init` (orderless: "without init") matches nothing.
- No initials or flex in either matcher: `igta` finds no `init-go-to-anything.el`,
  `vt` no `VectorTools.cc` (orderless's `orderless-matching-styles` is its default,
  literal and regexp; initialism and flex are off everywhere).
- `vector tools` matches `vector_tools.h` in both, `VectorTools.cc` only with
  orderless (case again).

**Symbols (`M-o` `s` / `l`, `C-c l s`).** The input goes whole to clangd; the client
filters nothing (`M-o`: split style `none`; `C-c l s`: perl style, the input after
the inserted `#` is all async until a second `#`). clangd's `getWorkspaceSymbols`:
- `a::b::name` splits at the last `::`: the scope part filters scopes loosely
  (`approximateScopeMatch`: `geom::comp` finds `geom::detail::compute_norm`), a
  leading `::` means the global scope. Only the name part is fuzzy matched.
- Dex first narrows by trigrams (`generateQueryTrigrams`): every three letters in a
  row of the query, lower-cased, separators dropped, must be among the symbol's
  trigrams, which are built only along "next letter of this segment" or "first
  letter of the next segment".
- `FuzzyMatcher` then needs every query character, in order, case ignored;
  the first must start a segment (`foo` misses `barefoot`), and after a skipped
  character the next match must start a segment too (`pat` misses `patnther`).
  Segments: `fooBar_baz` is foo, bar, baz; a space is a character like any other.
- Toy replies: `pba`, `pb`, `pushback`, `push_back` find `push_back`; `pshbk`
  does not (s inside a segment after a gap). `vt`, `vtools`, `vectools`,
  `vectortools` find `VectorTools`; `toolsvec` does not (order counts). `upt`
  finds `unique_ptr_helper`; `print` misses `sprintf_like`; `cn` and `cnorm` find
  `compute_norm`.
- **Spaces:** `push back`, `vec tools`, `comp norm` find nothing: no symbol name
  has a space (operators aside). The same words joined (`pushback`, `vectools`)
  do. In `M-o`, `vec tools` lists files and no symbols; in `C-c l s`, `#vec#tools`
  sends `vec` and filters clangd's reply by `tools` with orderless, over the
  candidate text (name, file, line).
- **Three characters first:** both prompts ask clangd only from the third
  character (`emacs-cpp-go--min-input` 3, `consult-async-min-input` 3), so two-letter
  initials such as `vt` or `pb` never reach it; `vtx` and longer do.
- **Ranking:** clangd's reply comes in order of its whole score, name match
  included; the `score` field it sends excludes the name match ("for client-side
  re-ranking", `FindSymbols.cpp`). consult-eglot (`consult-eglot-sort-results` t)
  and `emacs-cpp-go--symbol-request` both re-sort by that field, so a better name
  match can drop below a worse one. Toy, query `count`: clangd sends `count`
  (in `geom`, score 0.275) before `count_vertices_globally` (global, 0.55); both
  prompts show `count_vertices_globally` first. Within a score, `sort` keeps
  clangd's order.
- Second toy (2026-10-15, owner asked for a concrete case), query `vector`, symbols
  `dealii::Vector`, `dealii::VectorTools`, `::vector_n_rows_1d`:
  | clangd sends | `score` | after the re-sort |
  |---|---|---|
  | 1. `dealii::Vector` (exact name) | 0.275 | 1. `::vector_n_rows_1d` |
  | 2. `::vector_n_rows_1d` (prefix) | 0.550 | 2. `dealii::Vector` |
  | 3. `dealii::VectorTools` (prefix) | 0.200 | 3. `dealii::VectorTools` |
  Every `dealii::` symbol gets half the score of a global one for an unqualified
  query (`InBaseClass`: its scope differs from the query's, which is empty), and
  `score` divides the name match out, so in deal.II the re-sort lifts any global
  match above every namespaced one, however exact. Query `vec` on the same toy:
  both orders equal (exact `::vec` is global too).
- Highlighting: `C-c l s` marks the input as one regexp (`consult--async-highlight`),
  case sensitive, so fuzzy hits (`vtools`) show no marks; `M-o`'s symbol source
  marks nothing.

**Options** (not ruled, O-55):
- (a) Keep clangd's order: `M-o` appends the replies unsorted; `C-c l s` needs
  `:sort nil` without consult-eglot's re-sort, which `consult-eglot-sort-results`
  nil does not give (it turns vertico's sort on), so a consult-eglot patch (D-069)
  or `C-c l s` built on `M-o`'s symbol source. With two servers (clangd and
  pyright in one project) the two lists then follow each other, not interleaved.
- (b) Case: `M-o`'s static sources ignore case, always (bind
  `completion-ignore-case` t in the prompt) or smart as orderless (decided per
  input; consult reads the variable at each input, so it would be set in the
  minibuffer buffer on each change). Cost not measured.
- (c) Orderless for `M-o`'s static sources: a regexp compiler built on
  `orderless-compile` (orderless.el line 454; neither README shows one), giving
  dispatchers and the same words as `C-x b`; must keep S11's per-key times (D-075,
  D-077); not measured.
- (d) Initials and flex for files and buffers (`orderless-initialism`,
  `orderless-flex`, by dispatcher or in `orderless-matching-styles`): `igta`
  would find `init-go-to-anything.el`; more hits per input, slower over deal.II's
  34602 files; not measured.
- (e) Several words to clangd: `M-o` sends the words joined (`vec tools` as
  `vectools`), or the first word to clangd and the rest as a filter on the reply,
  as `C-c l s`'s `#vec#tools`. Joining keeps the order rule; filtering keeps
  any order.
- (f) Two-letter symbol input: lower the minimum to 2 for symbols; more and larger
  replies (`l` asks all of clangd's index; `s` up to
  `emacs-cpp-go-symbol-limit`); not measured.

## 15. Compared with CLion (owner request 2026-10-15, T-083)
Question: how CLion matches in the same places, against section 14. CLion 2026.2.3.1
is installed on the Mac; it was not driven by hand. Sources: JetBrains help pages
(CLion, IntelliJ IDEA, Rider, 2026.2), which say little about matching; the
IntelliJ platform sources on GitHub (`intellij-community`, master, 2026-10-15):
`platform/util/text-matching/.../psi/codeStyle/` (`NameUtil.java`,
`MinusculeMatcherImpl.kt`, `TypoTolerantMatcher.kt`) and
`platform/lang-impl/.../gotoByName/DefaultChooseByNameItemProvider.java`. The
installed CLion carries these classes (`lib/intellij.platform.analysis.jar` holds
`MinusculeMatcherImpl` and `TypoTolerantMatcher`); that its build equals master was
not checked. C++ symbols come from CLion Nova, the ReSharper C++ engine (only engine
since 2026.2, plugin `clion-radler`), whose own rules JetBrains documents for Rider.

**What CLion does:**
- Go to File / Class / Symbol build the platform matcher with
  `MatchingMode.IGNORE_CASE` (`buildPatternMatcher`). Rider: "You can type either
  uppercase or lowercase letters"; `ch` finds `ColorHelper`.
- Humps, also typed lower case: each pattern letter continues the current word or
  starts at a later word start (CamelCase, `_`, `-`, `.`, `:`, `+`, space); an upper
  case letter in a mixed-case pattern must hit a word start. CLion blog (2015):
  `cml` finds `CMakeLists.txt`. Close to clangd's `FuzzyMatcher` (section 14).
- A match starting mid-word needs a `*` before it, or the popup's "search in any
  place", which prepends `*`; such middle matches must be 3 or more characters
  ("to prevent too many irrelevant matches").
- A space in the pattern is a wildcard like `*`: the words in order, each next one
  at a later word start. A trailing space asks for the end of a word. Rider: parts
  of a qualified name are separated by spaces or dots; a quoted term is exact.
- Qualified names: each model's separators (`::` for C++ assumed, not read in
  Nova) become one separator in name and pattern, so `geom::vec` would find
  `geom::VectorTools`.
- Ranking: exact name first (`EXACT_MATCH_BONUS` 5000), then the matching degree
  (a word-start bonus of 1000, case agreement, fewer fragments and skipped humps),
  then path proximity to the open file. Search Everywhere's own mixing of the
  scopes not read.
- Typos: `TypoTolerantMatcher` allows one error per pattern (a QWERTY neighbour in
  the same row, two letters swapped, a letter missed), only for ASCII names, and
  only when the exact match fails; enabled by `MatcherBuilder.typoTolerant()` up to
  13 characters. Which popups enable it was not found (`DefaultChooseByNameItem
  Provider` does not); a Levenshtein fallback for qualified names sits behind the
  registry key `search.everywhere.fuzzy.class.search.enabled`.
- Scope: project items; libraries after a second double Shift or the "Include
  non-project items" box. Rider: if nothing in the solution matches, library items
  appear without asking.
- From the first character; no minimum.

**Side by side** (section 14's toy and batch inputs; CLion's column from the
sources; the owner's check in CLion follows below):
| Input / rule | CLion | `M-o` files, buffers | `M-o` `s` / `l`, `C-c l s` |
|---|---|---|---|
| case | ignored | sensitive (`readme` misses `README.md`) | ignored |
| humps, lower case (`cml`, `vt`) | yes | no | yes, from 3rd character |
| mid-word start (`ector`) | only after `*`, 3+ characters | yes, any substring | no |
| space (`vec tools`) | wildcard, words in order | words in any order | no match |
| `*` | wildcard | regexp `.*` | no |
| one typo (`vectro`) | `TypoTolerantMatcher`, popups unknown | no | no |
| `ns::name` | qualifier matched | as text in the path | scope matched loosely |
| best first | exact name, match quality | source order | quality, not the name match |
| libraries | on request; Rider: when the project has none | n/a | `l` |

**Against O-55's options:**
- (a) keep clangd's order: CLion ranks by name match first, so (a) moves toward it;
  CLion additionally puts the exact name on top, which clangd's own order mostly
  does (toy: `count` first).
- (b) ignore case: CLion ignores case everywhere in these popups.
- (c) orderless: orderless's literal and regexp parts are substrings in any order;
  CLion is in order and at word starts. (c) gains dispatchers and `C-x b`'s words,
  not CLion's behaviour.
- (d) initials / flex: CLion's humps are neither orderless's initialism (initials
  only, every word) nor flex (any letters in order, anywhere); clangd's matcher is
  the nearest. For files no packaged orderless style does humps; a custom matching
  style would (regexp per letter: continue the word or jump to a word start).
- (e) words to clangd: joining (`vec tools` as `vectools`) is CLion's space rule
  under clangd's matcher (in order, next word at a word start); the first-word
  filter is not.
- (f) two letters: CLion matches from the first.
- New, (g) one typo: nothing in Emacs here; orderless has no such style, and clangd
  has none. Lowest value, as CLion's own use is not confirmed.

**Owner's hand check in CLion** (asked: Search Everywhere (All) and Go to Symbol,
each input, the first item). Owner 2026-10-15, CLion 2026.2.3.1, the owner's
project (RMO with deal.II, judging by the names). Next to it, clangd 21.1.8 on a
toy holding the same names (Mac, the client of section 14), so the clangd column
says whether that name matches, not how it ranks among RMO's symbols.
| Input | CLion All | CLion Symbol | clangd, same names |
|---|---|---|---|
| `pshbk` | `pshtl.h.B...` (cut off) | none | none |
| `vec tools` | `vector_tools.h` | none | none |
| `vectro` | `vector_n_rows_1d` | `vector_n_rows_1d` | `vector_n_rows_1d` |
| `ector` | `EvaluatorSelector` | `#r_rmo_#3A_3ATangentVector` | none |
| `count` | `count() const` | `count() const` | `S::count` |
| `readme` | `README.md` | `read_particle_data_from_memroy` | the same |
| `cml` | `CMakeLists.txt` | `class_multilevel_experiment` | none |
| `geom::vec` | `vertices_per_cell` | `vertices_per_cell` | none |
`GeometryInfo::vec` finds `GeometryInfo::vertices_per_cell` in clangd; `Geom::vec`
does not.

What it shows:
- Symbols: CLion and clangd agree on five of eight. Neither finds `push_back` from
  `pshbk`, nor anything from `vec tools` (Go to Symbol takes the space as a
  qualifier separator, as Rider's page says; `VectorTools` is a deal.II namespace).
  `vectro` is no typo: `vect` + `r` at the start of `rows` + `o`, a hump match in
  both; so the one-typo matcher stays unconfirmed in CLion.
- Symbols, CLion only: mid-word matches (`ector` in `TangentVector`, 5 characters,
  over the 3 that IntelliJ's middle match needs); `cml` with `l` inside
  `multilevel`, which clangd refuses after a gap; a qualifier matched loosely
  (`geom` against, presumably, `GeometryInfo`), where clangd needs each scope
  segment whole (`approximateScopeMatch`).
- `#r_rmo_#3A_3ATangentVector` looks like a percent-escaped name (`%3A` is `:`);
  where Nova takes it from was not looked into.
- Ranking: `count` puts `count() const` first in CLion, as clangd's reply order
  does; `M-o` and `C-c l s` re-sort it away (section 14, option (a)).
- All (files and more): case ignored (`README.md`), humps over `.` and `_`
  (`pshtl.h.B...`, `CMakeLists.txt`), space as an in-order wildcard
  (`vector_tools.h`), mid-word from 3 characters (`EvaluatorSelector`). `M-o`'s
  files: `vec tools` and `ector` match (any substring), `readme`, `cml` and
  `pshbk` do not.

## 16. CLion's extra symbol matches with clangd (owner 2026-10-15, T-085)
Owner, ruling O-55 (a) + (b) (D-105): "research Optional", i.e. the three kinds of
symbol match CLion made and clangd refuses (section 15): mid-word (`ector` in
`TangentVector`), a lower-case letter inside a word after a gap (`cml` in
`class_multilevel_experiment`), a loose qualifier (`geom::vec` to
`GeometryInfo::vertices_per_cell`). Read in clangd 23.1.1 (`index/dex/Dex.cpp`,
`index/dex/Trigram.cpp`, `index/MemIndex.cpp`, `index/Index.h`, `FindSymbols.cpp`,
`FuzzyMatch.cpp`), which the patched clangd builds (patches 0001 - 0009 touch none
of these). Nothing built or measured.

**Where clangd refuses each, along a `workspace/symbol` request:**
1. `getWorkspaceSymbols` splits the query at its last `::` (scope, name), sends the
   name as `FuzzyFindRequest::Query` with the scope as a boost (`AnyScope`).
2. Dex intersects the query's trigrams with each symbol's (section 14), caps at
   `Limit * 100` by quality, then drops every symbol `FuzzyMatcher` refuses.
   MemIndex (main files, dynamic index) scans all symbols with the same matcher.
3. `getWorkspaceSymbols` drops symbols whose scope fails `approximateScopeMatch`
   (whole segments, in order), matches the name again, ranks, keeps `Limit`.
The index's matcher is shared: code completion (`CodeComplete.cpp`), the include
fixer and `XRefs.cpp` also call `fuzzyFind`. A looser matcher there changes what
completion receives within its limit, so any loosening needs a request field that
only workspace symbols set (as section 13 (b) for paths).

**Mid-word (`ector`):**
- Trigrams already admit it: a symbol's trigrams follow "next letter" and "next
  word start", so every run of three letters in a row is among them; `ect`, `cto`,
  `tor` are all in `TangentVector`'s. Only `FuzzyMatcher` refuses (first letter
  not at a word start).
- Change: a new `FuzzyFindRequest` field (for example `MiddleMatch`), set by
  `getWorkspaceSymbols` for queries of 3 or more letters (IntelliJ's minimum);
  where `FuzzyMatcher::match` fails, Dex, MemIndex and `getWorkspaceSymbols` accept
  a case-ignoring substring at a score below every hump match. Files: `Index.h`,
  `Index.cpp` (`==`, JSON), `Dex.cpp`, `MemIndex.cpp`, `FindSymbols.cpp`, a
  substring helper next to `FuzzyMatcher`. No index format change.
- Cost: no new candidates reach the loop, only fewer are refused; one substring
  test per refused candidate. More results per query, so the `Limit` cut and
  `M-o`'s `emacs-cpp-go-symbol-limit` are reached sooner (D-083's message).

**Inside a word after a gap (`cml`):**
- Trigrams refuse it before the matcher: a symbol's trigrams only jump to the next
  word start; `class_multilevel_experiment` has `cmu` and `cme`, not `cml`. Dex
  never offers the symbol.
- Change: either trigrams for every jump inside a word (per identifier about the
  cube of a word's length instead of its length: posting lists and memory grow,
  for every query, completion's too), or, under a request field, skip the trigram
  step and scan all symbols as MemIndex does (deal.II's index: number of symbols and
  scan time not known; S11's replies took 0.3 - 49 ms). Plus `FuzzyMatcher` letting
  a lower-case letter match after a gap (`allowMatch`), which also changes its
  scores.
- CLion's own rule for it was not found: the parts of IntelliJ's matcher read
  (section 15) do not say how an all-lower-case pattern treats a gap inside a word,
  and Go to Symbol's C++ results may use Nova's (ReSharper's) matcher; Rider's
  pages do not say.

**Loose qualifier (`geom::vec`):**
- Only step 3 refuses: the name `vec` matches `vertices_per_cell`, Dex boosts but
  does not require the scope (`AnyScope`), then `approximateScopeMatch` wants
  `geom::` as a whole segment of `GeometryInfo::`.
- Change in clangd: `approximateScopeMatch` matching each query segment with
  `FuzzyMatcher` against the symbol's segments, in order; `FindSymbols.cpp` only;
  the result field, ranking (`InBaseClass` penalty when scopes differ) unchanged.
- Without clangd: `M-o` splits the input at its last `::` itself, sends only the
  name (`vec`) and keeps replies whose `containerName` (the scope, sent by clangd)
  matches the qualifier, by a regexp per letter (continue the word, or jump to a
  later word start). For `s` this works within `emacs-cpp-go-symbol-limit` (the
  name alone matches more symbols; D-083's message warns at the cap); for `l` and
  `C-c l s` within clangd's 100, which a short name fills with other scopes.
  `C-c l s` would need its own source (consult-eglot sends the input whole).

**Ranking for all three:** CLion lists exact and hump matches before middle and
qualifier ones (section 15); clangd's order would hold that if the new matches score
below the old ones (a substring score under the lowest hump score; a fuzzy scope
match penalised as `InBaseClass`).

**Options** (not ruled, O-57):
- (a) Loose qualifier in Emacs only (`M-o`), no clangd change; `C-c l s` unchanged.
- (b) Patch 0010: loose qualifier in clangd (`FindSymbols.cpp` only), both prompts.
- (c) Patch 0010 / 0011: mid-word for 3+ letters under a request field (five
  files).
- (d) Inside-a-word gaps (`cml`): trigram change or a full scan; largest cost,
  rule not known from CLion; not pursued unless asked.
- (e) None.
- A clangd patch is tier 3: spike first (deal.II index: replies and times for a set
  of mid-word and qualified queries, against today).

## 17. Several servers' symbols, and `C-c l s`'s kind groups (owner 2026-10-15, T-086)
Owner, approving T-084: "research options with several servers' replies following
each other". Read in eglot 1.24.31 (Emacs 31.1), consult-eglot (pinned), vertico
2.15; replies from pyright (MacPorts) and texlab on a toy (Mac, the JSON-RPC client
of section 14); terminal check of T-084 on a CMake toy (tmux, `emacs -nw`, shipped
config, clangd 21.1.8), 2026-10-15.

**When a project has several servers:**
- eglot runs one server per project and language; `consult-eglot--servers` (used by
  both prompts) returns the project's servers that offer `workspace/symbol`, newest
  started first (eglot pushes each new one onto `eglot--servers-by-project`).
- Here: clangd (C++), pyright (Python, started when a `.py` file of the project is
  visited, `emacs-cpp-python-eglot-ensure`), texlab (LaTeX, `.tex` / `.bib`). R's
  server is not configured (O-39). deal.II's `step-1` holds `.py` files, so after
  visiting one, `M-o` symbols there come from clangd and pyright.
- pyright and texlab both answer `workspace/symbol` (`workspaceSymbolProvider`), each
  symbol with a range, none with a `score`. Toy replies: pyright 1 - 7 ms, texlab
  0.3 - 1 ms (`Vector spaces`, a section title, for `vec`).
- Before D-105 both prompts sorted by `score`, so the score-less servers' symbols
  always came after all of clangd's: a fixed order by accident. Since T-084 each
  reply is appended as it arrives: whichever server answers first is on top, which
  can differ from one key to the next; rows already shown do not move, the later
  reply comes below them.

**Options** (not ruled, O-58):
- (a) Arrival order, as built (T-084).
- (b) A fixed order: the server of the buffer `M-o` was called from first (clangd in
  a C++ buffer, pyright in a Python one), then the others newest first. A reply
  from a server ranked earlier that arrives later is inserted above rows already
  shown; the selected row can change under the cursor.
- (c) (b), but show nothing until every server has answered, or a timeout passes
  (for example 0.2 s, then the rest below as they come): no rows move; the wait is
  the slowest server's (ms on the toys), a hung server costs the timeout.
- (d) One source per server in `M-o` ("Symbol clangd", "Symbol pyright"): each its
  own group with a heading, in source order; same moving rows as (b) within the
  prompt. Narrow keys per server or one shared key: not checked. `C-c l s` stays
  one list.
- (e) Only the current buffer's server: a C++ buffer asks clangd alone, as the
  prompts did before pyright or texlab started. Loses the other languages' symbols.
- (f) Interleave the replies (first of each, second of each, ...): servers' ranks are
  not comparable; not recommended.

**`C-c l s` groups by kind, which reorders too (found in T-084's terminal check):**
- consult-eglot passes `:group (consult--type-group consult-eglot-narrow)`: each
  candidate's group is its symbol kind (Method, Function, Variable, Class, ...).
  vertico (`vertico--group-by`) then lists whole groups in the order each first
  appears; inside a group the order stays.
- Toy, `C-c l s` `count`: clangd sends 57 symbols, `std::...::count` methods first,
  `geom::count` (Variable) at 21, `count_vertices_globally` (Function) at 25. A
  Function appears before index 21, so the Function group, with
  `count_vertices_globally`, comes before the Variable group with `geom::count`:
  the exact name below the partial one again. Filtered to the toy's file
  (`#count#src`), only the two remain and `count` is first. `vector`: `Vector`
  (Class) first, as clangd sent.
- `M-o` groups by source only ("Symbol", "All Symbols"), not by kind: clangd's
  order shows unchanged (toy: `count` then `count_vertices_globally`; `Vector`,
  `vector_n_rows_1d`, `VectorTools`).
- CLion's Go to Symbol is one flat list (section 15). Narrowing by kind (`f`, `c`,
  `v`, ... after `<`) uses `:narrow`, which reads the same `consult--type`
  property, not `:group`.
- Options (O-58 (g) / (h)): (g) no kind groups in `C-c l s` (consult-eglot patch 0001
  gains a hunk dropping `:group`; narrowing by kind stays); (h) keep them.

## 18. `M-o` and `C-c l s` on mid-word matches (owner 2026-10-19)
Owner, on RMO-gross-pitaevskii (deal.II, Kokkos), patched clangd pkgrel 8: `ector`
gives `Vector` in `M-o` (project files only) but `EBOBaseImpl<T, ...>` from
`/usr/include/kokkos/...` first in `C-c l s`; `Vector` gives deal.II's `Vector` in
`C-c l s`. Read in `lisp/init-go-to-anything.el`, `lisp/init-lsp.el`, clangd patch
0012; S14's step-1 numbers (`spikes/s14-symbol-matches/RESULTS.md`); a toy with
Kokkos's `EBOBaseImpl` pattern, queried over JSON-RPC with
`/opt/clangd-index-nav/bin/clangd` (Arch, 2026-10-19).

**What each prompt asks clangd, and keeps:**

| | `M-o`, `s` (default) | `M-o`, `< l` | `C-c l s` |
|---|---|---|---|
| request `limit` | 10000 (D-083) | none: clangd's 100 | none: clangd's 100 |
| `looseScope`, `middleMatch` | yes (D-113) | yes | yes (consult-eglot 0001) |
| kept | defined under the project root (D-082) | all | all |
| order | clangd's (D-105) | clangd's | grouped by kind (D-106) |

**Why `ector` differs:**
- Patch 0012 ranks a mid-word match (`ector` in `Vector`) below every fuzzy match,
  so mid-word matches are the first to go at the limit (its commit message). On
  step-1, `ector` has 13 fuzzy and 924 mid-word matches (S14): within 100, the 13
  fuzzy come first and 87 of the 924 follow, ordered by clangd's quality (how often
  a symbol is referenced), which favours deal.II's and Kokkos's symbols over the
  project's. `M-o` asks for 10000, so all 937 arrive and the project's are kept.
- `EBOBaseImpl` is a fuzzy match, not a mid-word one. Kokkos's partial
  specialization `EBOBaseImpl<T, true, CtorNotOnDevice>` has a constructor clangd
  names with the template arguments, and the fuzzy matcher matches `ector` as `E`
  plus `ctor` in `CtorNotOnDevice` (each a word start). Toy: `ector` at limit 100
  lists that constructor first, then the mid-word `TangentVector` and `Vector`.
  Patch 0012 skips template arguments for mid-word matches only; clangd's own
  fuzzy matching has always included them.
- `C-c l s` then groups the 100 by kind: the group of the first symbol clangd sent
  (here the constructor's) heads the list, `Vector` (Class) lands in a later
  group if it is among the 100 at all.

**Why `Vector` gives deal.II's in `C-c l s`:** an exact name is a fuzzy match of the
best kind, so every `Vector` and `vector` in the index competes on quality; nothing
filters by location, and deal.II's `dealii::Vector` is referenced far more than a
project's own. Toy: `Vector` at limit 2 gives the project's `::Vector` (no rival
named `Vector` there), then `std::pmr::vector`. `M-o` `s` keeps the project's only;
`M-o` `< l` lists what `C-c l s` lists, in clangd's order without kind groups.

**Not asked, possible follow-ups:** a project-only `C-c l s` (as `M-o` `s`, or a
key in `C-c l s` to drop library symbols); a clangd change skipping template
arguments in fuzzy matches of constructor names (upstream behaviour, affects
completion too). None recorded as questions.

**The heading "Symbol (clangd)" (owner: research "Project Symbol (clangd)"):**
- `emacs-cpp-go--symbol-sources` names `s` "Symbol (server)" and `l` "All Symbols
  (server)"; the narrow labels are "Symbol" and "All Symbols" (shown after `<`,
  D-080). With a project root, `s` keeps the project's symbols only (D-082); without
  one (a buffer outside any project) `s` is every symbol, as `l`.
- The other project-only source is already named so: "Project File" (`f`); the
  known projects are "Project" (`p`, hidden).
- pyright and texlab only list the workspace's symbols (section 10), so "Project
  Symbol" is true for them too.
- Places that name it: `lisp/init-go-to-anything.el` (`emacs-cpp-go--symbol-sources`,
  its docstring), `test/init-go-to-anything-test.el` (four assertions), DESIGN D-082
  / D-106 text; no README text.
- CLion calls its tab "Symbols" and limits it to the project unless "Include
  non-project items" is ticked (section 15).
- Options as O-66.

## Sources
- JetBrains, CLion help "Search everywhere":
  https://www.jetbrains.com/help/clion/searching-everywhere.html
- consult 3.10: `lib/consult/consult.el`, `README.org` ("Multiple sources", "Project
  support"), `NEWS.org` (version 2.0).
- consult-eglot v0.5.0: `lib/consult-eglot/consult-eglot.el`.
- consult-project-extra: https://github.com/Qkessler/consult-project-extra
- consult-omni: https://github.com/armindarvish/consult-omni
- clangd, LLVM 23.1.1: `clang-tools-extra/clangd/` `Protocol.h`, `ClangdLSPServer.cpp`,
  `ClangdServer.cpp`, `FindSymbols.cpp`, `index/Index.h`, `index/Merge.cpp`,
  `index/MemIndex.cpp`, `index/FileIndex.cpp`, `index/BackgroundRebuild.cpp`,
  `index/Background.cpp`, `index/dex/Dex.cpp`, `index/dex/Trigram.cpp`, `FuzzyMatch.cpp`,
  `FuzzyMatch.h`.
- orderless 1.8: `lib/orderless/orderless.el`.
- IntelliJ platform, intellij-community master (2026-10-15):
  https://github.com/JetBrains/intellij-community, `platform/util/text-matching/src/
  com/intellij/psi/codeStyle/` and `platform/lang-impl/src/com/intellij/ide/util/
  gotoByName/DefaultChooseByNameItemProvider.java`.
- JetBrains help 2026.2: https://www.jetbrains.com/help/idea/searching-everywhere.html,
  https://www.jetbrains.com/help/rider/Navigation_and_Search__CamelHumps.html,
  https://www.jetbrains.com/help/rider/Navigation_and_Search__Go_to_Symbol.html,
  https://www.jetbrains.com/help/clion/clion-language-engines.html.
- CLion blog, "Search and navigation in CLion" (2015):
  https://blog.jetbrains.com/clion/2015/03/search-and-navigation-in-clion/
- D84811, "[clangd] Add an option to exclude symbols outside of project root from
  index": https://reviews.llvm.org/D84811
- clangd issues 1101 and 707, discussion 1382:
  https://github.com/clangd/clangd/issues/1101,
  https://github.com/clangd/clangd/issues/707,
  https://github.com/clangd/clangd/discussions/1382
