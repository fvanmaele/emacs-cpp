# emacs-cpp - Design

Living design record + decision ledger. Source of truth for WHAT this is, WHY it is that
way, and what is still UNDECIDED. When "why does it not do X" comes up, the answer is here
or gets added here.

Related documents: `POSTMORTEM.md` (lessons), `JOURNAL.md` + `docs/journal/` (per-chunk
teaching entries with ledgers), `spikes/` (PASS/FAIL prototypes), `RESEARCH_<tool>.md`
(findings; verdicts only here), `TASKS.md` (work from rulings), `CLAUDE.md` (session rules),
`README.md` (must never claim more than this file backs).

Status legend: DECIDED (D-nnn, date), PROTOTYPE (exists, unvalidated), UNDECIDED (open
question or spike named), REJECTED (reason), PROPOSED (awaiting owner ruling), TO FILL
(owner input needed).

## 1. Why this exists, honestly
The owner works on C++ in CLion and wants the same daily loop inside Emacs: navigate,
refactor, see diagnostics, build with CMake presets, debug with breakpoints, use git, and
jump to anything. Emacs 31 already ships most of the engine (eglot, xref, flymake,
project, treesit, which-key, use-package); the gap is wiring, keybindings and a few
packages, not new software.

Honest comparison (verdicts live in this file):
Format: CLion feature -> Emacs component. Gap vs CLion. Status.
- Go to definition / declaration -> xref via eglot + clangd (`M-.`,
  `eglot-find-declaration`). Gap: none. PROPOSED.
- Find usages -> xref `M-?` (eglot references). Gap: no read/write grouping. PROPOSED.
- Go to implementation -> `eglot-find-implementation`. Gap: none. PROPOSED.
- Call / type hierarchy -> `eglot-show-call-hierarchy`, `eglot-show-type-hierarchy`.
  Gap: simpler tree UI. PROPOSED.
- Rename -> `eglot-rename` (clangd, project-wide). Gap: none. PROPOSED.
- Other refactorings -> `eglot-code-actions` = clangd tweaks (extract variable /
  function, define outline, expand auto, swap if branches, ...). Gap: no change
  signature, inline, move, pull members up (R). PROPOSED.
- Static analysis, quick fixes -> flymake + clangd diagnostics + clang-tidy
  (`--clang-tidy`, project `.clang-tidy`); fixes via `eglot-code-actions`. Gap: no CLion
  data-flow analysis; clang-tidy `clang-analyzer-*` covers part (R). PROPOSED.
- Code completion -> corfu + eglot completion-at-point. Gap: none. PROPOSED.
- Inlay / parameter hints -> `eglot-inlay-hints-mode`. Gap: none. PROPOSED.
- Reformat -> `eglot-format-buffer` (clangd reads `.clang-format`). Gap: none. PROPOSED.
- Switch header / source -> `projectile-find-other-file`. Gap: name-based, not
  clangd-based. PROPOSED.
- Search everywhere, go to file / symbol / action -> vertico + orderless + marginalia +
  consult: `projectile-find-file`, `consult-buffer`, `consult-eglot-symbols`,
  `consult-imenu`, `consult-ripgrep`, `M-x`. Gap: no single combined popup. PROPOSED.
- Project tree -> treemacs + treemacs-projectile (installed). Gap: none. DECIDED
  (existing setup).
- CMake editing -> `cmake-mode` shipped by the system `cmake` package. Gap: no target
  completion. DECIDED D-013.
- CMake profiles / toolchains -> `CMakePresets.json` via projectile
  (`projectile-enable-cmake-presets`). Gap: no target picker UI. DECIDED D-005.
- Build / run / test -> projectile configure / compile / test / run -> `compile`
  buffer, `next-error`. Gap: no GoogleTest runner tree. PROPOSED.
- Debugger, breakpoints -> dape over DAP: `gdb -i dap` (gdb 17) or `lldb-dap`. Gap: no
  memory view parity (R). DECIDED D-002.
- Git -> magit (installed), diff-hl gutter, magit-blame, smerge for conflicts. Gap: none
  of note. PROPOSED.

Claim to confirm: "CLion parity for the daily loop is reachable with built-ins plus about
fifteen direct packages and under ~600 lines of own Lisp." Refuted if v0.3 needs more.
Rows marked (R) need a short RESEARCH note before a verdict is claimed in README.

