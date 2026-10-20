# 0092 - T-118: a project's library index reaches clangd

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-118"`
- **Tier:** 2
- **Decisions:** D-130, D-131 (as amended), D-133
- **Done when:** T-118's items 1 - 5 (agreed 2026-10-21); item 5 is the owner's hand
  check (H-14)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
deal.II is installed as headers and binaries only, so `M-.` on a deal.II function
lands on its declaration in `/usr/include`, and `M-?` misses its uses inside the
library. S10 showed that an offline index of deal.II's sources fixes both. Now:
`make library-index LIBRARY=dealii` builds that index into `indexes/` (D-133), a
project names the library in `.dir-locals.el`, and the clangd command gets
`--index-file` (D-130). Since clangd loads such an index only on its first query and
lets a non-index file pass silently, every failure is checked or watched for and
shown (D-131).

## Concepts (Emacs Lisp) explained
- **`defvar-local` with a `safe-local-variable` predicate:** a variable each buffer
  can hold its own value of, which `.dir-locals.el` may set without asking because the
  predicate (a list of symbols) says the value is harmless.
- **`user-error` inside the contact function:** the clangd command is computed by a
  function eglot calls; signalling there refuses to start clangd, and
  `emacs-cpp-presets-clangd-contact` turns the signal into an error-level warning
  (D-018), so a refusal is never only an echo-area line.
- **`jsonrpc-async-request` with `:success-fn`, `:error-fn`, `:timeout-fn`:** the
  probe asks clangd without blocking Emacs; each callback either stops, schedules the
  next try with `run-at-time`, or warns.
- **A buffer-local `after-change-functions` in clangd's stderr buffer:** jsonrpc
  inserts clangd's stderr there; the hook sees each new line, so "Can't open" is
  noticed the moment clangd prints it.

## Key files walked
- `lisp/emacs-cpp-library-index.el` (NEW): `emacs-cpp-library-index-check` (the checks
  before start), `emacs-cpp-library-index-on-connect` (probe and stderr watch).
- `lisp/emacs-cpp-presets.el`: `emacs-cpp-presets--clangd-command` adds the flag.
- `lisp/init-cpp.el`: the `eglot-connect-hook` entry.
- `lisp/defaults-*.el`: `emacs-cpp-default-library-include-dir` (Mac: nil, UNVERIFIED
  where deal.II.app's headers lie).
- `scripts/build-library-index.sh` (NEW), Makefile `library-index`.
- `packaging/clangd-index-nav`: pkgrel 10 with `clangd-indexer` (D-133).
- `test/emacs-cpp-library-index-test.el` (NEW): five tests, every diagnostic.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** `n_active_cells` stays a symbol whose definition lies in deal.II's
  sources. **Would break if:** a release moves it inline into a header; the probe then
  never finds a result in the sources and warns falsely. **DESIGN bet:** D-131.
- **Assumed:** clangd keeps loading `--index-file` lazily and reading non-RIFF files
  as YAML. **Would break if:** a release changes either; the probe still reports
  success or failure correctly, only the RIFF check may become redundant.
  **DESIGN bet:** D-131.
- **Assumed:** the buffer that starts eglot has its directory-local variables applied
  (eglot connects from `post-command-hook`, after `hack-local-variables`). **Would
  break if:** a buffer starts eglot before its local variables are in; clangd then
  starts without the index, silently. The e2e run below saw `(dealii)` in the buffer.

## How to verify
`make test` (141 tests on Arch). End to end, done here on the S10 copy of RMO with the
shipped config (scratchpad script, not kept): `M-.` on `n_active_cells` 2 s after
opening lands in `indexes/dealii-9.8.0/source/grid/tria.cc:15874` with the system
clangd (7.6 s, its parse) and with the patched one (0.0 s); immediately after opening
the patched one gives the declaration (D-131's accepted window); no warning in any
run. The owner's hand check on RMO itself: H-14.
