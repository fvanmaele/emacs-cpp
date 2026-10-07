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
| T-001 | next | S | spike S1 | O-1 | run 2 per RUN.md; done when: RESULTS.md PASS/FAIL |
| T-009 | next | S | RMO build fixes | D-011, D-012 | see below |
| T-002 | open | L | skeleton + packages | D-003, D-006 | see below |
| T-003 | open | M | completion stack | Q-3 | see below |
| T-004 | open | M | eglot + clangd | D-001, S1 | see below |
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
- T-003: completion group of DESIGN 12 added as submodules and configured; done when:
  `C-x b`, `C-c p f`, `consult-ripgrep` show vertico candidates with annotations in the
  reference project, and corfu pops up eglot completions.
- T-004: eglot on `c++-ts-mode` with the S1 compile-db choice; done when: in the
  reference project `M-.` crosses files, `M-?` lists usages, `eglot-rename` renames
  across files, and a clang-tidy warning shows in flymake.
- T-008: measure DESIGN 11 budgets (`emacs-init-time`, clangd numbers from S1) after
  T-004; done when: numbers are in DESIGN 11 and each tuning setting cites one.

## Later
| id | status | size | title | source | what |
|----|--------|------|-------|--------|------|
| T-005 | open | M | presets build | D-005 | done when: preset build errors jump to source |
| T-006 | open | M | dape debugging | D-002, S2 | done when: v0.3 ladder item holds |
| T-007 | open | S | `C-c l` map | D-004 | done when: which-key lists every DESIGN 10 key |
