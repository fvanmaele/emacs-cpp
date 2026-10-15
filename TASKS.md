# TASKS - work born from rulings

Fed by DESIGN rulings (open questions, parity verdicts) and spike results. A row leaves this
list only by landing as a journal entry, whose number replaces the status. Nothing here is
a commitment; order is the owner's priority.

Columns: id | status (open / next / done NNNN) | size (S / M / L) | title | source (D-nnn,
RESEARCH section, spike, owner ask) | what (one line, concrete enough to start from, ending
with `done when: ...`).

## v0.1 navigation
| id | status | size | title | source | what |
|----|--------|------|-------|--------|------|
| T-001 | done 0003 | S | spike S1 | O-1 | PASS (run 2); D-016 |
| T-009 | done 0003 | S | RMO build fixes | D-011, D-012 | RMO commit 9dc35b7 |
| T-002 | done 0002 | L | skeleton + packages | D-003, D-006 | owner confirmed 2026-10-07 |
| T-003 | done 0004 | M | completion stack | Q-3 | owner confirmed 2026-10-07 |
| T-004 | done 0017 | M | eglot + clangd | D-001, S1 | v0.1 tagged by owner |
| T-008 | done 0023 | S | performance baseline | D-010, D-038 | startup 0.36 -> 0.15 s |

- T-009 (owner, in RMO): `CMAKE_CXX_EXTENSIONS OFF`, commit `CMakePresets.json`, ignore
  `build/`; exact commands in `spikes/s1-compile-db/RUN.md`; done when: committed in RMO
  and `cmake --preset debug` writes `-std=c++20` into `build/debug/compile_commands.json`.
