# 0061 - T-065: LaTeX with AUCTeX from GNU ELPA and texlab; init-lsp.el

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lib/auctex`, `.gitmodules`,
  `patches/auctex/0001-...`, `scripts/build-packages.el`, `lisp/init-lsp.el` (new),
  `lisp/init-latex.el` (new), `lisp/init-cpp.el`, `lisp/init-python.el`,
  `lisp/defaults-*.el`, `init.el`, tests, README, CHEATSHEET)
- **Tier:** 2
- **Decisions:** D-090 (built here), D-091 (owner, during the work), O-42 (b)
- **Done when:** AUCTeX 14.2.0 as a submodule from GNU ELPA's git (pinned to the
  14.2.0 commit), built by `make packages` with its manual, one `use-package` form;
  `.tex` opens in AUCTeX's `LaTeX-mode`; texlab through eglot for `LaTeX-mode` /
  `bibtex-mode` files of a project, named explicitly; `C-c l b` builds through texlab
  (asynchronous, status in the echo area) and shows the line in the viewer (Skim on
  macOS, zathura on Arch); AUCTeX's keys unchanged; tests: mode, eglot program,
  build request and its report, viewer per platform; hand-on check on the Mac;
  `make test`; owner's hand check; zathura on Arch by the owner.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner chose both LaTeX tools (O-42 (b)): AUCTeX for writing (insertion prompts,
math keys, formula preview in the buffer, folding) and texlab for what AUCTeX does
not do across files (definitions and references of labels, citations and own
commands in other files, rename, symbols for `M-o`). Builds go through texlab on a
key, `C-c l b`, which runs latexmk in the background and afterwards shows the line
in the PDF viewer. AUCTeX comes from GNU ELPA, as asked: GNU ELPA keeps every
package on a branch of one git repository, and that branch already has the files
AUCTeX's own build would generate, so `make packages` compiles it like any other
package. During the work the owner asked to keep LaTeX out of `init-cpp.el`; eglot's
one configuration moved to a new `init-lsp.el`, and each language now names its own
server (D-091).

## Concepts explained
- **One git repository for all of GNU ELPA:** the submodule points at
  `elpa.git`, branch `externals/auctex`. A plain clone of a submodule fetches every
  branch (629 MB); `shallow = true` in `.gitmodules` cuts a `--recurse-submodules`
  clone to 217 MB, and `git submodule update --init --single-branch` fetches only
  AUCTeX's branch (17 MB). All other pins were checked to be reachable from their
  default branch, so `--single-branch` is safe for every submodule.
- **Generated files as a patch (D-069):** AUCTeX's manuals include `version.texi`
  and `preview-dtxdoc.texi`, which its makefile writes; the patch adds both, as
  generated at the release, so `makeinfo` builds `auctex.info` and
  `preview-latex.info`.
- **Files that must not load:** `lpath.el` sets AUCTeX's directories to "<none>"
  and exists only for AUCTeX's own installation; it is excluded from the build.
  `style/` (AUCTeX's per-package support) is not put on `load-path`: six of its files
  are named like Emacs libraries (`url`, `color`, ...) and would hide them.
- **Mode remapping:** AUCTeX's `tex-site.el`, loaded through the generated autoloads
  at startup, tells Emacs that its built-in `latex-mode` means AUCTeX's
  `LaTeX-mode` (`major-mode-remap-defaults`).
- **Registering a server (D-091):** `emacs-cpp-lsp-server` and
  `emacs-cpp-lsp-settings` (init-lsp.el) add a language's entry and settings to
  eglot when it loads; the languages call them, eglot's own options stay in its one
  form.

## Key files walked
- `lisp/init-lsp.el` - eglot's form, the two registration helpers, the generic
  `C-c l` map.
- `lisp/init-latex.el` - texlab's registration and settings (forward search after a
  build to `emacs-cpp-default-pdf-viewer`), `emacs-cpp-latex-build` on `C-c l b`,
  the `tex` and `bibtex` forms starting eglot in project files.
- `lisp/init-cpp.el`, `lisp/init-python.el` - clangd and pyright registered the
  same way; `o` and `P` added to the map by init-cpp.
- `test/init-latex-test.el` - modes, eglot's program, the viewer settings, the build
  request (stubbed) and its report.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** GNU ELPA keeps generating AUCTeX's Lisp into its branch. **Would break
  if:** a later pin lacks them; `make packages` then fails loudly (missing
  `tex-site.el`). **DESIGN bet:** D-090.
- **Assumed:** Savannah serves a pinned commit to a shallow clone (checked
  2026-10-13). **Would break if:** it stops; `--single-branch` without `shallow`
  still works.
- **Assumed:** texlab's forward search arguments for zathura (`--synctex-forward
  %l:1:%f %p`) as texlab documents them; not run on Arch.
- **Risk:** AUCTeX and texlab both complete; eglot's completion comes first in
  `completion-at-point-functions`. Not tuned.

## How to verify
- `make packages`: 31 packages, 4 patches, 213 files, 9 manuals. `make test`: 93
  tests (2 skipped).
- Done here (Mac, shipped config, batch): `main.tex` opens in `LaTeX-mode`, texlab
  starts; `M-.` on `\ref{sec:intro}` lands in `intro.tex` line 1; `C-c l b` reports
  "done" (0.3 - 2.6 s) and writes the PDF; texlab then ran the viewer with
  `-r -g 6 main.pdf main.tex` (line 6, logged through a wrapper); pyright and clangd
  still start through the new registration.
- Owner: a `.tex` file of a project: `C-c l b`, Skim shows the line; `C-c C-p C-p`
  on a formula previews it. On Arch: the same with zathura.
