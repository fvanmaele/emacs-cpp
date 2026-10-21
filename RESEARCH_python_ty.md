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
| pyright | 1.34 - 1.36 s | 0 results | 67 - 68 ms | 251 - 254 MB |
| ty | 0.20 - 0.23 s | 88 results, under 10 ms | under 1 ms | 205 MB |

- pyright answers `workspace/symbol` with nothing here, right after the first
  diagnostics; ty has indexed the project by then. `M-o`'s symbol source (D-085,
  D-106) asks any server, so ty would fill it for Python projects where pyright
  returns nothing this early. Not measured later in a pyright session.
- Diagnostics: section 4a.

## 4b. `M-.` and `M-?` on real trees (owner request 2026-10-21)
Owner: "Verify performance of M-. and M-? with pyright vs. ty". Arch, idle, pyright
1.1.412, ty 0.0.90. Two trees copied into the session's scratch directory, each a git
repository: the owner's `linux_theme_setter` (tracked files: 102 `.py`, 20158 lines) and
SymPy 1.14 from pacman's site-packages (1532 `.py`, 753362 lines). `M-.` from a use in
another file to the class (`Extension` in `ui/window.py`; `Symbol` in
`solvers/solvers.py`); `M-?` on the class's definition, `includeDeclaration` true as
eglot sends it. Two ways, two runs each, the servers alternating:
- **Server alone:** a small LSP client (as in section 4), so only the server's time
  counts. Cold is the first request after `didOpen`; warm the median of 5 (`M-.`) or 3
  (`M-?`) repeats.
- **Through eglot:** the shipped profile (`init.el` in a temporary HOME, as `make
  test`; the fswatch backend carries the watches), Emacs 31.1's eglot, timing
  `xref-backend-definitions` / `xref-backend-references` and, last, the `*xref*`
  buffer. With `emacs -Q` instead, pyright died at its first request: plain eglot lets
  it watch libraries outside the project (section 3, D-121).

| Tree, server | `M-.` cold / warm | `M-?` cold / warm, server alone | `M-?` through eglot, cold / warm / buffer | results | RSS |
|---|---|---|---|---|---|
| theme, pyright | 301 - 310 / 0.5 ms | 127 - 129 / 11 - 12 ms | 101 - 115 / 31 - 32 / 37 - 40 ms | 11 in 6 files | 177 - 178 MB |
| theme, ty | 20 - 21 / 0.4 - 0.6 ms | 105 - 126 / 3.1 - 3.2 ms | 124 - 125 / 11 - 14 / 27 - 29 ms | 11 in 6 files | 211 - 215 MB |
| SymPy, pyright | 468 - 490 / 0.3 ms | 8.9 - 9.0 s / 1087 - 1089 ms | 7.4 - 7.5 s / 7.9 - 8.0 s / 4.1 - 4.4 s | 5631 in 408 files | 2067 - 2079 MB |
| SymPy, ty | 65 - 72 / 0.4 ms | 1.67 - 1.87 s / 82 ms | 4.6 - 4.8 s / 3.0 s / 3.0 s | 5628 in 408 files | 1148 - 1160 MB |

`M-.` through eglot: pyright 611 - 617 ms cold on theme, 354 - 372 ms on SymPy; ty 25 -
30 and 67 - 72 ms; warm 2 - 4 ms for both.

- **`M-.`:** ty answers the first jump 5 - 15 times sooner (20 - 72 ms against 300 -
  617 ms); after that both are instant.
- **`M-?`, small project:** both about 0.1 s cold; warm, ty about 3 ms, pyright about
  12 ms; through eglot under 40 ms either way.
- **`M-?`, 5600 references:** the server alone, ty is 5 times faster cold (1.7 - 1.9 s
  against 9 s) and 13 times warm (82 ms against 1.09 s), at about half the memory
  (1.15 against 2.07 GB). Through eglot about 2.9 s of every warm call is Emacs's own:
  eglot reads the 408 files to make each reference's summary line (ty: 3.0 s with
  82 ms in the server). So warm `M-?` there is 3.0 s with ty, 4.1 - 8.0 s with pyright.
- **pyright's first `M-?` was incomplete through eglot:** in each of the three eglot
  runs on SymPy its first reply held 358 references in 81 files, sent before it logged
  "Found 1532 source files"; the next replies held all 5631. The client alone got all
  5631 in both runs. Why the order differs (eglot's `didOpen` of the second file, the
  watch registrations, timing) was not found: UNVERIFIED. ty's first reply was complete
  each time.
- The three references only pyright lists (5631 against 5628) were not looked at.

## 4a. Why the diagnostics differ on the same file
The first count (pyright 15, ty 48, 2026-10-20) came from this research's client, which
did not announce `tagSupport`; pyright then leaves out its "unnecessary" hints, ty
sends them anyway. With the capabilities Emacs 31's eglot sends (`tagSupport`
`[1 2]`, eglot.el about line 1184), `main.py` (argparse.py of Python 3.14) gets:

| | pyright 1.1.412 | ty 0.0.90 |
|---|---|---|
| hints, tag "unnecessary" (unused names) | 39 | 41 (the same 39 and 2 more) |
| errors | 15 | 7 |

The errors, line by line:
- **5 in both**, worded differently: 959 (`startswith` on a possible `None`), 2149
  and 2185 (`append` on `list[str] | str`), 1557 and 1746 (pyright: no attribute
  `_get_validation_formatter`; ty: `object` not callable, the same call).