- T-002: `early-init.el`, `init.el`, `lisp/init-project.el` (projectile, treemacs, theme
  moved from `~/.emacs`), `.gitmodules` + `lib/` submodules for the project, tree, git
  and owner's-existing groups of DESIGN 12, `scripts/build-packages.el`, `make
  packages`, `make test` (ERT for the build script + batch load of `init.el`); done
  when: `make packages && make test` pass, the owner symlinks per the handed-over
  commands and retires `~/.emacs`, and Emacs starts with no errors and the same theme,
  projectile, treemacs and magit behaviour as before.
- T-003: completion group of DESIGN 12 added as submodules and configured; drop the
  `projectile-consult.el` build-exclude once consult is vendored; done when:
  `C-x b`, `C-c p f`, `consult-ripgrep` show vertico candidates with annotations in the
  reference project, and corfu pops up completions while typing in an Emacs Lisp
  buffer. (Changed 2026-10-07 from "eglot completions": eglot arrives in T-004, whose
  done-when now carries that check; consult-eglot moved to T-004.)
- T-004: eglot on `c++-ts-mode`, clangd given the active preset's build directory
  (D-016), error if the database lacks `-std` (D-011); done when: in the
  reference project `M-.` crosses files, `M-?` lists usages, `eglot-rename` renames
  across files, a clang-tidy warning shows in flymake, and corfu shows clangd
  completions (on TAB / C-M-i since D-020); consult-eglot vendored and
  `consult-eglot-symbols` lists project symbols. Owner check 2026-10-08: usages,
  completion, consult-eglot-symbols, M-. into libraries OK; M-. inside library headers
  and auto-start fixed by D-019; rename works (owner, 2026-10-08, slow before D-026).
  clang-tidy: a `.clang-tidy` finding reaches eglot (toy, 2026-10-08; RMO now has a
  `.clang-tidy`; owner 2026-10-08: findings appear in flymake). Closed with the v0.1
  tag (0017).
- T-008: measure DESIGN 11 budgets (`emacs-init-time`, clangd numbers from S1) after
  T-004; done when: numbers are in DESIGN 11 and each tuning setting cites one. Done
  2026-10-08 (0023): startup, GC and LSP-reply numbers in DESIGN 11, D-038.

## Later
| id | status | size | title | source | what |
|----|--------|------|-------|--------|------|
| T-005 | done 0021 | M | presets build | D-005, D-035 | owner: RMO checked, v0.2.0 |
| T-006 | done 0019 | M | dape debugging | D-031, D-033 | owner: RMO checked, v0.2.0 |
| T-007 | done 0025 | S | `C-c l` map | D-004 | 12 keys, which-key lists them; test |
| T-010 | done 0024 | S | Info manuals | D-039 | `C-h i` lists magit (projectile: none) |
| T-011 | done 0015 | M | cold-header flags | O-5, D-028 | owner: RMO headers clean |
| T-012 | rejected (D-021) | M | preamble warm-up | S5 | owner ruled out extra open files |
| T-013 | closed (D-026) | L | ccls + clang-tidy | D-023, D-024 | branch kept, not merged |
| T-014 | done 0014 | M | patched clangd | D-026, D-027 | owner: RMO M-. works (pkgrel 3) |
| T-015 | done (tier 1) | S | treemacs-magit | v0.4 | loaded with treemacs + magit; test |
| T-016 | done 0026 | M | diff-hl | D-042, v0.4 | right fringe, follows magit; test |
| T-017 | done 0026 | M | breadcrumb | D-043, v0.4 | path + function in header; test |
| T-018 | done 0030 | M | Python rides along | D-045, O-19 | mode, pyright, debugpy; tests |
| T-019 | done 0029 | S | header first: 0006, 0007 | D-046, D-047 | S9 run 3: 0.9 s |
| T-020 | done 0041 | S | patch 0008 (review 0031) | D-059 | S9 run 4 unchanged |
| T-021 | done 0034 | M | config starts on macOS | D-050, D-054 | Arch make test 54 / 54 |
| T-022 | done 0035 | M | lldb-preset | D-051, O-22 | Arch session test 3 / 3 |
| T-023 | open | M | macOS clangd build script | D-052, O-23 | built 0036; owner run left |
| T-024 | open | M | platform defaults files | D-055 | ruled; code done-when proposed |
| T-025 | open | M | Python tools on macOS | owner | round 1 in RESEARCH doc |
| T-026 | open | L | setup wizard (doom doctor) | owner | research; proposed |
| T-027 | open | S | load measurements, macOS | owner, O-24 | Mac measured 0038; Arch left |
| T-028 | done 0037 | S | review debug and presets code | owner | 5 taken, O-25 to rule |
| T-029 | done | M | file watches on macOS | owner, D-054 | RESEARCH doc; O-26 ruled |
| T-030 | done 0040 | M | targets via CMake file API | D-056, O-25 | Arch make test ok |
| T-031 | done 0039 | M | platform defaults files | D-055, T-024 | debugger offered first |
| T-032 | open | S | send the eglot watch report | D-054, O-26 | owner sends the draft |
| T-033 | done 0042 | M | patch 0009: re-index flagged shards | D-060 | S9 run 4 unchanged |
| T-034 | done | S | indent-guessing packages | owner | RESEARCH doc; O-28 ruled, D-061 |
| T-035 | done 0043 | M | RET indents by clangd | D-061 | superseded by D-065 |
| T-036 | open | S | send the c++-ts-mode namespace report | D-061 | owner sends the draft |
| T-037 | open | S | send the c-ts-mode local style report | owner | owner sends it |
| T-038 | done 0044 | S | indentation from plain dir-locals | D-062 | RMO data-only |
| T-039 | open | S | c-ts-mode report: member after blank line | D-062 | owner sends it |
| T-040 | done | M | rules: case labels, argument lines | D-065 | 62 lines left |
| T-041 | open | S | send the treemacs follow-mode-off report | D-067 | owner sends it |
| T-042 | done 0045 | S | warn on a source not in the database | D-068 | probe gap, fixed |
| T-043 | open | S | pyright test failed once | none | capture the condition |
| T-044 | done 0046 | M | patch files for submodules | D-069 | treemacs 0001 first |
| T-045 | done | M | cells, notebooks, Quarto (Python, R) | owner | RESEARCH; O-29 |
| T-046 | done 0047 | M | Python and R cells, ESS | D-072 | owner's RMO check left |
| T-047 | done | S | research: go to anything prompt | owner | RESEARCH; O-30 |
| T-048 | done 0048 | S | spike S11: go to anything costs | D-074 | FAIL in one part |
| T-049 | done 0050 | M | go to anything prompt | D-074 | run 3 PASS, hand check PASS |
| T-051 | done 0049 | S | spike S11 run 2: the whole prompt | D-077 | PASS |
| T-052 | done | S | research: `M-o` narrowed to symbols | owner | RESEARCH 9; O-34 |
| T-053 | open | S | send the consult hidden-sources report | D-079 | owner sends it |
| T-054 | done 0053 | S | S11 run 4: narrowed, a deal.II project | D-079 | recorded |
| T-055 | done 0052 | S | consult patch 0001: hidden sources | D-079 | stand-in measured |
| T-050 | done | S | research: go to anything speed | owner | RESEARCH 8; O-33 |
| T-056 | done 0054 | S | narrow keys 0.2 s after `<` | D-080 | test, terminal check |
| T-057 | done 0055 | S | `C-c p ?` over projectile's files | D-081 | Mac measured |
| T-058 | open | S | send the projectile find-references report | D-081 | owner sends it |
| T-059 | done | S | S11 run 5: project symbols among clangd's | O-37 | RESULTS run 5 |
| T-060 | done 0056 | S | `M-o` project symbols, all on `l` | D-082 | toy with clangd |
| T-061 | done 0057 | S | project symbols: cap, encoding, case | D-083 | step-1, toys |
| T-062 | done 0058 | S | one URI matcher for every server | D-085 | clangd, pyright |
| T-063 | done 0059 | S | `< l` lists as `C-c l s` | D-086 | terminal check |
| T-064 | done 0060 | S | `M-o` previews after a pause | D-088 | terminal check |
| T-065 | done 0061 | M | LaTeX: AUCTeX, texlab, `C-c l b` | D-090, D-091 | Mac hand-on |
| T-066 | done 0062 | S | navigation clicks, right-click menu | D-093 | tests, clangd |
| T-067 | open | S | side buttons: back / forward | O-44 (c) | owner's `C-h k` |
| T-068 | done 0063 | S | clang-tidy fixes, clang-move | D-094 | generated project |
| T-069 | done 0066 | L | spike S12: change signature | O-43 (b) | FAIL; to owner |
| T-070 | open | S | send the clang-change-namespace report | D-094 | owner sends it |
| T-071 | done 0064 | S | yasnippet, collection; `C-c y` | D-095 | tests; Mac hand check |
| T-072 | done 0065 | S | patched clang-change-namespace, `C-c l N` | D-097 | generated |
| T-073 | done 0067 | S | macOS: patched clangd at LLVM 23.1.3 | D-100 | Mac build |
| T-074 | done 0068 | S | LaTeX: `C-c l f` by latexindent | D-101 | tests, real texlab |
| T-075 | done | S | research: clangd path filter for symbols | owner | RESEARCH 13; O-52 |
| T-076 | done | S | research: clangd patch, symlinked paths | owner | RESEARCH 2.8; O-50 |
| T-077 | open 0069 | M | spike S13: symlinked paths | O-50 (c) | PASS Arch; Mac |
| T-078 | done 0070 | S | latexindent: project settings, indent | D-103 | tests, texlab |
| T-079 | open | S | send the texlab range formatting report | D-101 | owner sends it |
| T-080 | done 0071 | S | `make test` in a temporary HOME | D-104 | real home unchanged |

- T-005: done when: preset build errors jump to source. Code and tests: 0021 (C-c p c
  o / c c / c t on the active preset from any buffer, D-035). Left: the owner's RMO
  check. Owner 2026-10-08: RMO check passed (v0.2.0, 0022).
- T-006: dape `gdb-preset` (D-031, D-032); done when (agreed 2026-10-08): in RMO with
  the `debug` preset, `C-x C-a d gdb-preset RET`, picking `main`, builds it and stops at
  a breakpoint in `src/main.cc` with stack, Locals (incl. `opts`) and a watch shown;
  step over, step in and quit work, no gdb left; with `emacs-cpp-debug-lazy-symbols` t
  the first stop takes about 2 s instead of 17 s; ERT covers program choice, gdb
  arguments, refusals and a toy session; make check / make test pass. Code and tests:
  0019. Owner's first RMO try: no program offered (build/debug never built); targets
  now come from build.ninja (D-033, 0020). Owner 2026-10-08: RMO check passed
  (v0.2.0, 0022).
- v0.4 rows (opened 2026-10-08, owner): T-007 also covers inlay hints, which eglot 31
  already turns on in every managed buffer; `C-c l I` toggles them. T-007 done when:
  every D-004 letter under `C-c l` runs its command (test), which-key lists them.
- T-016: done when: in a git file buffer, changed lines are marked in the right
  fringe (margin in a terminal), refreshed after magit stages or commits; test on a
  toy repository.
- T-017: done when: C++ buffers show the project-relative path and the function at
  point in the header line; test on a toy project.
- T-018 (opened 2026-10-08, O-19): needs `sudo pacman -S tree-sitter-python pyright
  python-debugpy` (owner). Done when: `.py` files open in `python-ts-mode` (startup
  stops with the fix if the grammar is missing, as for C++); eglot starts pyright in
  Python files of a project (`pyproject.toml`, `setup.py` or a git root), not in files
  outside one; `M-.` and `C-c l r` work through it; dape's `debugpy` config stops at a
  breakpoint in a toy script; the C++ tests unchanged; make test / make check pass.
- T-019: done when (agreed 2026-10-08): a clangd unit test asks a header's command
  before the project broadcast and gets the includer's; ClangdTests all pass; pkgrel 4
  carries 0006; S9 rerun on RMO (owner): header first 10 / 10 from the index, 0
  errors, decision under 1.5 s after opening; make test passes. Code, tests, package:
  0028. S9 run 2 (pkgrel 4): 10 / 10 from the index, 0 errors, but 1.48 - 1.56 s
  (5 of 10 over 1.5 s); owner chose patch 0007 (0029, pkgrel 5), same done-when.
  S9 run 3 (pkgrel 5, owner 2026-10-08): 10 / 10 from the index, 0 errors, 0.91 -
  1.02 s after opening; make test 42 / 42 with pkgrel 5. Done.
- T-020 (opened 2026-10-08 by the code review, 0031): patch 0008 for the local clangd:
  `includerOf` looks up a known includer before waiting for the compile database (no
  stall while its broadcast thread is busy with another project, nor for headers that
  have no includer); the load counter's increment and decrement paired in one place;
  the long doc comment of 0007 wrapped at 80 columns. Done when: ClangdTests pass, a
  unit test shows a known includer answered while the database is busy, pkgrel 6
  built, S9 unchanged on RMO (owner). Owner 2026-10-09: build now. Built 2026-10-09
  (0041): ClangdTests 1413 / 1413 on macOS with the new test (fails without the
  change), PKGBUILD pkgrel 6, `build-macos.sh` builds it. Owner 2026-10-09 went
  straight to pkgrel 7 (0008 and 0009) on Arch; S9 run 4 on RMO: header first 10 / 10
  from the index, 0 errors, 0.85 - 0.90 s after opening (run 3: 0.91 - 1.02 s). Done.
- T-021 (opened 2026-10-09, D-050): make the config start and test cleanly on the
  owner's Mac (DESIGN 3 macOS observations). Known so far: `init-cmake.el` names only
  `/usr/share/emacs/site-lisp` (MacPorts: `/opt/local/share/emacs/site-lisp`);
  `${hostSystemName}` in presets is an error outside GNU/Linux; a build-script test
  fails on `/var` vs `/private/var`; the other 14 failures not yet examined (most may
  follow from the startup stop). Tier 2. PROPOSED done when (owner to agree): Emacs
  starts on the Mac with no errors; `make test` passes there except tests that need
  gdb or the patched clangd, which skip with a reason until T-022 / T-023 land;
  `make test` still passes on Arch. Agreed 2026-10-09. Built 2026-10-09 (0034): the
  Mac part is met (startup clean, the gdb tests skip, the rest pass). Arch
  2026-10-09: `make packages && make test` 54 / 54, none skipped. Done.
- T-022 (opened 2026-10-09, D-051): `lldb-preset` in `lisp/init-debug.el`, built like
  `gdb-preset` from dape's `lldb-dap` configuration; lldb-dap from the Arch `lldb`
  package and, on macOS, the MacPorts `lldb-23` port (D-053; its installed name not yet
  checked). Tier 2. PROPOSED done when (owner to agree): `C-x C-a d lldb-preset RET`
  picks a target of the active preset, builds it, stops at a breakpoint and steps, on
  Arch and on the Mac; a missing lldb-dap refuses the session with the fix; an ERT
  test like `init-debug-gdb-preset-builds-stops-and-steps` covers it; the gdb tests
  are unchanged; make test passes on Arch. Agreed 2026-10-09. Built 2026-10-09
  (0035): on the Mac the session test passes (3 of 3 runs) and the refusal test.
  Arch 2026-10-09 (lldb 23.1.1, `/usr/bin/lldb-dap`): make test 54 / 54, the session
  test 3 of 3 runs, the refusal and gdb tests pass. Done.
- T-023 (opened 2026-10-09, D-052): a script (NEW, proposed
  `packaging/clangd-index-nav/build-macos.sh`) doing the steps of `docs/CHEATSHEET.md`
  macOS item 6: download the 23.1.1 tarball into `packaging/clangd-index-nav/`
  (git-ignored), check the PKGBUILD's sha256, apply every patch the PKGBUILD lists,
  build clangd and the builtin headers with MacPorts cmake and ninja, check both hidden
  flags, install to `~/opt/clangd-index-nav`. Tier 2. PROPOSED done when (owner to
  agree): run by the owner on the Mac, it installs a clangd that lists
  `--navigation-from-index` and `--header-flags-from-index`; a wrong checksum, a patch
  that does not apply or a missing tool stops it with the reason;
  `init-cpp-patched-clangd-navigates` passes on the Mac with that clangd; the steps in
  CHEATSHEET are replaced by a pointer to the script. Agreed 2026-10-09. Built
  2026-10-09 (0036): a test run into scratch directories (owner's tarball, no
  download) installed a clangd with both flags, and the test passes with it; the
  failure paths stop with the reason; left: the owner's run to `~/opt`.
- T-024 (opened 2026-10-09, owner): consider separate initialization files per
  platform, with different defaults (Linux: gdb, macOS: lldb). Today the platform
  differences are `system-type` branches inside the modules: cmake-mode's directory
  (`init-cmake.el`), eglot's file watches (`init-cpp.el`, D-054), lldb-dap's path
  (`init-debug.el`), `${hostSystemName}` (`emacs-cpp-presets.el`). Touches the load
  model (DESIGN 5: module order is the contract; one `use-package` form per package).
  PROPOSED done when (owner to agree): a DESIGN section rules between per-platform
  files and inline branches, lists every platform branch, and names how the default
  debugger is chosen at `C-x C-a d`; code only after that ruling. Ruled 2026-10-09
  (D-055): separate files for defaults only, platform differences stay in the
  modules; the code's done-when is proposed in D-055.
- T-025 (opened 2026-10-09, owner): research functional alternatives to pyright and
  debugpy on macOS; evaluate performance and stability. Seen so far: pyright exited
  when Emacs ran out of file descriptors (fixed by D-054); the debugpy test failed
  twice under load because dape waits a fixed 3 s for the adapter (0034). Candidates
  to check, not yet verified: basedpyright, python-lsp-server, jedi-language-server,
  Astral's ty, Meta's pyrefly; for debugging, other DAP adapters for Python if any.
  PROPOSED done when: `RESEARCH_python_macos.md` with, per candidate on the Mac,
  startup, memory, `M-.` / rename / diagnostics on a toy and a real project, and
  failures over repeated runs (idle and under load); verdicts then ruled in DESIGN.
  Round 1 2026-10-09 in `RESEARCH_python_macos.md`: six servers on three projects
  (no crash in 64 sessions; ty fastest but blind to user site-packages, pyrefly's
  references limited to the open file, pylsp the only ported alternative); debugpy
  misses dape's 3 s wait 7 of 10 times under load. Left: the items of its section 4.
- T-026 (opened 2026-10-09, owner): research a setup wizard like Doom Emacs's `doom
  doctor` / `doom install`: initialize the submodules and `make packages`, offer to
  build the patched clangd (makepkg on Arch, `build-macos.sh` on macOS) and set
  `emacs-cpp-clangd-program`, back up `~/.emacs` and `~/.emacs.d`, create the two
  symlinks, and check the system tools per platform. Touches the owner's live
  configuration (DESIGN 4 principle 5) and adds a network step (D-014).
  PROPOSED done when: `RESEARCH_setup_wizard.md` describing what doom's commands check
  and do, the checks this config needs on Arch and macOS, a dry-run mode, how a
  backup is restored, and shell vs Emacs Lisp; a DESIGN ruling before any code.
- T-027 (opened 2026-10-09, owner; O-24 b): further load measurements, macOS included
  in DESIGN 11. First number: startup 0.77 - 1.23 s on the Mac under load 4 (0034)
  against 0.15 s on Arch (D-038). PROPOSED done when: `scripts/measure-startup.sh`
  on both machines idle (10 runs each) plus the first `M-.` and memory on RMO, the
  numbers in DESIGN 11 per platform, and O-24 (b) put to the owner with them. Mac
  part measured 2026-10-09 (0038): startup, first `M-.` stock / patched, memory, in DESIGN
  11; O-24 (b) has the numbers. Left: the Arch runs (owner, commands in 0038).
- T-028 (opened 2026-10-09, owner): code review of `lisp/init-debug.el` and
  `lisp/emacs-cpp-presets.el` for simplicity and against hardcoded or brittle parsing
  (the build.ninja regular expressions, which already broke on CMake 3.31 in 0034;
  the preset macro expansion; the platform paths). D-033 rejected CMake's file API
  before; the review may reopen it. PROPOSED done when: a review journal entry with
  findings, each taken or not taken with a reason, and the taken ones fixed with
  tests. Done 2026-10-09 (0037): preset conditions, `$env{}` as CMake, lldb-dap by
  name, one build step; the file API instead of build.ninja is O-25.
- T-046 (opened 2026-10-10, D-072): code-cells and ESS as submodules, configured. Tier
  2. Done when (agreed 2026-10-10): `lib/code-cells` (b99013b) and `lib/ess` (v25.01.0,
  `load-path = lisp`, `info = doc/ess.texi`) are submodules and `make packages` builds
  them without errors; `.R` files open in `ess-r-mode`, no eglot for R; in
  `python-ts-mode` and `ess-r-mode` buffers `code-cells-mode` is on: `C-c C-c` runs the
  cell at point in the buffer's REPL (`run-python` or R, started if needed, R in the
  project root without a question), `M-n` / `M-p` move between cells, `C-c % s` runs and
  steps, Python's send-buffer stays on a key; ERT: Python and R cells share state (cell
  2 sees cell 1's variable; R tests skipped with a message where R is missing), the
  keys, `ess-r-mode` for `.R`, R's start directory; `make test` passes on Arch; MANUAL,
  cheat sheet, README (R from pacman `r` / MacPorts `R`), DESIGN 12 updated; startup
  median on Arch within D-057's budget; owner: an RMO R script and a plotting script
  with `# %%` cells run cell by cell. Built 2026-10-10 (0047): all met but the owner's
  RMO check; startup median 0.161 s.
