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
  latexindent, biber. No PDF viewer with SyncTeX installed.

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
- PDF viewers with SyncTeX: Arch `extra/zathura`, `extra/okular`; MacPorts `skim`
  5.7.4, `zathura` 0.4.4.

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

## 6. Not checked
- texlab on a large document (a thesis-sized project), memory and indexing time.
- chktex diagnostics through eglot (settings needed).
- Forward / inverse search with a real viewer.
- Arch: texlab and TeX Live there.