## 2. Place in the ecosystem, non-goals
For: one owner, one Arch Linux workstation, C++ projects built with CMake presets.
Not: an Emacs distribution (no Doom / Spacemacs layer), not a general-purpose config for
other languages (they may ride along, never drive design), not Windows / macOS, not evil
keys, not a CLion keymap emulation (D-004).
Complexity budget principle: prefer a built-in over a package, a package over own Lisp,
and own Lisp only for glue the owner touches daily.

## 3. Owner constraints (filled 2026-10-07)
Observed on the owner machine, 2026-10-07:
- Arch Linux, Emacs 31.1 (native-comp, treesit available), 16 cores, 31 GB RAM.
- clangd 22.1.8 at the survey, 23.1.1 by the S1 run the same day (rolling release; the
  design must not depend on one clangd version), clang-tidy, clang-format, gcc, clang,
  gdb 17.2, lldb-dap, cmake 4.4.3 (ships `/usr/share/emacs/site-lisp/cmake-mode.el`),
  ninja, ripgrep, fd, valgrind, rsync, python3. Not installed: bear, cppcheck, GNU time.
- Tree-sitter: `tree-sitter-cpp` 0.23.4 built and installed by the owner as a pacman
  package; `c++-ts-mode` parses with it (ABI 15, checked 2026-10-07). No C or CMake
  grammar installed.
- Existing config: `~/.emacs` (projectile on `C-c p`, MELPA archive, theme
  `modus-vivendi-tritanopia`, tool bar off). Installed: projectile 3.4.0, treemacs,
  treemacs-projectile, magit 4.7.1, markdown-mode, org-journal.
- Reference project (Q-1, D-009): `~/source/repos/RMO-gross-pitaevskii`. CMake >= 3.28,
  C++20, 38 source / header files (`.cc`, `.h`), links the system deal.II 9.8.0 (debug
  and release libraries, built with PETSc + Trilinos), Boost, and `fmt` (git
  submodule). Built today with Unix Makefiles in `build-release/`; no
  `CMakePresets.json`, no `compile_commands.json`, no `.clang-format` / `.clang-tidy`.
  After S1 run 1 the owner adds `set(CMAKE_CXX_EXTENSIONS OFF)` and commits the spike
  `CMakePresets.json` (D-011, D-012). Its `find_package(deal.II HINTS ../ ../../)` makes
  configure depend on checkout depth (S1 RUN.md Gotchas); not fixed, owner's call.
- GCC 16 is the system compiler and defaults to C++20.
- Scale target (Q-2, D-010): stay responsive on a deal.II-sized source tree (thousands
  of heavily templated translation units). Every translation unit of the reference
  project already pulls in deal.II headers, so per-file preamble cost matters even there.

## 4. Design principles
1. Fail loudly: a missing package or grammar is an error at startup, never a silent
   fallback; no `ignore-errors` / `with-demoted-errors` around config. Reason: a config
   that half-loads looks fine until the feature is needed.
2. Built-in first, then GNU / NonGNU ELPA packages, then MELPA-only packages (section 2
   budget); all non-built-ins arrive as pinned git submodules (D-006).
3. Every package is a `use-package` form in exactly one module; no package configured in
   two places. Reason: findability when something breaks.
4. Customize never writes into the repo: `custom-file` lives outside it (D-003).
5. The owner runs anything that touches the live `~/.emacs.d` or real projects; sessions
   hand over exact commands.
6. No module without a section here; no risky change without a PASS spike.
7. Performance is measured, not assumed (section 11): a tuning setting lands only with
   the number it moved, or with the source that justifies it.

## 5. Load model (the core contract)
- `early-init.el`: frame / UI settings, startup garbage-collection threshold,
  `package-enable-at-startup` nil. Nothing else.
- `init.el`: adds the generated load path and autoloads (below), sets `use-package`
  defaults, then `require`s `lisp/init-*.el` in a fixed, listed order. Module order is
  the contract; a module may depend only on modules loaded before it.
- Each module ends with `(provide 'init-<name>)`; a missing module is a load error.
- `use-package-expand-minimally` t: use-package then does not wrap forms in its own
  error catching, so a broken package form stops startup (principle 1).
- Packages: section 12 (D-006). `package.el` is not used at startup.

