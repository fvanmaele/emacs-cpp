# RESEARCH - C++ refactorings: CLion against clangd and Emacs

Question (owner, 2026-10-13): which of CLion's C++ refactorings does this config have,
in particular change signature and refactorings across the project's files? Fills
the (R) row "Other refactorings" of DESIGN 1. Findings only; verdicts go to DESIGN.

Sources: JetBrains' CLion help ("Refactoring source code", "Change signature"), read
2026-10-13; clangd 23.1.1 sources (`packaging/llvm-project-23.1.1.src`); hands-on on
the Mac with the shipped config and the patched clangd 23.1.1 (stock clangd 21.1.8 for
one check), on generated projects.

## 1. CLion
- The help's list of the most used: Rename, Change Signature, Extract Method (Extract
  function), Introduce Variable, Inline, Safe Delete, Copy. Its menu has more
  (introduce constant / parameter / typedef / define, move, pull members up / push
  members down, extract superclass ...); those pages were not read.
- Change Signature: rename the function, change its return type, add / remove /
  reorder parameters (each new one with a type, name and a default value written
  into existing calls; empty: a type default such as `0` or `nullptr`), make it
  `const` / `constexpr` / `noexcept`; it updates calls, implementations and overrides
  "that can be safely modified to reflect the change".

## 2. clangd 23.1.1
**Rename** (`eglot-rename`, `C-c l r`): across files, from the index. Measured on a
generated CMake project of 62 sources plus a header, all calling one function:
references from 63 files; rename refused with "The number of affected files exceeds
the max limit 50" (clangd's `--rename-file-limit`, default 50; the config passes
none); with `--rename-file-limit=0` all 63 files in 224 ms. The index must match the
files' paths: with the compilation database naming `/tmp/...` and the files opened as
`/private/tmp/...` (a macOS symlink) references found 2 files and rename changed 2,
silently.

**Code actions** (`eglot-code-actions`, `C-c l a`), the tweaks in
`clangd/refactor/tweaks/`: AddUsing, DefineInline (a function's definition into its
declaration's place, header-only), DefineOutline (a definition moved from a header to
its implementation file, a two-file edit), ExpandDeducedType (`auto` to the type),
ExpandMacro, ExtractFunction, ExtractVariable, MemberwiseConstructor, OverridePureVirtuals,
PopulateSwitch, RawStringLiteral, RemoveUsingNamespace, ScopifyEnum (unscoped to
`enum class`), SpecialMembers (copy / move members), SwapBinaryOperands,
SwapIfBranches; plus two hidden debug ones and two for Objective-C. Offered on a
generated file (hands-on): `switch` over an enum: "Populate switch"; `auto`:
"Replace with deduced type"; a selected expression: "Extract subexpression to
variable", "Swap operands to +"; `using namespace std`: "Remove using namespace,
re-qualify names instead"; a class with a pure virtual base and members: "Define
constructor", "Override pure virtual methods", "Declare implicit copy/move members".
Extract function was not offered for two statements whose variable is used after
them (as it should not); DefineOutline not for a header without a `.cc` beside it.

## 3. Against CLion
- Rename: yes, across files; capped at 50 files by default (above).
- Change Signature: none in clangd (no tweak), none in `clang-refactor`. Partly by
  hand: a new parameter with a default value needs no call-site edits in C++; a
  rename of the function is `C-c l r`; for reordering or removing parameters, the
  build's errors list every call (`C-c p c c`, `M-g n`), or `M-?`, then `C-.` `E`
  (embark exports consult's xref list to an `*xref*` buffer,
  `embark-consult-export-xref`) and `r` there (`xref-query-replace-in-results`) to
  replace in exactly the files with references (from the sources; not run here).
- Extract function / variable: yes (clangd), within one file; no extract constant,
  parameter, typedef or define.
- Inline: no "inline a function or variable at its uses"; DefineInline moves a
  definition into the header, ExpandMacro inlines a macro use.
- Safe Delete: no; `M-?` shows whether anything uses it.
- Move: DefineOutline (header -> source); `clang-move` (command line) moves class
  declarations and definitions between files; nothing in Emacs for it.
- Pull members up / push down, extract superclass: none.
- Generate (CLion's Generate menu, not a refactoring there): constructors, special
  members, overrides of pure virtuals, switch cases (clangd).

## 4. Command-line tools in the toolchain
In MacPorts' llvm-23 (`/opt/local/libexec/llvm-23/bin`, checked): `clang-move`,
`clang-change-namespace` (moves code to another namespace across files),
`clang-reorder-fields` (reorders a struct's fields and its initializations),
`clang-refactor`, `clang-include-fixer`, `clang-apply-replacements` and
`run-clang-tidy` (applies clang-tidy's fix-its over the whole compilation database,
e.g. `modernize-*`, with `-fix`). Arch's `clang` package: not checked. Each takes the
compilation database; none is wired into Emacs here.

## 5. Options (for O-43)
- (a) Pass `--rename-file-limit=0` to clangd (the preset contact): project-wide
  rename beyond 50 files; measured above.
- (b) A clangd change-signature tweak (patch 0010): reordering or removing
  parameters at every call needs each calling file parsed or a careful edit from the
  index's reference ranges; large, a spike first.
- (c) Commands around the CLI tools (`clang-move`, `clang-change-namespace`,
  `run-clang-tidy -fix`), e.g. under `C-c l`.
- (d) Document the by-hand route for signature changes (default arguments,
  `C-c l r`, build errors, `M-?` -> `E` -> `r`), after running it once.

## 6. Not checked
- The `M-?` -> `C-.` `E` -> `r` route by hand.
- Arch's clang package for the CLI tools.
- clangd's rename on RMO or deal.II (index coverage; the 50-file limit).
