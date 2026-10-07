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
- CMake editing -> `cmake-ts-mode` (needs a grammar). Gap: no target completion.
  UNDECIDED (S3).
- CMake profiles / toolchains -> `CMakePresets.json` via projectile
  (`projectile-enable-cmake-presets`). Gap: no target picker UI. DECIDED D-005.
- Build / run / test -> projectile configure / compile / test / run -> `compile`
  buffer, `next-error`. Gap: no GoogleTest runner tree. PROPOSED.
- Debugger, breakpoints -> dape over DAP: `gdb -i dap` (gdb 17) or `lldb-dap`. Gap: no
  memory view parity (R). DECIDED D-002.
- Git -> magit (installed), diff-hl gutter, magit-blame, smerge for conflicts. Gap: none
  of note. PROPOSED.

Claim to confirm: "CLion parity for the daily loop is reachable with built-ins plus about
ten ELPA/MELPA packages and under ~600 lines of own Lisp." Refuted if v0.3 needs more.
Rows marked (R) need a short RESEARCH note before a verdict is claimed in README.

## 2. Place in the ecosystem, non-goals
For: one owner, one Arch Linux workstation, C++ projects built with CMake presets.
Not: an Emacs distribution (no Doom / Spacemacs layer), not a general-purpose config for
other languages (they may ride along, never drive design), not Windows / macOS, not evil
keys, not a CLion keymap emulation (D-004).
Complexity budget principle: prefer a built-in over a package, a package over own Lisp,
and own Lisp only for glue the owner touches daily.

## 3. Owner constraints (partly filled 2026-10-07, rest TO FILL)
Observed on the owner machine, 2026-10-07:
- Arch Linux, Emacs 31.1 (native-comp, treesit available, no grammars installed),
  16 cores, 31 GB RAM.
- clangd 22.1.8, clang-tidy, clang-format, gcc, clang, gdb 17.2, lldb-dap, cmake 4.4.3,
  ninja, ripgrep, fd, valgrind. Not installed: bear, cppcheck. Arch ships
  `tree-sitter-c` but no `tree-sitter-cpp` or `tree-sitter-cmake`.
- Existing config: `~/.emacs` (projectile on `C-c p`, MELPA archive, theme
  `modus-vivendi-tritanopia`, tool bar off). Installed: projectile 3.4.0, treemacs,
  treemacs-projectile, magit 4.7.1, markdown-mode, org-journal.
TO FILL (Q-1, Q-2): the reference C++ project used to validate each milestone, and the
largest project the setup must stay responsive on (clangd index size, RAM).

## 4. Design principles
1. Fail loudly: a missing package or grammar is an error at startup, never a silent
   fallback; no `ignore-errors` / `with-demoted-errors` around config. Reason: a config
   that half-loads looks fine until the feature is needed.
2. Built-in first, then GNU / NonGNU ELPA, then MELPA (section 2 budget).
3. Every package is a `use-package` form in exactly one module; no package configured in
   two places. Reason: findability when something breaks.
4. Customize never writes into the repo: `custom-file` lives outside it (D-003).
5. The owner runs anything that touches the live `~/.emacs.d` or real projects; sessions
   hand over exact commands.
6. No module without a section here; no risky change without a PASS spike.

## 5. Load model (the core contract)
- `early-init.el`: frame / UI settings and package-system flags only.
- `init.el`: package archives, `use-package` defaults, then loads `lisp/init-*.el` in a
  fixed, listed order. Module order is the contract; a module may depend only on modules
  loaded before it.
- Each module ends with `(provide 'init-<name>)`; `init.el` uses `require`, so a missing
  module is a load error (principle 1).
- Packages install via `package.el` + `use-package :ensure t` from GNU, NonGNU and MELPA
  (D-006 PROPOSED). Version locking is UNDECIDED (O-3).

## 6. Architecture
| block | location | tag | notes |
|---|---|---|---|
| early init | `early-init.el` | UNVALIDATED | NEW |
| init, packages | `init.el` | UNVALIDATED | NEW, replaces `~/.emacs` (D-003) |
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
- PROPOSED: clangd args `--background-index --clang-tidy --header-insertion=never
  --completion-style=detailed --query-driver=/usr/bin/g++,/usr/bin/clang++`
  (query-driver so gcc's system headers resolve under gcc presets).
- UNDECIDED (S1): how clangd finds `compile_commands.json` when presets build into
  `build/<preset>/`. clangd only searches parent directories and their `build/` subdir.
  Candidates: (a) project `.clangd` with `CompileFlags: CompilationDatabase:`, (b) symlink
  `compile_commands.json` to the project root after configure, (c) per-project eglot
  `--compile-commands-dir` via `.dir-locals.el`. Presets must set
  `CMAKE_EXPORT_COMPILE_COMMANDS=ON`.
- UNDECIDED (S3): major mode `c++-ts-mode` (needs a self-built grammar, D-007 PROPOSED)
  vs `c++-mode` + `eglot-semantic-tokens-mode` (no grammar needed).

## 8. Build (CMake presets)
- DECIDED D-005: `CMakePresets.json` is the toolchain / profile mechanism; Emacs never
  stores its own per-project build settings while a preset exists.
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

## Scope ladder
- v0.1 navigation: config loads from the repo via symlink; completion stack; eglot +
  clangd navigate, rename and show clang-tidy diagnostics in the reference project (Q-1).
  Gated by S1.
- v0.2 build: configure / build / test via presets; errors jump to source; CMake editing
  mode chosen (S3).
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
| self-built C++ / CMake grammar ABI mismatch, Emacs 31 | S3 | owner | v0.2 |
| unpinned MELPA update breaks startup | none (O-3) | - | - |

## Research program
- `RESEARCH_refactoring.md`: which CLion refactorings clangd code actions cover in
  clangd 22 (fills the (R) rows of section 1). After v0.1.

## Open questions ledger (LIVING)
- Q-1 (OPEN): which project is the reference for milestone validation? Candidate seen:
  `~/source/repos/RMO-gross-pitaevskii` (CMake, no presets yet).
- Q-2 (OPEN): largest project size to stay responsive on (deal.II / Trilinos scale?).
- Q-3 (OPEN): accept the PROPOSED package set (vertico, orderless, marginalia, consult,
  consult-eglot, embark, embark-consult, corfu, cape, dape, diff-hl, breadcrumb)?
- O-1: compile DB discovery under presets -> S1.
- O-2: `c++-ts-mode` vs `c++-mode` + semantic tokens -> S3.
- O-3: package version locking (none / `package-vc` pins / lockfile) -> owner ruling.
Resolved:
- 2026-10-07, owner: LSP + debugger stack = eglot + dape (D-001, D-002); config home =
  this repo symlinked as `~/.emacs.d/init.el` (D-003); keys = Emacs-native + prefix
  (D-004); builds = CMakePresets.json (D-005).

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

PROPOSED, not yet rows: D-006 packages from GNU + NonGNU + MELPA via package.el (network
at install time); D-007 build tree-sitter grammars with `treesit-install-language-grammar`
(network git clone + local compiler) if S3 passes.

## Parity verdicts (from RESEARCH_*.md)
None yet; see section 1 (R) rows.

## Conventions
ASCII; no invented abbreviations; commits with Reasoning and tier; journal with code;
tests with logic; docs-sync same commit and `make check` before commit; decisions cite
D-nnn; Makefile/justfile default target = help.
