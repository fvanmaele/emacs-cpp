# 0057 - T-061: project symbols: cap, URI encoding, case

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`)
- **Tier:** 2
- **Decisions:** D-083 (built here), D-082 (whose risks it measures and covers)
- **Done when:** defcustom `emacs-cpp-go-symbol-limit`, default 10000 (0 = none),
  sent as clangd's limit for `s`; a reply reaching it shows a message; the root also
  matched in clangd's encoding, and ignoring case on macOS; tests for each; the toy
  checks re-run (`TOY/`, `c++ (x)@y` give 2); `make test`.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0056 listed three risks of `M-o`'s project symbols; the owner asked for them in
detail and for a configurable cap. Measured on the Mac against step-1's index and
two toy projects, two of the risks were real bugs, not hypotheticals: a project
whose path holds `+`, `(`, `)` or `@` (here `c++ (x)@y`), and a project opened
through a path typed in another case (`TOY/` for `toy/`), both listed no project
symbols at all. Both are fixed. The third, reply size, is bounded now: at most
`emacs-cpp-go-symbol-limit` symbols per request, 10000 by default, which keeps
every project symbol on step-1 (largest reply 6673); when a reply reaches the cap,
a message says project symbols may be missing, rather than dropping them silently.

## Concepts explained
- **Percent-encoding:** a URI writes some characters of a path as `%` and two hex
  digits (a space is `%20`). Which characters is partly a choice: clangd escapes
  everything but letters, digits and `- _ . ~ / :`; eglot leaves `+ ( ) @` and a
  few more as they are and escapes `:`. The filter compares strings, so it now
  holds the root in both spellings. `emacs-cpp-go--clangd-uri-chars` is clangd's
  rule as a 256-entry table, the form `url-hexify-string` takes.
- **Case:** macOS disks treat `TOY` and `toy` as the same directory; Emacs keeps the
  case you typed, clangd the case in `compile_commands.json`. `string-prefix-p`'s
  third argument ignores case; it is on for macOS only, where a case-only
  difference can't name a different directory on the default disk.
- **defcustom:** a user option; `M-x customize-option RET emacs-cpp-go-symbol-limit`
  changes it, or a line in custom.el. `natnum`: 0 or more.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-go-symbol-limit`,
  `emacs-cpp-go--clangd-uri-chars`, `emacs-cpp-go--root-ignore-case`;
  `emacs-cpp-go--root-uris` now returns up to four prefixes (as given / true name,
  each in eglot's and clangd's encoding); `emacs-cpp-go--symbol-request` sends the
  limit and warns when a reply reaches it.
- `test/init-completion-test.el` - `init-completion-go-project-symbols` (limit sent,
  message at the limit, none at 0 or below it), `init-completion-go-root-encoding-and-case`
  (a clangd-written URI under `c++ (x)@y` matches, `c++/` does not; an upper-case
  URI matches on macOS only).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 10000 holds every project symbol in the owner's projects. **Would
  break if:** an index with deal.II's sources (O-12) or a larger project makes a
  three-letter input match more; then the message appears, and a larger limit or 0
  is a customize away (cost about 7 us per symbol). **DESIGN bet:** D-083.
- **Assumed:** other language servers in `M-o` (pyright for Python) encode like
  eglot or like clangd. **Would break if:** one encodes a third way; for a root
  with special characters `s` lists nothing there, `< l` still works.
- **Assumed:** the Mac's disks ignore case. **Would break if:** a case-sensitive
  APFS volume holds two projects whose roots differ only in case; one would show
  the other's symbols.
- **Known, kept (owner):** code vendored under the root (step-1's `fmt/`) counts as
  the project's.
- **Message while typing:** a three-letter input on a large index can show the
  message for a moment; it goes away with the next key that narrows the reply.

## How to verify
- `make test`: the two tests above.
- Done here (Mac, patched clangd): toys `toy/`, `TOY/`, `c++ (x)@y`: `ans` gives the
  project's 2 symbols in each (before the fix: 2, 0, 0); step-1, `typ`: limit 5000
  gives 87 project symbols and the message, 10000 gives 111.
- Owner: in step-1, `M-o` `typ`: no message; `M-x customize-option RET
  emacs-cpp-go-symbol-limit` to 1000, `M-o` `typ`: the message.
