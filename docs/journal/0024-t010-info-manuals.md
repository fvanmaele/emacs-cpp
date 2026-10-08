# 0024 - T-010: package manuals in `C-h i`

- **Date:** 2026-10-08
- **Commits:** see `git log -- scripts/build-packages.el .gitmodules`
- **Tier:** 2
- **Decisions:** D-039
- **Done when:** `C-h i` lists magit, projectile (TASKS). Amended by the owner
  2026-10-08: the manuals the packages ship as Texinfo; projectile ships none.
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
Packages installed through package.el come with their manuals in `C-h i`; ours come
from git submodules and had none. `make packages` now also turns each package's
Texinfo source into an Info file in `lib/info/` and writes the `dir` index there;
`C-h i` reads that directory next to Emacs's own. Six manuals: magit, magit-section,
with-editor, embark, orderless and dash.

Projectile's manual is a website written in AsciiDoc. A conversion with pandoc worked
(21 chapters), but links between its pages were lost and it adds a build tool; the
owner chose the shipped manuals only. The same goes for the packages whose manual is
an Org README (vertico, consult, corfu, cape, marginalia, dape, treemacs), which GNU
ELPA converts with Org's exporter.

## Concepts explained
- **Texinfo, makeinfo, Info:** Texinfo is the GNU manual format; `makeinfo` turns a
  `.texi` file into an `.info` file that Emacs's reader shows. `install-info` adds the
  manual's entry (from its `@direntry`) to a `dir` file, the table of contents that
  `C-h i` opens.
- **`Info-additional-directory-list`:** directories Emacs searches after the standard
  ones; each `dir` found there is merged into the top menu.
- **The `info` key in `.gitmodules`:** like `load-path` and `build-exclude`, an extra
  key git ignores and the build script reads, so each manual is listed by hand next
  to its package.

## Key files walked
- `scripts/build-packages.el` - `build-packages-write-info` empties `lib/info/`, runs
  makeinfo and install-info per listed manual; `build-packages--run` turns a missing
  program or a failure into an error.
- `lisp/init-ui.el` - the `info` form adds `lib/info` and refuses if its `dir` is
  missing (packages built before this change).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the `.texi` files in the submodules match their pinned code (magit,
  embark and orderless commit them next to the source). **Would break if:** a package
  stops committing its `.texi`; the build then fails with "info ... does not exist".
- **Risk:** makeinfo warnings (commas in node names in embark and orderless) are let
  through, as third-party byte-compile warnings are.

## How to verify
`make packages` ends with "6 manuals"; `C-h i` shows Magit, Embark, Orderless, Dash,
With-Editor, Magit-Section; `make test` (34 tests).
