# RESEARCH - pyright to ty on Arch (T-025 round 2)

Findings only; verdicts go to DESIGN (D-045, O-72). Owner request 2026-10-20: research
a migration from pyright to Astral's ty, installed as `extra/ty` on Arch; the macOS
installation is unknown and deferred. Measured on the owner's Arch workstation
(16 cores, Python 3.14, Emacs 31.1), 2026-10-20, with a small LSP client written for
this research (scratchpad only, not kept): it sends what eglot sends and answers the
server's requests as eglot does. Round 1 (the Mac, ty 0.0.85) is
`RESEARCH_python_macos.md` section 2.

## 1. Versions and status
| Server | Version | Arch | MacPorts (D-053) |
|---|---|---|---|
| pyright (in use, D-045) | 1.1.412 | `extra/pyright` | `pyright` |
| ty | 0.0.90 (2026-10-20) | `extra/ty`, installed | none found (search, 2026-10-20; UNVERIFIED on ports.macports.org) |

ty is in beta since December 2025 (Astral's announcement); a 0.0.x version, so its
settings and rules may change between releases. Emacs 31.1's own eglot already lists
`("ty" "server")` among its Python servers (`eglot-server-programs`, after pylsp,
basedpyright and pyright), so the config's one line in `lisp/init-python.el`
(`emacs-cpp-lsp-server`) is what selects the server.

## 2. What ty answers
`initialize` capabilities of ty 0.0.90: definition, declaration, type definition,
implementation, references, document highlight, hover, completion, signature help,
rename with prepare, document and workspace symbols, call and type hierarchy, inlay
hints, semantic tokens, folding and selection ranges, code actions (`quickfix` only),
notebook sync. No formatting (as pyright; ruff's own server formats). Diagnostics are
pulled (`textDocument/diagnostic`, registered dynamically), which Emacs 31's eglot
supports, as pyright's are.

Toy project (`main.py` importing `pkg/a.py`): `M-.` crosses files, `M-?` lists both
uses, rename edits both files, hover gives the class, inlay hints give parameter names,
the wrong assignment `x: int = greet(...)` is reported (`invalid-assignment`). With a
`.venv` in the project an imported package (`six`) resolves; with no virtual
environment numpy resolves from the system `site-packages` and `M-.` on `np.zeros`
lands in numpy's stub `numpy/_core/multiarray.pyi` (pyright: a stub too, round 1). The
Mac's miss of round 1 (user site-packages) is not an Arch case: Arch installs Python
packages system-wide through pacman.

## 3. Watched files: the difference that matters here
| | pyright 1.1.412 | ty 0.0.90 |
|---|---|---|
| registrations of `workspace/didChangeWatchedFiles` | 2, then 1 dropped (also `**/pyrightconfig.json`) | 1 (`**`) |
| registration refused (eglot's limit) | next request unanswered in 120 s | alive, answers |

pyright's exit on a refused registration (RESEARCH_platform_differences 3.14; here it
stopped answering, its exit not checked) is why `lisp/emacs-cpp-eglot-watch.el` exists
(D-121) and why `test/init-lsp-test.el` runs
pyright. ty survives the refusal; it then misses changes made outside Emacs in the
directories not watched, which is the case the fswatch backend (D-127, S18) is for.
Its one glob `**` watches every directory of the project, like pyright's `**`. In this
small client neither server registered library directories (round 1 saw pyright ask for
about 2000 with its configuration answered; not repeated here, UNVERIFIED for ty).

## 4. Speed and memory
A copy of nine standard library packages plus `argparse.py` as `main.py` (139 files),
two runs each:

| Server | first diagnostics of `main.py` | `workspace/symbol` `Parser` | `M-.` | RSS |
|---|---|---|---|---|
| pyright | 1.34 - 1.36 s (15) | 0 results | 67 - 68 ms | 251 - 254 MB |
| ty | 0.20 - 0.23 s (48) | 88 results, under 10 ms | under 1 ms | 205 MB |

- pyright answers `workspace/symbol` with nothing here, right after the first
  diagnostics; ty has indexed the project by then. `M-o`'s symbol source (D-085,
  D-106) asks any server, so ty would fill it for Python projects where pyright
  returns nothing this early. Not measured later in a pyright session.
- The diagnostic counts differ (15 against 48): ty's rules are not pyright's. Which of
  ty's reports are true was not checked; ty is a beta.

## 5. What a migration touches (grounded)
- `lisp/init-python.el`: the server line and two comments naming pyright.
- `lisp/init-lsp.el:47-52`: the comment on pyright's library watches.
- `lisp/emacs-cpp-eglot-watch.el`: the advice that keeps the watches got so pyright stays
  up; with ty alone it guards texlab and clangd only (whether they need it: not
  checked).
- `test/init-lsp-test.el`: the watch tests run pyright (`init-lsp-test--with-pyright`)
  because it registers three times and exits; with ty they test a server that does
  neither.
- `lisp/init-go-to-anything.el:167`: a docstring naming `pyright-langserver`.
- `lisp/defaults-darwin.el:19`: pyright on the Mac's PATH; the Mac keeps pyright while
  ty has no port (D-053), so the server would be chosen per platform (D-055's
  defaults files).
- DESIGN D-045 and README name pyright.

## 6. Open
- Configuration surface: ty asks for the `ty` section (`workspace/configuration`);
  which settings the config would send (`environment.python` for the Mac's user
  site-packages, round 1) is not researched.
- A real Python project of the owner's (round 1 used pip's source and RMO's
  `staging/*.py`): not repeated on Arch.
- ty under load and over many sessions (round 1: 64 sessions, no failure; here about
  a dozen).
