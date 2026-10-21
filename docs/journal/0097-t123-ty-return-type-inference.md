# 0097 - T-123: ty's return type inference, opt-in per project

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-123"`
- **Tier:** 2
- **Decisions:** D-142 (built), D-091 (`emacs-cpp-lsp-settings` extended)
- **Done when:** T-123's four items (TASKS.md, agreed by the owner 2026-10-21)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
ty can infer the return types of functions without annotations since 0.0.89, but
leaves it off by default, and on a large unannotated project it costs a lot (SymPy:
the first `M-?` 22 s instead of 1.8 s, 8.3 GB instead of 1.15; RESEARCH_python_ty 8).
The owner ruled it opt-in per project (D-142): a project's `.dir-locals.el` sets
`emacs-cpp-ty-return-type-inference`, and the config sends ty the setting.

## Concepts (Emacs Lisp) explained
- **Workspace configuration as a function.** A language server asks the editor for
  settings (`workspace/configuration`). eglot answers from
  `eglot-workspace-configuration`; when that is a function, eglot calls it in a
  temporary buffer where the project's directory variables are set
  (`eglot--workspace-configuration-plist`). So a section computed by a function sees
  the project's `.dir-locals.el`.
- **`:safe #'booleanp`.** Marks the option as safe in directory variables when its
  value is t or nil, so Emacs applies it without asking.

## Key files walked
- `lisp/init-lsp.el` - `emacs-cpp-lsp-settings` keeps each section (a plist or a
  function) and `emacs-cpp-lsp-workspace-configuration` (NEW) joins them; it is
  eglot's default `eglot-workspace-configuration` now.
- `lisp/init-python.el` - `emacs-cpp-ty-return-type-inference` (NEW) and the `ty`
  section: ty's inline `configuration` with `analysis.return-type-inference`
  "always" when set.
- `test/init-python-test.el` - `init-python-ty-return-type-inference` (NEW): the real
  ty, a project with and without the `.dir-locals.el`, ty's revealed type in flymake.
- `test/init-latex-test.el` - the texlab settings read through the function.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** ty keeps the option's name and its inline `configuration` setting.
  **Would break if:** ty renames it (0.0.x) or makes the inference default; the test
  then fails on the revealed type. **DESIGN bet:** D-142.
- **Assumed:** a project that sets `eglot-workspace-configuration` itself in its
  `.dir-locals.el` wants its own value; it replaces the function there, as before.
- **Seen:** in batch no idle timer starts flymake, so the test calls `flymake-start`
  before waiting for ty's diagnostics.

## How to verify
- `make test </dev/null` - 150 tests on Arch.
- `sh scripts/measure-startup.sh 10` - 0.183 s against 0.182 s before.
- A project with the `.dir-locals.el` line, `M-x eglot-reconnect`, then
  `reveal_type(f())` of an unannotated `f` shows its type, not `Unknown`.
