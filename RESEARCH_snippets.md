# RESEARCH - Snippets: yasnippet and alternatives

Question (owner, 2026-10-14): research yasnippet. Findings only; verdicts go to DESIGN.

Sources: GNU ELPA's package pages for yasnippet, yasnippet-classic-snippets and
tempel, NonGNU ELPA's for yasnippet-snippets, its GitHub repository's `snippets/`
(read 2026-10-14); Emacs 31.1's eglot (`eglot--snippet-expansion-fn`).

## 1. What a snippet package changes here
- **eglot:** `eglot--snippet-expansion-fn` returns a function only when
  `yas-minor-mode` is defined, and eglot then tells servers it supports snippets
  (`snippetSupport`). Without yasnippet the servers send plain text: clangd
  completes `area` without its parameters, texlab `begin` without `\end{...}`
  (`RESEARCH_latex.md` 7). With yasnippet, clangd inserts a call with placeholders
  for its arguments (`area(${1:double scale})`), TAB moves between them.
- **Own templates:** a `for` loop, a class with its special members, a LaTeX
  `figure` with caption and label, typed by a short key.

## 2. Candidates
- **yasnippet** (GNU ELPA 0.14.3, 2025-06-02, maintainer Noam Postavsky; git:
  GNU ELPA's `externals/yasnippet`, upstream github.com/joaotavora/yasnippet).
  Snippets in the TextMate-like format (`$1`, `${2:default}`), one file per
  snippet in a directory per mode. Since 0.13 no snippets are bundled.
- **Snippet collections:** `yasnippet-snippets` (AndreaCrotti; NonGNU ELPA 1.0,
  2024-03-31, git: NonGNU ELPA's `elpa/yasnippet-snippets`; upstream master has
  directories for `c++-mode`, `c++-ts-mode`, `c-ts-mode`, `python-ts-mode`,
  `cmake-mode`, `latex-mode`, `bibtex-mode`, `markdown-mode`, ...; whether the 1.0
  release has the `-ts-mode` ones is not checked); `yasnippet-classic-snippets`
  (GNU ELPA 1.0.2, 2024-04-24, Noam Postavsky) with the set yasnippet once bundled.
  AUCTeX's `LaTeX-mode` has `latex-mode` among its parents (checked:
  `derived-mode-all-parents` gives `LaTeX-mode TeX-mode text-mode latex-mode
  tex-mode`), so `latex-mode` snippets are expected to apply there (not tried).
- **tempel** (GNU ELPA 1.14, 2026-07-05, Daniel Mendler, the author of consult,
  vertico, corfu): templates as Lisp data in Tempo's syntax, expanded through
  `completion-at-point` (corfu shows them); no LSP snippet expansion of its own:
  `eglot-tempel` (separate, not vendored here) lets eglot use it.
- **Built in:** `abbrev`, `skeleton`, `tempo`: own templates only; eglot does not
  use them for server snippets.

## 3. Fit with the config
- yasnippet: one GNU ELPA package (D-006 submodule from GNU ELPA's git, as AUCTeX,
  D-090), plus a collection if wanted (another submodule, MELPA or NonGNU). eglot
  turns snippet support on by itself once it is loaded; `yas-global-mode` or per
  mode. Placeholders interact with corfu's completion (TAB): order not checked.
- tempel: smaller, in the family the config already uses (consult, vertico, corfu);
  server snippets need eglot-tempel in addition.

## 4. Options (for O-45)
- (a) yasnippet for eglot's snippets (argument placeholders from clangd, environment
  templates from texlab), no collection; own snippets later.
- (b) (a) plus yasnippet-snippets for C++ and LaTeX templates.
- (c) tempel and eglot-tempel.
- (d) none.

## 5. Not checked
- yasnippet with corfu and TAB in this config; clangd's snippet completions through
  eglot with yasnippet.
- yasnippet-snippets 1.0's mode directories and its snippets in `LaTeX-mode`.

## 6. yasnippet against tempel (owner question 2026-10-14)
Sources: the projects' READMEs (github.com/joaotavora/yasnippet, github.com/minad/tempel,
github.com/fejfighter/eglot-tempel), MELPA's generated READMEs, NonGNU ELPA (404 for
eglot-tempel and tempel-collection), all read 2026-10-14; eglot 31.1's code.

- **package:** yasnippet: GNU ELPA 0.14.3 (2025-06-02). tempel: GNU ELPA 1.14
  (2026-07-05).
- **template format:** yasnippet: text files, TextMate-like (`$1`, `${2:x}`), one per
  snippet, a directory per mode. tempel: Lisp data, Tempo's elements (`p`, `(s name)`,
  `r`, `n`), one file of templates per mode group.
