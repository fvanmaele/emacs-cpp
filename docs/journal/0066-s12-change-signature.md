# 0066 - S12: change signature as a clangd code action, FAIL on calls in templates

- **Date:** 2026-10-14
- **Commits:** here: `git log -- spikes/s12-change-signature`
- **Tier:** 3 (spike S12)
- **Decisions:** none (O-43 (b) to the owner; O-50 opened)
- **Done when:** RESULTS.md carries a verdict against the pass criteria agreed
  2026-10-13 (T-069)
- **Tag:** none

> Plain English. No configuration code changed; everything lives in the spike's
> directory and in a scratch clangd under `/tmp/s12`.

## What + why
CLion can change a function's parameters and fix every call. clangd cannot (O-43). The
spike added a "Change signature" code action to a copy of the patched clangd. Emacs
asks for the new parameter list, for example `(scale, base, offset, tag)`, and the
action rewrites the declarations and every call it finds through clangd's index. It
reads each calling file's raw tokens and does not parse those files. A generated
project with 24 and then 48 calling files tested an add, a reorder and a removal on
three functions: a free function with overloads and default arguments, a member
function, and a function template.

All 2502 edits were right, including calls in macros' bodies, nested calls,
comparisons and template arguments holding commas. But 5 of the 9 operations left a
project that does not build or behaves differently. Each time the cause was a call
inside a template, which the index cannot settle:
- `combine(v, v)` with `v` of type `T` is listed for both overloads of `combine`.
- `m.adjust(...)` with `m` of type `M` is not listed at all.

The action reports these calls and leaves them alone, which is "reported", not
"right". So the verdict is FAIL against the criteria as agreed, and the owner chooses
the way on (RESULTS.md, options).

Time: clangd needs 57 - 259 ms. eglot then opens every edited file before it edits
it, about 95 ms per file, so the whole command takes 1.7 - 5.1 s.

On the way: a project under `/tmp` on the Mac loses every cross-file reference in the
index, with the stock clangd too. It is a separate question (O-50).

## Concepts explained
- **Code action / tweak:** clangd's name for a refactoring it offers at the cursor.
  The editor lists them (`textDocument/codeAction`, `C-c l a`), and choosing one sends
  `workspace/executeCommand`. clangd answers by asking the editor to apply a
  `WorkspaceEdit` (edits to several files). LSP has no way for a code action to ask
  the user something, so the spike adds an `input` field to clangd's command and has
  Emacs fill it (`prompt.el`).
- **Dependent call:** inside `template <class T>`, a call whose arguments involve `T`
  is resolved only when the template is instantiated with a concrete `T`. The index
  stores the template's text once, so it either lists every candidate overload, or
  (for `m.adjust` on an unknown type) nothing.
- **Raw tokens:** the file is split into words and punctuation without running the
  preprocessor or the compiler. That is fast, but a `<` can be a comparison or the
  start of template arguments, and the spike decides that from the tokens around it.

## Key files walked
- `spikes/s12-change-signature/clangd/ChangeSignature.cpp` - the tweak; `apply`
  collects the sites (the index's references, the AST's redeclarations, calls in
  macro bodies), reports what it cannot settle, and builds the edits innermost
  first.
- `spikes/s12-change-signature/run.sh`, `changesig.el` - nine operations, each on a
  fresh copy, built and tested against the unedited project's output.
- `spikes/s12-change-signature/RESULTS.md` - tables, findings, options.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the generated project's forms are representative of real code. **Would
  break if:** real projects lean on forms the project lacks: function pointers,
  `std::invoke`, constructors, virtual overrides (all refused or reported by the
  spike). **DESIGN bet:** O-43 (b).
- **Assumed:** the tests detect a wrong or missing edit. They do so because the bodies
  are not symmetric and the overloads return different values. A trial before run 1,
  with symmetric bodies, passed four operations by luck. **Would break if:** a missed
  call leaves the result unchanged by chance.
- **Risk:** a reported call that compiles unedited (finding 1) changes behaviour
  silently. Any patch built on this must make the list hard to miss.

## How to verify
`bash spikes/s12-change-signature/build.sh`, then
`sh spikes/s12-change-signature/run.sh` (about 4 minutes on the Mac, about 8 with
`48`), and compare with `results-run1.log` and `results-run2.log`. Optional hand check
in RUN.md.

## Open questions
O-43 (b): (b1) / (b2) / (b3), owner rules. O-50: `/tmp` paths on macOS, research
asked.
