# 0006 - T-004 fixes: library headers, eglot start, completion on request

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/init-cpp.el` (committed with this)
- **Tier:** 2
- **Decisions:** D-019 (new), D-020 (new)
- **Done when:** T-004's done-when (TASKS), now with completion on request
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner's check of T-004 found: no xref backend until eglot was started by hand,
`M-.` into deal.II / Boost slow, no clang-tidy warning, and a wish for completion on a
key instead of while typing. Findings, each measured here or on the owner's machine:

- **No xref backend inside library headers.** A deal.II header reached with `M-.` is
  not part of the project. The C++ mode hook tried to start a separate clangd for it,
  which D-018 refused (no presets in `/usr/include`), so that buffer had no language
  server. Fix (D-019): `eglot-extend-to-xref` attaches such headers to the project's
  clangd. A test checks it, and fails with the setting off.
- **eglot not starting by itself.** In a fresh session it does (checked in a real
  terminal session). The owner had followed the handover: open `main.cc` before
  configuring (refused, as designed), then configure. Reopening an already-open buffer
  does not rerun its mode hook, so it stayed without eglot. The refusal message now
  says "then M-x eglot". The new hook only starts eglot for files of preset projects,
  so opening a library header directly no longer raises a refusal warning.
- **Slow first `M-.`.** Measured on a synthetic deal.II + Boost file: the first request
  waits about 7 s for clangd's preamble (the parsed headers), later requests take 1 -
  2 ms, and opening the target header in Emacs 0.15 - 0.19 s. Not changed here; T-008
  owns it, including the risk that RMO's 13 s preamble exceeds jsonrpc's 10 s timeout.
- **No clang-tidy warning.** RMO has no `.clang-tidy`; clangd runs clang-tidy only for
  the checks a project lists. The owner's step.
- **Completion on request (D-020).** `corfu-auto` off; TAB (indent, then complete) or
  `C-M-i` asks for completions. `C-SPC`, CLion's key, stays `set-mark` (D-004).

## Concepts (Emacs Lisp) explained
- **Mode hooks run once per buffer:** `c++-ts-mode-hook` runs when a buffer gets its
  mode, normally when the file is first visited. Visiting a file that is already open
  only switches to the buffer.
- **Transient project:** a file outside any version-controlled directory has no
  project; eglot would invent one per directory. D-019 avoids starting servers for
  those files.
- **`bound-and-true-p`:** reads a variable only if it exists; the tests use it because
  eglot may not be loaded at all in the cases where it must not start.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets-eglot-ensure`, the hook function.
- `lisp/init-cpp.el` - hook, `eglot-extend-to-xref`.
- `lisp/init-completion.el` - `corfu-auto` nil.
- `test/init-cpp-test.el` - now starts eglot through the hook path, follows `M-.` into
  `<vector>`, and checks the two cases where eglot must not start.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** headers reached by `M-.` get usable flags from the project's clangd.
  **Would break if:** navigation inside deal.II headers shows false errors or no
  definitions. **DESIGN bet:** D-019.
- **Assumed:** a C++ file in a project without presets is rare enough for an
  echo-area note. **Would break if:** the owner works in such projects (would need a
  non-preset path, contradicting D-005). **DESIGN bet:** D-005.
- **Risk:** first `M-.` after opening a deal.II file may hit jsonrpc's 10 s timeout
  (T-008).

## How to verify
`make test` (22 tests). Owner: restart Emacs, open RMO `src/main.cc`; `M-.` into a
deal.II type, then `M-.` again inside the deal.II header; completion with TAB.

## Open questions
None new.
