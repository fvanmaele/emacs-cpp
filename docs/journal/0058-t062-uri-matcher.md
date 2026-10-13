# 0058 - T-062: project symbols: one URI matcher for every server

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`)
- **Tier:** 2
- **Decisions:** D-085 (built here; replaces D-083's spellings), O-40
- **Done when:** the spellings go; a symbol is kept when its URI starts with the
  root's safe prefix and, decoded, with the root path (as given or true name),
  ignoring case on macOS; tests: four spellings x three roots, sibling and library
  not, upper case on macOS only, symlinked root, `%` in the root's name; clangd and
  pyright under toy, TOY, `c++ (x)@y`, `a:b` + U+00E4, `py a:b c++` list the
  project's symbols; filter <= 5 ms per 6673 symbols as shipped; `make test`.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`M-o` keeps the symbols whose file lies in the project. A server names that file
as a `file://` URI, and servers disagree on which characters of a path to write as
`%` codes: eglot, clangd, pyright and R's languageserver gave four spellings of the
same path. D-083 kept one copy of the root per known spelling; a new server with a
new spelling would have listed nothing. The new test does not care: all four leave
letters, digits and `- _ . /` as they are, so up to the root's first other character
every spelling is the same. That part is checked first, as plain text, which turns
away the thousands of library symbols at once. The few that pass are decoded (the
`%` codes turned back into characters) and compared with the root's real path. It
is also 3.5 times faster than the tables: 3.7 - 4.2 ms per 6673 symbols against
13.6 - 14.2 ms.

## Concepts explained
- **Percent-decoding:** `%2B` is `+`, `%C3%A4` the two UTF-8 bytes of U+00E4.
  `url-unhex-string` turns codes into bytes, `decode-coding-string` the bytes into
  Emacs characters, so the URI compares with the path Emacs has.
- **Safe prefix:** `string-match-p` finds the root URI's first character outside
  `[A-Za-z0-9._/-]`, starting after `file://` (whose `:` would otherwise stop it at
  once); the URI up to there is the safe prefix.
- **Warm and cold:** the first `seq-filter` call in a session sets up its generic
  dispatch, about 30 ms once; measurements here are after one warm-up call, as every
  later key is.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-go--root-uris` now returns (SAFE . FULL)
  pairs; `emacs-cpp-go--under-root-p` tests SAFE, then FULL against the decoded URI.
  `emacs-cpp-go--uri-chars` and `emacs-cpp-go--server-uri-chars` are gone.
- `test/init-completion-test.el` - `init-completion-go-root-encoding-and-case`: each
  of the four spellings under each of three roots matches, its `-other` sibling
  does not, its upper-cased form only on macOS; a library URI does not; `50%off/`
  matches `50%25off`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** no URI encoder escapes letters, digits or `- _ . /` (RFC 3986 says
  unreserved characters should not be). **Would break if:** one does, for example a
  server writing `%2D` for `-`; then that project's symbols leave `s`. `~` is left
  out of the safe set for that reason (some encoders escape it). **DESIGN bet:**
  D-085.
- **Assumed:** servers send composed Unicode (NFC). **Would break if:** one sends
  decomposed (NFD) names; not seen with clangd, pyright or languageserver.
- **Assumed:** `file:///path` URIs. `file://localhost/path` would fail the safe
  prefix; none of the servers sends it.

## How to verify
- `make test`: `init-completion-go-root-encoding-and-case`,
  `init-completion-go-project-symbols`.
- Done here (Mac): clangd under toy, TOY, `c++ (x)@y`, `cc a:b` + U+00E4 and pyright
  under pytoy, PYTOY, `py c++ (x)@y`, `py a:b` + U+00E4, `py a:b c++`: 2 project
  symbols each; filter 3.7 - 4.2 ms per 6673 symbols (three runs).
- Owner: `M-o` `typ` in step-1 lists the project's symbols as before.
