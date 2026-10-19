# 0079 - T-106: eglot finders with Emacs 31's xref

- **Date:** 2026-10-19
- **Commits:** see `git log --grep T-106` (the patch, the test and this entry)
- **Tier:** 2
- **Decisions:** D-117 (O-65 (a)), D-069, D-108
- **Done when:** patch 0003 after 0002 in `.gitmodules`, `make packages` applies 9
  patches; an ERT test runs `eglot-find-implementation`, `-declaration`,
  `-type-definition` and the old `eglot-find-typeDefinition` against clangd on a toy
  class hierarchy, with no prompt for the identifier, and fails without the patch;
  `init-lsp.el` names the new command; `make test`; the patch joins the upstream
  report (T-032).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner saw native-compiler warnings that eglot calls `xref-read-identifier` and
`xref-find-by-kind`. Upstream eglot rewrote its "find declaration / implementation /
type definition" commands on 2026-09-08 for a new xref in Emacs master; Emacs 31.1's
xref (1.7.0) has neither function, so since eglot was vendored (T-090) `C-c l i`,
`C-c l d` and the implementation click stopped with `void-function`. The rewrite also
renamed `eglot-find-typeDefinition`, which eglot's menu and our click still named.
Patch 0003 uses the new xref when it is there and otherwise does the same work with
functions xref 1.7.0 has.

## Concepts (Emacs Lisp) explained
- **`fboundp`** asks whether a function is defined, at run time; the patch takes the
  master path only when `xref-find-by-kind` exists. `with-no-warnings` keeps the
  compiler quiet about the calls it cannot see defined.
- **A fetcher.** `xref-show-xrefs` takes a function that returns the results when
  called, so the list can be refreshed (`g` in `*xref*`); the patch's fetcher goes
  back to the buffer and position of the call and asks the backend
  (`xref-backend-xrefs-by-kind`, the eglot method that maps a kind to an LSP request).
- **Dynamic binding of an option.** `(let ((xref-prompt-for-identifier nil)) ...)`
  changes the option only while the identifier is read. Its default makes every
  command but find-definitions prompt; the finders' docstring and Emacs 31's eglot
  prompt only with a prefix argument.
- **`defalias`** makes the old command name another name for the new one, so keys,
  menus and user code naming `eglot-find-typeDefinition` keep working.

## Key files walked
- `patches/eglot/0003-Find-declarations-implementations-type-definitions-w.patch` -
  `eglot--find-by-kind`, the `eglot--deffinder` macro calling it, the alias, the menu
  and command list naming the new command.
- `lisp/init-lsp.el` - `:commands` and `emacs-cpp-lsp-mouse-type-definition` name
  `eglot-find-type-definition`.
- `test/init-cpp-test.el` - `init-cpp-eglot-finders-with-emacs-31-xref`: a toy with
  `Shape` / `Square`, each finder run as a key would run it, `completing-read` made
  to fail so a prompt shows up as an error.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** `xref--read-identifier` (internal) stays in Emacs 31's xref. **Would
  break if:** a later xref drops it; then it has `xref-read-identifier` and
  `xref-find-by-kind`, and the patch takes that path. **DESIGN bet:** D-117.
- **Assumed:** a single result shows as Emacs 31's eglot showed it (through
  `xref-show-xrefs-function`, a list unless the user's settings jump). **Would break
  if:** the owner expects a jump for one result; that is `xref-auto-jump-to-first-xref`.
- **Risk:** the master path (`xref-find-by-kind`) is not exercised here; it is
  upstream's own code, unchanged.

## How to verify
- `make packages`: "9 patches in force".
- `make test`: 126 tests, 0 unexpected (Arch, 2026-10-19); without 0003 the new test
  fails with `(void-function xref-read-identifier)`.
- By hand: in a C++ buffer under eglot, `C-c l i` on a virtual call lists the
  overrides; `C-c l d` on a call goes to its declaration; no prompt; `C-u C-c l i`
  prompts.