## 6. Architecture
| block | location | tag | notes |
|---|---|---|---|
| early init | `early-init.el` | UNVALIDATED | NEW |
| init | `init.el` | UNVALIDATED | NEW, replaces `~/.emacs` (D-003) |
| packages | `lib/<repo>/` submodules | UNVALIDATED | NEW (D-006, section 12) |
| package build | `scripts/build-packages.el` | UNVALIDATED | NEW, run by `make` |
| completion UI | `lisp/init-completion.el` | UNVALIDATED | NEW: vertico .. corfu |
| project, tree | `lisp/init-project.el` | UNVALIDATED | NEW: projectile, treemacs |
| C++, LSP | `lisp/init-cpp.el` | UNVALIDATED | NEW: eglot, flymake, format |
| CMake | `lisp/init-cmake.el` | UNVALIDATED | NEW: presets, compile |
| debugger | `lisp/init-debug.el` | UNVALIDATED | NEW: dape |
| git | `lisp/init-git.el` | UNVALIDATED | NEW: magit, diff-hl |
| keys | `lisp/init-keys.el` | UNVALIDATED | NEW: `C-c l` map (D-004) |
| tests | `test/*.el`, `make test` | UNVALIDATED | NEW: batch load + ERT |
Known defects: none yet (nothing built).

