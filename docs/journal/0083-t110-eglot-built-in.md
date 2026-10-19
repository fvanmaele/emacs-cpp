# 0083 - T-110: Emacs's own eglot, macOS watch advice

- **Date:** 2026-10-20
- **Commits:** see `git log --grep T-110` (the code, the tests and this entry)
- **Tier:** 2
- **Decisions:** D-121 (O-69 (c) + (d)); supersedes D-108, D-117
- **Done when:** submodule `lib/eglot` and `patches/eglot/0001 - 0003` removed,
  `make packages` 33 packages, 6 patches, 9 manuals, both machines on Emacs 31.1's
  eglot 1.24.31 with its manual listed once; `lisp/emacs-cpp-eglot-watch.el` (NEW),
  loaded from init-lsp's eglot form on macOS only, carrying 0001 / 0002 as advice and
  refusing loudly at load for any eglot but 1.24.31; init-lsp's type-definition
  click on `eglot-find-typeDefinition`; tests: the module off on Arch, the shipped
  profile on the built-in eglot, 0001 / 0002's tests with the advice switched on (on
  Arch too), the finders with built-in names; `make test` on Arch, the Mac's by the
  owner; docs.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
From 2026-10-15 the config carried its own copy of eglot (GNU ELPA's development
version) for two file-watch fixes; that copy then needed Emacs master's xref, which
cost a third patch (`RESEARCH_eglot_fork.md`). The owner chose to drop the copy: both
machines now load the eglot Emacs 31.1 ships, and the two watch fixes, which only
macOS needs (one file descriptor per watched directory), live in a config file
loaded on the Mac. While building it turned out that Arch needs a setting too: with
the stock eglot, pyright's watch of Python's library (6358 directories) passed
eglot's limit and pyright exited, so both platforms now watch only the project.

## Concepts (Emacs Lisp) explained
- **Advice.** `advice-add` wraps or replaces a function without editing its file:
  `:override` replaces `eglot--watch-globs` and `eglot--count-file-watches`, `:around`
  wraps `eglot-unregister-capability` (and passes everything but file watches through
  unchanged), `:before` runs ahead of `eglot--on-shutdown`. `advice-remove` takes it
  back, which the tests use to switch the fixes on and off on Arch.
- **Advice on a generic function.** `eglot-unregister-capability` is a
  `cl-defgeneric`; advice wraps the whole dispatcher, so the wrapper checks the
  method name itself.
- **A weak hash table.** The shared watches are kept per server in a table whose
  keys are weak (`:weakness 'key`): a server that is gone and no longer referenced
  disappears from it by itself; nothing had to be added to eglot's server class.
- **Version pinning by the library header.** Emacs 31.1's eglot has no version
  variable; `lm-version` reads the `Version:` line of `eglot.el.gz`.
  `emacs-cpp-eglot-watch-enable` signals an error unless it says 1.24.31, so an Emacs
  update stops at startup with the reason instead of running the advice on code it
  was not written for.

## Key files walked
- `lisp/emacs-cpp-eglot-watch.el` - the advice; `emacs-cpp-eglot-watch-enable`,
  `-disable`.
- `lisp/init-lsp.el` - project-only watches on both platforms; on macOS the cap of
  500 and the advice; `eglot-find-typeDefinition` again.
- `lisp/init-ui.el` - comment: no manual Emacs ships is vendored any more.
- `.gitmodules`, `patches/eglot/` - eglot gone.
- `test/init-lsp-test.el`, `test/init-ui-test.el`, `test/init-cpp-test.el`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the advised internals of eglot 1.24.31 stay as they are within Emacs
  31.x. **Would break if:** a 31.x release changes eglot's version; the advice then
  refuses at startup on the Mac, and must be checked and re-pinned. **DESIGN bet:**
  D-121.
- **Assumed:** project-only watches are enough for Python. **Would break if:** the
  owner edits installed packages and expects pyright to notice without a restart.
- **Risk:** the Mac's `make test` has not run with this change.
- **Risk:** the research's "Arch unaffected" was wrong (it counted project
  directories only); found by `make test` before the commit, corrected in
  RESEARCH_eglot_fork 7.

## How to verify
- `make packages`: 33 packages, 6 patches, 9 manuals.
- `make test`: 133 tests, 0 unexpected (Arch, 2026-10-20); with
  `emacs-cpp-eglot-watch-enable` stubbed out, both watch tests fail.
- Mac (owner): `make test`; `M-x eglot` in a large Python tree stays up, with the cap
  warning.
