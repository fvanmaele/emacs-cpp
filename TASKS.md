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
| T-020 | open | S | patch 0008 (review 0031) | D-046, D-047 | owner: rebuild now or later |
| T-021 | open | M | config starts on macOS | D-050, D-054 | built 0034; Arch run left |
| T-022 | open | M | lldb-preset | D-051, O-22 | built 0035; Arch run left |
| T-023 | open | M | macOS clangd build script | D-052, O-23 | CHEATSHEET item 6; proposed |

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
  built, S9 unchanged on RMO (owner).
- T-021 (opened 2026-10-09, D-050): make the config start and test cleanly on the
  owner's Mac (DESIGN 3 macOS observations). Known so far: `init-cmake.el` names only
  `/usr/share/emacs/site-lisp` (MacPorts: `/opt/local/share/emacs/site-lisp`);
  `${hostSystemName}` in presets is an error outside GNU/Linux; a build-script test
  fails on `/var` vs `/private/var`; the other 14 failures not yet examined (most may
  follow from the startup stop). Tier 2. PROPOSED done when (owner to agree): Emacs
  starts on the Mac with no errors; `make test` passes there except tests that need
  gdb or the patched clangd, which skip with a reason until T-022 / T-023 land;
  `make test` still passes on Arch. Agreed 2026-10-09. Built 2026-10-09 (0034): the
  Mac part is met (startup clean, the gdb tests skip, the rest pass); left: `make
  test` on Arch (owner).
- T-022 (opened 2026-10-09, D-051): `lldb-preset` in `lisp/init-debug.el`, built like
  `gdb-preset` from dape's `lldb-dap` configuration; lldb-dap from the Arch `lldb`
  package and, on macOS, the MacPorts `lldb-23` port (D-053; its installed name not yet
  checked). Tier 2. PROPOSED done when (owner to agree): `C-x C-a d lldb-preset RET`
  picks a target of the active preset, builds it, stops at a breakpoint and steps, on
  Arch and on the Mac; a missing lldb-dap refuses the session with the fix; an ERT
  test like `init-debug-gdb-preset-builds-stops-and-steps` covers it; the gdb tests
  are unchanged; make test passes on Arch. Agreed 2026-10-09. Built 2026-10-09
  (0035): on the Mac the session test passes (3 of 3 runs) and the refusal test;
  left: the same on Arch with the lldb package (owner).
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
  CHEATSHEET are replaced by a pointer to the script.
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
