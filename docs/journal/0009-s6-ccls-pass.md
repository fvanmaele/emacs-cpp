# 0009 - S6 PASS: ccls answers from its disk index

- **Date:** 2026-10-08
- **Commits:** see `git log -- spikes/s6-ccls` (committed with this)
- **Tier:** 3 (spike S6)
- **Decisions:** none yet (O-8 for the owner)
- **Done when:** RESULTS.md carries a verdict
- **Tag:** none

> Plain English. No configuration code changed.

## What + why
With clangd, every file waits 7 - 13 s before its first `M-.` in a session, and the
owner ruled out keeping extra files open to hide it (D-021). ccls, another language
server built on clang, stores for every file where each name points, on disk. On RMO
a freshly started ccls answered `M-.` 1.2 s after starting, for any file, and a
header opened first showed no false errors. The price: the first indexing of a build
directory takes about two minutes, ccls has no clang-tidy, and it lacks clangd's
refactorings, type hierarchy and inlay hints. A message ccls sends that eglot rejects
was traced to a deviation from the LSP specification with no practical effect.

## Concepts explained
- **Answer from disk vs answer from a parse:** clangd must parse the open file before
  it knows what is under the cursor; ccls looks it up in the per-file index it saved
  when it indexed the project, as long as the file has not changed since.
- **One server per buffer:** eglot attaches exactly one language server to a buffer,
  so "ccls for navigation, clangd for clang-tidy" cannot both run through eglot; a
  hybrid would run clang-tidy as a separate flymake checker.

## Key files walked
- `spikes/s6-ccls/RESULTS.md` - numbers, capability comparison, the timer-error cause.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO is representative of the owner's projects. **Would break if:** a
  deal.II-sized project makes ccls's first indexing or cache impractical (D-010).
- **Risk:** ccls is maintained far less actively than clangd; future clang versions
  may break it.
- **Risk:** during the first indexing of a build directory (about two minutes on
  RMO), `M-.` is refused.

## How to verify
Read `spikes/s6-ccls/RESULTS.md` and `results-run1.log`.

## Open questions
O-8: the owner's choice between ccls, clangd and a hybrid.
