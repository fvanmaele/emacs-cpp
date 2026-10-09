# 0037 - T-028: review of init-debug.el and emacs-cpp-presets.el

- **Date:** 2026-10-09
- **Commits:** see `git log -- lisp/emacs-cpp-presets.el`
- **Tier:** 2
- **Decisions:** D-016, D-033 (reopened as O-25), D-051
- **Done when:** a review journal entry with findings, each taken or not taken with a
  reason, and the taken ones fixed with tests (proposed with the task, 2026-10-09;
  the owner asked for the review the same day).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## Review fold-in
Source: Claude (LLM session), 2026-10-09, owner's brief: simplicity, no hardcoded or
brittle parsing. Both files read in full; CMake's presets manual checked for the
semantics (cmake.org, cmake-presets(7)).

- **Taken: preset `condition` was ignored.** A preset can say when it applies, e.g.
  only when `${hostSystemName}` is `Darwin`. CMake then refuses `--preset` for it; the
  config offered it anyway and could make it the default, so the first preset of a
  cross-platform file could be one for the other machine. Now evaluated as CMake does:
  inherited, except a parent's `null`; a disabled preset is left out of the default
  and of `C-c l P`. Matters since macOS is supported (D-050). Test:
  `emacs-cpp-presets-conditions-disable-presets`.
- **Taken, refused instead of guessed: `matches` / `notMatches`.** CMake uses
  ECMAScript regular expressions; Emacs's differ (classes, escapes), so a translation
  would sometimes be wrong without saying so. Such a preset file is an error naming
  the condition type.
- **Taken: `$env{NAME}` took the preset's raw value.** CMake expands macros inside
  `environment` values and treats `null` as "unset", also over an inherited value;
  the config returned the text unexpanded and fell back to the process environment
  for `null`. Now expanded, `null` is empty, and a cycle (`A` uses `B` uses `A`)
  is an error. Test: `emacs-cpp-presets-environment-as-cmake`.
- **Taken: lldb-dap's path tied to one port version.**
  `/opt/local/libexec/llvm-23/bin/lldb-dap` breaks with lldb-24. MacPorts offers
  `port select --set lldb mp-lldb-23`, which links `/opt/local/bin/lldb-dap`, as the
  config already asks for clangd. The default is now `lldb-dap` from the PATH on both
  platforms; the refusal names the `port select` command on macOS.
- **Taken: duplicated build step.** `gdb-preset` and `lldb-preset` each put the
  build command into the configuration; now one function does it and gdb's adds its
  arguments on top.
- **Proposed, owner to rule (O-25): the build.ninja parsing.** The target list reads
  `build.ninja` with regular expressions over CMake's link-rule names; it broke once
  already (CMake 3.31 writes the build type elsewhere, 0034). CMake's file API is the
  documented way: a JSON reply listing each target with its type and artifact paths,
  for any generator. It needs a query file before configuring, which D-033 counted
  against it; the configure command could write it, and CLion already does (its RMO
  builds on the Mac have replies). Not changed here: it reverses a decision.
- **Not taken: build.ninja read up to three times per session** (target prompt,
  build command, dape's second call after the build). RMO's file is small; no
  measurable cost.
- **Not taken: the patched-flag check searches `--help-hidden` for the flag text**,
  so a longer flag starting with the same text would also match. No such flag exists;
  the check names exactly the two flags the patches add.
- **Not taken: `emacs-cpp-presets-select` computes the project root twice**
  (interactive part and body). Cosmetic; the body must check the name anyway when
  called from Lisp.
- **Not taken: `emacs-cpp-debug--root` and `emacs-cpp-presets--current` overlap.**
  Different error messages for different callers; merging saves four lines.

## Concepts explained
- **Inherited conditions.** `inherits` copies a parent's fields into the child unless
  the child sets them. A `condition` follows that rule, so a child of a macOS-only
  preset is macOS-only too. The one exception in CMake's manual: a `null` condition
  enables its own preset but is not handed down.
- **Why refuse rather than translate a regular expression.** `\d` means a digit in
  ECMAScript and the letter `d` in Emacs; a translation table would cover the common
  cases and silently mis-answer the rest (DESIGN 4, principle 1).

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets--condition-p`,
  `emacs-cpp-presets--enabled-p`, `emacs-cpp-presets--env`;
  `emacs-cpp-presets-visible-names` now takes the project root and leaves disabled
  presets out.
- `lisp/init-debug.el` - `emacs-cpp-debug--prepare-build`, the lldb-dap default.
- `test/emacs-cpp-presets-test.el` - conditions and environment, as above.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** CMake disables a preset whose condition is false (`cmake --preset`
  refuses it); the manual does not spell this out. **Would break if:** CMake lets a
  disabled preset be used; the config would then refuse one CMake accepts.
- **Risk:** the owner's Mac needs `sudo port select --set lldb mp-lldb-23` once, or
  `lldb-preset` is refused (with that command in the message).
- **Risk:** `emacs-cpp-presets-visible-names` changed its argument (root instead of
  the read presets); all callers in the repository changed with it.

## How to verify
`make test`. On the Mac, after `sudo port select --set lldb mp-lldb-23`, the lldb
session test runs instead of skipping.
