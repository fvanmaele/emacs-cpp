# RESEARCH - Test runner: neotest and its Emacs equivalents

Question (owner, 2026-11-12): research a neotest equivalent; named neotest,
neotest-python, neotest-gtest, neotest-ctest. Findings only; verdicts go to DESIGN
(O-90).

Sources (all read 2026-11-12): the four neotest repositories, cloned (depth 30) and
read: github.com/nvim-neotest/neotest (v5.20.0, last commit 27bf921 2026-08-16),
github.com/nvim-neotest/neotest-python (no tags, 1b56ca4 2026-07-15),
github.com/alfaix/neotest-gtest (no tags, 9e8031a 2026-10-25),
github.com/orjangj/neotest-ctest (v0.3.0, cb3abe9 2026-06-14); all MIT. Emacs
candidates cloned and read: github.com/wbolster/emacs-python-pytest (3.6.0, 8c0e048
2026-06-30), github.com/martini97/testrun.el (0.1.0, 5cd767f 2023-06-29),
github.com/johannes-mueller/test-cockpit.el (0.1.0, 1fe3b6d 2026-11-06),
github.com/mohkale/projection (898c6fc 2026-06-14), github.com/darcamo/cmake-integration
(bb766cb 2026-08-21), github.com/danlamanna/helm-ctest (b17d81e 2022-11-02, archived).
Searches: DESIGN 1's `Searches:` line. No hands-on run: nothing below was executed.

