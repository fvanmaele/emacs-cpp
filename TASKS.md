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
| T-008 | open | S | performance baseline | D-010 | see below |

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
  `.clang-tidy`; not yet checked there). Closed with the v0.1 tag (0017).
- T-008: measure DESIGN 11 budgets (`emacs-init-time`, clangd numbers from S1) after
  T-004; done when: numbers are in DESIGN 11 and each tuning setting cites one.

## Later
| id | status | size | title | source | what |
|----|--------|------|-------|--------|------|
| T-005 | open | M | presets build | D-005 | done when: preset build errors jump to source |
| T-006 | open | M | dape debugging | D-002, S2 | done when: v0.3 ladder item holds |
| T-007 | open | S | `C-c l` map | D-004 | done when: which-key lists every DESIGN 10 key |
|       |      |   | (`C-c l P` exists since T-004) | | |
| T-010 | open | S | Info manuals | DESIGN 12 | done when: `C-h i` lists magit, projectile |
| T-011 | done 0015 | M | cold-header flags | O-5, D-028 | owner: RMO headers clean |
| T-012 | rejected (D-021) | M | preamble warm-up | S5 | owner ruled out extra open files |
| T-013 | closed (D-026) | L | ccls + clang-tidy | D-023, D-024 | branch kept, not merged |
| T-014 | done 0014 | M | patched clangd | D-026, D-027 | owner: RMO M-. works (pkgrel 3) |

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
