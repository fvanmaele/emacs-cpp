# 0056 - T-060: `M-o` symbols: the project's, all on `l`

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`)
- **Tier:** 2
- **Decisions:** D-082 (built here), O-37, S11 run 5 (T-059)
- **Done when:** `s` asks clangd with limit 0 and lists only symbols whose URI is
  under the project root (as projectile gives it or its true name); hidden `l` ("All
  Symbols") lists clangd's best 100 of everything, as `s` did; `C-c l s` unchanged;
  tests for the request's parameters and filter, the sources and keys; `make test`;
  owner's hand check: `M-o` `opt` and `< l` in step-1.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
clangd's index holds every symbol the project's files see: deal.II's, Boost's, the
standard library's. Asked for symbols matching `opt`, it returns its best 100 by name
match and how much each is used, wherever they are defined, so in the owner's
project `opt` showed 12 of the project's 66 matching symbols. CLion's Symbols tab
shows the project's alone unless "Include non-project items" is ticked. Now `M-o`
does the same: the `s` source asks clangd for every match (a clangd extension of
the LSP request, `limit` 0) and keeps those whose file lies under the project root.
S11 run 5 measured that this loses nothing and that the slowest reply took 15.9 ms.
The previous behaviour is on `< l` ("All Symbols"); `C-c l s` keeps it too.

## Concepts explained
- **URIs, not file names:** clangd names each symbol's file as a `file://` URI. The
  filter compares the start of that string with the project root's URI, a plain
  string test, so 2458 symbols cost no file system calls (S11 run 5's harness
  resolved each file instead). The root's URI ends in `/`, so `step-1-old/` is not
  taken for `step-1/`.
- **Two spellings of the root:** `eglot-path-to-uri` resolves symlinks unless told
  the path is already resolved (`:truenamep t`). clangd's URIs follow the paths in
  the compilation database, resolved or not, so both the root as projectile gives it
  and its true name are accepted.
- **Hidden source:** consult's `:hidden t` keeps a source out of the list until its
  narrow key is pressed; with D-079's patch it sends clangd nothing until then.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-go--root-uris`, `emacs-cpp-go--under-root-p`;
  `emacs-cpp-go--symbol-request` takes the root URIs (then `:limit 0` and the
  filter); `emacs-cpp-go--symbol-sources` returns `s` and `l` (only `s`, unfiltered,
  when there is no project root); `emacs-cpp-go--symbol-source` builds either.
- `test/init-completion-test.el` - `init-completion-go-symbol-sources` (names, keys,
  hidden), `init-completion-go-project-symbols` (a symlinked root: both spellings;
  a reply with a project file, the same file through the link, a library header and
  a sibling directory: the first two kept, `:limit 0` sent; without root URIs no
  limit and nothing dropped).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** clangd and eglot percent-encode a path the same way. **Would break
  if:** a project path holds characters they encode differently; then `s` shows
  nothing there and `< l` still works. **DESIGN bet:** D-082.
- **Assumed:** no-limit replies stay small enough. **Would break if:** an index
  holding deal.II's sources (O-12) answers a three-letter query with tens of
  thousands of symbols; S11 run 5 saw at most 2458 (15.9 ms). A cap is the fallback
  (O-37's other option). **DESIGN bet:** D-082.
- **Assumed:** a file system's case matches between the compilation database and
  projectile's root. **Would break if:** they differ on the Mac's case-insensitive
  disk; the symbols would be filtered out.

## How to verify
- `make test`: the two tests above and `init-completion-go-symbols-from-third-character`.
- Done here (Mac, toy CMake project including `<vector>` and `<string>`, patched
  clangd, the shipped sources): `ans` -> `s` 2 symbols (`answer`, `AnswerTable`),
  `l` 15 (the same two and 13 from the SDK's headers).
- Owner: in `~/CLionProjects/step-1`, `M-o` `opt`: only the project's symbols among
  the symbols; `< l` `opt`: deal.II's and the standard library's too.
