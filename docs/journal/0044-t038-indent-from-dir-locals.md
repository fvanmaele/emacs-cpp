# 0044 - T-038: C++ indentation from plain .dir-locals.el values

- **Date:** 2026-10-10
- **Commits:** the commit that adds this entry (`lisp/init-cpp.el`,
  `test/init-cpp-test.el`)
- **Tier:** 2
- **Decisions:** D-062 (built here); supersedes the `.dir-locals.el` part of D-061
- **Done when:** ERT shows a dir-local `bsd` applies, the brace rule holds, the
  option flattens namespaces with no prompt; the RMO re-indent count stays at 2955
  with data only; MANUAL 8 drops the `eval`; `make test` passes (agreed 2026-10-10).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
RMO's `.dir-locals.el` needed an `eval` form, code that Emacs asks you to trust,
because of two gaps in Emacs 31.1's `c++-ts-mode` (both drafted as upstream reports):
a `c-ts-mode-indent-style` from `.dir-locals.el` is stored but never used, and a `{`
on its own line after `namespace` or `class` is indented in every style. The owner
asked for a `.dir-locals.el` without code.

The config now does that code's work for every C++ buffer: once Emacs has read a
file's local variables, it rebuilds the indent rules from the (local) style and adds
the namespace / class brace rules. A new option, `emacs-cpp-indent-namespace-body`,
declared safe for local use, says whether namespace contents are indented. RMO's
`.dir-locals.el` is now five plain values, and Emacs applies them without asking.
Re-indenting RMO with it changes the same 2955 lines as the `eval` version.

The brace rules apply to every C++ buffer, with or without project settings: a `{`
alone on a line after `class` now sits under `class`, as it already did under
`struct` and functions. A `{` at the end of the `class` line is not affected.

## Concepts (Emacs Lisp) explained
- **Order of a file visit.** Emacs runs the major mode, then its mode hooks, then reads
  the file's local variables (`.dir-locals.el`, the `-*-` line), then runs
  `hack-local-variables-hook`. `c++-ts-mode` builds its indent rules in the first
  step, too early to see a local style; adding a function to
  `hack-local-variables-hook` from the mode hook catches the right moment.
- **Safe local variables.** Values from `.dir-locals.el` are applied silently only
  for variables declared safe for that value (`:safe #'booleanp` on the new option);
  `eval` is never safe, hence the trust prompt before.
- **Idempotent rebuild.** The rules are rebuilt from the style each time rather than
  added on top, so running the function twice (once in the mode hook, once after the
  local variables) gives the same rules.

## Key files walked
- `lisp/init-cpp.el` - `emacs-cpp-indent-namespace-body`, `emacs-cpp-indent--apply`
  (rebuild + rules), `emacs-cpp-indent-setup` (on `c++-ts-mode-hook`).
- `test/init-cpp-test.el` - `init-cpp-indent-from-dir-locals-data`,
  `init-cpp-indent-braces-after-namespace-and-class`; both fail with the setup
  disabled.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** Emacs keeps reading local variables after the mode hooks (subr.el
  `run-mode-hooks` says so in 31.1). **Would break if:** the order changes; the rules
  would then miss a local style. The dir-locals test would catch it. **DESIGN bet:**
  D-062.
- **Risk:** `M-x c-ts-mode-set-style` in a buffer drops the brace rules until the file
  is visited again.
- **Risk:** when Emacs fixes either gap, the workaround may double up; the rules
  are the same, so doubling is harmless, but D-062 says to drop each one then.

## How to verify
`make test`. Owner, on RMO: restart Emacs, open `src/main_coarse.cc`: no question
about local variables, and `M-: c-ts-mode-indent-style` shows `bsd`; `TAB` inside the
namespace leaves a line at column 0.
