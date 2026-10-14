# 0064 - T-071: snippets with yasnippet, its collection on `C-c y`

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `.gitmodules`, `lib/yasnippet`, `lib/yasnippet-snippets`,
  `patches/yasnippet-snippets/0001-...`, `test/init-completion-test.el`,
  `test/init-cpp-test.el`, `test/init-test.el`)
- **Tier:** 2
- **Decisions:** D-095 (built here), O-45 (b), keys (k2)
- **Done when:** yasnippet 0.14.3 (GNU ELPA git) and yasnippet-snippets 1.0 (NonGNU
  ELPA git) as pinned submodules; yasnippet on in code and LaTeX buffers; `C-c y`
  expands a snippet key before point; TAB / S-TAB next / previous field only while a
  snippet is active, corfu's popup keeping TAB; TAB elsewhere unchanged (D-020);
  clangd completions insert argument placeholders (eglot announces snippets). Tests:
  keys, TAB unchanged without a snippet, field moves, a collection snippet expanding
  in c++-ts-mode, python-ts-mode, LaTeX-mode; startup cost measured (snippets loaded
  on first use if > ~20 ms); Mac hand check; make test. Met but the owner's Mac hand
  check; the collection's pin differs (below).
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
A snippet is a small template with gaps ("fields") you fill in one after the other.
Two things come from adding yasnippet. First, eglot sees it and tells the language
servers it can take snippets: picking `area` from clangd's completions now inserts
`area(double scale, int n)` with the cursor on `double scale`, and TAB goes to
`int n`. Second, yasnippet-snippets brings ready-made templates: `for`, `class`,
`def`, `begin` ... typed and then expanded with `C-c y`. TAB itself does not expand,
so indentation and completion on TAB stay exactly as before; only inside a snippet
does TAB move between fields, and even there it completes while corfu's popup is
open.

## Concepts explained
- **Minor mode keymaps:** yasnippet's `yas-minor-mode-map` binds TAB to a
  "conditional" command (expand if a key is before point). The config removes that
  binding (`keymap-unset`) and puts its own command on `C-c y`. The field keys live
  in a second map, `yas-keymap`, active only while a snippet is being filled.
- **A hook that switches keys off:** every key of `yas-keymap` first asks
  `yas-keymap-disable-hook`; the config's function answers "off" while
  `completion-in-region-mode` is on, which is when corfu shows its popup.
- **Autoloads and `eval-after-load`:** the collection's file carried a cookie that
  copied "when yasnippet loads, scan the collection" into the generated autoloads
  file, so the 130 - 150 ms scan ran with the first code buffer. Patch 0001 removes
  the cookie; the same form still runs when the collection's own file is loaded,
  which `C-c y` does with `require` the first time.
- **`<remap>`:** `C-c & C-s` (yasnippet's insert by name) is remapped to a command
  that loads the collection, then runs yasnippet's.

## Key files walked
- `lisp/init-completion.el` - section "Snippets": `emacs-cpp-snippets-expand`,
  `-insert`, `--completing-p`, the `use-package yasnippet` form.
- `patches/yasnippet-snippets/0001-...` - the dropped autoload cookie.
- `test/init-completion-test.el` - keys in three modes, expansion and field moves,
  no key before point, the autoloads file free of the collection.
- `test/init-cpp-test.el` - `init-cpp-completion-inserts-argument-placeholders`:
  real clangd, waits for its first parse (its clang-tidy finding), then completes.
- `test/init-test.el` - `user-emacs-directory` now stays the temporary home for the
  whole test run: yasnippet creates `snippets/` under it when it first loads
  snippets, and the earlier probes had created an empty `~/.emacs.d/snippets`.

## Measurements (Mac, batch, shipped config)
- Startup: yasnippet not loaded. First code or LaTeX buffer: yasnippet 8.5 - 11 ms.
- Collection scan: 130 - 150 ms (124 directories; elp: 87 ms of it reading each
  `.yas-parents`, 0.7 ms per file read on this Mac). First `C-c y`: 213 ms
  (scan and loading the buffer mode's snippets); later ones 0.3 ms.

## Assumptions + risks  (the postmortem ledger)
- **Pin:** the done when said yasnippet-snippets 1.0; the 1.0 commit (39e640c,
  2021) has no `c++-ts-mode` or `python-ts-mode` directory, so the branch's tip
  606ee92 (2025-12-15) is pinned (D-006: newest commit when the release lacks
  what is needed). **Would break if:** a later tip renames directories.
- **Assumed:** a key typed by chance never expands (TAB does not expand). **Would
  break if:** a later yasnippet re-adds TAB elsewhere; the key test catches it.
- **Assumed:** clangd's first-parse word list (no snippets) is short-lived; a
  completion in the first seconds after opening a file comes without fields.
- **Known:** a `.tex` file with no LaTeX in it opens in plain TeX mode, where
  yasnippet is off.
- **Found, not fixed here:** `make test` adds its temporary preset projects to the
  owner's `~/.emacs.d/projects.eld` (project.el remembers projects; the presets
  tests load it before any redirect). Fixed in the next commit.

## How to verify
- `make test`: 105 tests, 103 pass, 2 skipped.
- Owner (Mac, GUI): in a C++ file of a preset project, type `are`, complete a
  function with parameters: fields appear, TAB moves, `S-TAB` back; type `for` and
  `C-c y`; open corfu's popup inside a field: TAB completes; in a `.tex` file
  `begin` `C-c y`; TAB on an indented line without a snippet completes as before.
