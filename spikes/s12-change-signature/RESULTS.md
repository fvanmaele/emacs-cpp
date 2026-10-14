# S12 - change signature as a clangd code action: results

Verdict: FAIL against the pass criteria as written (runs 1 and 2, 2026-10-14, Mac).
Every edit the tweak made was right (0 wrong edits found), but in 5 of the 9
operations the edited project does not compile or its output changes, always
because of calls inside templates that the index cannot settle. The tweak names
each such call in its report and leaves it unedited. clangd computes the edits in
57 - 259 ms; the whole command, with eglot opening and editing every file, takes 1.5 -
5.1 s. The owner decides between the options at the end (O-43 (b)).

## Setup
- clangd: the patched tree of pkgrel 7 (23.1.1) copied to `/tmp/s12/clangd`, plus
  `clangd/0001-tweak-input.patch` (an `input` field on clangd's `applyTweak` command,
  passed to the tweak; the editor fills it) and `clangd/ChangeSignature.cpp` (the
  tweak). Built by `build.sh`; a first build is about 25 minutes on the Mac, a rebuild
  after a change to the tweak about one minute.
- Project: `gen_project.py`, 24 (run 1) or 48 (run 2) calling files, with three targets
  in `include/calc/api.h`:
  `int combine(int base, int scale, int offset = 0, int tag = 0)` with two overloads
  (two doubles, five longs); `int Meter::adjust(int, int, bool, int) const`, defined in
  `src/meter.cpp`; and `template <class T> T weigh(T, int, int, int)`, defined in the
  header. Each file calls these targets in several forms: qualified and unqualified,
  over several lines, nested, with comparisons and template arguments holding
  commas, inside lambdas, through a macro's argument and a macro's body, from default
  arguments, from a namespace-scope initializer, from a member function, and from
  templates. The function bodies are not symmetric in the parameters a run reorders,
  and the double overload returns something different from the int one. So a call
  that is edited wrongly, or left unedited, changes the test output.
- Driver: `run.sh` -> `changesig.el` in batch Emacs with the shipped config.
  `eglot-code-actions` at the function's name (what `C-c l a` calls) runs "Change
  signature". `prompt.el` supplies the new list, the shipped eglot confirmation
  (`maybe-summary`) is answered yes, the buffers are saved, then the project is built
  and its test output compared with the unedited project's. Each operation runs on a
  fresh copy.

## Runs 1 and 2 (raw output: `results-run1.log`, `results-run2.log`)

| operation | new list | result | reported calls (run 1) |
|---|---|---|---|
| combine add | `(base, scale, int extra = 7, offset, tag)` | tests fail | 25 |
| combine reorder | `(scale, base, offset, tag)` | tests fail | 25 |
| combine remove | `(base, scale, offset)` | PASS | 25 |
| adjust add | `(delta, times, clamp, reserved, int extra = 7)` | build fails | 24 |
| adjust reorder | `(times, delta, clamp, reserved)` | tests fail | 24 |
| adjust remove | `(delta, times, clamp)` | build fails | 24 |
| weigh add | `(value, factor, int extra = 7, shift, unused)` | PASS | 0 |
| weigh reorder | `(value, shift, factor, unused)` | PASS | 0 |
| weigh remove | `(value, factor, shift)` | PASS | 0 |

Run 2 (48 files) has the same results, with twice the counts (49 and 48 reported).

Edited in run 1 / run 2: combine 2 declarations and 166 / 331 calls in 26 / 50 files,
adjust 2 and 47 / 92, weigh 1 and 63 / 125; one macro body each for combine and
adjust.

