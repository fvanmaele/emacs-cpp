# 0059 - T-063: `M-o` `< l` lists as `C-c l s` for empty input

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`)
- **Tier:** 2
- **Decisions:** D-086 (built here; narrows D-077's empty-input rule to `s`)
- **Done when:** empty input asks clangd for "" and lists its 100; 1 - 2 characters
  keep that list; from 3, clangd's matches; `s` unchanged; opening `M-o` sends no
  extra request; test for the request steps; terminal check on the toy (empty 100,
  a 100, an 100, ans 15, as `C-c l s`); `make test`.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner's hand check of T-060: `M-o` `< l` showed nothing until three letters
were typed, while `C-c l s` opens with a list of clangd's first 100 symbols (the
counter shows 1/100). Two rules in `M-o`'s symbol source caused it: no request for
an empty input (D-077, which avoided 100 arbitrary symbols at every opening of
`M-o`) and at least three characters. Both stay for `s`; `l` now asks for the empty
input as `C-c l s` does. Because a hidden source receives no input, the request
goes out only once the prompt is narrowed to `l`, never when `M-o` opens.

## Concepts explained
- **Async steps:** consult passes each input through a chain of small functions
  ("steps"): minimum length, throttle, the request, the conversion to candidates.
  `emacs-cpp-go--min-input` replaces consult's minimum-length step for both
  sources: with EMPTY it lets "" through, otherwise it behaves as consult's.
- **cancel:** a too-short input sends `cancel` down the chain, which stops a pending
  request but leaves the list shown; that is why `a` and `an` keep the 100 in both
  commands.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-go--min-input`; the EMPTY argument of
  `emacs-cpp-go--symbol-request` and `emacs-cpp-go--symbol-source`; `l` is built
  with it, `s` without.
- `test/init-completion-test.el` - `init-completion-go-all-symbols-empty-input`: the
  step's output for "", a, an, ans with and without EMPTY; a request for "" only
  from `l`'s request step.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** narrowing hands a hidden async source the input it holds (D-079's
  patched `consult--async-predicate`). **Would break if:** a consult update changes
  that; `< l` would then wait for a key again. The terminal check would show it.
- **Assumed:** clangd's answer to "" stays small (its default 100). The `l` source
  sends no `limit`, so D-083's cap does not apply and is not needed.

## How to verify
- `make test`: `init-completion-go-all-symbols-empty-input`.
- Done here (terminal Emacs, toy with clangd): candidates after empty / a / an / ans:
  `C-c l s` 100 / 100 / 100 / 15; `M-o` `< l` the same; `workspace/symbol` requests:
  0 at opening, 1 after `< l`, none for a and an, 1 for ans.
- Owner: RMO `main.cc`, `M-o` `< l`: 1/100 at once, as `C-c l s`.
