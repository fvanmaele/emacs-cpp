# RESEARCH - one "go to anything" prompt (T-047)

Findings only; verdicts go to DESIGN (O-30 -> D-074, O-31 -> D-076, O-32 -> D-075,
performance: O-33 -> D-077, narrowed to symbols: O-34 -> D-079). Owner request
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

## Sources
- JetBrains, CLion help "Search everywhere":
  https://www.jetbrains.com/help/clion/searching-everywhere.html
- consult 3.10: `lib/consult/consult.el`, `README.org` ("Multiple sources", "Project
  support"), `NEWS.org` (version 2.0).
- consult-eglot v0.5.0: `lib/consult-eglot/consult-eglot.el`.
- consult-project-extra: https://github.com/Qkessler/consult-project-extra
- consult-omni: https://github.com/armindarvish/consult-omni
