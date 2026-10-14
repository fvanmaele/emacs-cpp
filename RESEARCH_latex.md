# RESEARCH - LaTeX with a language server (texlab)

Question (owner, 2026-10-13): LaTeX support through a language server, texlab in
particular. Findings only; verdicts go to DESIGN.

Sources: texlab's README and wiki (Configuration, LSP Internals, Workspace commands,
Project Detection), Arch's package search and the AUR's JSON interface, MacPorts'
`port info`, all read 2026-10-13; hands-on on the Mac with the shipped config.

## 1. What is there today
- Emacs 31.1: the built-in `latex-mode` (tex-mode.el) for `.tex`, `bibtex-mode` for
  `.bib`; no tree-sitter LaTeX mode; AUCTeX is not vendored.
- eglot's default for `latex-mode`, `plain-tex-mode`, `context-mode`,
  `texinfo-mode`, `bibtex-mode`, `tex-mode`: digestif, else texlab
  (`eglot-alternatives`; without a prompt it takes the first found, digestif).
- The Mac: texlab 5.25.1 (MacPorts, installed); TeX Live 2026 under
  `/Library/TeX/texbin` (MacTeX, not MacPorts) with digestif, latexmk, chktex,
  latexindent, biber. Skim 1.7.17 installed by the owner 2026-10-13 (outside
  MacPorts).

## 2. Candidates and packaging
- **texlab** (Rust; MIT): Arch `extra/texlab` 5.25.1 (official), MacPorts `texlab`
  5.25.1; also AUR `texlab-bin` 5.26.0, GitHub binaries, cargo. Works on all files of
  the project without a TeX installation; building needs one (or Tectonic).
- **digestif** (Lua, ships with TeX Live): AUR `digestif` 0.6 on Arch, part of TeX Live
  on the Mac. Completion and help for commands and packages.
- **ltex-ls** (grammar and spelling via LanguageTool, Java): AUR only; not a LaTeX
  structure server; not looked at further.
- **Tectonic** (self-contained TeX engine): Arch `extra/tectonic` 0.17.0; texlab
  supports it as builder.
- PDF viewers with SyncTeX: Arch `extra/zathura`, `extra/okular`; MacPorts
  `zathura` 0.4.4. Skim (the macOS viewer) is not in MacPorts: MacPorts' `skim` 5.7.4
  is an unrelated fuzzy finder (corrected 2026-10-13); the owner installed Skim 1.7.17
  from its own download, `/Applications/Skim.app`.