- T-049 (opened 2026-10-11, D-074): the go-to-anything command in
  `lisp/init-completion.el` (`consult--multi`, sources as D-074) on the key O-31
  rules (D-076: `M-o`), with D-077's speed settings. Tier 2. Done when (proposed
  2026-10-11, owner agrees before code): `M-o` opens one prompt from any buffer;
  buffers, recent files, bookmarks and the project's files (listed before the
  prompt opens, S11 run 2 finding 3) from the first key, clangd symbols from the
  third, no request for an empty input, commands and project roots behind narrow
  keys; D-077's settings bound only around the prompt; `make test` covers the
  sources, the empty-input rule and the key; S11 run 2's criteria hold on RMO when
  `prompt.sh`'s timing is repeated against the shipped command; owner's hand check
  on RMO and the deal.II tree. Agreed 2026-10-11. Built 2026-10-11 (0050): all met
  but the owner's S11 run 3 on RMO and hand check; 80 tests; startup median 0.179 s.
  S11 run 3 PASS 2026-10-11 (0051): opening 54 - 74 ms, keys 2 - 30 ms, symbols
  122 - 150 ms on RMO. Owner's hand check 2026-10-11: pass. Done.
- T-082 (opened 2026-10-15, owner): research a theme following the OS's dark / light
  setting, stage 1 macOS. Done when: `RESEARCH_dark_theme.md` with what Emacs 31.1's
  NS build offers, how to read the setting and its cost, options. Done 2026-10-15:
  options as O-56.