## 1. What neotest is
- **Core** (Lua, about 8800 lines, needs nvim-nio): a tree of positions (directory,
  file, namespace, test) per adapter; consumers read it: `summary` (the tree window
  with run / stop / attach / output keys), `run` (nearest, file, suite, last),
  `output` (one test's output), `output_panel` (all output over time), `diagnostic`
  (failures as `vim.diagnostic` at the failing line), `status` (a sign at each test's
  definition: passed, failed, running, skipped), `watch` (rerun on change), `jump`
  (next failed test), `quickfix`, `benchmark`.
- **Strategies:** `integrated` (a background process, its terminal attachable), `dap`
  (the adapter builds an nvim-dap configuration).
- **Adapter interface:** `root`, `is_test_file`, `discover_positions` (usually a
  tree-sitter query with `@test.name` / `@test.definition` captures, parsed by
  `lib.treesitter.parse_positions`), `build_spec` (command plus context for one
  position), `results` (map the run's output to per-test results). Results for files,
  namespaces and directories are derived from their tests.

## 2. neotest-python (1159 lines)
- Discovery: test files are `test_*.py` or `*_test.py`; a tree-sitter query on the
  Python grammar captures functions (and methods inside classes) whose name matches
  `^test`, or pytest's own `python_functions` setting read from pytest when
  `pytest_discover_instances` is on; that option (experimental) also lists
  `parametrize` instances through pytest.
- Run: its own script `neotest.py` wraps pytest (or unittest, Django's runner) with a
  pytest plugin; each finished test is written as one JSON line to a stream file
  (`--stream-file`), the whole result set to a results file (`--results-file`) at the
  end. The stream is what lets the tree update per test during a run.
- Python found from a local virtualenv, Pipenv or Poetry when not set.
- Debug: debugpy through nvim-dap (`dap` option passes its settings).

## 3. neotest-gtest (2785 lines)
- Discovery: a tree-sitter query on the C++ grammar for `TEST`, `TEST_F`, `TEST_P`,
  `TYPED_TEST`, `TYPED_TEST_P`; parameterized and typed instances from the
  executable's `--gtest_list_tests`, shown below their source declaration once an
  executable is known and the file saved.
- Executable per file: by hand (`:ConfigureGtest` in the summary, stored in a JSON file
  under Neovim's data directory), or found: `compile_commands.json` above the file
  gives the file's build directory and its target (`CMakeFiles/<target>.dir/` in the
  command), `ctest --test-dir <dir> --show-only=json-v1` gives each executable's
  `--gtest_filter` arguments (as written by `gtest_discover_tests`), and the executable
  holding most of the file's `Suite.Test` names wins (`executables/ctest.lua`).
- Run: the executable directly, `--gtest_filter=A.x:B.y --gtest_output=json:<file>`,
  grouped by executable; `process_isolation` runs one process per test. Results from
  Google Test's JSON report; a failure's `file:line` becomes a diagnostic when the
  file matches; an exit code other than 0 or 1 marks unreported tests failed.
- No build step: the owner rebuilds by hand. Debug through nvim-dap (codelldb
  recommended).

## 4. neotest-ctest (1027 lines)
- Discovery: per framework a tree-sitter query (GoogleTest `TEST`, `TEST_F`,
  `TEST_P` with `Range` / `Values` / `Bool` only; Catch2 3.3+; doctest 2.4.8+;
  CppUTest), the framework detected from the file's `#include`.
- Needs the project to register tests one by one with CMake (`gtest_discover_tests`,
  `catch_discover_tests`, ...), so CTest's names equal the framework's names; a plain
  `add_test` per executable gives one CTest test per executable, not per test.
- Build directory: the first `CTestTestfile.cmake` within three levels below the root;
  CTest 3.21 or newer.
- Run: `ctest --test-dir <dir> --quiet --output-on-failure --output-junit <file>
  --output-log <file>` plus a name filter; results from CTest's JUnit file; error lines
  from each framework's text output by regular expression (GoogleTest's `file:line:
  Failure`). Debug: the executable run directly under nvim-dap, not through CTest.
- No build step (cmake-tools recommended beside it).

## 5. Emacs: what exists
No Emacs package found with a test tree, per-test status at the definition or failures
as diagnostics, for any of pytest, GoogleTest or CTest.
- **python-pytest** (MELPA, 3.6.0): pytest only; a transient menu
  (`python-pytest-dispatch`); test or class at point by tree-sitter
  (`python-pytest-run-def-at-point-treesit`), file, last failed, repeat; runs in a
  compilation buffer, `--pdb` tracking. No parsed results, no tree.
- **test-cockpit.el** (not on an archive): transient over cargo, cask, eldev, mix,
  npm-jest, python (pytest); last test in dape for Python (debugpy, `-m pytest`). No
  C++, no tree.
- **testrun.el** (not on an archive, quiet since 2023-06-29): vim-test's model, nearest
  test by tree-sitter, run in `compile`; pytest, jest, ERT, buttercup. No C++.
- **projection** (MELPA): CMake project type; CTest tests and labels as
  `compile-multi` targets from `ctest --show-only=json-v1` (cached per build
  directory), plus `--rerun-failed`. Pick by name, no test at point, no results.
- **cmake-integration** (darcamo): `ctest --preset <preset>` or `ctest .`, with label
  include / exclude. Whole suite only.
- **helm-ctest** (archived): CTest tests by number in helm.
- Not read (R): lsp-mode's Java test explorer (lsp-treemacs); a personal
  `gtest-mode.el` (regex for `TEST(` at point, `--gtest_filter`).

## 6. What this config has
- `C-c p c t`: `ctest --test-dir <binaryDir> --output-on-failure` in a compilation
  buffer (`emacs-cpp-presets-test-command`, D-035). Whether compile's error regexps
  take GoogleTest's `file:line: Failure` lines: UNVERIFIED.
- `c++-ts-mode` and `python-ts-mode` on the system grammars (D-008, D-140), so
  tree-sitter queries like neotest's run in Emacs's `treesit-query-capture`.
- dape with gdb / lldb-dap (D-002), debug targets from CMake's file API (D-056,
  `emacs-cpp-presets-request-codemodel`).
- RMO registers 6 tests with plain `add_test` (`RESEARCH_keys_build_debug_ui.md`), so
  CTest sees executables there, not GoogleTest tests; which framework RMO's tests
  use, and how deal.II-based projects register theirs: not checked.

## 7. Pieces an Emacs equivalent needs, against what Emacs and the tools give
- **Discovery:** `treesit-query-capture` with neotest-gtest's / neotest-python's
  queries (MIT, liftable as patterns); or from the tools: `ctest --show-only=json-v1`,
  an executable's `--gtest_list_tests`, `pytest --collect-only -q`.
- **Executable for a file:** neotest-gtest's method (compilation database target,
  then CTest's `--gtest_filter` arguments), or the file API codemodel the config
  already reads (D-056): each target's sources are listed there, so the lookup needs
  no command-string parsing (not tried).
- **Run:** `compile` (keeps `next-error`) or `make-process`.
- **Results:** Google Test `--gtest_output=json:<file>`, CTest `--output-junit
  <file>` (3.21+), pytest's built-in `--junitxml=<file>`: no pytest plugin needed
  for end-of-run results; per-test updates during a run need one, as neotest-python's
  stream shows. Emacs parses JSON natively (`json-parse-buffer`) and XML with libxml
  (`libxml-parse-xml-region`, when built with it: UNVERIFIED on both machines).
- **Display:** failures as a flymake backend (eglot's diagnostics share the buffer);
  status at definitions as fringe bitmaps or overlays; a tree as a
  `tabulated-list-mode` or `outline` buffer, or a treemacs extension.
- **Debug:** dape: the executable with `--gtest_filter=<Suite.Test>` under gdb /
  lldb-dap; `debugpy` with `-m pytest <node id>` (as test-cockpit.el does).
- **Watch:** neotest's `watch` reruns on change; the config's fswatch watches (D-110)
  could signal it (not designed).