- **2 rules ty has off by default**: 567 and 1687, a name possibly unbound (pyright
  `reportPossiblyUnboundVariable`). ty's `possibly-unresolved-reference` is at level
  `ignore` (`ty explain rule`); `ty check --warn possibly-unresolved-reference`
  reports both lines. Its `possibly-missing-attribute` is off as well.
- **8 from inference of unannotated code**: 259 and 272 (`items`, `parent` of an
  optional `_current_section`), 1543 and 1547 (four attributes of `object`), 2360
  (two reports on one `join`). ty types an unannotated parameter as `Unknown` and
  does not report on `Unknown` (gradual typing), so `self.parent = parent` gives no
  `None` to complain about. pyright infers from the call: on a test file
  (`reveal_type`, 2026-10-21) `C(None).parent` is `None` for pyright, `Unknown` for
  ty; an unannotated `def ret(): return 1` gives `ret()` as `Literal[1]` for pyright,
  `Unknown` for ty (ty 0.0.90 infers no return type of an unannotated function); a
  parameter `r=3` is `int` for pyright, `Unknown | Literal[3]` for ty. Both take an
  attribute's type from every assignment in the class (`self.n`: `None | int`) and
  both then report `c.n.bit_length()`. No ty rule reports a missing annotation
  (none in `ty explain rule`); pyright has `reportMissingParameterType` and others
  (off in its standard mode).
- **2 ty alone**: 200, `import _colorize` unresolved: ty takes the standard library
  from its own copy of typeshed (`vendored://stdlib`), which has no stub for this
  private 3.13+ module, and does not fall back to `/usr/lib/python3.14`; pyright
  resolves it (how: not traced). 2371, `not in` with a right operand that may be
  `None` (`fromfile_prefix_chars`); the caller checks it first, so a false report by
  flow, which pyright does not make.

So: pyright is stricter on unannotated code by default, ty on operators; neither
report set is a superset. Code with annotations (the owner's own Python, UNVERIFIED
how much is annotated) narrows the inference group, which is pyright's lead here.
ty also reads `PYTHONPATH` as extra search paths (this machine sets PETSc's and
SLEPc's), which the config would inherit from Emacs's environment.

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

## 7. A local MacPorts port for ty (owner question 2026-10-21)
Owner: "How involved is it to write a local port file for ty for use with macos?"
Read 2026-10-21: MacPorts' API (`ports.macports.org/api/v1`), MacPorts' `devel/ruff`
Portfile (master), ty's 0.0.90 release on GitHub. Nothing written or built on the Mac.
- **No port today**: `ports/ty/` answers "No Port matches the given query". MacPorts has
  `ruff` 0.17.1 (`devel/ruff`, PortGroups `cargo 1.0` and `github 1.0`, 570 lines, of
  which 498 are its `cargo.crates` list), `rust` 1.99.1 and `cargo2port` 0.3.1. ty and
  ruff share one Rust workspace (`ruff/crates/ty*`), both with `rust-version = "1.97"`.
- **ty's sources**: the release asset `source.tar.gz` (17.6 MB, with a `.sha256`)
  carries the ruff submodule (`ruff/`, 2720 entries under `ruff/crates/ty*`), unlike
  GitHub's own archive of the tag. `ruff/Cargo.lock` lists 553 crates, none from git,
  so `cargo2port` can write the `cargo.crates` list.
- **(p1) A source port**, ruff's Portfile as the model: `github.setup astral-sh ty
  0.0.90`, the sources from the release asset (`github.tarball_from releases`,
  `distname source`), the cargo build run in `ruff/` for the `ty` package only
  (`build.args -p ty`), ruff's `reinplace` for jemalloc's build script, `destroot`
  installing `target/[cargo.rust_platform]/release/ty`; the crate list generated with
  `cargo2port ruff/Cargo.lock`. About 40 hand-written lines plus about 550 generated.
  Each ty release (0.0.85 to 0.0.90 in about a month): new version and checksums,
  the crate list regenerated. Build time on the Mac not known (a ruff-sized Rust
  build; UNVERIFIED).
- **(p2) A binary port**: the prebuilt `ty-aarch64-apple-darwin.tar.gz` (12.8 MB, with
  its `.sha256`), extracted and installed to `${prefix}/bin`: about 25 lines, no crate
  list, no build; a version bump is two checksums. MacPorts' own ports build from
  source; for a local port that is a convention, not a check.
- **Local ports, how**: a directory tree (`<category>/ty/Portfile`), `portindex` run in
  it, a `file:///...` line ahead of the `rsync` one in
  `/opt/local/etc/macports/sources.conf` (a system file: the owner's), then `sudo port
  install ty`; `port upgrade outdated` then sees it. The tree could live in this
  repository (as `packaging/` does for clangd and fswatch, D-052, D-109).
- **Case against either**: a port the owner keeps current by hand, against D-053's
  MacPorts-maintained tools; the Mac's ty install still unchecked (round 1: user
  site-packages missed).

## 6. Open
- Configuration surface: ty asks for the `ty` section (`workspace/configuration`);
  which settings the config would send (`environment.python` for the Mac's user
  site-packages, round 1) is not researched.
- A real Python project of the owner's (round 1 used pip's source and RMO's
  `staging/*.py`): not repeated on Arch.
- ty under load and over many sessions (round 1: 64 sessions, no failure; here about
  a dozen).