- T-081 (opened 2026-10-15, owner): research fuzzy matching in `M-o` and `C-c l s`.
  Done when: `RESEARCH_go_to_anything.md` 14 with each prompt's matcher, checked
  by hand, options. Done 2026-10-15: options as O-55.
- T-080 (opened 2026-10-14, D-104, O-54 (b)): tests in a temporary HOME. Done when:
  `make test` creates an empty temporary HOME (mktemp -d), runs ERT with HOME set to
  it, deletes it afterwards, keeps ERT's exit status. The runner checks first, in that
  Emacs, that HOME is not the real home (`~` vs `~USER`) and stops with an error
  otherwise. `make test REAL_HOME=1` runs in the real HOME as before, no check. Test
  files unchanged; they still run by hand in any HOME; the 7416ce8 project-list-file
  redirect stays. Evidence: make test on the Mac leaves the real home unchanged
  (snapshot before/after, ~/.python_history included), REAL_HOME=1 still passes, the
  check refuses when the temporary HOME is bypassed. Arch run by the owner. DESIGN
  D-104 resolves O-54; CLAUDE.md Tests and README note REAL_HOME; journal. Agreed
  2026-10-14. Done 2026-10-14 (0071): met on the Mac; Arch run left (owner).
- T-079 (opened 2026-10-14, D-101, D-103): send
  `docs/upstream/texlab-range-formatting.md` to texlab's issue tracker (github.com/
  latex-lsp/texlab); outward, so the owner sends it. Done when: sent, issue number
  noted here.