## 7. C++ language server (eglot + clangd)
- DECIDED D-001: eglot is the LSP client.
- PROPOSED: clangd args `--background-index --background-index-priority=low
  --clang-tidy --header-insertion=never --completion-style=detailed --pch-storage=memory
  --malloc-trim -j=8 --query-driver=/usr/bin/c++,/usr/bin/g++,/usr/bin/clang++`
  (query-driver so gcc's system headers resolve; deal.II is built with `/usr/bin/c++`).
  Each flag is kept only if S1 or a section 11 measurement backs it.
- UNDECIDED (S1, O-1): how clangd finds `compile_commands.json` when presets build into
  `build/<preset>/`; clangd only searches parent directories and their `build/` subdir.
  Candidates: (B) project `.clangd` with `CompileFlags: CompilationDatabase:`, (C)
  symlink in the project root, (D) `--compile-commands-dir` passed by Emacs from the
  active preset. S1 run 1: all three find the database with identical results and cost
  (about 7.6 s, 457 MB for a deal.II translation unit); final choice after run 2.
  Presets must set `CMAKE_EXPORT_COMPILE_COMMANDS=ON`.
- DECIDED D-011: a project's compile database must state the C++ standard explicitly.
  GCC 16 defaults to C++20, so CMake omits `-std` and clangd then assumes C++17 (false
  errors, S1 run 1). Projects set `CMAKE_CXX_EXTENSIONS OFF`, which makes CMake emit
  `-std=c++NN`. PROPOSED for T-004: when eglot starts for a project, Emacs signals an
  error if the database has entries without `-std=` (fail loudly instead of false
  diagnostics).
- UNDECIDED (S1 run 2, live check 6): headers are not in the database; a header opened
  with no including file open gets flags interpolated from a "nearest" entry (in RMO
  `fmt/src/format.cc`, wrong include paths). Size of the problem in a running clangd is
  measured by run 2; mitigation, if needed, becomes its own task.
- DECIDED D-008: C++ major mode is `c++-ts-mode` on the system grammar; `.h` files open
  in `c++-ts-mode` (the owner's projects are C++, and no C grammar is installed). A
  missing grammar is a startup error, not a fallback to `c++-mode`.

## 8. Build (CMake presets)
- DECIDED D-005: `CMakePresets.json` is the toolchain / profile mechanism; Emacs never
  stores its own per-project build settings while a preset exists.
- DECIDED D-013: CMake files use `cmake-mode` from the system `cmake` package
  (`/usr/share/emacs/site-lisp`), version-matched to the installed CMake; no grammar, no
  submodule. Rejected alternative: `cmake-ts-mode`, needs a self-built
  `tree-sitter-cmake` for highlighting only.
- PROPOSED: `projectile-enable-cmake-presets` t; projectile configure / compile / test
  commands prompt for a preset; one compilation buffer per project
  (`projectile-per-project-compilation-buffer`). Build-target choice is by editing the
  prompted command (`--target X`); a target picker is deferred.

## 9. Debugger (dape)
- DECIDED D-002: dape is the debugger front-end; gdb 17 via its native DAP interpreter
  is the default adapter, lldb-dap the alternate.
- UNDECIDED (S2): deriving the program path from the active preset's `binaryDir`;
  breakpoints persisting across sessions.

## 10. Keys
- DECIDED D-004: Emacs-native bindings (`M-.`, `M-?`, `M-,`, `C-c p` projectile) plus one
  user prefix map `C-c l` for code actions, discoverable via which-key. Proposed letters:
  `r` rename, `a` code action, `f` format, `i` implementation, `d` declaration, `h` call
  hierarchy, `t` type hierarchy, `o` other file, `s` workspace symbol, `e` project
  diagnostics, `I` inlay hints toggle. Debugger keys stay on dape's own prefix + repeat map.

## 11. Performance (Q-2, D-010)
Budgets, measured on the owner machine (T-008 measures, numbers land here):
- Startup: `(emacs-init-time)` <= 0.5 s with all packages built (`make packages`).
- Typing: no perceptible lag in a reference-project `.cc` buffer while clangd builds
  its preamble or background index.
- clangd: a deal.II translation unit's first parse and RSS are recorded by S1; the
  background index of a deal.II-sized tree must not starve the build (low priority).
Mechanisms, each PROPOSED until measured:
- Packages ahead-of-time byte- and native-compiled by `make packages`; one combined
  autoloads file; no `package.el` activation at startup.
- Everything deferred (`use-package-always-defer` t) except the completion UI and theme.
- `gc-cons-threshold` raised in `early-init.el`, restored to a moderate value after
  startup; `read-process-output-max` 4 MB (large LSP replies).
- eglot: `eglot-events-buffer-config` size 0 (no JSON logging), `eglot-sync-connect`
  nil, `eglot-autoshutdown` t.
- clangd flags in section 7.
- Not adopted unless a measurement asks for it: `emacs-lsp-booster` (an external binary,
  would need its own D-nnn), gcmh.

## 12. Packages (D-006, D-007)
- DECIDED D-006: every non-built-in package is a git submodule under `lib/<repo>/`,
  pinned to an exact commit; upgrading is a commit in this repo, rollback is
  `git revert`. Initial pin: newest release tag, else the commit of the MELPA snapshot
  installed on 2026-09-14.
- Per-package build data lives in `.gitmodules` as extra keys (`load-path`, e.g. `lisp`
  for magit, `extensions` for vertico / corfu), read with `git config -f .gitmodules`.
- `scripts/build-packages.el` (run by `make packages`) byte-compiles and native-compiles
  every submodule and writes two generated, git-ignored files: `lib/load-path.el` and
  `lib/autoloads.el`. `init.el` loads both and stops with "run make packages" if absent.
- REJECTED: borg (the tool this layout imitates). It assumes the package repository is
  the Emacs directory itself, which contradicts D-003; reconsider if own glue grows past
  about 100 lines. REJECTED: straight.el, elpaca, package-vc (owner ruling 2026-10-07).
- DECIDED D-007: network access happens only when the owner runs `git submodule update`
  or adds a submodule (GitHub and the upstream hosts below); Emacs makes no network
  calls at startup.
- Package set (Q-3 accepted 2026-10-07; dependencies from the 2026-09-14 archive
  snapshot). Built into Emacs 31 and not vendored: eglot, jsonrpc, project, flymake,
  transient, compat, seq, cl-lib, org, which-key. Vendored, 28 repositories:
  - completion: vertico, orderless, marginalia, consult, consult-eglot, embark (holds
    embark-consult), corfu, cape.
  - IDE: dape, diff-hl, breadcrumb.
  - project + tree: projectile, treemacs (holds treemacs-projectile), and its
    dependencies dash, s, ace-window, avy, pfuture, hydra (holds lv), ht, cfrs,
    posframe.
  - git: magit (holds magit-section), with-editor, cond-let, llama.
  - owner's existing: markdown-mode, org-journal.

## Scope ladder
- v0.1 navigation: config loads from the repo via symlink with all packages vendored;
  completion stack; eglot + clangd navigate, rename and show clang-tidy diagnostics in
  the reference project (D-009). Gated by S1.
- v0.2 build: configure / build / test via presets; errors jump to source; CMake mode
  (O-4).
- v0.3 debug: breakpoint, step, locals, stack, watch via dape + gdb in the reference
  project. Gated by S2.
- v0.4 polish: diff-hl, breadcrumb, `C-c l` map complete, inlay hints, treemacs-magit.
Ride-along only when a milestone needs them: cppcheck, valgrind integration, sanitizer
presets, GoogleTest runner.

## Risk register -> spike targets
| Risk | Spike | Who runs | Blocks |
|---|---|---|---|
| clangd misses compile DB under preset `binaryDir` | S1 | owner | v0.1 |
| dape + `gdb -i dap` fails on a preset-built binary | S2 | owner | v0.3 |
| own package build glue mis-orders compilation | none (tests) | - | v0.1 |
| clangd too slow / too large on deal.II scale | S1 numbers | owner | v0.1 |

## Research program
- `RESEARCH_refactoring.md`: which CLion refactorings clangd code actions cover in
  clangd 22 (fills the (R) rows of section 1). After v0.1.

## Open questions ledger (LIVING)
- O-1: compile DB discovery under presets -> S1 run 2 (B, C, D tied in run 1).
- O-5: cold-header flags (DESIGN 7) -> S1 run 2 live check 6.
Resolved:
- 2026-10-07, owner: LSP + debugger stack = eglot + dape (D-001, D-002); config home =
  this repo symlinked as `~/.emacs.d/init.el` (D-003); keys = Emacs-native + prefix
  (D-004); builds = CMakePresets.json (D-005).
- 2026-10-07, owner: Q-1 reference project = RMO-gross-pitaevskii (D-009); Q-2 scale =
  deal.II size, focus on performance (D-010, section 11); Q-3 package set accepted;
  O-3 versions pinned as git submodules (D-006); O-2 owner installed
  `tree-sitter-cpp`, so `c++-ts-mode` (D-008) and spike S3 is dropped.
- 2026-10-07, owner after S1 run 1: O-4 CMake files use the system `cmake-mode` (D-013);
  missing `-std` fixed by `CMAKE_CXX_EXTENSIONS OFF` in the project (D-011); Q-4 the
  reference project commits the spike `CMakePresets.json` (D-012).

## Decisions ledger (LIVING, append only)
| id | date | decision (one line) | section | from |
|----|------|---------------------|---------|------|
| D-001 | 2026-10-07 | eglot (built-in) is the LSP client for clangd | 7 | owner |
| D-002 | 2026-10-07 | dape debugger UI; gdb DAP default, lldb-dap alternate | 9 | owner |
| D-003 | 2026-10-07 | config in this repo, symlinked into `~/.emacs.d` | 5 | owner |
| D-004 | 2026-10-07 | Emacs-native keys plus a `C-c l` code prefix map | 10 | owner |
| D-005 | 2026-10-07 | CMakePresets.json is the build profile mechanism | 8 | owner |
D-003 detail: `~/.emacs.d/{init,early-init}.el` symlink here; `~/.emacs` is retired (an
existing `~/.emacs` shadows `~/.emacs.d/init.el`); `custom-file` lives outside the repo.

| D-006 | 2026-10-07 | packages are git submodules pinned in `lib/` | 12 | O-3 |
| D-007 | 2026-10-07 | network only on owner-run submodule add / update | 12 | O-3 |
| D-008 | 2026-10-07 | `c++-ts-mode` on system grammar, `.h` is C++ | 7 | O-2 |
| D-009 | 2026-10-07 | reference project is RMO-gross-pitaevskii | 3 | Q-1 |
| D-010 | 2026-10-07 | performance target is deal.II scale (budgets in 11) | 11 | Q-2 |
| D-011 | 2026-10-07 | compile DB must carry `-std`; projects set EXTENSIONS OFF | 7 | S1 |
| D-012 | 2026-10-07 | reference project commits the spike CMakePresets.json | 3 | Q-4 |
| D-013 | 2026-10-07 | CMake files use the system `cmake-mode` | 8 | O-4 |

## Parity verdicts (from RESEARCH_*.md)
None yet; see section 1 (R) rows.

## Conventions
ASCII; no invented abbreviations; commits with Reasoning and tier; journal with code;
tests with logic; docs-sync same commit and `make check` before commit; decisions cite
D-nnn; Makefile/justfile default target = help.