| time | run 1 (24 files) | run 2 (48 files) |
|---|---|---|
| code action list (`textDocument/codeAction`) | 1 - 11 ms | 1 - 11 ms |
| tweak in clangd (the log's "S12" line) | 57 - 160 ms | 148 - 259 ms |
| eglot applying the edit (opens each file) | 1.5 - 2.6 s | 3.0 - 4.9 s |
| whole command (`workspace/executeCommand`) | 1.7 - 2.7 s | 3.2 - 5.1 s |

### Every failure is a reported call
- The tests that fail differ only in files that call the reported templates: run 1:
  12, 9, 9 of 24 lines differ (combine add, combine reorder, adjust reorder); run 2:
  24, 18, 18 of 48. In both runs, not a single differing line comes from a file
  without such a call (checked by script; the lines at the end of each log).
- The build errors of adjust add and adjust remove are all at line 19 of the calling
  files: `m.adjust(1, 2, true, 0)` inside `template <class M> int poke(const M& m)`.
- No call of the other overloads (`combine(1.5, 2.0)`, `combine(1L, ...)`,
  `twice(1.5)`) changed in any run (0 diff lines).
- Read by hand in the diffs: reordering inside nested calls, `i < 3, i > 1`, and
  `std::pair<int, int>{3, 4}` (template arguments with a comma); the default argument
  written out where a reorder needs it; a call spread over three lines keeps its
  layout; `COMBINE_TWICE` and `ADJUST_ONCE` (calls written in a macro body) edited once
  in the macro.

## Findings
1. **A call that depends on a template parameter and names an overloaded function
   cannot be settled from the index.** For `combine(v, v)` in `template <class T> T
   twice(T v)` and `calc::combine(t, 2)` in `via_template`, the index lists the same
   position for both `combine(int, ...)` and `combine(double, double)`. Which one is
   called is decided per instantiation. A trial run before run 1 edited it (the int
   overload's reference), and `twice<double>` then quietly called the int
   overload. The tweak now reports such calls ("a call the index also lists for
   another overload"). Left
   unedited they compile, but after an add or a reorder they bind differently:
   `twice<int>`'s `combine(v, v)` no longer fits the int overload and so picks the
   double one. The build stays green and the output changes. A report the user skips
   is a silent behaviour change.
2. **A member call through a template parameter is not in the index at all.**
   `m.adjust(...)` with `m` of type `const M&` is not resolved when the template is
   parsed, and the indexer does not index instantiations, so no reference exists. The
   tweak now scans the files it reads for calls by the name that no overload's
   reference covers, and reports them ("a call by this name the index lists for no
   overload"). A file without any listed reference to the function is not read, so
   such a call there goes unnoticed. The compiler catches it after an add or a remove
   (wrong argument count), not after a reorder of parameters of the same type.
3. **Everything the index lists precisely was edited correctly** from the files' raw
   tokens, with no parse of the calling files: 0 wrong edits. Per operation 281
   sites (run 1: 168 for combine, 49 for adjust, 64 for weigh) and 553 (run 2), so
   843 and 1659 edits over the 9 operations. The token rules that made this hold:
   - Arguments are split at commas outside brackets.
   - A `<` .. `>` holding a comma is read as template arguments when a name comes
     before the `<` and one of `{ :: , ) >` comes after the `>`; as two comparisons
     when a value comes after it. When a `(` comes after it, the call is reported as
     ambiguous (none occurred here).
   - An argument count outside the overload's range is reported as another
     overload's call.
   - A call nested in another's arguments is edited first, and the outer call
     carries that edit.
4. **Calls written in a macro's body** are listed by the index at the macro's use. The
   tweak finds the macro through this file's preprocessor and edits the call in its
   body once. A macro the opened file's parse does not see would be reported (none
   here).
5. **Time is spent in Emacs, not clangd.** The tweak takes 57 - 259 ms for 26 - 50
   files. eglot spends about 95 ms per file, opening each one (mode hooks, eglot's
   `didOpen`) before it edits it. Before applying, eglot asks for confirmation with a
   list of the files (the shipped `maybe-summary`); in batch it was answered yes.
6. **Not part of the tweak, found on the way:** in a project under `/tmp` on macOS the
   index loses every cross-file reference (3 instead of 201 for `combine`). This holds
   for the installed patched clangd and for MacPorts' stock clangd 23.1.3 alike. CMake
   writes `/tmp/...` into the compile database, while Emacs (and with it the opened
   file's URI) uses the true name `/private/tmp/...`. The spike therefore works in
   `~/.cache/emacs-cpp-s12`. Researched separately (O-50).
7. **Not tried:** constructors, virtual functions and their overrides, operators,
   variadic functions and parameter packs are refused (no code action). The tweak
   does not handle a function whose address is taken (reported as "not a call"),
   names other than ASCII, a parameter with an attribute before it, or a default value
   in a declaration the AST does not see.

## Options for the owner (O-43 (b))
- (a) A patch written fresh along the spike's lines: it edits what the index shows,
  lists the rest in its message (file:line, why), and the user finishes those by
  hand. That does not meet the criteria as agreed; finding 1 means the list must be
  read.
- (b) A second spike round: parse the files that hold a reported call (with their
  instantiations, through clangd's own parse) and settle those calls from the AST.
  Cost: one parse per file holding such a call, seconds each in a large project.
- (c) Stop here: the by-hand route in MANUAL 8 stays the way.
- Independent of these: eglot's 95 ms per file (finding 5) puts any change across 20 or
  more files over 2 s. Whether "answers in under 2 s" means clangd's answer (met) or
  the whole command (not met) is the owner's call.
