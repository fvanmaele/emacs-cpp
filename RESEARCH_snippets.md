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
