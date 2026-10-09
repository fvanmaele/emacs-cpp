# RESEARCH - guessing a project's indentation and format style (T-034)

Findings only; verdicts go to DESIGN (O-28). Owner request 2026-10-09: research
indent-guessing packages, after the manual procedure (`docs/MANUAL.md` 8) was applied
to RMO. Measured on Arch with Emacs 31.1, clang-format and clangd 23.1.1 (system and
patched), 2026-10-09. Package facts from their source and the GitHub API the same
day.

## 1. Two things to guess, two places they live
- **Format** (`C-c l f`): clangd formats with the project's `.clang-format`, LLVM
  style without one (clangd's `--fallback-style`).
- **Indentation** (`TAB`, `RET`): `c++-ts-mode`'s tree-sitter rules, set by
  `c-ts-indent-offset` (renamed from `c-ts-mode-indent-offset` in Emacs 31, the old
  name an obsolete alias), `c-ts-mode-indent-style` (`gnu`, `k&r`, `linux`, `bsd`, or
  a function) and `indent-tabs-mode`. They do not read `.clang-format`.

A guesser serves one of the two; none found serves both.

## 2. Candidates
| Package | Guesses | Runs in | Licence | Last push | Notes |
|---|---|---|---|---|---|
| dtrt-indent 1.28 | step, tabs | Emacs, at open | GPL | 2026-07-09 | Emacs >= 28.1 |
| guess-style | step, tabs | Emacs | - | 2021-07-26 | cc-mode era |
| `c-guess` (built in) | cc-mode style | Emacs | GPL | 31.1 | `c++-mode` only |
| whatstyle | `.clang-format` | shell | MIT | 2021-12-22 | Python 2.7, 3.2 - 3.5 |
| unformat | `.clang-format` | shell | Apache-2.0 | 2024-12-02 | clang-format 3.8 / 3.9 |
| ranking (MANUAL 8) | base style | shell | - | - | clang-format only |

- **dtrt-indent** maps `c++-ts-mode` to `c-ts-mode-indent-offset` (source line 383).
  In Emacs 31.1 `setq-local` on that obsolete alias sets `c-ts-indent-offset`
  buffer-locally (checked), so it works. It guesses only the step and tabs: thresholds
  `dtrt-indent-min-quality` 80, `dtrt-indent-max-lines` 5000. Brace placement and
  namespace indentation (section 3) are out of its reach.
- **`c-guess`** reads a region into a cc-mode style; `c++-ts-mode` has no counterpart
  in 31.1. guess-style predates tree-sitter modes and is not maintained.
- **whatstyle** reformats with many option combinations and diffs, starting from the
  built-in styles; `--mode resilient` adds options. **unformat** mutates
  configurations at random and keeps the one with the smallest Levenshtein distance;
  it runs until stopped. Neither has been run here: unformat names clang-format 3.8 /
  3.9, whatstyle names no version and was last changed in 2021; options were renamed
  since (e.g. in 23.1.1 `SpaceInEmptyBlock: false` had no effect over WebKit's
  `SpaceInEmptyBraces: Always`), and both are Python from outside the system's packages.
- Format-on-save packages (apheleia, reformatter) run a formatter; they guess nothing.

## 3. RMO, measured
46 files of RMO's own (not `fmt/`, about 10,100 lines), HEAD versions copied to a
scratch directory. "Changed lines" = lines `diff` marks as new after the tool ran.

**clang-format.** The built-in styles changed: WebKit 2107, Microsoft 3057, LLVM 7873,
Google 8210, Chromium 8352, Mozilla 8927, GNU 9313 lines. WebKit plus 24 option values
(RMO's `.clang-format`; the brace, `else`, lambda, pointer, initializer and comment
choices from counts over the sources, e.g. `else` after `}` on its own line 28 times
against 4; union / enum braces assumed like class) changed 831 lines. What remains is
not consistent in the code itself: hand-aligned declarations and assignments, `)` alone
on a line (7 times), `for (x: v)` (6) beside `for (x : v)` (47). One construct breaks:
boost `po::options_description::add_options()` chains are joined into one call
(`include/rmo/option.h`); `// clang-format off` / `on` around them keeps them.

**Emacs indentation.** `indent-region` over the same files, offset 4, spaces:
| Rules | Changed lines |
|---|---|
| `gnu` (default) | 7760 |
| `bsd` | 7624 |
| `bsd` + 3 added rules (below) | 2955 |

In every built-in style of 31.1, a `{` on its own line after `namespace` or `class`
is indented one step, and everything inside follows; the rule list names
`function_definition`, `struct_specifier` and others, not `namespace_definition` or
`class_specifier`. `gnu` and `k&r` are the same list. The 3 rules, added with the public
`treesit-simple-indent-add-rules`:
```
((parent-is "namespace_definition") standalone-parent 0)
((parent-is "class_specifier") standalone-parent 0)
((n-p-gp nil "declaration_list" "namespace_definition") parent-bol 0)
```
Of the 2955 left, seen in samples: `case` labels at the column of `switch` (RMO indents
them), arguments after a `(` at the end of a line aligned to the `(` instead of one step
in, and members of some template classes at the class's column (cause found
2026-10-10: a member after a blank line in a body that starts with `public:`, T-039;
with D-062's rules 452 lines are left).

## 4. clangd already indents on RET (on-type formatting)
clangd 23.1.1 (both builds) announces `documentOnTypeFormattingProvider` with trigger
`"\n"`. Eglot sends `textDocument/onTypeFormatting` from `post-self-insert-hook`, which
`newline` runs. Batch test with RMO's `.clang-format`, RET at the end of a line in a
namespace and after `public:`:

| Setup | after `int g();` in namespace | after `public:` |
|---|---|---|
| no eglot | column 4 (wrong) | 4 |
| eglot, `electric-indent-mode` on | 4 (wrong) | 4 |
| eglot, `electric-indent-mode` off in the buffer | 0 (right) | 4 |

clangd answers, but electric indentation runs later in the same hook and re-indents
the line by the tree-sitter rules. Not measured: the time per RET (one synchronous
request), what clangd does to the previous line, and `TAB`. LSP has no "indent this
line" request; `eglot-format` on a line's range reformats the whole line, not only its
indentation.

## 5. What this leaves (for O-28)
- A guesser for the indent step (dtrt-indent) would fix none of RMO's differences: the
  step and tabs were never the problem, the rules are.
- `.clang-format` from a file: the manual ranking works with today's clang-format;
  whatstyle / unformat are unproven at 23.1.1.
- Making indentation follow `.clang-format` needs no guesser: RET through clangd
  (section 4) once electric indentation stops overriding it; TAB has no direct LSP
  route.