## 3. texlab: protocol surface (wiki, 2026-10-13)
- Standard: completion, definition, references, rename, hover, document and
  workspace symbols, document highlight, document links, folding, formatting
  (latexindent by default, `texlab.latexFormatter`; BibTeX by texlab's own), inlay
  hints for label definitions and references, execute command.
- Custom requests: `textDocument/build` (runs `texlab.build.executable`, default
  `latexmk -pdf -interaction=nonstopmode -synctex=1 %f`) and
  `textDocument/forwardSearch` (runs `texlab.forwardSearch.executable` with `%f`,
  `%p`, `%l`); announced as experimental capabilities; eglot has no command for
  either.
- Workspace commands: `texlab.cleanAuxiliary`, `texlab.cleanArtifacts`,
  `texlab.changeEnvironment`, `texlab.findEnvironments`, `texlab.showDependencyGraph`,
  `texlab.cancelBuild`.
- Diagnostics: the build log, and chktex when `texlab.chktex.onOpenAndSave` /
  `onEdit` are set (both off by default).
- Settings arrive through `workspace/configuration` (eglot:
  `eglot-workspace-configuration`), e.g. `texlab.build.onSave`,
  `texlab.forwardSearch.*`.
- Project detection: walks up from the opened file loading the TeX files of each
  directory, follows `\input` / `\import`; the root document from `.texlabroot`,
  `Tectonic.toml`, `.latexmkrc` or the file with the `document` environment.

## 4. Hands-on (Mac, 2026-10-13)
Toy project: `main.tex` (`\input{chapters/intro}`, `\ref`, `\cite`, `\newcommand`,
`\bibliography{refs}`), `chapters/intro.tex` (section, labels), `refs.bib`; eglot on
`main.tex` in `latex-mode`, the server named explicitly.
- texlab: managed 29 - 368 ms after the visit. Definition of `\ref{sec:intro}` -> the
  label in `intro.tex` (not open), references -> both files, definition of
  `\cite{knuth1984}` -> `refs.bib`, of `\answer` -> its `\newcommand`, each about
  1 ms; hover on the citation shows "D. Knuth: "The TeXbook". Addison-Wesley,
  1984."; completion inside `\cite{}` offers `knuth1984`; workspace symbol `intro` ->
  "Introduction"; formatting through latexindent 0.1 - 1.1 s; `textDocument/build`
  ran latexmk, status 0, PDF written, 1.5 - 2.3 s.
- digestif 0.6 (TeX Live): managed 0.2 - 0.5 s; no definition for `\ref` or `\cite`
  across files, no hover or completion for the citation, no workspace symbols, no
  formatting ("Unknown method textDocument/formatting"); definition of `\answer` and
  references in the same file work.
- Forward search to Skim (2026-10-13): `texlab.forwardSearch.executable`
  `/Applications/Skim.app/Contents/SharedSupport/displayline`, args `-r -g %l %p
  %f`; after a build (SyncTeX written), `textDocument/forwardSearch` on line 6:
  status 0, Skim showed the line; 6.9 s at Skim's first start after installing,
  then 154 - 234 ms. The settings reach texlab only from the global or directory-local
  `eglot-workspace-configuration` (eglot reads it in the project's directory-local
  context); a buffer-local value gave status 3, "Unconfigured". Inverse search
  (Skim -> Emacs: Skim's Sync preset "Emacs", `emacsclient`, a running Emacs server)
  not tested.
- A colon in the project path breaks texlab's cross-file features: under `tex a:b`
  definition of `\ref` and `\cite`, hover and completion of the citation return
  nothing, while `tex a b`, `tex c++`, `tex x@y`, `tex (x)` work. eglot sends `:` as
  `%3A`; texlab apparently keeps two documents for the open file. `M-o`'s project
  symbols (D-085) are not affected: texlab's URI `tex%20a:b%20c++` matched.

## 5. How it would fit this config
- Mode: the built-in `latex-mode` suffices for eglot; AUCTeX (GNU ELPA) would add
  its own compile / view commands, folding and `preview-latex`, a large package
  (D-006 submodule) for which texlab covers navigation already.
- Server: texlab named explicitly in `eglot-server-programs`, as pyright (D-045),
  started for project files; packaged on both machines (D-053 holds on the Mac).
- Build: `C-c p c c` via projectile with `latexmk`, or a small command sending
  texlab's `textDocument/build` (eglot has none); `texlab.build.onSave` builds on
  save without a command.
- View: forward search through texlab (`texlab.forwardSearch.*`) to Skim on the
  Mac, zathura on Arch, both installed separately; inverse search needs the viewer
  to call `emacsclient`, so an Emacs server.
- `M-o`: texlab's workspace symbols (sections, labels, environments) would join `s`
  with no change (D-085).
- TeX Live itself on the Mac is MacTeX, not MacPorts (as R, O-39; D-053).

## 7. texlab against AUCTeX; build triggers (owner questions 2026-10-13)
**What texlab gives for writing** (hands-on, Mac): completion returns plain names,
no snippets (`begin` after `\beg`, `equation` inside `\begin{}`; no `\end{...}` added;
eglot would expand snippets only with yasnippet, not vendored); hover on `\alpha`
returns Markdown with the glyph as an embedded PNG (`texlab.hover.symbols` `image`),
not a rendered formula of the document, and eglot's help display is not expected to
show the image (not checked). No in-buffer preview, no insertion commands: those
are editor features, not language-server ones.

**Emacs's built-in `latex-mode`** (tex-mode.el): `C-c C-o` inserts an environment
(asks its name, adds `\begin` / `\end`), `C-c C-e` / `C-c ]` closes the open one,
`C-c {` braces, `C-c C-c` / `C-c C-f` / `C-c C-b` run TeX, `C-c C-v` views,
`C-c C-u` to the last unclosed block. No preview, no math shortcuts.

**AUCTeX** (GNU ELPA 14.2.0, 2026-09-15; features from its manual, not run here):
preview-latex renders formulas, figures and sections as images in the buffer
(needs gs, dvipng or dvisvgm and `preview.sty`: all present on the Mac, gs from
MacPorts, the rest from TeX Live); `TeX-fold-mode` folds macros and environments into
their text or glyph; `LaTeX-math-mode` (a prefix key, `` ` `` by default, then a
letter for a symbol); insertion with prompts: `C-c C-e` environments (labels,
captions), `C-c C-m` macros with their arguments, `C-c C-s` sectioning with a
label, `C-c C-f` fonts; `C-c C-c` runs what the document needs next (LaTeX, BibTeX,
view); `` C-c ` `` steps through errors with their help; SyncTeX forward and
inverse search with Skim / zathura; per-package style hooks (commands and
environments of loaded packages offered). RefTeX (part of Emacs) adds a table of
contents and label / citation selection in either mode. AUCTeX 14 changed its major
mode names (`LaTeX-mode` and others, no longer replacing the built-in
`latex-mode`): not verified here (Savannah timed out); eglot's server entry would
have to name AUCTeX's modes.

**AUCTeX and texlab together:** AUCTeX for writing (insertion prompts, math keys,
preview, folding, its compile / view / error keys), texlab for what AUCTeX does not
do across files: definitions and references of labels, citations and own commands
in other files, rename, workspace symbols (`M-o`), project-wide diagnostics. Both
offer completion, building, viewing and diagnostics, so each needs one owner: e.g.
completion from eglot first, building and viewing from AUCTeX's `C-c C-c` /
`C-c C-v`, texlab's build unused. Cost: a large submodule (D-006); its git tree has
generated files (`tex-site.el` and others from `.in` templates), so `make packages`
may need a step for it (not checked).

**Build triggers** (texlab's build request, measured on the Mac): a 217-page document
(lipsum) built in 3.7 s; during the build texlab answered every definition request
in under 1 ms, and eglot sends the build request asynchronously, so Emacs is not
blocked. On save (`texlab.build.onSave`): every save starts latexmk (CPU for the
length of a build, each time; diagnostics and the PDF refresh by themselves, Skim
reloads with `-r`); saves made mid-edit build documents with errors; whether a save
during a running build cancels or queues it is not measured (`texlab.cancelBuild`
exists). On a key: builds only when asked.

## 6. Not checked
- texlab on a large document (a thesis-sized project), memory and indexing time.
- chktex diagnostics through eglot (settings needed).
- Inverse search (Skim -> Emacs), and zathura on Arch.
- Arch: texlab and TeX Live there.

## 8. Keys like LyX's (owner question 2026-10-14)
LyX's bind files, current master, read from its Codeberg mirror 2026-10-14
(codeberg.org/LyX-org/lyx, `lib/bind/cua.bind` and `lib/bind/mac.bind`; LyX's own
git server no longer serves files, "due to massive AI bot abuse"):
- `cua.bind` (Linux, Windows): Ctrl+M math mode (inline); Ctrl+Shift+M display
  math; Ctrl+Alt+B bold (`font-bold`; Ctrl+B is `font-boldsymbol`); Ctrl+E
  emphasis; Ctrl+Shift+P typewriter; Ctrl+L TeX code (ERT); Ctrl+R view;
  Ctrl+Shift+R update (build); Ctrl+K deletes to the end of the line (the small
  capitals binding is commented out).
- `mac.bind`: its C- is Command, M- is Control (Qt's swap): Command+M math;
  Command+Shift+M display math; Command+B bold; Command+Ctrl+E emphasis;
  Command+Shift+P typewriter; Command+L TeX code; Command+R view; Command+Shift+R
  update.
- The LyX wiki ("Frequently used shortcuts", read 2026-10-14) adds: Alt+M F a
  fraction, Alt+M S a square root, Alt+M G and a letter a Greek letter, `^` / `_`
  super- / subscript, Ctrl+Alt+N numbered display math, Alt+P then Space the
  paragraph styles (sections, lists); label, reference and citation keys are not
  bound by default.

**Against AUCTeX** (`docs/CHEATSHEET-AUCTEX.md`): inline math has no key of its own
(`$` types it; `C-c C-e` `equation` / `displaymath` for display math); fonts are
`C-c C-f C-b` (bold), `C-c C-f C-e` (emph), `C-c C-f C-t` (typewriter); fractions,
roots and Greek letters by the math keys (`` ` `` then a letter, `C-c ~`); view
`C-c C-v`, build `C-c C-c` or `C-c l b`; no ERT (all of it is TeX code).

**Emacs's own keys in the way:** `C-m` is RET, `C-b` / `C-e` move backward / to the
end of the line, `C-k` kills, `C-l` recenters; LyX's Ctrl keys on Arch would take
them. On the Mac, Emacs.app binds most of LyX's Command keys itself (checked):
`s-m` minimizes the frame, `s-M` opens a man page, `s-e` searches for the last
kill, `s-k` kills the buffer, `s-l` goes to a line; `s-b` and `s-i` are free. LyX's
keys in `LaTeX-mode`'s own map would override those in LaTeX buffers only.

**Options (for O-46):** (a) LyX's Mac keys on Command in `LaTeX-mode` on the Mac only
(`s-m` inline math `\( \)`, `s-M` display math, `s-b` bold, `C-s-e` emphasis, `s-P`
typewriter, `s-r` view, `s-R` build), Arch keeping AUCTeX's; (b) the same set under a
prefix on both machines (e.g. `C-c l` letters free there); (c) AUCTeX's keys only.
