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
| T-001 | next | S | spike S1 | O-1 | RUN.md for S1; done when: RESULTS.md has a verdict |
| T-002 | open | M | config skeleton | D-003 | see below |
| T-003 | open | M | completion stack | Q-3 | see below |
| T-004 | open | M | eglot + clangd | D-001, S1 | see below |

- T-002: `early-init.el`, `init.el`, `lisp/init-project.el` (projectile + treemacs moved
  from `~/.emacs`), `make test` batch-loads init; done when: owner symlinks per the
  handed-over commands, retires `~/.emacs`, and Emacs starts with no errors and the
  same theme / projectile behaviour as before.
- T-003: vertico, orderless, marginalia, consult, embark, corfu; done when: `C-x b`,
  `C-c p f`, `consult-ripgrep` show vertico candidates with annotations in a real project.
- T-004: eglot on C++ buffers with the S1 compile-db choice; done when: in the Q-1
  project `M-.` crosses files, `M-?` lists usages, `eglot-rename` renames across files,
  and a clang-tidy warning shows in flymake.

## Later
| id | status | size | title | source | what |
|----|--------|------|-------|--------|------|
| T-005 | open | M | presets build | D-005 | done when: preset build errors jump to source |
| T-006 | open | M | dape debugging | D-002, S2 | done when: v0.3 ladder item holds |
| T-007 | open | S | `C-c l` map | D-004 | done when: which-key lists every DESIGN 10 key |