- T-078 (opened 2026-10-14, D-103, O-53 (a), (b)): latexindent as texlab runs it.
  Done when: C-c l f (buffer and region) passes --local and runs latexindent from the
  nearest directory upward (within the project) with .latexmkrc / latexmkrc /
  .texlabroot / texlabroot, else the file's directory. Without a yaml there
  (localSettings.yaml, .localSettings.yaml, latexindent.yaml, .latexindent.yaml) and
  without a user indentconfig.yaml (~/indentconfig.yaml, ~/.indentconfig.yaml,
  ~/.config/latexindent/indentconfig.yaml) it adds -y=defaultIndent: with
  LaTeX-indent-level spaces, a tab when indent-tabs-mode. Tests: project yaml
  defaultIndent "    " gives 4 spaces (also from a subdirectory with .latexmkrc
  above); no yaml gives 2 spaces (AUCTeX's level); indent-tabs-mode gives a tab;
  existing tests adjusted; make test on the Mac. DESIGN D-103 (amends D-101, resolves
  O-53), journal. Agreed 2026-10-14. Done 2026-10-14 (0070): met on the Mac.
- T-077 (opened 2026-10-14, owner: "spike for (c)"): spike S13, clangd patch naming
  the background index's main files by their real directory
  (`spikes/s13-symlinked-paths/RUN.md`, pass criteria proposed 2026-10-14). Done
  when: RESULTS.md has a verdict on criteria 1 - 5. Arch 2026-10-14 (0069): criteria
  1 - 4 PASS. Left: the owner confirms the criteria; criterion 5, the owner's Mac run
  under `/tmp`.
- T-076 (opened 2026-10-14, owner, O-50 (c)): research a clangd patch for projects
  reached through a symlink. Done when: `RESEARCH_platform_differences.md` 2.8 with
  the comparison that drops the main file, the patch's place and cost, what a spike
  checks. Done 2026-10-14; the Arch run of 2.6 recorded there.
- T-075 (opened 2026-10-12, owner): research a server-side path filter for `M-o`
  symbols (project files only, `a` for all). Done when: `RESEARCH_go_to_anything.md`
  13 with clangd's request path, why existing knobs do not fit, options. Done
  2026-10-12: options as O-52.
- T-074 (opened 2026-10-14, D-101, O-51 (a)): LaTeX formatting by latexindent.
  Done when: `C-c l f` in a LaTeX buffer with an active region writes the buffer to a
  temporary directory, runs `latexindent -c DIR --lines A-B` (the region's lines) and
  replaces only those lines (the rest and point kept, one undo step); without a
  region latexindent formats the whole buffer (owner, amended: latexindent for both,
  not texlab); latexindent missing or exit != 0: user-error with the fix or its
  stderr, buffer untouched. Tests: real latexindent (skipped if absent) changes only
  the region's lines and matches the buffer result there; stubbed failure and missing
  program; make test on the Mac. DESIGN D-101, CHEATSHEET, journal. Agreed
  2026-10-14. Done 2026-10-14 (0068): met on the Mac; 111 tests.
- T-073 (opened 2026-10-14, D-100): the patched clangd on macOS at LLVM 23.1.3.
  Done when: build-macos.sh builds 23.1.3 with patches 0001 - 0009, checksum-checked;
  run on the Mac it installs to ~/opt/clangd-index-nav a clangd whose `--version`
  says 23.1.3 and that lists both hidden flags; `init-cpp-patched-clangd-navigates`
  and make test pass on the Mac; DESIGN (D-100), README and a journal entry updated.
  Agreed 2026-10-14. Done 2026-10-14 (0067): installed, 23.1.3 with both flags;
  make test 107 / 109, 2 skipped (gdb); one flaky lldb timeout on a first run.
- T-072 (opened 2026-10-14, D-097): clang-change-namespace with the crash fix. Done
  when: packaging/clang-change-namespace/: the patch file and a build script (Mac:
  against MacPorts' llvm-23 into ~/opt/clang-change-namespace; Arch: against the
  system clang, same script) with the program path as a defcustom (refused loudly
  when missing). `C-c l N` asks old and new namespace, runs the tool on all sources
  of the database in a compilation buffer, then replaces `old::` with `new::` in the
  project's files through an editable list (as MANUAL 8's namespace route) for
  review. Run on a generated project: compiles after; tests with stubbed processes;
  make test. Agreed 2026-10-14. Done 2026-10-14 (0065): met on the Mac; the script
  not run on Arch (owner); 108 tests.
- T-071 (opened 2026-10-14, D-095, O-45 (b)): snippets. Done when: yasnippet 0.14.3
  (GNU ELPA git) and yasnippet-snippets 1.0 (NonGNU ELPA git) as pinned submodules;
  yasnippet on in code and LaTeX buffers; `C-c y` expands a snippet key before point;
  TAB / S-TAB next / previous field only while a snippet is active, corfu's popup
  keeping TAB; TAB elsewhere unchanged (D-020); clangd completions insert argument
  placeholders (eglot announces snippets). Tests: keys, TAB unchanged without a
  snippet, field moves, a collection snippet expanding in c++-ts-mode,
  python-ts-mode, LaTeX-mode; startup cost measured (snippets loaded on first use if
  > ~20 ms); Mac hand check; make test. Agreed 2026-10-14. Done 2026-10-14 (0064):
  all met but the owner's Mac hand check; the collection pinned to the branch tip,
  not the 1.0 commit (D-095); it loads on first use (130 - 150 ms); 105 tests.
- T-070 (opened 2026-10-14, D-094): send
  `docs/upstream/clang-change-namespace-multiple-sources.md` to LLVM's issue
  tracker; outward, so the owner sends it. Done when: sent, issue number noted here.
- T-069 (opened 2026-10-14, O-43 (b)): spike S12, a change-signature code action in
  clangd (`spikes/s12-change-signature/RUN.md`, pass criteria agreed 2026-10-13).
  Done when: RESULTS.md with a verdict against them. Done 2026-10-14 (0066): FAIL;
  0 wrong edits, but 5 of 9 operations break on calls in templates the index cannot
  settle (reported, not edited); clangd 57 - 259 ms, the whole command 1.7 - 5.1 s.
- T-068 (opened 2026-10-13, D-094, O-43 (c)): commands around clang's tools. Done
  when: `C-c l T` run-clang-tidy -fix (checks asked), `C-c l N` clang-change-namespace,
  `C-c l M` clang-move, each in a compilation buffer on the active preset's
  database, buffers reverted; tool directory a D-055 default, checked loudly; tests
  with stubbed processes; a run of each on a generated project. Agreed 2026-10-13.
  Done 2026-10-14 (0063): T and M met; N not built (the tool crashes, D-094); 100
  tests.
- T-067 (opened 2026-10-13, O-44 (c)): the mouse's side buttons for back / forward
  (`xref-go-back` / `xref-go-forward`). Owner first: in the Mac's Emacs, `C-h k` then
  the back button, and the forward button; report the event names (or that nothing
  arrives). Done when: bound to the events reported, test.
- T-066 (opened 2026-10-13, D-093, O-44 (a), (b2)): navigation clicks and the
  right-click menu. Done when: Cmd+Click (Mac) / Ctrl+Click (Arch) definition, or
  references on the definition; Opt / Alt implementations; Shift type; right click
  a menu with the server's entries; tests for the bindings per platform, the
  definition / references choice, the menu; owner's hand check in the GUI, Arch by
  the owner. Agreed 2026-10-13. Built 2026-10-13 (0062): all met but the owner's
  checks; 96 tests. 2026-10-14 (owner): Super instead of Ctrl on Arch, Ctrl's clicks
  kept.
- T-065 (opened 2026-10-13, D-090, O-42 (b)): LaTeX with AUCTeX and texlab. Done
  when: AUCTeX 14.2.0 as a submodule from GNU ELPA's git (pinned to the 14.2.0
  commit), built by `make packages` with its manual, one `use-package` form; `.tex`
  opens in AUCTeX's `LaTeX-mode`; texlab through eglot for `LaTeX-mode` /
  `bibtex-mode` files of a project, named explicitly; `C-c l b` builds through texlab
  (asynchronous, status in the echo area) and shows the line in the viewer (Skim on
  macOS, zathura on Arch, D-055); AUCTeX's keys unchanged; tests: mode, eglot
  program, build request and its report, viewer per platform; hand-on check on the
  Mac; `make test`; owner's hand check; zathura on Arch by the owner. Agreed
  2026-10-13. Done 2026-10-13 (0061): all met but the owner's two checks; 93 tests.
  With it D-091 (owner): eglot's form moved to lisp/init-lsp.el.