- **fields:** yasnippet: numbered, mirrors and transformations, embedded Lisp. tempel:
  placeholders, named fields that update each other, Lisp forms, `:pre` / `:post`.
- **expansion:** yasnippet: a key (TAB, `yas-expand`); listing snippets in
  `completion-at-point` needs an extra package (not checked which). tempel:
  `completion-at-point` (`tempel-complete`, `tempel-expand`): corfu lists templates like
  other candidates; `tempel-insert` by name.
- **servers' snippets (eglot):** yasnippet: built in: eglot 31.1 announces snippet
  support when yasnippet is loaded and expands with it. tempel: needs `eglot-tempel`
  (MELPA only), which patches eglot's yasnippet check and converts the server's snippet
  to tempel; "conflicts with yasnippet".
- **ready-made templates:** yasnippet: `yasnippet-snippets` (NonGNU ELPA 1.0; C++, C++
  ts, Python ts, LaTeX, CMake ...). tempel: `tempel-collection` (MELPA only; modes not
  listed in its README).
- **author / family:** yasnippet: repository joaotavora/yasnippet (Joao Tavora also
  wrote eglot), GNU ELPA's maintainer Noam Postavsky. tempel: Daniel Mendler (consult,
  vertico, corfu, cape, already vendored).
- **size:** yasnippet: large (snippet tables, menus). tempel: small ("small and simple
  packages").

What decides it here:
- The servers' snippets (clangd's argument placeholders, texlab's environments) work
  with yasnippet out of the box in eglot; with tempel they need eglot-tempel, a
  MELPA-only package (DESIGN 4 principle 2 puts MELPA last) that patches eglot.
- Own templates fit tempel better in this config: they complete through corfu
  like everything else, in Lisp; yasnippet's need a key or an extra capf package.
- Ready-made C++ and LaTeX templates: yasnippet-snippets (NonGNU ELPA); tempel's
  collection is MELPA only.
- Both together: eglot-tempel says it conflicts with yasnippet; tempel for own
  templates and yasnippet only for eglot's snippets (no eglot-tempel) would be two
  template systems.
- Not measured: load time of either (neither is vendored), TAB's interplay with
  corfu and indentation (`tab-always-indent`, D-020).

## 7. Keys: TAB or another (owner question 2026-10-14)
yasnippet 0.14.3's keys (its source, read 2026-10-14):
- `yas-minor-mode-map`: `TAB` is `yas-maybe-expand`, a conditional definition: it
  expands only when a snippet key is before point, otherwise TAB runs what it ran
  before (here indent or complete, D-020); `C-c & C-s` inserts a snippet by name,
  `C-c & C-n` / `C-c & C-v` make / visit one.
- `yas-keymap`, active only while a snippet's fields are being filled: `TAB` next
  field (or expand a nested snippet), `S-TAB` previous field, `C-g` abort, `C-d`
  clear the field, `DEL` clear it when at its start. Every one goes through
  `yas-keymap-disable-hook`, which can switch them off, e.g. while corfu's popup is
  open, so that TAB completes there.
- Snippets from the servers (clangd, texlab) need no expansion key: eglot expands
  them when a completion is chosen; only the field keys matter for them.
- Elsewhere: CLion's live templates expand with Tab after the abbreviation (Space or
  Enter selectable) and move with Tab / Shift+Tab; VS Code the same.

What the keys collide with here: TAB indents and, on an indented line, completes
(D-020, `tab-always-indent`); a snippet key typed by chance (`for`, `if`, `cls`)
would expand on TAB instead of completing. `M-n` / `M-p` move between cells in
Python and R (D-072).

Options (for D-095's done when):
- (k1) yasnippet's own: TAB expands a key before point, else indents / completes;
  TAB / S-TAB move between fields (CLion's and VS Code's way). Corfu's popup takes
  TAB while open (`yas-keymap-disable-hook`).
- (k2) Expansion on a key of its own, TAB / S-TAB only for fields: TAB never expands,
  so indent / complete stay as they are; e.g. `C-c y` (free in C++ and LaTeX
  buffers, checked), or `M-/` (`dabbrev-expand` there now).
- (k3) Expansion from the completion popup: snippet keys offered with the other
  candidates (`C-M-i` / TAB on an indented line), RET inserts; needs a small
  completion function or a package (`yasnippet-capf`, not checked); TAB / S-TAB for
  fields.
- (k4) No TAB at all: expansion as (k2), fields on other keys (e.g. `C-<return>` /
  `C-S-<return>`, free in C++ and LaTeX buffers; not `C-c C-n` / `C-c C-p`, AUCTeX's
  normal mode and preview prefix), TAB left entirely to indentation and completion.

