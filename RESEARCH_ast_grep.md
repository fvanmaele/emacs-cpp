# RESEARCH - ast-grep in place of clangd for C/C++

Question (owner, 2026-10-31): "Research ast-grep instead of clangd for LSP functionality
in C/C++". Findings only; verdicts go to DESIGN (O-77).

Context: clangd is the C++ server (D-001, T-004), locally patched for navigation from its
index (D-026 .. D-028, D-046, D-047, D-059, D-060). The config uses from it, counted in
`lisp/*.el` 2026-10-31: definition and references (`xref-find-*`),
`eglot-find-implementation`, `eglot-rename` (D-092), `eglot-code-actions` (clangd's
tweaks), `workspace/symbol` (`M-o`, D-082 .. D-086), call and type hierarchy, inlay
hints, completion (corfu), hover (eldoc), diagnostics with clang-tidy (flymake), file
watches (D-110, D-111).

Sources, all read 2026-10-31: ast-grep's documentation (Editor Integration, FAQ, Core
Concepts pages on ast-grep.github.io); its source at `main` 72f1509 (2026-10-29,
workspace version 0.51.0): `crates/lsp/src/lib.rs`, `crates/language/src/lib.rs`,
`crates/language/Cargo.toml`, `crates/outline/`, `crates/cli/src/outline.rs`;
`pacman -Si ast-grep`; ports.macports.org's ast-grep page; Emacs 31.1's `eglot.el.gz`
and `eglot.info.gz` on Arch. Hands-on: no ast-grep binary was run (not installed; running
a downloaded release binary was refused by the session's permission check); one
tree-sitter parse measurement with Emacs's own grammar (section 4).

## 1. What ast-grep is
- A structural search, lint and rewrite tool over tree-sitter syntax trees: "ast-grep,
  contrary to its name, searches and rewrites code based on CST patterns, instead of
  AST" (Core Concepts). Patterns are code with metavariables (`$NAME`), or YAML rules
  over node kinds.
- No semantics, by its own FAQ: "Does ast-grep support some advanced static analysis?
  Short answer: NO." Not supported: scope analysis, type information, control flow,
  data flow, taint analysis, constant propagation. "Find variables of a specific type"
  is given as a task it cannot do.
- C++ through the `tree-sitter-cpp` crate 0.23.x (`crates/language/Cargo.toml`), the
  same release line as Arch's `tree-sitter-cpp` 0.23.4 that `c++-ts-mode` uses (D-008).
  Extensions read as C++: cc, hpp, cpp, c++, hh, cxx, cu, ino; `.h` is read as C
  (`crates/language/src/lib.rs` line 508), so a C++ project's `.h` headers need
  `languageGlobs` in `sgconfig.yml`.

## 2. Its language server, `ast-grep lsp`
Capabilities announced in `initialize` (`crates/lsp/src/lib.rs`, 0.51.0), everything
else left at the default (none):
- `textDocumentSync` FULL (a source comment: "TODO: change this to incremental").
- `codeActionProvider`: the fixes of the project's rules ("Fix diagnostic code
  action"), plus the command `ast-grep.applyAllFixes`.
- `hoverProvider`: shows a rule's `note` text at a place where that rule matched
  (`do_hover` looks up `ast.notes` by position); nothing elsewhere.
- Diagnostics (`publishDiagnostics`) from the rules in the project's rule directories.
Requirement: `sgconfig.yml` in the project root ("ast-grep LSP requires `sgconfig.yml`
in the project root"), or `ast-grep lsp -c <configPath>`. Without rules it reports
nothing.

Not provided: definition, declaration, references, implementation, rename, completion,
signature help, document or workspace symbols, call or type hierarchy, inlay hints,
semantic tokens, formatting, `didChangeWatchedFiles` registration (it handles the
notification but does not ask for watches). Emacs 31.1's `eglot-server-programs` has no
ast-grep entry (checked, `eglot.el.gz`).

`ast-grep outline` (CLI, `crates/outline/`, rules `default_rules/cpp.yml`: includes,
function definitions, classes, structs, ...) lists a file's top-level items as text or
JSON; it is not served over LSP.

## 3. Feature against feature
| config feature (clangd) | ast-grep |
|---|---|
| `M-.` definition, `M-?` references | none over LSP; a pattern search finds same-named text, not the entity |
| rename (D-092) | `ast-grep run -p P -r R` rewrites matches by syntax, blind to scope, overloads, namespaces |
| `M-o` symbols (D-082) | none; `outline` per file only |
| hierarchies, implementation | none |
| completion, hover types, inlay hints | none; hover is rule notes only |
| diagnostics | rule matches only; no compiler errors, no clang-tidy |
| code actions | the rules' own fixes |

The gap is by design (section 1): finding the definition a `foo(x)` call resolves to
takes overload resolution, templates, ADL, `using` declarations and the preprocessor,
which need the compiler that clangd is and a syntax tree does not have.

## 4. Parse quality on the owner's code (measured)
Emacs 31.1 with Arch's tree-sitter-cpp 0.23.4, counting `ERROR` and `MISSING` nodes
(the script lived in the session's scratch directory; numbers are what ast-grep would
match against, assuming its bundled 0.23.x grammar parses alike: UNVERIFIED):
- deal.II `base/tensor.h`, 3103 lines: 146 ERROR, 42 MISSING; 86 lines use
  `DEAL_II_HOST_DEVICE`, `DEAL_II_CXX20_REQUIRES` or `DEAL_II_CONSTEXPR`, and
  `DEAL_II_NAMESPACE_OPEN` hides the outer namespace from the tree.
- deal.II `lac/vector.h`, 1539 lines: 1 ERROR, 3 MISSING.
- deal.II `fe/fe_values.h`, 745 lines: 8 ERROR, 1 MISSING; 0 namespace definitions
  seen.
- RMO `src/main.cc`, 125 lines: none.
So patterns over deal.II's headers miss or misread code around its macros; clangd sees
them expanded.

## 5. Packaging
- Arch: pacman `extra/ast-grep` 0.44.1-1 (built 2026-07-18), MIT, depends on glibc and
  libgcc only; not installed.
- Mac: MacPorts `ast-grep` 0.51.0 (updated about 2026-10-18); not checked by `port
  info` from this session (it ran on Arch).
- Version skew 0.44 against 0.51 between the machines; the custom-language opt-in
  (`--custom-languages`) arrived in 0.50.0 per the docs, so flags differ.

## 6. Where it could fit next to clangd
- Structural search and rewrite as a command, like D-097's grep-edit list: pattern
  matches across the project in a grep buffer, edits reviewed before saving. Emacs
  packages: `ast-grep.el` (consult / completing-read front end, named on the docs'
  editor page; not checked on MELPA by this session).
- Project lint rules (`ast-grep scan`) as a flymake backend, the shape D-143 chose for
  ruff over a multiplexer.
- A second server in the same buffer through rassumfrassum (`rass -- clangd -- ast-grep
  lsp`), the route Emacs 31's eglot manual describes (node "Multi-server support").
  RESEARCH_python_ty.md found rass in the AUR and pip only, not in pacman or MacPorts;
  D-143 took the flymake route instead for ruff.
