# 0075 - T-090: eglot vendored with the partial-watch patch

- **Date:** 2026-10-15
- **Commits:** see `git log --grep T-090` (the code and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-108 (O-60 (b)), D-111 (agreed); D-069 (fixes as patch files)
- **Done when:** submodule `eglot` (`lib/eglot`, github.com/emacs-straight/eglot,
  c79f727, `info = eglot.texi`, patch 0001); `make packages` with 7 patches; no
  startup check of where eglot comes from; tests: eglot from `lib/eglot`, pyright up
  with the cap at 5 on 20 directories (down without the patch), existing eglot tests
  pass; `make test` and startup on the Mac; Arch `make test` by the owner.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
eglot is part of Emacs, so it could not carry a local fix. When pyright asked to
watch more directories than eglot allows (500 on the Mac, D-054), eglot failed the
whole request and pyright exited (deal.II's step-1, O-59). Now eglot comes from a
git submodule, GNU ELPA's copy of Emacs master's eglot, with patch 0001: at the limit,
or when macOS refuses a watch, eglot keeps the watches it has, warns once and
answers the request successfully.

## Concepts (Emacs Lisp) explained
- **Shadowing a built-in package.** Emacs finds a library by walking `load-path`
  in order. `lib/load-path.el` (written by `make packages`) puts every `lib/`
  directory in front of Emacs's own, so `(require 'eglot)` loads
  `lib/eglot/eglot.elc`; the built-in autoloads name only the feature, so they
  land there too.
- **A submodule plus a patch file (D-069).** The submodule stays at the mirror's
  commit; `make packages` applies `patches/eglot/0001-...patch` to its working tree
  and byte-compiles it, so a fresh checkout gets the same eglot.

## Key files walked
- `.gitmodules` - the `eglot` entry with `ignore`, `info` and `patch`.
- `patches/eglot/0001-Keep-partial-file-watches-when-the-limit-is-reached-.patch` -
  `eglot--watch-globs`: a `full` flag stops adding watches at the limit or at a
  `file-notify-error`, with a warning, instead of `jsonrpc-error`.
- `test/init-lsp-test.el` - `init-lsp-eglot-vendored` (eglot's file under
  `lib/eglot`) and `init-lsp-eglot-keeps-partial-watches` (pyright alive after its
  registrations with `eglot-max-file-watches` 5; checked to fail with the patch
  reversed).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the mirror's eglot (newer than 31.1's, 182 lines apart outside the
  watch code) works with Emacs 31.1's bundled jsonrpc, flymake, eldoc, project and
  xref; their versions meet its requirements, and `make test` passes.
  **Would break if:** a later mirror commit needs newer ones; a pin bump shows it.
  **DESIGN bet:** D-108.
- **Assumed:** nothing loads eglot before `lib/load-path.el` runs. Checked: eglot is
  not loaded at startup at all. **Would break if:** an early-init file required it.
- **Risk:** with the cap reached pyright stays up but can end with no watches once it
  drops its first registrations (research 3.10); D-111 adopts shared watches (e) to
  close that, a later patch.
- **Risk:** two Eglot manuals in `C-h i` (Emacs's and this one).

## How to verify
- `make packages` reports 7 patches; `make test`.
- In Emacs: `M-: (symbol-file 'eglot--watch-globs)` names `lib/eglot/eglot.elc`.
- Arch (owner): `make packages && make test`.
