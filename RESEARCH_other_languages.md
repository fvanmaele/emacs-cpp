# RESEARCH - Python, R and Perl next to the C++ setup

Question (owner, 2026-10-08): which modes for Python, R and Perl, and do they conflict
with the current C++ keys and settings? Findings only; verdicts go to DESIGN (O-19,
O-20). Checked on the owner machine against Emacs 31.1, the shipped configuration at
1e2ab29 and the local package database (`pacman -Ss`, no network); ESS is not
installed, so its rows are from its documentation as remembered, not checked.

Scope reminder (DESIGN 2): other languages "may ride along, never drive design". So
the question is what each language needs to work at all, and what the C++ setup must
not break for it.

## 1. What exists per language
Python:
- modes `python-mode`, `python-ts-mode` (built in); tree-sitter grammar not installed,
  packaged as `extra/tree-sitter-python` 0.25.0; Python 3.14.7.
- eglot's default servers, first one found: pylsp, basedpyright, pyright, ruff,
  jedi-language-server and others. None installed; packaged: `extra/pyright`
  1.1.412, `extra/python-lsp-server` 1.15.0, `extra/ruff` 0.16.10.
- debugger: dape ships a `debugpy` config; `extra/python-debugpy` 1.8.22, not installed.
- built-in checker: flymake's `python-flymake` runs `pyflakes`, not installed, so the
  backend reports itself disabled.

R:
- no mode built in; ESS (`ess-r-mode`, NonGNU ELPA / MELPA) is not vendored. R 4.6.1.
- eglot's default server for `ess-r-mode`: `R -e languageserver::run()`; the
  `languageserver` R package is not installed (CRAN, not packaged).
- debugger: none in dape.

Perl:
- modes `perl-mode`, `cperl-mode` (built in); no `perl-ts-mode` in Emacs 31; perl
  5.42.2.
- eglot's default server: `perl -MPerl::LanguageServer`; not installed (CPAN, not
  packaged).
- debugger: `Perl::LanguageServer` also speaks DAP; dape has no config for it.
- built-in checker: flymake's `perl-flymake` (`perl -c`) in `perl-mode`.

## 2. Where the C++ setup touches other languages
Checked in the shipped profile unless noted.
- **Hooks are C/C++ only.** eglot starts from `c++-ts-mode-hook` (D-005, D-019);
  breadcrumb and dape's gutter clicks from `c-ts-base-mode-hook` (D-036, D-043). Python,
  R and Perl buffers get none of them: no automatic eglot, no header line, no
  fringe-click breakpoints. `M-x eglot` works by hand.
- **eglot settings are global** and harmless for other servers:
  `eglot-events-buffer-config` size 0, `eglot-autoshutdown` t, `eglot-extend-to-xref` t
  (a library file reached by `M-.` joins the project's server, as for C++).
- **`C-c l` is global** (T-007): its eglot commands work with any eglot server; `P`
  (preset) refuses loudly outside a CMake preset project; `o` (projectile other file)
  works for any language. None of `python-mode-map`, `cperl-mode-map`, `perl-mode-map`
  binds `C-c l`, `C-c p`, `C-c t` or `C-x C-r` (checked). `C-c` + letter is reserved
  for users by Emacs's key conventions, which ESS follows as far as remembered.
- **`C-x C-a` is shared with gud** (checked in gud.el): loading gud, which `M-x pdb`,
  `M-x perldb` and `M-x gdb` do, runs `(global-set-key gud-key-prefix gud-global-map)`
  with the default prefix `C-x C-a`. From then on dape's keys (D-036, D-037) are gone
  for the session. It concerns C++ too (`M-x gdb`).
- **TAB** completes after indenting (`tab-always-indent` `complete`, D-020). In
  Python, TAB on an already indented line completes as in C++; pressed again it
  cycles the indentation levels (`python-indent-line`), as Python users expect. Not
  tested.
- **Projectile** only has its `cmake` project type changed (D-035). Python and R
  projects keep projectile's own commands; a repository with both `CMakeLists.txt`
  and `pyproject.toml` is typed by projectile's precedence (not checked which wins).
- **diff-hl** (D-042) and **recentf** (D-041) apply to every file: wanted.
- **`.h` is C++** (D-008) and `major-mode-remap-alist` remaps only `c++-mode`; nothing
  else is remapped, so `.py` stays `python-mode` while the Python grammar is missing.

## 3. Options (PROPOSED, for O-19)
Per language three levels: (a) mode only, (b) plus a language server through eglot,
(c) plus a debugger through dape.
- **Python** (all from the Arch repositories, no new submodule):
  (a) install `tree-sitter-python`, remap `python-mode` to `python-ts-mode`;
  (b) `pyright` (types, navigation) or `python-lsp-server` + `ruff` (lint, format),
  started by `eglot-ensure` from `python-ts-mode-hook` in projects only;
  (c) `python-debugpy` and dape's `debugpy` config as it ships.
- **Perl**: (a) `cperl-mode` for `.pl` / `.pm` (remap `perl-mode`, built in);
  (b) `Perl::LanguageServer` from CPAN (outside pacman; a new dependency on the
  system) or perlnavigator (npm); (c) only with `Perl::LanguageServer`.
- **R**: (a) ESS as a new submodule (network, D-014; it brings its own REPL and
  keys); (b) the `languageserver` package from CRAN; (c) nothing usable in dape.
- **gud prefix (O-20)**: set `gud-key-prefix` to another key before gud loads, so
  pdb, perldb and `M-x gdb` keep working without taking dape's prefix. Unbound in the
  shipped profile (checked, magit loaded): `C-x M-a`, `C-x M-d`, `C-x C-y`. Not
  `C-x C-g`: `C-g` inside a key sequence is how a prefix is cancelled.

## 4. Not checked
- ESS's keys and its interplay with corfu and eglot (not installed).
- Which projectile type wins in a mixed CMake / Python repository.
- pyright versus pylsp on the owner's Python code (real data).