- T-064 (opened 2026-10-13, D-088, O-41 (b)): `M-o` previews 0.3 s after typing,
  at once when browsing. Done when: `M-o` binds that preview key; other prompts
  unchanged; terminal check: `answer` at 50 ms per key on a session's first `M-o`
  handles every key without the freeze, preview after the pause, `<down>` previews
  at once; test that the setting is bound; `make test`. Agreed 2026-10-13. Done
  2026-10-13 (0060): all met; 90 tests.
- T-063 (opened 2026-10-13, D-086, owner's T-060 hand check): `M-o` `< l` behaves as
  `C-c l s`. Done when: empty input asks clangd for "" and lists its 100; 1 - 2
  characters keep that list; from 3, clangd's matches; `s` unchanged; opening `M-o`
  sends no extra request; test for the request steps; terminal check on the toy
  (empty 100, a 100, an 100, ans 15, as `C-c l s`); `make test`. Agreed 2026-10-13.
  Done 2026-10-13 (0059): all met; requests at opening 0; 89 tests.
- T-062 (opened 2026-10-13, D-085): replace D-083's per-server spellings. Done
  when: the spellings go; a symbol is kept when its URI starts with the root's safe
  prefix and, decoded, with the root path (as given or true name), ignoring case on
  macOS; tests: four spellings x three roots, sibling and library not, upper case on
  macOS only, symlinked root, `%` in the root's name; clangd and pyright under toy,
  TOY, `c++ (x)@y`, `a:b` + U+00E4, `py a:b c++` list the project's symbols; filter
  <= 5 ms per 6673 symbols as shipped; `make test`. Agreed 2026-10-13. Done
  2026-10-13 (0058): all met, 3.7 - 4.2 ms; 88 tests. Owner's hand check 2026-10-13
  (`M-o` `typ` in step-1): pass.
- T-061 (opened 2026-10-13, D-083): risks of D-082 measured; cap and filter fixes.
  Done when: defcustom `emacs-cpp-go-symbol-limit`, default 10000 (0 = none), sent
  as clangd's limit for `s`; a reply reaching it shows a message; the root also
  matched in clangd's encoding, and ignoring case on macOS; tests for each; the toy
  checks re-run (`TOY/`, `c++ (x)@y` give 2); `make test`. Agreed 2026-10-13. Done
  2026-10-13 (0057): toys 2 / 2 / 2; step-1 `typ` at 5000: 87 and the message, at
  10000: 111; 87 tests.
- T-060 (opened 2026-10-13, D-082): `M-o` `s` lists the project's symbols, hidden
  `l` all of them. Done when: `s` asks clangd with limit 0 and lists only symbols
  whose URI is under the project root (as projectile gives it or its true name);
  hidden `l` ("All Symbols") lists clangd's best 100 of everything, as `s` did;
  `C-c l s` unchanged; tests for the request's parameters and filter, the sources
  and keys; `make test`; owner's hand check: `M-o` `opt` and `< l` in step-1. Agreed
  2026-10-13. Built 2026-10-13 (0056): all met but the owner's hand check; 86 tests.
  The `s` part passed in the owner's checks of D-083 and D-085 (`M-o` `typ`, step-1);
  `< l`: owner 2026-10-13, empty input listed nothing (`opt`: deal.II and the
  standard library) -> T-063, D-086.
- T-059 (opened 2026-10-13, O-37): owner runs S11 run 5
  (`spikes/s11-go-to-anything/scope.sh`, RUN.md run 5) on RMO. Done when:
  `results-run5.log` handed back and RESULTS.md has run 5; O-37 then goes to the
  owner with the numbers. Done 2026-10-13 (owner ran it on `~/CLionProjects/step-1`
  on the Mac, not RMO): no limit loses nothing, slowest 15.9 ms.
- T-058 (opened 2026-10-13, D-081): send
  `docs/upstream/projectile-find-references-file-list.md` to projectile's issue
  tracker; outward, so the owner sends it. Done when: sent, issue number noted here.
- T-057 (opened 2026-10-13, D-081): projectile patch 0001, `C-c p ?` over
  projectile's file list with the platform's search program. Done when: on the Mac,
  `C-c p ?` for `make_array_view` in deal.II lists its matches in about 12 s or less
  (from 156 s); a test on a toy project gives tracked and untracked files, not
  git-ignored ones, and fails without the patch; startup fails loudly without the
  program; `make test`; owner measures on Arch. Agreed 2026-10-13. Built 2026-10-13
  (0055): 10.6 - 11.3 s, same 607 / 9429 matches; all met but the owner's Arch
  measurement and hand check.
- T-056 (opened 2026-10-12, D-080): which-key lists consult's narrow keys 0.2 s
  after `<` in any prompt that has them. Done when: in such a prompt, `<` lists them
  after about 0.2 s; ESC, `C-x` and other prefixes still wait 3 s, in the prompt and
  outside it; after the prompt closes every prefix waits 3 s again; an ERT test
  checks the delays for `<` and ESC inside and outside a prompt; owner's hand check
  with `M-o` and `C-x b`. Agreed 2026-10-12. Built 2026-10-12 (0054): all met but
  the owner's hand check; 82 tests.
- T-055 (opened 2026-10-11, D-079): consult patch 0001 (D-069) and narrowing with `<`
  documented. Done when (from O-34 (a), (c)): narrowed to symbols on the stand-in
  tree, updates at most about 5 ms per key; widening brings the files back; a test
  fails without the patch. Done 2026-10-11 (0052): 0.2 - 4.2 ms; widening about 30 ms;
  `init-completion-go-narrowing-drops-hidden-candidates` fails unpatched (renamed
  `init-go-to-anything-narrowing-drops-hidden-candidates`, D-099).
- T-054 (opened 2026-10-11, owner): S11 run 4, `M-o` narrowed to symbols against
  `C-c l s` at 100 ms per key, in a deal.II project (RUN.md run 4). Done when:
  `results-run4.log` handed back and RESULTS.md has run 4. Done 2026-10-11 (0053),
  setup (1): narrowed `M-o` median 1.4 ms per key, `C-c l s` 3.0 - 3.3 ms.
- T-053 (opened 2026-10-11, D-079): send `docs/upstream/consult-async-hidden-sources.md`
  to consult's issue tracker; outward, so the owner sends it. Done when: sent, issue
  number noted here.
- T-052 (opened 2026-10-11, owner report): `M-o` narrowed to symbols against
  `C-c l s` in a deal.II-sized tree. Done when: `RESEARCH_go_to_anything.md` 9 with
  the measured difference, its cause and checked options. Done 2026-10-11: cause in
  consult's async narrowing, a GC bug of T-049 fixed (2e778ee); options as O-34.
- T-051 (opened 2026-10-11, D-077): owner runs S11 run 2
  (`spikes/s11-go-to-anything/prompt.sh`, RUN.md run 2). Done when:
  `results-run2.log` handed back and RESULTS.md has run 2. Done 2026-10-11 (0049):
  PASS on RMO.
- T-050 (opened 2026-10-11, owner): research how to make the go-to-anything prompt
  faster. Done when: `RESEARCH_go_to_anything.md` 8 with measured options. Done
  2026-10-11: prototype in a terminal Emacs, four variants timed; GC is 69 % of the
  first letter; options put to the owner as O-33.
- T-048 (opened 2026-10-11, D-074): owner runs spike S11
  (`spikes/s11-go-to-anything/RUN.md`); pass criteria proposed there, agreed before
  the run. Done when: `results.log` handed back and `RESULTS.md` written. Done
  2026-10-11 (0048): FAIL in one part, one letter over deal.II 31.8 ms; O-32.
- T-047 (opened 2026-10-11, owner): research a "go to anything" key like CLion's
  Search Everywhere (symbols, project files, bookmarks, ...). Done when:
  `RESEARCH_go_to_anything.md` with what CLion does, what the config has, what consult
  and consult-eglot offer at their pins, the key, and options. Done 2026-10-11: one
  batch check of a static plus an async source in `consult--multi`; clangd symbols in
  the combined prompt not checked by hand; options put to the owner as O-30.
- T-045 (opened 2026-10-10, owner): research cell modes for Python and R, notebooks,
  Quarto and other options. Done when: `RESEARCH_notebooks_cells.md` with the
  candidates, what is built in, what was checked by hand, and the external tools per
  machine. Done 2026-10-10: code-cells with `run-python` and with ESS verified, org-babel
  Python and R verified (an R session needs ESS loaded first); Jupyter, EIN and Quarto
  not checked; options put to the owner as O-29; ruled 2026-10-10 (D-072).
- T-044 (opened 2026-10-10, D-069): done when (agreed 2026-10-10): a repeatable
  `.gitmodules` key `patch` (repository-relative); `make packages` applies each series
  before compiling, a second run is safe, a patch that does not apply stops the build
  naming submodule, patch and git's message; a missing listed patch and an unlisted
  file under `patches/<name>/` are errors; T-041's fix moves into
  `patches/treemacs/0001` and the Lisp workaround goes, `init-treemacs-follow-options`
  still passes; tests in `test/build-packages-test.el` fail on the old code; DESIGN 12,
  README, journal. Done: 0046.
- T-043 (opened 2026-10-10): `init-python-pyright-navigates-and-renames` failed once in
  six runs on the Mac (one full `make test`; it passed three times alone and in the
  other full runs), right after D-068's hook was added; the hook returns at once in a
  project without CMakePresets.json. The condition was not captured. Done when: the
  next failure's condition is recorded here and explained, or 20 full runs pass.
  Arch, 2026-10-10 (all of D-067 .. D-072 in): 20 of 20 full runs pass, 75 tests each;
  left open, since the failure was on the Mac: 20 full runs there close it.
- T-042 (opened 2026-10-10, D-068): done when (agreed 2026-10-10): opening an existing
  C++ source that the active preset's database does not list shows one warning per
  session naming the file and the fix, clangd still manages it; listed sources,
  headers and files not yet saved get none; `make test` passes. Done: 0045.
- T-041 (opened 2026-10-10, D-067): turning `treemacs-project-follow-mode` off signals
  `(wrong-type-argument timerp nil)` (unchecked `cancel-timer`); worked around in
  `emacs-cpp-tree--apply-follow`, test `init-treemacs-follow-options`; since D-069 the
  fix is `patches/treemacs/0001-...` (the upstream draft's fix) instead. Drafted:
  `docs/upstream/treemacs-project-follow-mode-off.md`; outward, so the owner sends it.
  Done when: sent, issue number noted here.
- T-040 (opened 2026-10-10, D-065): indent rules for the two gaps left on RMO after
  D-062 (452 lines re-indented): `case` labels one step in from `switch`
  (`IndentCaseLabels: true`), and arguments after a `(` that ends a line one step in
  rather than aligned with the `(`. Tier 1 (rules with tests, as T-039). Done
  2026-10-10: measured against clang-format's own output of RMO, Emacs's re-indent
  differs on 244 -> 62 lines (case labels, argument lists via
  `c-ts-common-list-indent-style` `simple`, constructor initializers, `requires`); test
  `init-cpp-indent-like-clang-format` re-indents a clang-format sample from nothing to
  the same text. RMO's `.dir-locals.el` gains `emacs-cpp-indent-case-labels`.
- T-039 (opened 2026-10-10, owner report: `explicit ...` after `public:` typed at column
  0): the workaround is in (D-062, test `init-cpp-indent-members-after-a-blank-line`).
  Drafted 2026-10-10: `docs/upstream/c-ts-mode-member-after-blank-line.md`, reproduction
  `c_ts_mode_member_blank_line_repro.el`, with a one-line fix tested over master
  (c-ts-common's baseline rule, "Condition 2 for initializer list", catches
  `field_declaration_list`; same in master); outward, so the owner sends it. Done when:
  sent, bug number noted here.
- T-038 (opened 2026-10-10, owner: "update dir-locals.el, preferably without
  executable code"; D-062): tier 2 in `lisp/init-cpp.el`. Done when (agreed
  2026-10-10): ERT shows a dir-local `bsd` applies, the brace rule holds, the option
  flattens namespaces with no prompt; the RMO re-indent count stays at 2955 with data
  only; MANUAL 8 drops the `eval`; `make test` passes. Done 2026-10-10 (0044); RMO's
  `.dir-locals.el` now data only (uncommitted there, the owner's to commit).
- T-037 (opened 2026-10-10, owner): send
  `docs/upstream/c-ts-mode-local-indent-style.md` (reproduction
  `c_ts_mode_local_style_repro.el`): `c-ts-mode-indent-style` from `.dir-locals.el` or
  a `-*-` line is set but not applied (31.1 and master). Outward, so the owner sends
  it. Done when: sent, and the bug number noted here and in MANUAL 8.
- T-036 (opened 2026-10-10, D-061, O-28 (e)): send
  `docs/upstream/c-ts-mode-namespace-class-braces.md` (reproduction
  `c_ts_mode_namespace_repro.el`) to the Emacs bug tracker (`M-x report-emacs-bug` or
  bug-gnu-emacs@gnu.org); outward, so the owner sends it. Done when: sent, and the
  bug number noted here and in D-061.
- T-035 (opened 2026-10-10, D-061): RET in eglot-managed C++ buffers indents the new
  line by clangd's on-type formatting, the line above kept as typed. Tier 2, in
  `lisp/init-cpp.el`. Done when (agreed 2026-10-10, owner: "implement (b)"): ERT with
  clangd on a toy project carrying RMO's `.clang-format`: RET after a declaration in an
  unindented namespace lands at column 0, after `public:` at 4, inside a function body
  at 8, and the hand-aligned line above (`int  x   = 1;`) is unchanged; typing `}` is
  still re-indented by Emacs's rules; without eglot, and after `eglot-shutdown`, RET
  indents as before (electric indentation, newline among its characters); an error from
  clangd's reply is shown, not swallowed; MANUAL 8 and the cheat sheet say what RET and
  TAB follow; `make test` passes on Arch; RET on RMO (owner, `src/main_coarse.cc`) feels
  immediate (batch: 2 - 6 ms per RET on a toy file, 2026-10-10). Built 2026-10-10
  (0043): all met but the owner's RMO check. Superseded 2026-10-10 by D-065.
- T-034 (opened 2026-10-09, owner): research packages that guess a project's
  indentation or format style, after MANUAL 8 was applied to RMO. Done when:
  `RESEARCH_indent_guessing.md` with the candidates, their state, and what each
  would change on RMO. Done 2026-10-09: dtrt-indent guesses only step and tabs,
  whatstyle / unformat are unproven at clang-format 23; Emacs 31.1's rules miss
  namespace and class braces; clangd's on-type formatting is overridden by
  electric indentation. Options put to the owner as O-28; ruled 2026-10-10 (D-061).
- T-033 (opened 2026-10-09, D-060): patch 0009 in `BackgroundIndex::loadProject`: a
  loaded shard with `HadErrors` schedules its `DependentTU` like a stale one; a log
  line names the source. Tier 2. PROPOSED done when (owner to agree): a unit test (a
  source indexed while an included header is missing; the header created; a new
  index re-indexes the source and its shard is clean) fails without the change and
  passes with it; ClangdTests pass on macOS; PKGBUILD pkgrel 7 and `build-macos.sh`
  build it; on the owner's `step-1` the five flagged sources get clean shards in one
  session, and after the next restart their first `M-.` comes from the index (no
  "indexed with errors" in clangd's log); pkgrel 7 on Arch with S9 unchanged (owner).
  Agreed 2026-10-09. Built 2026-10-09 (0042): all met on the Mac. pkgrel 7 installed
  on Arch 2026-10-09 (owner), S9 run 4 unchanged (see T-020). Done.
- T-032 (opened 2026-10-09, O-26 (d)): send
  `docs/upstream/eglot-watch-cap-partial-watches.md` to the Emacs bug tracker
  (`M-x report-emacs-bug` or bug-gnu-emacs@gnu.org); outward, so the owner sends it.
  Done when: sent, and the bug number noted here and in D-054.
- T-031 (opened 2026-10-09, D-055): the per-platform defaults files; done when as
  written in D-055 (agreed 2026-10-09).
- T-030 (opened 2026-10-09, D-056): replace the build.ninja reading in
  `lisp/init-debug.el` (`emacs-cpp-debug-programs`) by CMake's file API reply, and
  write the query file from `emacs-cpp-presets-configure-command` and the debug
  presets. Tier 2. PROPOSED done when (owner to agree): `gdb-preset` / `lldb-preset`
  list the same targets as before on RMO (Ninja) and on a Makefiles preset; a build
  directory without a reply refuses the session naming `C-c p c o`, which writes the
  query and, after configuring, makes the targets appear; the CMake 3.31 and 4
  `build.ninja` fixtures are replaced by reply fixtures from both CMake versions;
  the lldb and gdb session tests unchanged; make test passes on the Mac and on Arch.
  Agreed 2026-10-09. Built 2026-10-09 (0040): all met on the Mac (RMO's CLion build:
  the same 11 targets as from build.ninja). Arch 2026-10-09 (CMake 4.4.4): make
  test 54 / 54. Done.
- T-029 (opened 2026-10-09, owner; D-054): research the file descriptor per watched
  directory issue on macOS and its effects on C++ work in Emacs. Open: why Emacs
  stopped at descriptor 975; which parts watch files in a C++ session (eglot for
  clangd, auto-revert, treemacs, magit, diff-hl); whether a deal.II-sized tree hits
  the limit. PROPOSED done when: `RESEARCH_file_watches_macos.md` with the mechanism
  (kqueue, Emacs's limit), descriptor counts measured in a C++ session on RMO on the
  Mac, and a proposal to keep or change D-054. Done 2026-10-09:
  `RESEARCH_file_watches_macos.md` (superseded 2026-10-14 by
  `RESEARCH_platform_differences.md` 3); options for D-054 put to the owner as O-26.
  Revisited 2026-10-09 (owner): the Dock-start limit of 207 was wrong (975, real
  Launch Services start); at eglot's cap pyright exits; pyright does not watch by
  itself; O-26 options revised.
- T-014: the config runs the patched clangd (D-026) installed from
  packaging/clangd-index-nav (D-027); done when (agreed 2026-10-08): the config starts
  the patched clangd with --navigation-from-index when its path is set (customize
  variable, default: the system clangd), fails loudly if the configured binary is
  missing or lacks the flag; make test covers both the system and the patched server;
  on RMO, after a restart, M-. on a deal.II / std name answers within 2 s.
  Extension (owner report, agreed 2026-10-08): after a restart, M-. on an `#include`
  line of an unchanged file answers from the index (unit test in BackgroundIndexTests,
  synthetic project under 1 s); ambiguous or unmatched includes take the old path;
  ClangdTests pass; the package carries the patch. Done: 8df32dbe5, patch 0004,
  pkgrel 2. Owner 2026-10-08 with pkgrel 3: M-. on names and #include lines works on
  RMO; O-13 closed.
- T-013 (closed, superseded by D-026): hybrid per D-023 / D-024, built on branch
  `t013-ccls-hybrid`; done when (agreed
  2026-10-08): in a fresh Emacs on RMO with a .clang-tidy, after ccls's first indexing:
  `M-.` on a deal.II / std name answers within 2 s of opening any source; a header
  opened first shows no "not found" errors; a clang-tidy finding appears in flymake for
  a source; `make test` covers ccls navigation, header-first and the clang-tidy
  backend; D-018 refusals still work. Blocked by the ccls abort (O-10).
- T-011: mechanism D-028 (patch 0005; owner ruled tier 2 instead of spike S4); done
  when (agreed 2026-10-08): after a restart with the index on disk, a header without a
  database entry gets the flags of a source file that includes it, per the stored index
  (log: "inferred from src/main.cc"); on the fmt toy and on RMO, `option.h` reached by
  `M-.` on its `#include` line and `include/rmo/fe/assemble.h` opened first show no
  flymake errors; the config refuses loudly a clangd lacking the flag; ClangdTests and
  `make test` pass; pkgrel 3 carries the patch; first sessions unchanged. Done on the
  toy (b704ffd66, pkgrel 3); owner 2026-10-08 on RMO: no errors in either case.
