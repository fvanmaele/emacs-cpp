# RESEARCH - R language servers

Question (owner, 2026-10-13): which language servers exist for R, and what would
one give this config next to ESS (D-072, which has none)? Findings only; verdicts go
to DESIGN.

Sources: the projects' pages and releases, CRAN, the AUR's JSON interface, all read
2026-10-13; hands-on on the Mac with the shipped config (eglot, ESS v25.01.0),
`languageserver` 0.3.18 already installed there. Arity, Air and Ark not run.

## 1. Candidates
- **languageserver** (REditorSupport): an R package that runs in an R process. 0.3.20
  on CRAN, 2026-09-24. LSP: completion, hover, signature, definition, references,
  rename, document and workspace symbols, formatting (styler), diagnostics (lintr),
  code actions, folding, call and type hierarchy, semantic tokens. Needs R and about
  a dozen CRAN packages (lintr, styler, roxygen2, xml2, callr ...). Arch: AUR
  `r-languageserver` 0.3.20. MacPorts: none; CRAN `install.packages`. eglot's default
  contact for `ess-r-mode`: `R --slave -e languageserver::run()`. MIT.
- **Arity** (jolars): standalone, Rust, no R needed (export names of 500+ packages
  bundled). GitHub v0.25.0 2026-10-05, AUR 0.26.0. LSP: formatting, diagnostics with
  fixes, hover, completion, signature, definition, references, rename, document and
  workspace symbols, semantic tokens, folding, call hierarchy. Arch: AUR `arity`,
  `arity-bin`. MacPorts: none; GitHub binaries, cargo, npm, PyPI, a Homebrew tap,
  nixpkgs. Emacs not mentioned. MIT.
- **Air** (Posit): formatter and language server, Rust, no R needed. 0.12.0,
  2026-10-01. LSP: formatting only today; Posit plans to move Ark's LSP features
  into it. Arch: AUR `r-air`, `r-air-bin`. MacPorts: none; GitHub binaries, an
  installer script, PyPI `air-formatter`, Homebrew. eglot: `("air"
  "language-server")` for `ess-r-mode` (Air's Emacs page). MIT.
- **Ark** (Posit): an R kernel for Jupyter with LSP and DAP; "The LSP and DAP
  features are currently only available in Positron". GitHub zip, unsigned on
  macOS. Arch, MacPorts: none. MIT.

No R language server is in Arch's official repositories or in MacPorts; every
choice is a new dependency from outside pacman / MacPorts (D-053), as when D-072
was ruled.

## 2. Hands-on: languageserver 0.3.18, Mac (2026-10-13)
Toy projects under scratch, eglot started on `R/main.R` with eglot's default contact,
the shipped config otherwise.
- Start: managed 0.8 - 2.0 s after the visit (an R process starts).
- Capabilities announced: hover, completion, signature help, definition,
  references, highlight, document and workspace symbols, code actions, formatting
  (document, range, on-type), rename, links, colors, folding, selection ranges,
  call and type hierarchy, semantic tokens.
- **An R package** (a `DESCRIPTION` file at the root): files under `R/` are indexed
  without being open. `answer_value` used in `main.R`, defined in `utils.R`:
  definition 30 ms, references 55 ms (both files), hover with the function, workspace
  symbol `answ` 16 ms (2 symbols).
- **A plain script project** (no `DESCRIPTION`): only open files are known; definition,
  references, hover and workspace symbols across files return nothing until
  `utils.R` is open, then definition 70 ms, symbols 16 ms. `source("R/utils.R")` is
  not followed.
- Diagnostics: lintr's, per open file ("Use one of <-, <<- for assignment, not =.",
  "Variable and function name style should match snake_case or symbols.").
- URIs: escapes the space and little else; `r a:b c++` came back as
  `r%20a:b%20c++`, a fourth spelling next to eglot's, clangd's and pyright's: D-083's
  three prefixes would not match it (see `RESEARCH_go_to_anything.md` 11).

## 3. What ESS already gives without a server
Through the running R process (`lib/ess/lisp`): completion of objects and packages
(`ess-r-object-completion`, `ess-r-package-completion` in
`completion-at-point-functions`), definitions of loaded functions (`ess-r-xref-backend`
in `xref-backend-functions`), eldoc, and debugging (`ess-tracebug`). Only what the
session has loaded; nothing static across the project. ESS's own lintr flymake is
off (D-072).

## 4. How each would fit this config
- **languageserver:** eglot's default contact works as is; `ess-r-mode` would start it
  like pyright (`emacs-cpp-python-eglot-ensure`'s pattern). Cross-file features need
  the project to be a package; scripts get open-file features only. Needs R plus
  about a dozen CRAN packages on both machines (on the Mac already there; on Arch
  the AUR package or `install.packages`). Its lintr diagnostics overlap with ESS's
  flymake, which is off.
- **Arity:** one binary, no R; the only standalone server with navigation. Pre-1.0,
  releases every two to three weeks. Not run here: whether it knows the project's
  own functions across script files without a `DESCRIPTION` is not documented.
- **Air:** formatting only; would sit next to another server or replace styler.
- **Ark:** not usable from eglot today.
- `M-o` symbols (D-082, D-083) would need R's URI spelling, or a matcher that does
  not depend on spellings (`RESEARCH_go_to_anything.md` 11).

## 5. Found on the way
- The Mac's R is CRAN's `R.framework` (`/usr/local/bin/R` ->
  `/Library/Frameworks/R.framework/...`, R 4.5.2), not MacPorts' port as D-072 and
  `lisp/init-r.el` say; MacPorts has no `R` installed (`/opt/local/bin/R` missing).
  D-053 says MacPorts only.
- Installed there in R's system library: `languageserver` 0.3.18, `lintr` 3.3.0.1,
  `styler` 1.11.0.

## 6. Not checked
- Arity, Air and Ark run by hand (each a download outside MacPorts / pacman).
- Arch: the AUR packages built or used (2026-10-21: counted, not built; section 7).
- languageserver on a large R package (indexing time, memory).

## 7. Arch, 2026-10-21 (owner: "verify aur r-languageserver")
- The AUR page itself answers bots with a check page (Anubis); the AUR's JSON
  interface (`/rpc/v5/info`) answered. `r-languageserver` 0.3.20-1, the CRAN
  release of 2026-09-24, maintainer BioArchLinuxBot, last changed 2026-09-24, not
  flagged, 3 votes, popularity 0, MIT.
- Its dependencies, followed through the AUR to the end: 48 AUR packages in all
  (itself included); from pacman's repositories only `r`, cmake, git, icu, libuv,
  libxml2, zlib and a few libraries. Of the 48, two are orphaned (`r-remotes`,
  `r-withr`) and two flagged out of date (`r-rex` since 2026-05-02, `r-withr` since
  2026-07-18). So the AUR route is 48 builds, each updated by hand with the AUR.
- Meanwhile the owner installed languageserver 0.3.20 with `install.packages` into
  R's user library (`~/R/x86_64-pc-linux-gnu-library/4.6`, built 2026-10-21 03:13
  UTC, 118 packages there): it loads, and `R --slave -e languageserver::run()`
  answers `initialize` in 1.08 s with definition, references, rename, workspace
  symbols, hover, completion, formatting, call and type hierarchy among its
  capabilities (a stdio check from Python; not yet through eglot).

