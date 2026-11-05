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
Format: CLion feature -> Emacs component. Gap vs CLion. Status. Every row ruled
2026-10-20 (D-126, review 0084 A-3): DECIDED with the decisions it shipped under,
gaps named; "PROPOSED" had stood unchanged since 2026-10-07.
- Go to definition / declaration -> xref via eglot + clangd (`M-.`,
  `eglot-find-declaration`). Gap: none. DECIDED D-001, D-026 (from the index), D-004.
- Find usages -> xref `M-?` (eglot references). Gap: no read/write grouping. DECIDED
  D-001, D-026.
- Go to implementation -> `eglot-find-implementation`. Gap: none. DECIDED D-004.
- Call / type hierarchy -> `eglot-show-call-hierarchy`, `eglot-show-type-hierarchy`.
  Gap: simpler tree UI. DECIDED D-004.
- Rename -> `eglot-rename` (clangd, project-wide). Gap: none. DECIDED D-092.
- Other refactorings -> `eglot-code-actions` = clangd tweaks (extract variable /
  function, define outline, expand auto, swap if branches, ...). Gap: no change
  signature, inline, move, pull members up (R). DECIDED D-094 (clang-tidy fixes,
  clang-move), D-097 (namespace), D-064; gaps kept: change signature (S12 FAIL,
  O-43 (b)), inline, pull members up (`RESEARCH_refactoring.md`).
- Static analysis, quick fixes -> flymake + clangd diagnostics + clang-tidy
  (`--clang-tidy`, project `.clang-tidy`); fixes via `eglot-code-actions`. Gap: no CLion
  data-flow analysis; clang-tidy `clang-analyzer-*` covers part (R). DECIDED D-094;
  gap kept, no RESEARCH note yet on how much `clang-analyzer-*` covers.
- Code completion -> corfu + eglot completion-at-point, on request with TAB or `C-M-i`
  (D-020). Gap: none. DECIDED.
- Inlay / parameter hints -> `eglot-inlay-hints-mode`. Gap: none. DECIDED D-004.
- Reformat -> `eglot-format-buffer` (clangd reads `.clang-format`). Gap: none. DECIDED
  D-004; indentation while typing by Emacs's rules (D-065).
- Switch header / source -> `projectile-find-other-file`. Gap: name-based, not
  clangd-based. DECIDED D-004 (kept name-based).
- Search everywhere, go to file / symbol / action -> vertico + orderless + marginalia +
  consult: `projectile-find-file`, `consult-buffer`, `consult-eglot-symbols`,
  `consult-imenu`, `consult-ripgrep`, `M-x`; one combined prompt on `M-o` (D-074 ..
  D-078, T-049): buffers, recent files, bookmarks, project files, clangd symbols,
  commands and projects behind narrow keys. Gap: no settings or git items. DECIDED
  D-074 .. D-088, D-120.
- Project tree -> treemacs + treemacs-projectile (installed). Gap: none. DECIDED
  (existing setup).
- CMake editing -> `cmake-mode` shipped by the system `cmake` package. Gap: no target
  completion. DECIDED D-013.
- CMake profiles / toolchains -> `CMakePresets.json` via projectile
  (`projectile-enable-cmake-presets`). Gap: no target picker UI. DECIDED D-005.
- Build / run / test -> projectile configure / compile / test / run -> `compile`
  buffer, `next-error`. Gap: no GoogleTest runner tree. DECIDED D-005, D-035.
- Debugger, breakpoints -> dape over DAP: `gdb -i dap` (gdb 17) or `lldb-dap`. Gap: no
  memory view parity (R). DECIDED D-002.
- Git -> magit (installed), diff-hl gutter, magit-blame, smerge for conflicts. Gap: none
  of note. DECIDED D-042 (diff-hl), magit as installed (D-006); shipped in v0.4.

SUPERSEDED (2026-10-20, refuted; review 0084, A-2): "CLion parity for the daily loop is
reachable with built-ins plus about fifteen direct packages and under ~600 lines of own
Lisp. Refuted if v0.3 needs more." v0.4.1 (2026-10-08) needed more; at c031e2b the tree
pins 33 submodules and holds 3111 lines of own Lisp (19 files). No size budget replaces
it: features are judged by their D-nnn, the packages by D-006.
Rows marked (R) need a short RESEARCH note before a verdict is claimed in README.

## 2. Place in the ecosystem, non-goals
For: one owner, an Arch Linux workstation and a macOS machine (D-050), C++ projects
built with CMake presets.
Not: an Emacs distribution (no Doom / Spacemacs layer), not a general-purpose config for
other languages (they may ride along, never drive design), not Windows, not evil keys,
not a CLion keymap emulation (D-004).
SUPERSEDED by D-050 (2026-10-09): "For: one owner, one Arch Linux workstation" and "not
Windows / macOS".
- DECIDED D-050 (owner 2026-10-09): macOS is a supported platform next to Arch Linux. A
  platform difference is handled like any other missing piece (principle 1): the path or
  tool is chosen per platform and a missing one stops with the fix, never a silent
  fallback. Observed before any code change (section 3): on the owner's Mac the config
  does not start (cmake-mode path, D-013) and `make test` fails 17 of 45; making it start
  and pass is T-021, built 2026-10-09 (0034): Emacs starts on the Mac with no errors; make
  test 54 / 54 on Arch (2026-10-09). Rulings: debugger without gdb O-22 -> D-051, patched
  clangd on macOS O-23 -> D-052, package source O-24 (a) -> D-053. Open: O-24 (b), (c).
- DECIDED D-053 (owner 2026-10-09, O-24 a): on macOS the system tools come from
  MacPorts only; Homebrew is not supported. Paths the config names for macOS are
  MacPorts paths (`/opt/local`).
Complexity budget principle: prefer a built-in over a package, a package over own Lisp,
and own Lisp only for glue the owner touches daily.
- DECIDED D-122 (owner 2026-10-20, review 0084 A-5: "A-5 license, MIT"): the
  repository's own work (init files, `lisp/`, `test/`, `scripts/`, the docs, the
  PKGBUILDs and build scripts) is under the MIT license, `LICENSE` at the root. The
  patch files (`*.patch`) change GPL-3.0-or-later Emacs packages and fswatch, and
  Apache-2.0-with-LLVM-exception clangd; they keep those projects' licenses, and the
  submodules in `lib/` keep their own; `LICENSE` says so.

## 3. Owner constraints (filled 2026-10-07)
Observed on the owner machine, 2026-10-07:
- Arch Linux, Emacs 31.1 (native-comp, treesit available), 16 cores, 31 GB RAM.
- clangd 22.1.8 at the survey, 23.1.1 by the S1 run the same day (rolling release; the
  design must not depend on one clangd version), clang-tidy, clang-format, gcc, clang,
  gdb 17.2, lldb-dap, cmake 4.4.3 (ships `/usr/share/emacs/site-lisp/cmake-mode.el`),
  ninja, fd, valgrind, rsync, python3. Not installed: ripgrep (corrected 2026-10-07:
  the survey's `which rg` found a shell function, not a binary; superseded 2026-10-21:
  pacman's ripgrep 15.2.0 installed 2026-10-07 23:42, and the_silver_searcher), bear,
  cppcheck, GNU time.
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

Observed on the owner's Mac, 2026-10-09 (D-050):
- macOS (Darwin 27), Apple silicon (arm64). System tools from MacPorts (`/opt/local`).
- Emacs 31.1 from the `emacs-app` port (variants nativecomp, rsvg, treesitter), in
  `/Applications/MacPorts/Emacs.app`; `/usr/local/bin/emacs` is a shell wrapper for it.
- Ports: clang 20, 21 and 23 (23.1.3; `clang_select` points `clangd` at 21.1.8), cmake
  3.31.12 (ships `/opt/local/share/emacs/site-lisp/cmake-mode.el`), ninja, ripgrep, fd,
  texinfo 7.3, pyright, `tree-sitter-cpp` 0.23.4, `tree-sitter-python` 0.25.0; Emacs
  finds both grammars without configuration. Not installed: gdb (no port for Apple
  silicon), debugpy (`py314-debugpy` exists). `lldb-dap` comes with the Xcode Command
  Line Tools. Later the same day: the `lldb-23` port (23.1.3), whose lldb-dap is in
  `/opt/local/libexec/llvm-23/bin`; its `lldb` binary there has an invalid code
  signature and is killed at start (lldb-dap is not affected).
- Existing config: `~/.emacs` and a plain `~/.emacs.d/early-init.el` (not symlinks).
- `make packages` builds all 28 packages and 6 manuals. `make test`: 17 of 45 fail, 1
  skipped. `init.el` stops in `init-cmake.el` (`/usr/share/emacs/site-lisp` has no
  `cmake-mode.el`); a build-script test compares `/var/...` with its true name
  `/private/var/...`. After T-021 (0034): all pass but the gdb and patched-clangd tests,
  which skip; on Arch all 54 pass (2026-10-09). Startup 0.77 - 1.23 s (3 runs, load 4;
  Arch: 0.15 s, D-038).
- MacPorts CMake is 3.31.12: its `build.ninja` names the build type once, as the
  file's `CONFIGURATION`, not as `CONFIG` in every link block as CMake 4 does (D-033).

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
8. DECIDED D-058 (owner 2026-10-09, O-24 c): `make test` passes on the machine at hand
   (Arch or the Mac) before a commit; the other platform is not required.
9. DECIDED D-104 (owner 2026-10-14, O-54 (b); "let test files run in real HOME, if
   desired; move the check to the runner"): `make test` runs ERT with HOME set to an
   empty temporary directory (`mktemp -d`, deleted afterwards, ERT's exit status
   kept), so no test can write to the owner's home. In that Emacs the runner first
   checks that HOME is not the real home (`~` against `~USER`, which the user database
   answers whatever HOME says) and stops otherwise. `make test REAL_HOME=1` runs in
   the real HOME, without the check. The test files do not check: a hand run works in
   any HOME, so per-file guards such as the presets tests' `project-list-file`
   (7416ce8) stay. Built (T-080, 0071): on the Mac the real home stayed unchanged
   (`~/.python_history`, which a real-HOME run rewrites, included).

## 5. Load model (the core contract)
- `early-init.el`: frame / UI settings, startup garbage-collection threshold,
  `package-enable-at-startup` nil. Nothing else.
- `init.el`: adds the generated load path and autoloads (below), loads `use-package`
  and sets its defaults, then `require`s `lisp/init-*.el` in a fixed, listed order.
  Module order is the contract; a module may depend only on modules loaded before it.
- Each module ends with `(provide 'init-<name>)`; a missing module is a load error.
- DECIDED D-098 (owner 2026-10-14, O-48 (e)): no switch for turning modules on or off;
  every module loads on both machines, DESIGN 2's "no Doom / Spacemacs layer" stays.
  Checked the same day for dependencies that only init.el's order satisfied (each
  module loaded alone after init.el's prelude; each file byte-compiled alone):
  init-python called init-lsp's `emacs-cpp-lsp-server` without requiring it; it now
  does, as init-cpp and init-latex (removed by D-145) do, and the test
  `init-modules-load-alone` loads
  every module of init.el on its own in a child Emacs. At run time, not load time,
  init-completion's `M-o` calls projectile and eglot, configured by init-project and
  init-lsp below it: O-49, moved by D-099. Everything else a module uses is its own
  packages, init.el's prelude (`emacs-cpp-root`, the platform defaults) or a module
  above it.
- DECIDED D-099 (owner 2026-10-14, O-49 (a)): go to anything (`M-o`,
  `emacs-cpp-go-*`) moves unchanged from init-completion to its own module,
  `lisp/init-go-to-anything.el`, loaded after init-lsp and requiring init-completion,
  init-project and init-lsp, whose packages it uses (consult; projectile's files and
  projects; eglot's servers through consult-eglot). Its tests move to
  `test/init-go-to-anything-test.el` (renamed `init-go-to-anything-...`). After the
  move, byte-compiling init-completion alone names only its own packages.
- `use-package-expand-minimally` t: use-package then does not wrap forms in its own
  error catching, so a broken package form stops startup (principle 1).
- Packages: section 12 (D-006). `package.el` is not used at startup.
- DECIDED D-045 (owner 2026-10-08, O-19): Python rides along with mode, language server
  and debugger (T-018): `python-ts-mode` (system grammar `tree-sitter-python`), pyright
  through eglot in project files (SUPERSEDED in part 2026-10-21 by D-140: ty on Arch,
  pyright on the Mac), debugpy through dape's own config; all from the Arch
  repositories (on macOS the ports of section 3, D-050), no submodule. R and Perl: not
  configured (built-in modes only, as before). Built in T-018: pyright is named in
  `eglot-server-programs` (eglot would otherwise take pylsp or basedpyright first if
  installed later); a Python project is
  what projectile finds (git root first, else `pyproject.toml`, `setup.py` and its other
  markers), as for C++ (SUPERSEDED, code review 0031: "for Python buffers only,
  `pyproject.toml` and `setup.py` also mark a project root, buffer-local" - the
  buffer-local value had no effect); dape's `debugpy` listens on 127.0.0.1 instead of
  upstream's 0.0.0.0 (every network interface), and dape connects to 127.0.0.1, not to
  "localhost" (which can resolve to IPv6 ::1 first); startup stops if dape's debugpy
  entries change shape. Remote files (TRAMP) cannot be debugged this way: the adapter
  would listen on the remote loopback (DESIGN 2).
- DECIDED D-132 (owner 2026-10-21, O-72: "pyright, until ty can check unannotated
  code"): pyright stays the Python server on both machines (D-045); ty is not adopted.
  Revisit when ty infers the types of unannotated code, measured as in
  `RESEARCH_python_ty.md` 4a: `ret()` of `def ret(): return 1` not `Unknown`, and
  pyright's 8 inference reports on argparse.py found. The watch advice and its pyright
  tests stay (D-121). SUPERSEDED 2026-10-21 by D-140.
- DECIDED D-140 (owner 2026-10-21, D-132 reconsidered: "D-132 (b), defer (c) until ty
  testing on mac is done"; supersedes D-132, D-045 in part): the Python server is
  chosen per platform (D-055): ty (`ty server`, pacman `extra/ty`) on Arch, pyright
  on the Mac (MacPorts). Grounds: RESEARCH_python_ty 4b (first `M-.` 20 - 72 ms
  against 300 - 617 ms; large `M-?` 82 ms against 1.09 s in the server, half the
  memory; pyright's first `M-?` through eglot incomplete) and the owner's project
  (pyright 370 errors, ty 298, both mostly `gi.repository` without stubs). Accepted:
  ty's weaker inference of unannotated code (4a). (c), ty on the Mac too, waits until
  ty is tested there (T-121; a local port, RESEARCH_python_ty 7; the port: D-180).
  Built by T-120.
- DECIDED D-142 (owner 2026-10-21, O-75: "make return-type inference opt-in with a
  per-project .dir-locals.el switch"): ty's `analysis.return-type-inference` stays
  off; a project turns it on with `emacs-cpp-ty-return-type-inference` (NEW,
  default nil) in its `.dir-locals.el`. The config sends it as ty's inline
  `configuration`, computed per project: eglot reads `eglot-workspace-configuration`
  in a temporary buffer with the project's directory variables applied
  (`eglot--workspace-configuration-plist`). Grounds: RESEARCH_python_ty 8 (on SymPy
  the first `M-?` 12 times as long, 7 times the memory). pyright (the Mac, D-140)
  always infers return types; the switch does nothing there. Built (T-123, 0097).
- DECIDED D-143 (owner 2026-10-21, O-75 (r2): "Draft the flymake backend + ruff
  format changes"): ruff without its language server: a flymake backend running
  `ruff check --output-format json --stdin-filename FILE -` beside eglot's, and
  `C-c l f` formatting by `ruff format --stdin-filename FILE [--range ...] -`, as
  latexindent does for LaTeX (D-101). ruff from pacman (`extra/ruff`) and MacPorts
  (`ruff`), no new package source. Build: T-124. DEFERRED 2026-10-21 (owner: "until
  performance with ty alone becomes an actual problem, due to additional maintenance
  overhead from ignore lists").
- DECIDED D-055 (owner 2026-10-09, T-024): defaults that differ by platform live in one
  file per platform (NEW, `lisp/defaults-<platform>.el`), loaded by `init.el` for
  `system-type` before the modules; they hold choices only, e.g. the debugger offered
  first (Linux: gdb, macOS: lldb). Platform mechanics stay inside their modules as
  `system-type` branches: cmake-mode's directory (D-013), eglot's watch limits (D-054),
  lldb-dap's program (D-051), `${hostSystemName}` (D-016). Done when for the code
  (agreed 2026-10-09; built in T-031, 0039): `init.el` loads the file for the running
  platform and stops with an error on an unknown one; `C-x C-a d` in a C++ buffer offers
  `gdb-preset` on Linux and `lldb-preset` on macOS when dape's history has no entry
  (history still wins); tests on both platforms; make test passes.
- DECIDED D-040 (2026-10-08, owner report "custom themes are not saved on restart"):
  `custom.el` loads last, so a setting saved with Customize wins over the config's
  default. The default theme (`modus-vivendi-tritanopia`) is loaded from
  `after-init-hook` only when no theme was saved. Cause found: loading it before
  `custom.el` enabled the saved theme left no theme's faces in effect (white
  background in a graphical frame, `custom-enabled-themes` naming the saved one).
- DECIDED D-139 (owner 2026-10-21, O-56: "O-59 close", confirmed the same day as
  meaning O-56): no theme follows macOS's dark / light setting; the theme is the one
  chosen or saved with Customize (D-040). RESEARCH_dark_theme stays as findings.
- DECIDED D-041 (owner 2026-10-08): built-in `recentf-mode` is on, 200 files, Emacs's
  state files under `~/.emacs.d/.cache/` left out. `C-x b` (consult) lists recent
  files below the buffers, `C-x C-r` is `consult-recent-file` (instead of
  `find-file-read-only`), `C-c p e` the project's. Startup unchanged (0.151 s).
- DECIDED D-066 (owner question 2026-10-10: advancing indentation by hand by the
  configured step): in C++ buffers `tab-stop-list` follows `c-ts-indent-offset`
  (stops at one and two steps; Emacs repeats the interval), so `M-i`
  (`tab-to-tab-stop`) and `C-x TAB` then `S-<right>` move by the project's step from
  `.dir-locals.el`; before, they moved by `tab-width` (8). `tab-width` itself is
  left alone: it is how existing tab characters are shown.
- DECIDED D-063 (owner 2026-10-10: "global-display-line-numbers-mode, but without
  buffers like treemacs"): line numbers in buffers whose mode derives from
  `prog-mode`, `text-mode` or `conf-mode`, from their hooks. Not the global mode: in
  Emacs 31.1 it turns on in every buffer but the minibuffer, with no exemption list,
  so leaving out treemacs, magit, `*compilation*`, help and dape's buffers would need
  a list grown with every package; the three hooks give the same set the other way.
- DECIDED D-073 (owner 2026-10-10: "when scrolling a file with line numbers, the line
  number bar width changes"): the line number column is as wide as the buffer's last
  line number needs when `display-line-numbers-mode` turns on
  (`display-line-numbers-width-start` t) and never narrows
  (`display-line-numbers-grow-only` t). Emacs's default sizes it for the lines in the
  window, so scrolling from line 99 to 100 widened it and shifted the text sideways.

## 6. Architecture
Current overview for any reader: `ARCHITECTURE.md` (2026-11-04). The table below is the
block list as built through T-046 and partly stale (Python's server: D-140).
| block | location | tag | notes |
|---|---|---|---|
| early init | `early-init.el` | KEEP | T-002, owner-confirmed |
| platform defaults | `lisp/defaults-<platform>.el` | PROTOTYPE | T-031 (D-055) |
| init | `init.el` | KEEP | T-002, replaces `~/.emacs` (D-003) |
| packages | `lib/<repo>/` submodules | KEEP | 34 packages after T-090 (section 12) |
| clangd, macOS | `packaging/clangd-index-nav/build-macos.sh` | PROTOTYPE | T-023, D-052 |
| fswatch | `packaging/fswatch-no-loss/` | PROTOTYPE | T-098, D-109 |
| package build | `scripts/build-packages.el` | KEEP | T-002, `make packages` |
| theme | `lisp/init-ui.el` | KEEP | T-002 |
| writing | `lisp/init-writing.el` | KEEP | T-002: markdown, org-journal |
| completion UI | `lisp/init-completion.el` | KEEP | T-003, owner-confirmed |
| project, tree | `lisp/init-project.el` | KEEP | T-002: projectile, treemacs |
| LSP | `lisp/init-lsp.el` | PROTOTYPE | eglot's form, `C-c l` (D-091) |
| go to anything | `lisp/init-go-to-anything.el` | KEEP | `M-o` (D-074, D-099) |
| C++ | `lisp/init-cpp.el` | PROTOTYPE | T-004: c++-ts-mode, clangd |
| presets | `lisp/emacs-cpp-presets.el` | PROTOTYPE | T-004: D-016 - D-018 |
| CMake build | `lisp/emacs-cpp-presets.el`, projectile form | PROTOTYPE | T-005 (D-035) |
| CMake mode | `lisp/init-cmake.el` | PROTOTYPE | system cmake-mode (D-013) |
| Python | `lisp/init-python.el` | PROTOTYPE | T-018: ts-mode, pyright, debugpy (D-045) |
| cells | `lisp/init-cells.el` | PROTOTYPE | T-046: code-cells, Python (D-072, D-145) |
| debugger | `lisp/init-debug.el` | PROTOTYPE | gdb / lldb presets (D-031, D-051, D-056) |
| git | `lisp/init-git.el` | KEEP | magit, treemacs-magit, diff-hl (T-015, T-016) |
| keys | `lisp/init-keys.el` | UNVALIDATED | NEW: `C-c l` map (D-004) |
| tests | `test/*.el`, `make test` | KEEP | 21 ERT tests after T-004 |
Known defects: none yet (nothing built).

## 7. C++ language server (eglot + clangd)
- DECIDED D-001: eglot is the LSP client.
- DECIDED (T-004, 2026-10-07): clangd gets only `--compile-commands-dir` (D-016); all
  other flags stay at clangd's defaults until a measurement asks for one (principle 7).
  Superseded PROPOSED list (background-index, clang-tidy, header-insertion,
  completion-style, pch-storage, malloc-trim, -j, query-driver): S1 showed
  `--query-driver` changes nothing for RMO, and the T-004 integration test shows clangd
  23 runs clang-tidy without `--clang-tidy`. clang-tidy checks come from the project's
  `.clang-tidy`; without one, no clang-tidy findings appear.
- The user-level clangd config `~/.config/clangd/config.yaml` exists, generated by Qt
  Creator (Hover ShowAKA, strict unused includes) and overwritten by it; this config
  does not depend on it and does not edit it.
- DECIDED D-016 (S1 PASS, owner 2026-10-07): eglot starts clangd with
  `--compile-commands-dir=<binaryDir of the active preset>`; switching the preset
  restarts the server with the new directory. Nothing is written into project trees.
  Implemented in `lisp/emacs-cpp-presets.el` (T-004): `inherits` resolved as CMake does
  (earlier parent wins, `hidden` not inherited), the documented path macros expanded
  (`${hostSystemName}`: Linux or Darwin, T-021), `include` and `$vendor{}` rejected
  as unsupported. T-028 (0037): a preset's `condition` is evaluated as CMake does
  (inherited, a parent's null not; a false one leaves the preset out of the choice,
  the default and `C-c l P`), except the regular-expression types, which are refused
  (ECMAScript, not Emacs syntax); `$env{}` takes the preset's `environment` expanded,
  null as unset, a cycle as an error.
- DECIDED D-092 (owner 2026-10-13, O-43 (a), tier 1): clangd starts with
  `--rename-file-limit=0`, for the system and the patched clangd: its default stops a
  rename at 50 files ("The number of affected files exceeds the max limit 50").
  Measured on a generated project of 62 sources: refused before, 63 files renamed
  in 284 ms through the shipped config after.
- DECIDED D-094 (owner 2026-10-13, O-43 (c); done when agreed): refactorings by
  clang's command-line tools, from `lisp/emacs-cpp-refactor.el` on the active preset's
  database, each in a compilation buffer from the project root, unmodified buffers
  reverted afterwards: `C-c l T` run-clang-tidy -fix (checks asked, empty: the
  project's .clang-tidy); `C-c l M` clang-move (classes to a new header / source,
  run from the include root so the new `#include` is spelled like the old one, the
  old header including the new one; the new source must be added to CMakeLists.txt,
  a message says so). Tools from `emacs-cpp-default-llvm-tools-dir` (D-055: MacPorts'
  `/opt/local/libexec/llvm-23/bin`; Arch: exec-path, pacman's clang ships them),
  refused by name when missing. Not built: `C-c l N` clang-change-namespace (agreed):
  LLVM 23.1.3's crashes (segmentation fault) when given two sources, and run per
  source it renames the header's namespace but not the uses in main.cc, then fails.
  Debugged 2026-10-14: a use-after-free, `MoveNamespaces` keeps each translation
  unit's `SourceManager` pointer and is never cleared (still so on LLVM `main`;
  report drafted, `docs/upstream/clang-change-namespace-multiple-sources.md`). And
  by design the tool only re-qualifies references inside the moved code, never the
  uses outside the old namespace, so even fixed it would leave those broken: the
  text route (MANUAL 8, "Renaming a namespace") stays the way. Patched 2026-10-14
  (owner): clearing both maps at the end of each translation unit; built in scratch
  from 23.1.1's two sources against MacPorts' LLVM 23.1.3 libraries (10 s): two and
  three sources run, header and sources moved once, they compile; the patch is in
  the report draft. Shipped as D-097.
  Run here on a generated project (namespace `geom`, two classes): tidy replaced
  both `0`s with `nullptr`; move created `geom/square.h` / `square.cc`, the project
  built and ran once `square.cc` was in CMakeLists.txt. Built (T-068, 0063).
- DECIDED D-136 (owner 2026-10-21, O-43 (b3): "O-43 (b3)"): no change-signature
  tweak for clangd; S12's FAIL stands and MANUAL 8's by-hand route is the way.
- DECIDED D-146 (owner 2026-10-31, O-77 (a): "O-77 (a)"): clangd stays the C/C++
  server and ast-grep is not added, neither as a server, a search command nor a
  flymake backend: its server serves rule diagnostics only, it sees no scopes or types,
  and tree-sitter misreads deal.II's macros (RESEARCH_ast_grep 2 - 4).
- DECIDED D-097 (owner 2026-10-14, "package + `C-c l N`"; done when agreed):
  `packaging/clang-change-namespace/` holds D-094's fix as a patch file (0001,
  `git format-patch` form) and `build.sh`, one script for both machines: the tool's
  three files of LLVM 23.1.1 (downloaded from github.com's llvm-project at tag
  llvmorg-23.1.1, or taken from the release tarball with `--tarball`; sha256-checked
  either way), patched, compiled and linked against the installed LLVM 23 (macOS:
  MacPorts' llvm-23, with the SDK passed explicitly; Arch: pacman's llvm and clang),
  then run once on two generated sources (the unpatched tool: exit 139 there), and
  installed to `~/opt/clang-change-namespace` with `lib/clang` linked to the installed
  clang's builtin headers. Mac: 31 s. Arch: not run yet. `C-c l N`
  (`emacs-cpp-refactor-change-namespace`, `lisp/emacs-cpp-refactor.el`) asks the old
  and the new name (`a` or `a::b`, anything else refused), refuses loudly when
  `emacs-cpp-namespace-program` (default the installed file) is missing, runs the
  tool in place on every source of the active preset's database in a compilation
  buffer, limited to files under the project root
  (`-file_pattern`), then lists the lines still using `old::` in the project's files
  in a grep buffer in Emacs 31's grep-edit mode with `new::` already put in: the
  edits are in the files' buffers, not saved, `C-/` in the list takes one back,
  `C-x s` saves (MANUAL 8's route, without the typing). A `x::old::` nested
  namespace, `myold::`, `using namespace old;` and `namespace a = old;` are left
  alone. No `-style`: the tool takes the same value as its fallback style, where
  `file` is refused and its clean-up skipped (an empty `namespace old {}` left), so
  it formats its edits in LLVM style, not the project's `.clang-format`. Run here on
  a generated project (header, two sources, `geom` to `shapes`): header and source
  moved, `geom::` and `::geom::` in main.cc replaced through the list; saved, it built
  and ran. Built (T-072, 0065).
- DECIDED D-026 (owner 2026-10-08, after S8 PASS): the config keeps clangd and can run
  the patched clangd that answers navigation from its index (O-11):
  `emacs-cpp-clangd-program` nil = system clangd; a path = that program with
  `--navigation-from-index`. A configured program that is missing or lacks the flag
  refuses eglot (no silent fall back to the system clangd). Supersedes D-023 / D-024
  (ccls hybrid, never merged; branch `t013-ccls-hybrid` kept for reference).
- DECIDED D-027 (owner 2026-10-08): the patched clangd is installed from
  `packaging/clangd-index-nav` (PKGBUILD: 23.1.1 tarball plus the local clangd
  commits as patches, four since pkgrel 2; standalone build against the system LLVM) to
  `/opt/clangd-index-nav`, depending on `llvm-libs` and `clang` = 23.1.1 exactly, so
  an LLVM upgrade is visible to pacman and needs a rebuild of the package.
  Arch only; on macOS D-052. Amended 2026-10-20 by D-123: `pkgver` follows the
  installed LLVM, written by `make clangd`; the exact `depends` stay.
- DECIDED D-052 (owner 2026-10-09, O-23): on macOS the patched clangd is built by a
  script in the repository (NEW, T-023) that follows the self-contained build in
  `docs/CHEATSHEET.md` (macOS item 6): the 23.1.1 release tarball, checked against the
  PKGBUILD's sha256 (since D-100: 23.1.3, the script's own sha256); the same patches;
  clang and clang-tools-extra built with CMake and Ninja from MacPorts (D-053);
  clangd and its builtin headers installed to `~/opt/clangd-index-nav`, a directory
  outside the repository. Self-contained, not
  built against the system LLVM as D-027: MacPorts' `llvm-23` is 23.1.3, not 23.1.1.
  Extends D-014: the script downloads the tarball, only when the owner runs it.
  Built in T-023 (0036, 2026-10-09): `packaging/clangd-index-nav/build-macos.sh` reads
  version, patches and checksums from the PKGBUILD (the version and the tarball's
  checksum no longer, D-100); `--tarball` uses a downloaded file. Test run on the Mac:
  14 min wall, 3.3 GB build tree; the clangd links MacPorts' libedit, zlib and zstd.
- DECIDED D-100 (owner 2026-10-14: "update llvm/clangd to 23.1.3 on macOS", macOS
  only): on macOS the patched clangd is built from LLVM 23.1.3, the release of
  MacPorts' `llvm-23`. `build-macos.sh` names the release and its tarball's sha256 (the
  one github.com lists) itself and still takes the patches and their checksums from
  the PKGBUILD. Arch stays at 23.1.1, pacman's LLVM (D-027; since D-123 whatever
  pacman installs, 23.1.3 on 2026-10-20): each platform follows its
  system's LLVM, so the two releases can differ. Amends D-052. Patches 0001 - 0009
  apply to 23.1.3 without fuzz; clangd's sources differ from 23.1.1 only in
  `CodeComplete.cpp` and its test. Built (T-073, 0067).
- DECIDED D-123 (owner 2026-10-20, 0084 review:B-1: "Tier 2 under own D-nnn
  llvm-unpin.patch"; amends D-027): on Arch the PKGBUILD's `pkgver` follows the
  installed LLVM. `make clangd` runs `scripts/build-clangd.sh`, which reads
  `llvm-config --version`, refuses anything but three numbers and an `llvm-libs` of
  another release, writes `pkgver` and refreshes the checksums with `updpkgsums`
  (`pacman-contrib`) when they differ, then runs `makepkg` with `MAKEPKG_FLAGS`
  (`-si` installs). `depends` stay exact (D-027's reason: the binary links the
  system `libLLVM` and reads the system clangd's shards). `pkgrel` keeps counting
  the patch series, not reset per LLVM release (superseded by D-150: reset to 1).
  The patch is the review's
  (`pepopepopepo/emacs-cpp`, `review/llvm-unpin.patch`), with a stricter version
  check and tests (`test/build-clangd-test.el`). The PKGBUILD is committed at
  23.1.3; the review built all 13 patches on it, no offset, `check()` passed.
  Done when: `make clangd MAKEPKG_FLAGS=-si` on the owner's Arch machine builds,
  passes `check()` and installs `clangd-index-nav` at pacman's LLVM (owner's run);
  the two refusals are tested. Built (0085).
- DECIDED D-150 (owner 2026-11-02, amends D-123): on an LLVM release `pkgrel` of
  `packaging/clangd-index-nav` resets to 1, as pacman's own convention; it counts the
  patch-series changes within one LLVM release only. The PKGBUILD is committed at
  23.1.4-1, the version installed on Arch since 2026-10-31. Reason: the installed
  package already carries 23.1.4-1; a label kept at 10 would mismatch it. Not taken:
  pkgrel 10 per D-123 (the series count "pkgrel 9", "pkgrel 10" in older entries
  stays as history; the patch files' numbers identify the series). `make clangd`
  still writes only `pkgver` and checksums; the reset is by hand.
- DECIDED D-060 (owner 2026-10-09, O-27 (b)): patch 0009 for the local clangd: at
  startup the background index also re-indexes the sources whose stored shards carry
  `HadErrors` (through each flagged shard's `DependentTU`, as for stale shards), so a
  source indexed while the code did not compile gets a clean shard once it compiles, and
  the index-first path of D-026 answers it again. A flagged shard is never trusted; a
  source that still has errors stays flagged and is answered from the parse.
  Unconditional (also helps `M-?`, whose cross-file results come from the same shards).
  Built in T-033 (0042, pkgrel 7): on RMO (Mac) one session rewrote the five flagged
  shards; after a restart their first `M-.` took 5 ms - 2.7 s instead of 7.4 - 12.6 s;
  ClangdTests 1414 / 1414. pkgrel 7 on Arch, S9 run 4 unchanged (owner 2026-10-09).
- DECIDED D-059 (owner 2026-10-09, T-020, review 0031): patch 0008, pkgrel 6:
  `includerOf` answers a known includer at once, before waiting for the compile
  database; only an unknown header waits as D-046 / D-047 require. The load counter's
  increment and decrement are a pair of functions side by side. ClangdTests 1413 /
  1413 on macOS with a new test that fails without the change (0041); S9 run 4 on Arch
  (pkgrel 7) unchanged: header first 10 / 10 from the index, 0.85 - 0.90 s. Not taken from
  the T-020 text: "no stall for headers that have no includer"; skipping that wait
  would bring back the header-opened-first guess of O-21.
- DECIDED D-047 (owner 2026-10-08, T-019, S9 run 2): patch 0007 (llvm-clangd cb118e30f,
  pkgrel 5): the wait of D-028 / D-046 ends as soon as the includers are recorded
  (right after the stored shards are read), not when the whole load returns. On RMO
  that drops about 0.6 s (merging symbols, rebuilding the index) from every header's
  wait; S9 run 2 measured 1.48 - 1.56 s from opening to the decision with 0006 alone.
- DECIDED D-046 (owner 2026-10-08, O-21, S9 PASS): patch 0006 (llvm-clangd 9fc23463e,
  pkgrel 4): `BackgroundIndex::includerOf` first waits for the compile database to hand
  over its pending projects (`blockUntilIdle`), then for the stored shards to load,
  both within the 5 s of D-028, so a header opened as the first file of a session gets
  its includer's command. Cost on RMO: about 0.4 s more for such a header (the load).
- DECIDED D-028 (owner 2026-10-08, tier 2; resolves O-5 for indexed headers): the
  patched clangd compiles a header without a database entry with the command of a
  source file that includes it, as the background index records (patch 0005, hidden
  flag `--header-flags-from-index`, waits up to 5 s for stored shards still loading);
  clangd's own includer cache keeps precedence. The config passes both patched flags
  and refuses a binary lacking either (D-026). Headers no indexed source includes, and
  first sessions before indexing, keep clangd's guess. Replaces spike S4 (owner
  ruling: the synthetic reproduction is the evidence, RMO the proof).
- DECIDED D-023 (superseded by D-026) (owner 2026-10-08, after S6): eglot runs ccls,
  told the active preset's
  build directory (`compilationDatabaseDirectory`) and keeping its index cache in
  `<build>/.ccls-cache`; clang-tidy, which ccls lacks, runs as a separate flymake
  backend over a copy of the database without GCC's module-scanning flags (clang-tidy
  rejects `-fmodules-ts`, `-fmodule-mapper=`, `-fdeps-*=`), for source files only.
  Loses clangd's refactoring code actions, type hierarchy and inlay hints. Supersedes
  D-016 once T-013 merges; blocked by O-10.
- DECIDED D-024 (superseded by D-026) (owner 2026-10-08): the clang-tidy backend runs
  on open and on save by
  default, `emacs-cpp-clang-tidy-trigger` set to `demand` restricts it to
  `emacs-cpp-clang-tidy-check`. clang-tidy reads the saved file; unsaved edits keep
  the last findings.
- DECIDED D-019 (2026-10-08): eglot starts only for C++ files of a project with
  CMakePresets.json (`emacs-cpp-presets-eglot-ensure` on `c++-ts-mode-hook`); a project
  without presets gets an echo-area note, a file in no project gets nothing. Library
  headers reached with `M-.` (deal.II, Boost, the standard library) join the project's
  clangd through `eglot-extend-to-xref`, so `M-.` keeps working inside them. Before:
  such a header tried to start its own server, was refused by D-018, and had no xref
  backend (owner report 2026-10-08).
- DECIDED D-018: eglot is refused, with an error-level warning naming the fix, when the
  active preset's `compile_commands.json` is missing (`cmake --preset <name>`) or an
  entry lacks `-std=` (D-011). Before T-004, eglot started a bare clangd: 21 false
  errors and no `M-.` in RMO (owner, 2026-10-07; reproduced by a negative control).
  Extended 2026-10-10 (owner, after a probe of seven broken projects): the same
  warning for every error on the way to clangd's command, which eglot showed as one
  echo-area line only (a mistyped preset file, a preset without `binaryDir`, a database
  CMake is still writing), and for an empty database (`[]`), with which clangd started
  on its fallback flags for every file. Fallback flags were not slower (5.0 s against
  6.8 s, `clangd --check`, one file); the cost is false errors.
- DECIDED D-068 (owner 2026-10-10, after the D-018 probe): a C++ source (`.cc`,
  `.cpp`, `.cxx`, `.c++`, `.C`) that exists on disk but is missing from the active
  preset's `compile_commands.json` gets a `*Warnings*` popup when eglot starts
  managing it, once per file per session, naming the file and the fix (add it to
  CMakeLists.txt, configure with `C-c p c o`). clangd keeps running: it guesses the
  file's flags from a listed neighbour, which may be wrong. Refusing would stop clangd
  for the whole project over one file. Not for headers (a database lists none), files
  not yet saved (a new file comes before its CMakeLists.txt line) or files outside a
  preset project. The database is read again only when it changes on disk.
- Background (S1, O-1): how clangd finds `compile_commands.json` when presets build into
  `build/<preset>/`; clangd only searches parent directories and their `build/` subdir.
  Candidates: (B) project `.clangd` with `CompileFlags: CompilationDatabase:`, (C)
  symlink in the project root, (D) `--compile-commands-dir` passed by Emacs from the
  active preset. S1 run 1: all three find the database with identical results and cost
  (about 7.6 s, 457 MB for a deal.II translation unit); final choice after run 2.
  Presets must set `CMAKE_EXPORT_COMPILE_COMMANDS=ON`.
- DECIDED D-011: a project's compile database must state the C++ standard explicitly.
  GCC 16 defaults to C++20, so CMake omits `-std` and clangd then assumes C++17 (false
  errors, S1 run 1). Projects set `CMAKE_CXX_EXTENSIONS OFF`, which makes CMake emit
  `-std=c++NN`. Enforced at eglot start by D-018.
- DECIDED via D-028 (was UNDECIDED, S4, O-5): headers are not in the database; a
  header opened with no including file open gets flags interpolated from a "nearest"
  entry (in RMO `fmt/src/format.cc`, wrong include paths). S1 live check: once an
  including `.cc` is open, clangd reuses its flags and the header is clean; opened
  first, it shows errors. The patched clangd takes an includer from its index (D-028).
- DECIDED D-121 (owner 2026-10-20, O-69: "(c) + (d) - use the mac specific fixes as
  Lisp in the config, and keep it as platform-specific code"; "also remove vendored
  xref": none is vendored, the xref patch 0003 goes with eglot): eglot is Emacs
  31.1's own (1.24.31) on both machines; submodule `lib/eglot` and patches
  `patches/eglot/0001 - 0003` removed (supersedes D-108, D-117). On macOS only,
  `lisp/emacs-cpp-eglot-watch.el` carries the former 0001 / 0002 as advice on the
  built-in eglot (`eglot--watch-globs`, `eglot--count-file-watches` overridden,
  `eglot-unregister-capability` wrapped, `eglot--on-shutdown` preceded): partial
  watches at the cap or a refused watch, the registration answered with success;
  one watch per directory shared by a server's registrations. It refuses loudly to
  install for any eglot but 1.24.31 (its library header). The owner's exception to
  D-069's "no Lisp workarounds beyond a line or two". Found while building (owner
  2026-10-20: "Project only, as Mac"): with the built-in eglot on Arch, pyright's
  watch of Python's library (6358 directories, three registrations) passed eglot's
  10000 and pyright exited, so `eglot-watch-files-outside-project-root` is nil on
  both platforms (RESEARCH_eglot_fork 7 corrects its Arch estimate). Built (T-110,
  0083). SUPERSEDED in part (2026-10-21, T-119, D-127): `lisp/emacs-cpp-eglot-watch.el`
  removed, the fswatch backend (DESIGN 7.1) carries eglot's watches on both
  machines; watches outside the project root stay skipped, by the backend itself.
- DECIDED D-120 (owner 2026-10-20: "Go with LSP 3.18 as far as possible--in particular
  the consistent config--but leave changing the three-letter pre-filter for a later
  stage"; answers the same day: ignore case, tiers everywhere, paths keep
  partial-completion): the config's definition of a match is LSP 3.18's
  (`workspace/symbol`'s `query`: "match case-insensitive and ... check that the
  characters of query appear in their order in a candidate"), ranked in tiers as
  clangd ranks with patch 0013: (1) the input runs unbroken from a word start; (2) it
  runs unbroken inside a word, or its letters start several words; (3) letters in
  order with gaps inside a word. Every prompt but path completion (`C-x C-f` keeps
  `partial-completion`, the documented exception): orderless's prompts (`C-x b`,
  `C-c p f`, `M-x`, ...) and `M-o`'s buffers, recent files, bookmarks and project
  files; case always ignored (smart case off; D-105 already for `M-o`); sorted by
  tier, the present order kept within a tier, `M-o` keeping its sources apart and
  clangd's symbols in clangd's order. clangd's own matcher stays as it is until O-68's
  later stage, so tier 3 does not reach symbols yet. Build: T-109. Built (T-109,
  0082): tiers by regexps compiled once per input (1 - 7 ms for 2767 names, at most
  89 ms for 35000, Arch); `make test` 132. S11 run 6 (owner, RMO, 4286 files):
  opening 88.6 - 101.0 ms, each key's first screen at most 87.8 ms, within 150 / 100
  ms (run 3: 63 - 74 / 29.5 ms on 2673 files).
- DECIDED D-141 (owner 2026-10-21, after "\"ect\" matches ~/sourc\"e\"/repos/
  RMO-gross-pitaevskii/in\"c\"lude/rmo/gpe/me\"t\"ric.h": option (c)): (a) the filter
  matches D-120's definition: orderless's `orderless-flex` (gaps anywhere, across
  words and `/`) gives way to letters in order with gaps only inside one word, in
  every orderless prompt; (b) in `M-o`, as CLion's Go to File
  (`GotoFileItemProvider.processItemsForPattern`: the input split at its last `/`),
  a word without `/` must match within a candidate's last path component, the file
  name; a word with `/` matches its part after the last `/` in the file name and
  its part before in the directories. Measured on RMO's 437 tracked files (Python
  stand-in for the rules): `met` 420 recent files today, 9 then; `gpe` 437 and 167
  today, 1 by name (`gpe/` for the directory). Built (T-122, 0096): every input
  under 23 ms a key on RMO's 4402 files; `make test` 149.
- SUPERSEDED by D-134 (2026-10-21; the function pays only compiled, S16): DECIDED D-124
  (owner 2026-10-20, review 0084 section 3: "C, spike first"): D-120's tiers become a
  function, `emacs-cpp-word-start-p` (the word-start rule in one place) and a matcher that
  finds tier 1 by `string-search` on the lower-case candidate, each hit tested for a word
  start on the original (its capitals decide), tier 2 by a second search or one pass for
  initials; the 15 rows and the sort example of `init-completion-match-tiers` stay its
  specification, `emacs-cpp-match-tier` and `emacs-cpp-match-sort-by-tier` keep their
  signatures. Rejected: (A) Emacs 31's `flex` cost (review M-5: loses the initials rows
  and the order within a tier, i.e. D-120); (B) a scoring library (a new dependency, a
  rule clangd does not share). Spike S16 (`spikes/s16-match-function`, T-112) first. Dry
  run (Mac, 2026-10-20, 33768 deal.II 9.6.2 names, 8 inputs): spec 0 failures, 270144
  pairs with the regexps' tier, 0 disagree; sorting a prompt's filtered set takes the
  function 1.3 - 1.9 times the regexps' time interpreted, a third of it byte-compiled, a
  quarter native. So the function is adopted only together with compiled `lisp/` (D-125,
  S17); interpreted, the regexps stay.
- DECIDED D-119 (owner 2026-10-19, O-67 (a): "O-67 (a) agree"): mid-word matches
  ranked by shape in clangd (rule R4, `RESEARCH_go_to_anything.md` 19) go to spike
  S15 (`spikes/s15-mid-word-rank`, T-107) before any patch; tier 3. A fuzzy match
  contiguous from a word start keeps its place and order; scattered fuzzy and
  mid-word matches follow, by the share of the name they cover (doubled at a word
  end) times quality, in Dex and MemIndex too, whose own cut at the limit runs
  first. Found on the way: patch 0012's Dex and MemIndex score a mid-word match -1
  times quality, so among mid-word matches the better symbol ranks lower and a
  limit keeps the worst; and they subtract 1e6 from a float, whose steps there are
  0.0625, so mid-word matches tie (S15 dry run 2). Recorded, fixed by the patch S15
  leads to (a Low score becomes -1 / (1 + score)). A PASS leads to clangd patch 0013
  with unit tests, pkgrel 9, a Mac rebuild. Dry run 3 (2026-10-19, Arch, a toy with
  Kokkos, deal.II, Trilinos headers): 7 of 7 criteria, after the criteria were
  refined in dry runs 1 - 2 (`spikes/s15-mid-word-rank/DRY-RUN.md`); `ector` ->
  `dealii::Vector` first, no good fuzzy match moved. Owner 2026-10-19: RMO on Arch
  decides (not step-1). Owner's run 1 on RMO: 6 of 7, criterion 4 failed for `ass`
  only, the baseline differing from itself between its two runs; owner: rerun.
  S15 PASS (owner's run 2, 2026-10-19, RMO, `RESULTS.md`): 7 of 7; next T-108,
  patch 0013. Built (T-108, 0081): `packaging/clangd-index-nav/0013-...`, pkgrel 9;
  ClangdTests 1426 passed on Arch (6 new; 4 fail with 0012's ranking); the package
  built from the clean tarball. Left: install and `make test` on both machines, the
  Mac build, the owner's check on RMO.
- DECIDED D-118 (owner 2026-10-19, O-66 (a)): with a project root, `M-o`'s `s`
  symbols (the project's only, D-082) are headed "Project Symbol (server)", narrow
  label "Project Symbol", as "Project File"; without a root `s` (every symbol) stays
  "Symbol (server)"; "All Symbols" unchanged. Built (tier 1).
- DECIDED D-117 (SUPERSEDED 2026-10-20 by D-121: the built-in eglot's finders work
  with xref 1.7.0, no patch; owner 2026-10-19, O-65 (a)): eglot patch 0003 (D-069): the
  finders `eglot-find-declaration`, `-implementation`, `-type-definition` call
  `xref-find-by-kind` where xref has it, else show the backend's
  `xref-backend-xrefs-by-kind` through `xref-show-xrefs` (xref 1.7.0, Emacs 31),
  asking for the identifier only with a prefix argument or none at point, as
  Emacs 31's finders; `eglot-find-typeDefinition` is an alias of the new name,
  which eglot's menu and command list and `init-lsp.el` now use. Goes upstream
  with T-032. Built (T-106, 0079).
- DECIDED D-115 (owner 2026-10-19, O-64 (a)): file-watch limits stay as they are on
  Arch: `eglot-max-file-watches` 10000, the kernel's own. The owner's numbers on
  step-1 (31 GB RAM): `fs.inotify.max_user_watches` 524288, `max_user_instances`
  1024, `max_queued_events` 16384; the kernel limit is about fifty times eglot's,
  so (b) is not needed; (c) and (d) not taken. (Since D-121 Arch runs the built-in
  eglot and every platform watches only the project.) The vendored eglot answers a refused
  watch with success (D-108), so pyright does not exit into a reconnect loop.
- DECIDED D-111 (owner 2026-10-15: "Agree to recommendations on open watch
  questions"): DESIGN 7.2 as recommended: T-090 agreed (vendor eglot, no startup
  check); patch 0001 kept; O-61 (a) tracked-only lists closed; (b) a README note,
  no code; (c) watch patterns only as the fswatch backend's pre-filter; (d) dropped;
  (e) shared watches adopted for the `file-notify` path, with each handler called
  under `condition-case`; (g) dropped; T-032 sent with 0001 and (e) (the owner's).
- DECIDED D-110 (owner 2026-10-15, O-62 (a) - (e)): the fswatch backend of DESIGN
  7.1: (a) `eglot-fswatch-program`, set by the user; (b) a stock fswatch runs with
  one warning, recognised by `--queue-limit` missing from its `--help`; (c) a
  warning on `Overflow`; (d) `eglot-watch-file-patterns` as pre-filter, with the
  benchmark repeated on the built filter; (e) a dead fswatch reported, restarted
  by hand with `M-x eglot-fswatch-restart` or `M-x eglot-reconnect`. Built after
  T-090; its done when to agree.
- DECIDED D-109 (owner 2026-10-15, O-61 (h1) (ii); tier 2, done when to agree): a
  patched fswatch is built locally on both machines, as clangd is (D-026, D-052):
  its FSEvents callback never blocks on the reader, drops are reported as
  overflow, a path's present state decides removed or not
  (`RESEARCH_platform_differences.md` 3.13); installed next to the system fswatch.
  It serves an fswatch backend for eglot (O-61 (h1)), which is not designed yet.
  Build: T-098. Owner 2026-10-15 with T-098: the cap configurable. Built (T-098,
  0074): `packaging/fswatch-no-loss/` (fswatch 1.22.0, patches 0001 - 0004,
  `PKGBUILD`, `build-macos.sh`, `check.sh`); `--queue-limit=N` (default 200000,
  0: no limit). On the Mac all seven checks pass and it is installed to
  `~/opt/fswatch-no-loss`. Arch 2026-10-19: two fixes (pkgrel 2: exit under glibc,
  the cap with inotify's batches; 0074), all seven checks pass, installed; the Mac
  re-check of pkgrel 2 is left. pkgrel 3 adds patch 0005 (D-144, 0098).
- DECIDED D-108 (SUPERSEDED 2026-10-20 by D-121: Emacs's own eglot, no submodule;
  owner 2026-10-15, O-60 (b): "Vendor eglot"; tier and done when to agree): eglot
  comes from a submodule, `lib/eglot` from
  github.com/emacs-straight/eglot (GNU ELPA's eglot, i.e. Emacs master's, no tags),
  and carries patch 0001 keeping partial file watches at the cap or a refused watch
  (`docs/upstream/eglot-watch-cap-partial-watches.patch`, D-069); it shadows Emacs's
  built-in eglot (`lib/` first on `load-path`). The mirror at c79f727 (2026-10-14)
  is newer than 31.1's eglot 1.24.31 (its header says 1.24): 182 lines differ outside
  the watch code (`eglot-completion-replace-semantics`, fixes). The upstream report
  (T-032) still goes out with the patch. Build: T-090. Owner 2026-10-15: no startup
  check that the patched eglot is the one loaded; that is the user's responsibility.
  Built (T-090, 0075): submodule `eglot` at c79f727 with
  `patches/eglot/0001-Keep-partial-file-watches-...`, its manual from `eglot.texi`;
  `make packages` 34 packages, 7 patches, 10 manuals; the shipped profile loads
  `lib/eglot/eglot.elc`. With the cap at 5 on 20 directories pyright stays up (the
  test fails without the patch); `make test` 119 tests, 0 unexpected (Mac). eglot
  is not loaded at startup, so startup is unchanged: median 0.550 s on the Mac (10
  runs, 0.531 - 0.560). Its manual (owner 2026-10-15: "avoid listing two Eglot
  manuals"): `lib/info` is searched first (`Info-directory-list`, not the
  additional list), so `(eglot)` opens the vendored eglot's manual and `C-h i` lists
  Eglot once; eglot is the only vendored package Emacs also documents.
- DECIDED D-107 (owner 2026-10-15, O-59 (a): "build*/ to .gitignore"): a project's
  large untracked output trees belong in its `.gitignore`; eglot's watches and
  projectile's file lists follow git's ignore rules, and the config does not list
  them separately. For deal.II's step-1, `build*/` (the owner's project; the owner
  edits and commits it): 478 files in 22 directories instead of 14782 in 1811,
  below D-054's cap (`RESEARCH_platform_differences.md` 3.7, 3.8). Tracked-only
  listing (O-59 (b)) and an eglot patch (O-59 (c)) researched as O-60.
- DECIDED D-054 (2026-10-09, T-021; confirmed by the owner 2026-10-09, O-26 (a)): on
  macOS eglot watches files only inside the project root
  (`eglot-watch-files-outside-project-root` nil) and at most 500 directories
  (`eglot-max-file-watches`). Reason: macOS watches with kqueue, one file descriptor per
  directory; pyright asks to watch Python's library and site-packages, about 2000
  directories, Emacs refused watches at 975 and pyright exited, eglot restarting it in a
  loop (0034). Cost: a package installed while pyright runs is seen after a restart.
  Arch (inotify, one descriptor) keeps eglot's defaults. At the cap eglot fails the
  server's whole watch request and pyright exits (O-26). pyright registers its project
  three times at start before dropping two, so the cap of 500 holds Python projects up
  to about 160 directories (measured: 150 run, 400 exit); the owner's have one. An
  upstream report asks eglot to keep partial watches and to share watches among
  registrations (`docs/upstream/eglot-watch-cap-partial-watches.md`, O-26 (d), T-032).
- DECIDED D-008: C++ major mode is `c++-ts-mode` on the system grammar; `.h` files open
  in `c++-ts-mode` (the owner's projects are C++, and no C grammar is installed). A
  missing grammar is a startup error, not a fallback to `c++-mode`.
- SUPERSEDED by D-065 (2026-10-10; (e) stands): D-061 (O-28 (b), (e)): RET indents by
  the project's `.clang-format`. In a
  `c++-ts-mode` buffer managed by eglot whose server offers on-type formatting on
  newline (clangd does), RET takes the new line's indentation from clangd; the line
  above stays as typed (owner 2026-10-10: clangd's reformat of it would collapse hand
  alignment, about 900 lines in RMO). Mechanism: newline leaves electric
  indentation's characters in those buffers, so eglot's own on-type request is not
  undone by it; the line above is restored if clangd changed it. TAB and the other
  electric characters (`}`, `;`, ...) keep Emacs's tree-sitter rules; buffers without
  eglot keep electric indentation. The tree-sitter gap for namespace and class braces
  goes upstream (`docs/upstream/c-ts-mode-namespace-class-braces.md`, T-036);
  projects meanwhile carry the three rules in `.dir-locals.el` (MANUAL 8; superseded
  2026-10-10 by D-062: the config carries them). Code: T-035 (0043). A second report
  (owner 2026-10-10, T-037): a local `c-ts-mode-indent-style` is set but not applied.
- DECIDED D-065 (owner 2026-10-10, superseding D-061 (b)): RET indents by Emacs's
  rules (electric indentation with D-062's rules), not by clangd; eglot ignores the
  server's on-type formatting (`eglot-ignored-server-capabilities`), so clangd is not
  asked on newline and changes no text. Why: clangd's on-type reply also reformats the
  line RET ended (hand alignment collapsed, `double value() {}` split in two), and
  taking only part of it duplicated text (owner report 2026-10-10, fixed in 5592b4e);
  with D-062 the rules place RET's line as `.clang-format` would in RMO's cases (0 / 4 /
  8, batch 2026-10-10), need no server and no round trip. Left: `case` labels and
  arguments after an open `(` (T-040). `C-c l f` stays for exact `.clang-format`.
- DECIDED D-062 (owner 2026-10-10): a project's `.dir-locals.el` sets C++
  indentation with plain values, no `eval`. The config works around both upstream
  gaps until Emacs fixes them: after a buffer's local variables are read it rebuilds
  the indent rules from `c-ts-mode-indent-style` (T-037), adds the rules that keep a
  `{` on its own line after `namespace` or `class` at the keyword's column, in every
  C++ buffer (T-036), and, with the new safe option
  `emacs-cpp-indent-namespace-body` nil, leaves namespace contents unindented. Drop
  each workaround when the Emacs in use carries the fix. Code: T-038 (0044). Third
  workaround (owner report 2026-10-10): a class member after a blank line is aligned
  with the body's first child, `public:` at the class's column, because the fallback
  rule takes a class body for an initializer list (31.1 and master); members now sit
  one step in from the body's `{` line. RMO re-indent: 2955 -> 452 lines (T-039).
  Extended 2026-10-10 (T-040, after D-065): a second safe option
  `emacs-cpp-indent-case-labels` (default nil, as Emacs); argument lists in
  `c-ts-common-list-indent-style` `simple` (after a `(` that ends a line one step in,
  otherwise aligned with the first argument, as clang-format); constructor
  initializers and `requires` clauses one step in. Against clang-format's output of
  RMO (its `.clang-format`), Emacs's re-indent differs on 244 -> 62 lines; left: `<<`
  chains aligned under the first `<<`, macro bodies, template and alias continuations.
  Extended again (owner 2026-10-10, "add them"): four more safe options, each one
  clang-format option with the same numbers, default nil / t = Emacs's behaviour:
  `emacs-cpp-indent-access-offset` (`AccessModifierOffset`), `...-initializer-offset`
  (`ConstructorInitializerIndentWidth`), `...-continuation-offset`
  (`ContinuationIndentWidth`), `...-align-arguments` (`AlignAfterOpenBracket`). With
  MANUAL 8's values, clang-format's seven built-in styles re-indent a sample to
  clang-format's text exactly, WebKit only without nested namespaces (`Inner`).
- DECIDED D-064 (owner 2026-10-10: "leave it"): clangd's "Move function body to
  out-of-line" stays offered in every header, as upstream. clangd checks for the
  header's source file only when the action is applied (`DefineOutline.cpp`: no disk
  access in `prepare`), so on a header without a source it fails with "Couldn't find
  a suitable implementation file." (owner report, RMO). That error is accurate; no
  patch 0010 to hide the action.
- DECIDED D-130 (owner 2026-10-21, O-12 (b): "O-12 (b)"): a library's offline index
  reaches clangd through `--index-file=<index>`, added by the config to clangd's
  command for a project that names the library; the index's path per machine in the
  platform defaults file (D-055), the project naming only the library (a
  `.dir-locals.el` value, as D-062). No clangd config file is written. Reason: S10
  run 2 (`spikes/s10-library-index/RESULTS.md`): with the flag, `M-?` 2 -> 19 and
  RMO's own index kept (14 uses of `refine_global`, against 10 with a config's
  `MountPoint: /`), +218 MB. Open before code: the first `M-.` lands on the
  declaration while the index loads (S10 criterion 1); a clangd patch that waits for
  it is researched (T-117). Built with the index's build step (offline, about 2.5 min,
  10 GB peak; DESIGN 7, O-9); tier and done when proposed with T-117's result.
  Optional (owner 2026-10-21: "ensure this functionality is entirely optional"): a
  project that names no library gets clangd's command as before, needs no index,
  stamp, include directory or `clangd-indexer`, and its clangd gets no probe and no
  stderr watch (test `emacs-cpp-library-index-optional`); only `make library-index`
  uses `clangd-indexer`.
- DECIDED D-133 (owner 2026-10-21, T-118: "Patched package"): library indexes are
  written by the `clangd-indexer` of the patched clangd's own tree, so their format is
  the one the clangd reading them expects: packaging/clangd-index-nav pkgrel 10
  installs it as /opt/clangd-index-nav/bin/clangd-indexer, build-macos.sh as
  ~/opt/clangd-index-nav/bin/clangd-indexer. `make library-index LIBRARY=dealii`
  (`scripts/build-library-index.sh`) reads the library's version from its installed
  `deal.II/base/config.h`, archives that tag of the git checkout at
  ~/source/repos/dealii (an input outside the repository, read only; `DEALII_SOURCES`
  names another), configures and indexes it into indexes/ of this repository
  (ignored by git): the sources and build directory are kept, since the index points
  into them, with `dealii.dex` and `dealii.stamp`. Rejected: the indexer of an
  llvm-clangd build outside the repository (nothing keeps it at the patched clangd's
  version); deferring the build step. Kept in the package after T-118 made the
  feature optional (owner 2026-10-21: "(a) Keep it in the package"): one compile and
  one link per package build; the index format is stock LLVM's (no patch touches
  `index/Serialization`), so the system clangd reads it too. pkgrel 10 installed on
  Arch 2026-10-21 (owner); `make library-index` with it: 38 MB, `RIFF`.
- DECIDED D-131 (owner 2026-10-21, O-73 (a): "O-73 (a), with proper user
  diagnostics"): no clangd patch for the first request; the config sends one
  `workspace/symbol` when clangd connects with an `--index-file`, which starts the
  index's load (clangd loads it on the first query, 1.1 - 1.3 s;
  `RESEARCH_library_sources_index.md` 7). The window left (patch 0002's shard path
  answering within about 1.2 s of connecting) is accepted. Every way the library index
  can fail is told to the person, not swallowed (DESIGN 4): a library named by the
  project but not known on this machine, a missing or unreadable index file (both
  before clangd starts, eglot refused as D-018), clangd's own `Can't open` / `Bad index
  file` (`index/Serialization.cpp:712, 729`, error level, so seen without verbose
  logging), an index built for another library version than the one installed, and
  the request at connect failing. Code: T-118, tier 2, done when proposed there.
  Amended 2026-10-21 (owner: "can workspace/symbol be empty, what are the
  fallbacks?"; measured, `RESEARCH_library_sources_index.md` 7a): the request's reply
  is empty whatever its query (clangd answers it from the index's empty placeholder
  before the load), so it proves nothing; an empty query starts the load as any other
  does. The request is therefore a probe: it asks for one symbol the library's index
  must hold (stored with the index when it is built) and is repeated every 0.5 s until
  a result lies in the library's sources, at most 10 s; none, a warning. That also
  catches what clangd lets pass in silence: a file that is not an index (not starting
  with `RIFF`) loads as an empty YAML index with no error line, so the config checks
  the four bytes before clangd starts as well. Fallback when the probe fails: clangd
  still loads the index on the first `M-.` (the declaration first, then the
  definition), and the warning says so.

### 7.1 File watches: an fswatch backend for eglot (D-110, 2026-10-15)
- DECIDED D-127 (owner 2026-10-20, O-70 (b): "O-70 (b) agree"): watches work on very
  large projects (LLVM's size) on both machines through an fswatch backend over the
  built-in eglot: config Lisp beside `lisp/emacs-cpp-eglot-watch.el`, one patched
  fswatch (`packaging/fswatch-no-loss`, D-109) per server and project root, FSEvents on
  the Mac, inotify on Arch; `file-notify` no longer carries eglot's watches. Tier 3:
  spike S18 (`spikes/s18-fswatch-backend`, T-116) first, on both machines: a generated
  LLVM-sized tree, pyright on it, a burst of 20000 changes while Emacs is blocked for
  5 s, every change reaching `workspace/didChangeWatchedFiles`, Emacs's CPU per 1000
  records, startup unchanged. After a PASS this section is rewritten for the built-in
  eglot (its text below still assumes the vendored eglot of D-108). Supersedes the
  review's "park fswatch" (0084, O-70) and D-110's switch defaulting to nil: the
  program is set per platform (D-055), a missing one refused at startup (principle 1).
  Mac dry run 2026-10-20 (`spikes/s18-fswatch-backend/DRY-RUN.md`, 0087): 5 of 5
  proposed criteria; 20000 of 20000 changes with Emacs blocked 5 s, 7 - 9 ms of
  Emacs's CPU per 1000 records, eglot's own glob predicates fast enough; Emacs's own
  watches fail at kqueue's 975. Arch run: H-12.
  S18 PASS on both machines in mode `dedup` (2026-10-21; `RESULTS.md`): Arch run 2
  37 - 39 ms per 1000 records (run 1's 194 ms came from `eglot-path-to-uri`'s
  `file-truename` and inotify's three records per file); the owner's Mac run 4
  2 ms. Next: T-119, this section rewritten and the backend written fresh in
  `lisp/` (done when proposed there).
  Corrected 2026-11-03 (O-80, 0111): the Mac's figures in this entry (7 - 9 ms, 2 ms)
  are 41.7 times too small (`process-attributes` on Apple silicon), about 290 - 375
  and 83 ms per 1000 records, over S18's 50; Arch's stand. The PASS holds on Arch.
  Measured 2026-11-04 (D-164, 0114): the Mac's shipped backend 61 - 64 ms.
**The backend as built (T-119, 2026-10-21; supersedes the design below for the built-in
eglot).** `lisp/emacs-cpp-eglot-fswatch.el`, written fresh in the shape S18's `dedup`
mode measured (37 - 39 ms of Emacs's CPU per 1000 records on Arch; the Mac's 2 ms
read 41.7 times too small, measured 61 - 64 ms, O-80):
- **Where it hooks.** An `:around` method on `eglot-register-capability` and on
  `eglot-unregister-capability` for `workspace/didChangeWatchedFiles` takes the
  registration over (eglot's own method is not called, so `file-notify` holds no
  watch for it, and `eglot-max-file-watches` no longer applies); advice before
  `eglot--on-shutdown` ends the server's processes. Watchers based outside the
  project root are skipped, as D-121's `eglot-watch-files-outside-project-root` nil
  did (eglot's own method, which read it, no longer runs for watches). The eglot
  internals it uses (`eglot--on-shutdown`, `eglot--project`,
  `eglot--uri-path-allowed-chars`) are checked when it loads.
- **Process.** One patched fswatch per registration and root:
  `fswatch -0 -r -x --event-flag-separator=, -l 0.1 --allow-overflow -e /\.git/
  ROOT`, ROOT the root's true name (fswatch reports true names); `:noquery`, pipe,
  its stderr in a hidden buffer. It ends with its registration and its server.
- **Records to changes.** NUL-separated `PATH FLAGS`; the records of one filter call
  merged per path, flags joined (inotify writes three per written file); the type
  from the flags and the path's present state (`file-exists-p`: gone -> 3, `Created`
  -> 1, else 2); the URI as the root's URI plus the hexified relative path (not
  `eglot-path-to-uri`, whose `file-truename` was 77 of its 95 us per path, S18);
  each glob, relative to the root (a watcher's base inside the root becomes a
  prefix), as one anchored regexp; the `kind` bits honoured; a file a managed buffer
  visits skipped, as eglot does; one notification per filter call.
- DECIDED D-144 (owner 2026-10-21, T-125: "fswatch patch 0005, verify per-path time
  map memory usage on larger projects"): FSEvents keeps `Created` on a recently
  created file, so every later change of it, also of a file created before fswatch
  started, came as `Created,...,Updated` and was sent as created (1), not changed (2)
  (seen by `emacs-cpp-eglot-fswatch-real` on the Mac; a file born hours earlier
  reports `IsFile,Updated` only). fswatch patch 0005 (`packaging/fswatch-no-loss`
  pkgrel 3, `fsevents_monitor.cpp`, FSEvents only) keeps `Created` only for a file
  born after the stream's start whose inode was not reported `Created` yet; the
  inode is forgotten when the path is reported removed. The ruling's per-path time
  map was measured first: about 250 bytes per path changed (25000 paths: +6.2 MB,
  over `check.sh`'s 3 MB bound), so it is keyed by inode and holds only files created
  while fswatch runs: on S18's tree 287398 old files changed cost nothing over
  pkgrel 2, 100000 created files +4.8 MB (about 48 bytes each). An atomic save
  (a new file renamed over the old) is reported created only when its temporary
  file was not reported yet (inotify's report of it: UNVERIFIED). Rejected: a table
  in Emacs (the first change of a file created before the start stays wrong),
  accepting the label.
  `check.sh` check 5. Arch needs no rebuild (inotify, unchanged code).
- **Loudly.** The program per platform (`emacs-cpp-default-fswatch-program`, D-055);
  at startup a missing one, or one whose binary lacks `--queue-limit` (the patched
  build's option, read from the file, 0.1 ms; `--help` would cost a process start,
  3.9 ms), stops startup with the command that installs it (principle 1, D-127). At
  run time: an `Overflow` record is one warning per server per minute naming `M-x
  eglot-reconnect`, nothing sent (LSP has no "rescan"); the process exiting while
  its registration lives is a warning with its status and stderr, no restart behind
  the user's back.
- **Not covered:** remote projects (TRAMP); build directories inside the root are
  watched too (their records cost the filter, matched by the globs, mostly sent to
  nobody; measured in S18 only for created files).

SUPERSEDED (2026-10-21, by the backend as built above; the design for the vendored
eglot of D-108, kept for its reasoning):
Owner request 2026-10-15: "Design fswatch backend for eglot". A patch on the
vendored eglot (D-108, T-090), reading the patched fswatch (D-109). (Since D-121
there is no vendored eglot: the backend would be Lisp in the config on top of the
built-in eglot, as `lisp/emacs-cpp-eglot-watch.el` is; not redesigned yet.) Findings behind
it: `RESEARCH_platform_differences.md` 3.9 - 3.13. Ruled by the owner as O-62
(a) - (e) (D-110), built after T-090 (owner, O-62 (f) open).

**Goal.** Servers that ask for `workspace/didChangeWatchedFiles` (pyright, texlab)
see changes in project trees of any size on macOS, at the cost of one fswatch
process per server and root (8 descriptors, 6 MB idle), not one kqueue descriptor
per directory; no event lost to a busy Emacs, drops said out loud.

**Switch** (O-62 (a)). `eglot-fswatch-program`: nil (default) keeps today's
`file-notify` watches; a file name runs that fswatch. Set by the user (owner
2026-10-15: "user responsibility"), e.g. to `~/opt/fswatch-no-loss/bin/fswatch`, in
`custom.el`; the config sets nothing. Meant for macOS: on Linux fswatch uses
inotify, one watch per directory as `file-notify` does, so it saves nothing on Arch.

**Stock or patched fswatch** (O-62 (b)). Before the first start eglot reads
`PROGRAM --help` once per program: `--queue-limit` there means the patched build
(0001; 0002 - 0004 come with it in `packaging/fswatch-no-loss`), and the option
is passed. Without it the backend still runs, without `--queue-limit`, and warns
once that this fswatch loses events when Emacs does not read in time and mixes the
flags of a created-then-removed file (3.13); the type is then decided by
`file-exists-p`. `--allow-overflow` exists in both.

**Which registrations.** A registration group whose base is the project (no base
URI, or one inside the root) goes to fswatch. A group based outside the root
(pyright's library roots) is handled as today: `file-notify`, or skipped when
`eglot-watch-files-outside-project-root` is nil (macOS, D-054). The glob matching,
the `kind` bits and "not for a buffer eglot manages" stay as in
`eglot--watch-globs`.

**Process.** One per server and project root, started at the first project
registration, shared by all of the server's registrations (a handler per
registration id, as the shared-watches draft does), killed when the last of them
is removed and at server shutdown. Command:
`fswatch -0 -r -x --event-flag-separator=, -l LATENCY --allow-overflow
--queue-limit=N -e REGEXP... ROOT`, with `LATENCY` from `eglot-fswatch-latency`
(0.1 s), `N` from `eglot-fswatch-queue-limit` (200000), `REGEXP`s from
`eglot-fswatch-exclude` (default `/\.git/`). `:connection-type 'pipe`,
`:noquery t`, `LC_ALL=C` in its environment.

**Records to changes** (the process filter):
- Split at NUL, keep a partial record for the next call; `PATH FLAGS`.
- Map the path: fswatch reports real paths (`/private/tmp/...`); a prefix equal to
  the root's `file-truename` is replaced by the root as eglot spells it (cf. O-50).
- `Overflow` (O-62 (c)): changes were lost. One warning per server and minute naming
  `M-x eglot-reconnect`; nothing sent (LSP has no "rescan" notification).
- Type: `Removed` -> 3 (deleted), `Created` -> 1, any other flag -> 2 (changed);
  with the patched fswatch a path's present state is decided there (0003); with a
  stock one a `file-exists-p` decides between 3 and 1 / 2.
- Pre-filter (O-62 (d)): `eglot-watch-file-patterns` (the patterns draft, base-name
  wildcards per major mode) as one regexp on the base name, first. Benchmark
  (2026-10-15, 20000 paths of the LLVM-sized tree, 193 of them `.py`, batch Emacs,
  the mirror's compiled globs): glob `**` alone 1.6 us per path, all 20000 pass;
  glob `**/*.{py,pyi}` alone 6.4 us, 193 pass; pre-filter then `**` 1.0 us, 193 pass.
  The globs are cheap; the gain is what the pre-filter drops: pyright registers
  `**`, so without it every record of a build or checkout goes on to the stat, the
  URI and the notification (the prototype filter of 3.12: about 190 us per record
  for all of that), and to pyright. The built backend repeats this benchmark on the
  whole filter, with and without the pre-filter.
- Every registration handler whose globs match gets the change; all changes of one
  filter call go out as one `workspace/didChangeWatchedFiles` per server (today
  eglot sends one notification per event).

**Failure, loudly** (D-018's spirit, no silent fallback):
- Program missing or not executable at registration: an `eglot--warn` naming the
  variable, the registration answered successfully with no watches (a failed
  registration makes pyright exit, 3.3).
- The process exits while registrations use it (O-62 (e)): a warning with its exit
  status and stderr; no restart behind the user's back. To restart by hand:
  `M-x eglot-fswatch-restart` (new) starts the current server's fswatch again for
  its registrations, without restarting the server; or `M-x eglot-reconnect`
  restarts both. Either way changes made while no fswatch ran are not reported; the
  warning says so.
- The watch count (`eglot-max-file-watches`) does not count fswatch processes, so
  the cap (500 on macOS, D-054) does not limit project registrations served by
  fswatch (owner question 2026-10-15). It still applies to what stays on
  `file-notify`: the backend switched off, groups based outside the root, Arch;
  and it keeps macOS's descriptors (about 975 per Emacs) for auto-revert and
  treemacs.

**Not covered:** remote projects (TRAMP): the backend is local only.

**Tests (when built):** ERT with a fake `fswatch` (a shell script that prints given
records, then waits), no real file events: records split across filter calls,
the real-path mapping, the three change types, `Overflow` warns and sends nothing,
handlers per registration and their removal, one notification per batch, process
start once per server and root and kill with the last registration, the warnings
for a missing program, a stock fswatch and a dying process, and
`eglot-fswatch-restart`. The pre-filter benchmark above on the whole filter. A
terminal check with pyright and the patched fswatch on an LLVM-sized tree (research
3.12's tree).

### 7.2 File watches: open questions revisited (2026-10-15, D-111)
SUPERSEDED in part (2026-10-21, T-119): the items for the `file-notify` path (0001
partial watches, O-61 (e) shared watches, the kqueue cap) no longer apply to eglot's
watches, which the fswatch backend of 7.1 carries on both machines; they stand as
history.
Owner request 2026-10-15: "revisit open questions regarding file watches". State of
each, with a recommendation; the owner agreed to all of them (D-111):
- T-090, vendor eglot (D-108): done when amended, not agreed. Agree: every eglot
  patch below waits on it.
- 0001, partial watches: drafted, checked. Keep: the `file-notify` path needs it.
- O-61 (a), tracked-only lists: undecided. Close: with the backend `project-files`
  no longer sizes the watches.
- O-61 (b), per-project exclusions: in research 3.9. A README note, no code.
- O-61 (c), watch patterns: drafted (3.10). Only as the backend's pre-filter (7.1).
- O-61 (d), open buffers first: not drafted. Drop.
- O-61 (e), shared watches: drafted, checked (3.11). Adopt for the `file-notify`
  path (Arch, groups based outside the root). Downsides, looked at on request:
  - Gain by platform: on macOS each kqueue watch is a file descriptor
    (`kqueue.c` opens the directory per watch), so (e) cuts descriptors by up to
    three for pyright. On Linux the kernel already shares one inotify watch per
    directory (`inotify.c`: "inotify returns the same descriptor WD for multiple
    calls ... with the same file"); there (e) only stops eglot's own
    `eglot-max-file-watches` from counting a directory three times.
  - One handler's error stops the rest: the first draft called the handlers of a
    shared watch in a loop, so an error in one skipped the others. Fixed in the
    revised draft (T-101): each call under `condition-case`, the error warned about.
  - A deleted directory, found on revisiting (T-101): kqueue ends a watch whose
    directory is deleted (`deleted`, then `stopped`, and `file-notify-valid-p` nil;
    terminal Emacs, macOS). The first draft kept that dead entry, so a directory
    created again under the same name got no watch, where stock eglot adds a fresh
    one. Fixed in the revised draft: `stopped` forgets the entry, and an invalid
    one is replaced when a watch is asked for.
  - Keys are spelled paths (`directory-file-name`), not true names: one directory
    reached by two spellings (a symlink) keeps two watches; no worse than today.
  - A watch lives as long as any registration uses it: removing one registration
    leaves the directory watched for the others (intended), and its count drops
    only with the last.
  - Duplicate notifications are unchanged: each registration whose globs match
    sends, as today with separate watches.
  - Divergence from upstream: 101 changed lines on the vendored eglot (revised
    draft), to carry across mirror updates; for Emacs itself, copyright paperwork.
  - Revised draft checked against `lib/eglot` with pyright (cap 500): 400 directories
    end with 401 watches, never more; 600 end with 500; through the real dispatcher,
    `stopped` removes the entry, the parent's `created` brings a valid watch back,
    and a failing handler next to the real one leaves one notification sent and one
    warning. `docs/upstream/eglot-watch-shared-directories.patch`; build: T-102.
  - Built (T-102, 0076; since D-121 the same logic as advice in
    `lisp/emacs-cpp-eglot-watch.el`, macOS only):
    `patches/eglot/0002-Share-one-file-watch-...`, 8 patches in
    force; the shipped-profile test with pyright (cap 500, 400 directories): at
    most 401 watches, 401 left (fails without 0002: 500 reached).
- O-61 (g), retry what the cap cut short: drafted, checked (3.11). Drop if (e) is
  adopted: (e) leaves no duplicate registration to retry.
- O-61 (h1), fswatch backend: designed (7.1). Rule O-62.
- T-032, eglot report: drafted, unsent. Send, with 0001 and (e) as patches.
- O-50, symlinked paths: open. The backend maps real paths itself (7.1).

## 8. Build (CMake presets)
- DECIDED D-005: `CMakePresets.json` is the toolchain / profile mechanism; Emacs never
  stores its own per-project build settings while a preset exists.
- DECIDED D-017 (owner 2026-10-07): the active preset of a project is the first
  non-hidden configure preset unless the owner picked another with `C-c l P`
  (`emacs-cpp-presets-select`), which restarts eglot. The pick is stored per project
  root in `~/.emacs.d/emacs-cpp-presets.eld` (outside project and repository). It is a
  choice among the project's presets, not a build setting, so D-005 holds. A stored
  pick that no longer exists is an error, not a silent return to the default.
- DECIDED D-013: CMake files use `cmake-mode` from the system `cmake` package
  (`/usr/share/emacs/site-lisp`), version-matched to the installed CMake; no grammar, no
  submodule. Rejected alternative: `cmake-ts-mode`, needs a self-built
  `tree-sitter-cmake` for highlighting only.
  macOS (D-050): MacPorts installs it in `/opt/local/share/emacs/site-lisp`;
  `init-cmake.el` takes the directory by platform (T-021, 0034).
- SUPERSEDED by D-035 (2026-10-08): "PROPOSED: `projectile-enable-cmake-presets` t;
  projectile configure / compile / test commands prompt for a preset; one compilation
  buffer per project." That prompt ignores the active preset (D-017).
- DECIDED D-035 (owner 2026-10-08, O-17, T-005): projectile's `cmake` project type gets
  the commands from `emacs-cpp-presets.el`: `C-c p c o` = `cmake --preset <active>`,
  `C-c p c c` = `cmake --build <binaryDir>`, `C-c p c t` = `ctest --test-dir
  <binaryDir> --output-on-failure` (directory relative to the root, where they run).
  Any buffer of the project builds the same directory, like CLion's Build; switching
  the preset (`C-c l P`) changes the next command, since projectile re-reads a
  function command on every run (an edit at the prompt is kept instead).
  `projectile-enable-cmake-presets` stays nil. Target choice: edit the prompt
  (`--target X`); a picker is deferred. Errors jump to source: Ninja passes absolute
  source paths.

## 9. Debugger (dape)
- DECIDED D-002: dape is the debugger front-end; gdb 17 via its native DAP interpreter
  is the default adapter, lldb-dap the alternate.
  macOS (D-050): no gdb for Apple silicon; `gdb-preset` (D-031) is gdb-only (D-051).
- DECIDED D-051 (owner 2026-10-09, O-22): lldb is supported in addition to gdb, on both
  platforms. Built in T-022 (0035, 2026-10-09; done-when agreed with this shape; session
  test 3 / 3 on the Mac and on Arch): an `lldb-preset` entry next to `gdb-preset` that
  picks the same preset programs (D-033), builds them the same way and starts dape's
  `lldb-dap` configuration; gdb stays the default on Arch (D-002), lldb is the only
  adapter on macOS; the gdb options (D-030 lazy symbols, D-032 gdb scripts) stay gdb-only
  until a need for an lldb counterpart shows. The program is
  `emacs-cpp-debug-lldb-dap-program`: `lldb-dap` on `exec-path` on both platforms (Arch
  lldb package; MacPorts lldb-23 after `sudo port select --set lldb mp-lldb-23`, T-028,
  0037; SUPERSEDED: "on macOS `/opt/local/libexec/llvm-23/bin/lldb-dap`", a path tied to
  one port version); missing, it refuses the session with the fix. No codesigning:
  MacPorts' lldb-dap launches and stops a program through its own ad hoc signed
  debugserver, Developer Mode off (checked 2026-10-09); the port's note to codesign
  lldb-server concerns LLDB's own debug server, which LLVM documents as unneeded with the
  system one. Cross-check: CLion on macOS defaults to its bundled LLDB and warns of issues
  with GDB there (jetbrains.com/help/clion, "Configure CLion on macOS").
- S2 PASS (2026-10-08, RMO): dape + gdb 18.1 DAP stops at a source breakpoint, shows
  stack, variables and a watch, steps and ends cleanly; lldb-dap too. Findings for
  T-006: program path = active preset's `binaryDir` + target name; breakpoints persist
  with `dape-breakpoint-save` / `-load`; the stop takes 17 s on RMO (gdb reading
  `libdeal_II.g.so`, not dape), 2.3 s with shared-library symbols on demand (deal.II
  frames then lack symbols); deal.II's printers need `contrib/utilities/dotgdbinit.py`
  sourced as a gdb script. Variant choice: O-14, ruled by D-030.
- DECIDED D-030 (owner 2026-10-08, O-14): gdb starts with full symbols (deal.II code
  steppable at once; 17 s to the first stop on RMO); loading shared-library symbols
  on demand (`set auto-solib-add off`, 2.3 s) is an option the owner can turn on.
- DECIDED D-031 (owner 2026-10-08, T-006): a `gdb-preset` entry in `dape-configs`,
  started with `C-x C-a d gdb-preset RET` (`:bind-keymap` loads dape on the first
  `C-x C-a`). It asks for a program among the ELF executables under the active
  preset's `binaryDir` (not `CMakeFiles/`, hidden directories or `.so` files; last
  pick is the default) [SUPERSEDED by D-033: targets from build.ninja], builds its
  target first (`cmake --build <binaryDir> --target <file name>` [target name per
  D-033]; a failed build starts no session), and starts gdb in the project root
  with `set debuginfod enabled off` (D-014). `emacs-cpp-debug-lazy-symbols` (default
  nil) adds `set auto-solib-add off` (D-030). Breakpoints across sessions: dape's own
  `dape-breakpoint-save` / `-load`, nothing automatic.
- DECIDED D-033 (owner 2026-10-08, T-006 RMO check): `gdb-preset` offers the preset's
  executable targets from `<binaryDir>/build.ninja` (`build <output>:
  <LANG>_EXECUTABLE_LINKER__<target>_<CONFIG>`), so a target never built can be
  picked and built; the target name comes from the rule, not the file name
  (`OUTPUT_NAME` works). Ninja generator only: no build.ninja refuses the session.
  Reason: the owner's RMO `build/debug` was configured but not built, and the ELF
  scan of D-031 offered nothing. Not taken: CMake's file API (query file in the build
  directory plus a reconfigure).
  The build type: the link block's `CONFIG` (CMake 4), else the file's
  `CONFIGURATION` (CMake 3.31, MacPorts; T-021, 0034). Reopened by O-25 (T-028);
  SUPERSEDED by D-056 (T-030, 0040): `build.ninja` is no longer read.
- DECIDED D-056 (owner 2026-10-09, O-25): the debug presets take the preset's executable
  targets from CMake's file API, not from `build.ninja`. Grounded on the owner's CLion
  build of RMO (CMake 4.3.1, 2026-10-09): the shared query
  `<binaryDir>/.cmake/api/v1/query/codemodel-v2` (an empty file) makes every configure
  write `reply/index-*.json`; its `codemodel-v2` object lists configurations and targets,
  each target file has `type` (`EXECUTABLE`), `name` and `artifacts[].path` (relative to
  the build directory). Any generator; Makefiles too. Agreed for T-030 (owner 2026-10-09;
  built 0040; make test on the Mac and Arch): the configure command (`C-c p c o`, D-035)
  and the debug presets write the query file into the preset's `binaryDir` (CMake's output
  directory, not the source tree D-016 keeps clean); the newest reply index is read; no
  reply refuses the session with the fix ("configure once with `C-c p c o`"); more than
  one configuration (multi-config generators) is refused until needed; the target name
  stays the build target (`cmake --build <dir> --target <name>`).
- DECIDED D-037 (owner 2026-10-08, O-15): built-in `repeat-mode` is on (3 ms at start),
  so after `C-x C-a n` plain `n s o c p r f u < >` keep stepping; Emacs's own repeat
  maps (`C-x o o`, `C-x u u`) come with it. dape gives every command its repeat map;
  only stepping and execution commands keep it, so after `C-x C-a b` / `w` / `i` the
  next letter is text again (checked in `emacs -nw`).
- DECIDED D-036 (owner 2026-10-08, O-18): `dape-breakpoint-mode` in C and C++ buffers
  (`c-ts-base-mode-hook`): clicking the fringe (margin in a terminal) toggles a
  breakpoint, mouse-2 / mouse-3 add a condition / log message. It loads dape (135 ms)
  with the first such buffer; not on `prog-mode`, since `*scratch*` would load it at
  every start. Breakpoints inherit the theme's `error` face (red), the stopped line its
  `hl-line` face; the modus themes style neither dape face.
- DECIDED D-044 (owner 2026-10-08, O-20): `gud-key-prefix` is `C-x M-a`. gud (`M-x
  gdb`, `pdb`, `perldb`) binds its map globally on that prefix when it loads; on the
  default `C-x C-a` it took dape's keys for the rest of the session.
- DECIDED D-032 (owner 2026-10-08, O-14): gdb scripts outside the repo, such as
  deal.II's `contrib/utilities/dotgdbinit.py`, are listed in
  `emacs-cpp-debug-gdb-scripts` (default nil, so none by default); each is sourced
  with `set script-extension off` (read as gdb commands whatever the extension); a
  listed file that is missing refuses the session.

## 10. Keys
- DECIDED D-004: Emacs-native bindings (`M-.`, `M-?`, `M-,`, `C-c p` projectile) plus one
  user prefix map `C-c l` for code actions, discoverable via which-key. Proposed letters:
  `r` rename, `a` code action, `f` format, `i` implementation, `d` declaration, `h` call
  hierarchy, `t` type hierarchy, `o` other file, `s` workspace symbol, `e` project
  diagnostics, `I` inlay hints toggle. Debugger keys stay on dape's own prefix + repeat map.
  Built in T-007 (2026-10-08): all eleven plus `P` preset; `o` is
  `projectile-find-other-file` (by name across the project; RMO splits include/ and
  src/); inlay hints are on by default (eglot 31), `I` hides them.
- DECIDED D-093 (owner 2026-10-13, O-44 (a), (b2); done when agreed): navigation
  clicks as CLion's, on the platform's modifier (`emacs-cpp-default-mouse-modifier`,
  D-055: Command (`super`) on the Mac, Super on Arch (amended 2026-10-14, owner:
  "don't give up Ctrl clicks"; was Control)): click = definition of the
  symbol clicked, or its references when the click is on its definition; with Opt /
  Alt = implementations; with Shift = type definition. The press of each is unbound
  so the click arrives; Ctrl's clicks keep Emacs's buffer menu and rectangle drag.
  Whether the Arch desktop takes Super+click is the owner's check. Right click opens a menu
  (`context-menu-mode`): Emacs's Find Definition / Find References at the click and
  editing entries, plus in eglot buffers Rename Symbol, Code Actions, Go to
  Implementation (each at the click) and Format Buffer. Shift+click extends the
  selection (Emacs's `mouse-save-then-kill`, as right click did; a quick second
  Shift+click on the same spot cuts). Built (T-066, 0062).
- DECIDED D-138 (owner 2026-10-21, O-44 (c): "mouse-back -> button-8,
  mouse-forward -> button-9"): the mouse's back button, Emacs's `<mouse-8>`, runs
  `xref-go-back`, the forward button, `<mouse-9>`, `xref-go-forward`, on both
  machines (T-067). The Mac's events are the X11 numbering as the owner gave it;
  whether the NS build reports the same numbers is UNVERIFIED (hand check, H-15).
- DECIDED D-096 (owner 2026-10-14, O-47 (c2) asked, then "leave as-is, close"): a
  plain click on a symbol gets no tooltip or child frame; as before, eglot's hover
  for the symbol at point reaches the echo area through eldoc 0.5 s after the click
  (`RESEARCH_mouse.md` 6). Options c1 - c4 closed. O-47 (a), the hover highlight,
  stays open for further research on its performance.
- DECIDED D-137 (owner 2026-10-21, O-47 (c): "O-47 (c)"): no hover highlight or
  pointer change; the clicks (D-093) and eldoc's echo-area hover (D-096) stay as
  they are.
- DECIDED D-034 (owner 2026-10-08, O-16): built-in `which-key-mode` is on: after any
  prefix (`C-c p`, `C-x C-a`, `C-c l`) its keys appear once you pause 1 s
  (`which-key-idle-delay` default; 3 s since D-071); `C-h` after a prefix still
  searches them (embark);
  projectile's own menu stays on `C-c p m`. Turning it on costs about 11 ms at start.
- DECIDED D-074 (owner 2026-10-11, O-30 (b): "(b) measure first"): one go-to-anything
  prompt, a new command built with consult's `consult--multi`, in
  `lisp/init-completion.el` (`lisp/init-go-to-anything.el` since D-099): buffers,
  project files (projectile), recent files and bookmarks from the first key; clangd
  symbols (`workspace/symbol`, through consult-eglot's functions) from the third;
  commands and project roots behind narrow keys. `C-x b` stays `consult-buffer`. Spike
  S11 measures each source on RMO and the deal.II tree first
  (`spikes/s11-go-to-anything/RUN.md`); code (T-049) after S11 and the key (O-31). No
  new package. S11 run 1 (0048, FAIL in one part): file listing RMO 51 ms (2765 files),
  deal.II 66 ms (34602), no cache needed; symbols from the index median 5.5 ms, slowest
  16.3 ms, but none until the stored index has loaded; filtering every input over RMO
  1.5 - 6.7 ms; over deal.II the first letter 31.8 ms (criterion 20 ms), then 13.1 ms
  and less. Handling: O-32 -> D-075; speed: O-33.
- DECIDED D-075 (owner 2026-10-11, O-32 (b)): the first letter's cost in a
  deal.II-sized tree is accepted; project files join from the first key. T-049's hand
  check on the deal.II tree decides whether O-32 (a) follows.
- DECIDED D-076 (owner 2026-10-11, O-31: "M-o"): the go-to-anything prompt is on
  `M-o` (unbound in Emacs 31.1 and in every mode the config uses; one chord; also in a
  terminal; Option-o on the Mac).
- DECIDED D-077 (owner 2026-10-11, O-33: "adopt all four and skip empty symbol
  request"): the prompt binds, around its `consult--multi` call,
  `gc-cons-threshold` to 64 MB, `consult--regexp-compiler` to one that highlights only
  the first 100 hits per input, and `consult-async-refresh-delay` to 0.05 s; it passes
  `:sort nil`; its symbol source throttles and debounces at 0.05 s (SUPERSEDED by
  D-087: consult's 0.5 s / 0.2 s, as `C-c l s`) and sends no
  `workspace/symbol` request for an empty input (its own request step instead of
  consult-eglot's `setup` request; `< l` asks for it since D-086). Owner asked for
  S11 run 2 first: the whole prompt
  on RMO with the patched clangd, listing project files at each opening
  (`spikes/s11-go-to-anything/RUN.md`, run 2). Run 2 PASS (0049): RMO opening
  89 - 96 ms, each key's results 6 - 24 ms, symbols on screen 122 - 150 ms after
  the key, no collection while typing; deal.II's files: opening up to 178 ms, first
  letters up to 139 ms. Interrupted static computations repeat the file listing
  (deal.II: 6 of 10 openings); T-049 lists the files before `consult--multi`.
- DECIDED D-078 (owner 2026-10-11, "hide the #"): the prompt binds
  `consult-async-split-style` to nil, so its input starts without consult's `#`;
  a second filter over symbol results (`#vec#push`) is given up.
  Built (T-049, 0050): `emacs-cpp-go-to-anything` in `lisp/init-completion.el` (moved
  by D-099), on
  `M-o`. Narrow keys: `b` buffers, `r` recent files (consult's `f` taken), `m`
  bookmarks, `f` project files, `s` symbols, `x` commands, `p` projects (the last two
  hidden until narrowed). A chosen command or project runs after the prompt's
  bindings end. S11 run 3 (0051, PASS): on RMO opening 54 - 74 ms, keys 2 - 30 ms,
  symbols 122 - 150 ms after the third key, no collection, no `#`.
  Fixed 2026-10-11 (owner report, tier 1): the files were listed before the 64 MB
  threshold was bound; on 34583 files opening took 302 - 311 ms with 6 collections,
  after the fix 112 - 122 ms with none (stand-in tree, scratch harness).
- DECIDED D-079 (owner 2026-10-11, O-34 (a) and (c)): consult patch 0001 (D-069,
  `patches/consult/0001-...`): in a `consult--multi` prompt with an async source, a
  source hidden by narrowing drops its candidates when input reaches it
  (`consult--async-predicate` sends `flush`), and computes again when widened
  (`consult--async-dynamic` forgets its last input on that `flush`). Narrowing is
  documented as `<` and the letter (no first-letter filter over the files). Upstream
  report drafted (`docs/upstream/consult-async-hidden-sources.md`), the owner sends
  it (T-053). Built (0052): stand-in tree, 100 ms per key, narrowed: 0.2 - 4.2 ms
  per update (before 15 - 35 ms; `C-c l s` 0.6 - 49.7 ms with a collection); widening
  with `< <` brings the files back for the current input in about 30 ms. Owner asked
  for a deal.II benchmark (S11 run 4, T-054): 0053, RMO and deal.II's files with
  RMO's clangd, 100 ms per key: narrowed median 1.4 ms per update in both (`C-c l s`
  3.0 - 3.3 ms), final list 107 - 186 ms after the last key (`C-c l s` 406 - 461 ms),
  twice the clangd requests. deal.II with its own clangd not measured.
- DECIDED D-082 (owner 2026-10-13, O-37: "no limit + root filter", "M-o key + C-c l s
  all"): `M-o`'s symbol source (`s`) lists the project's symbols only: each
  `workspace/symbol` request asks for every match (clangd's `limit` 0, an LSP extension;
  stock clangd, no patch; capped since D-083) and keeps symbols whose file URI starts
  with the project root's, as projectile gives it or its true name. A hidden source on
  `l` ("All Symbols") asks as `s` did before: clangd's best 100 of the whole index,
  deal.II's and the standard library's too (CLion's "Include non-project items").
  `C-c l s` stays as it is, all symbols. S11 run 5 (T-059): filtering clangd's usual
  100 lost project symbols in 14 of 40 queries, no limit in none, slowest reply
  15.9 ms. Built (T-060, 0056).
- DECIDED D-083 (owner 2026-10-13: "a configurable cap as fallback"; done when agreed;
  "keep fmt as project"): `M-o`'s project symbols ask clangd for at most
  `emacs-cpp-go-symbol-limit` matches (defcustom, default 10000, 0 = none); a reply
  that reaches it shows a message (project symbols may be missing, type more). The
  root also matches in clangd's URI encoding (it escapes `+ ( ) @ , ; = ! $ & ' *`,
  eglot does not, and eglot escapes `:`) and, on macOS, ignoring case. Measured on
  step-1 (deal.II, Mac, 47 three-letter inputs, no limit): largest reply `typ` 6673
  symbols, 48.9 ms round trip (about 7 us per symbol, most of it clangd's while
  Emacs takes keys); project symbols kept for `typ` / `ope` at 1000: 0 / 21, 2000:
  33 / 24, 5000: 87 / 106, 10000: 111 / 111 (all). Toy checks with clangd: a root
  opened as `TOY/` and a root `c++ (x)@y` listed 0 project symbols before, 2 after.
  Vendored code under the root counts as the project's (owner): step-1's `fmt/`
  submodule gives 144 of `for`'s 146. Generated files under `build/`: none seen.
  Built (T-061, 0057). The spellings below are SUPERSEDED by D-085 (2026-10-13): one
  matcher for every server. Amended 2026-10-13 (owner, tier 1): pyright, the config's
  other server, escapes `:` like eglot and `+ ( ) @` like clangd, so a root holding
  both kinds matched neither (`py a:b c++`: no project symbols); pyright's rule is
  a third spelling of the root. Checked with both servers under `c++ (x)@y`,
  `a:b` plus U+00E4, `py a:b c++`, other case: all list the project's symbols.
  Adding a language server to the config (its own D-nnn) includes checking its URI
  encoding the same way and, if it is a fourth, adding it to
  `emacs-cpp-go--server-uri-chars`; not a user option (owner question 2026-10-13).
  Correction 2026-10-13: the shipped filter costs 16.7 ms per 6673 symbols (up to six
  prefixes, interpreted), not about 1 ms as measured with one inline prefix. A
  mechanism without per-server spellings, 4x faster, is researched as O-40
  (`RESEARCH_go_to_anything.md` 11). Warm (a first call pays `seq-filter`'s setup):
  13.6 - 14.2 ms.
- DECIDED D-088 (owner 2026-10-13, O-41 (b); done when agreed): `M-o` previews the
  selected candidate 0.3 s after the last typed key (`consult-preview-key` bound to
  `(:debounce 0.3 any :debounce 0 <up> <down> C-n C-p <next> <prior> C-v M-v)` while
  the prompt is open); moving through the list previews at once. Other prompts keep
  consult's immediate preview. Terminal check on the toy, `answer` at 50 ms per key,
  a session's first `M-o`: every key handled on time (before: none for about 0.5 s
  after the third), the first file preview after the pause (812 - 821 ms), `<down>`
  previewed within 1 ms. Built (T-064, 0060).
- DECIDED D-087 (owner 2026-10-13, tier 1: "use C-c l s request timing for M-o as
  well"): `M-o`'s symbol sources (`s`, `l`) throttle and debounce with consult's
  defaults, as consult-eglot's `C-c l s`: a request at most every 0.5 s
  (`consult-async-input-throttle`), once typing has paused for 0.2 s
  (`consult-async-input-debounce`); D-077 had 0.05 s / 0.05 s. The screen refresh
  delay (0.05 s, D-077) stays. Terminal check on the toy, `answer` typed at 50 ms per
  key: `C-c l s` one request at 455 ms; `M-o` `< l` one at 456 ms; `M-o` (`s`), second
  use in the session, one at 460 ms. The first `M-o` of a session froze for about
  0.5 s at the third key, with either timing: consult's preview opening the first
  file candidate (`consult--find-file-temporarily`: `c++-ts-mode` setup, and the
  native trampoline for its advice on `run-hooks`, cached but loaded again each
  session, 60 - 104 ms); not changed here, researched as O-41.
- DECIDED D-106 (owner 2026-10-15, O-58: "(d) One source per server, (h) Keep grouping
  for C-c l s"; tier 2, done when to agree): in `M-o` each language server of the
  project gets its own symbol sources, so clangd's, pyright's and texlab's symbols
  each sit under their own heading, in a fixed order, instead of one list in
  arrival order (RESEARCH_go_to_anything 17). `C-c l s` keeps consult-eglot's
  groups by symbol kind; T-084's `C-c l s` `count` check is waived by this.
  Build: T-087. Built (T-087, 0073): per server an `s` and a hidden `l` source,
  headed `Symbol (clangd)` (`Project Symbol (clangd)` since D-118),
  `All Symbols (pyright-langserver)` ...; the calling
  buffer's server first, then eglot's order; narrow keys `s` / `l` shared, one entry
  each. Terminal check (toy, clangd and pyright): `M-o` `vector` from the `.cc`
  buffer shows clangd's heading first, from the `.py` buffer pyright's; `< s` shows
  both.
- DECIDED D-114 (owner 2026-10-15, O-50 (c): "Yes, with T-104"; S13's criteria confirmed):
  clangd patch 0010 names the background index's translation units by their real
  directory (S13, PASS on Arch and the Mac), written fresh with a unit test in
  `BackgroundIndexTests.cpp`, built together with T-104's 0011 / 0012: one pkgrel
  (8), one Mac rebuild, one Arch package. Projects reached through a symlink, and
  every project under `/tmp` on the Mac, keep their references. Built (T-104, 0077):
  `packaging/clangd-index-nav/0010-...`, its test on a real symlink fails without it.
- DECIDED D-113 (owner 2026-10-15, O-63 (b)): CLion-style symbol matches (patches 0011
  / 0012, if S14 passes) are switched per request: fields in `workspace/symbol`'s
  parameters next to clangd's `limit` (e.g. `middleMatch` with its minimum length,
  `looseScope`), off unless sent; Emacs options decide for `M-o` and `C-c l s`
  separately (the latter through our consult-eglot patch). Our first own protocol
  extension: patches 0001 - 0009 touch no `Protocol.h` / `.cpp` and switch by hidden
  flags (`--navigation-from-index`, `--header-flags-from-index`; 0009 always on);
  the config uses only clangd's own `limit` (D-083). A stock clangd ignores unknown
  fields, so the patch also announces support in its `initialize` reply's
  capabilities (as clangd's own extensions such as `memoryUsageProvider` do), and
  Emacs warns when an option is on but the server lacks it (fail loudly, no silent
  no-op). Built (T-104, 0077): patches 0011 / 0012, pkgrel 8, options
  `emacs-cpp-symbol-loose-scope` (t) and `emacs-cpp-symbol-middle-match` (3).
- DECIDED D-112 (owner 2026-10-15, O-57: "Spike for O-57 (b) + (c), drop (d)"): CLion's
  loose qualifiers (`geom::vert`) and mid-word matches (`ector`) in clangd go to
  spike S14 (`spikes/s14-symbol-matches`, T-103) before any patch; tier 3. Gaps
  inside a word (`cml`) are dropped: clangd's trigrams refuse them before its
  matcher, so they need a full scan or a far larger index. A PASS leads to clangd
  patches 0011 / 0012 (0010 is O-50's), built with O-50's rebuild. Dry run 5
  (2026-10-15, step-1's index cloned): all five criteria pass, mid-word matches
  ranked last by a negative score, identifiers only; criteria refined during the dry
  runs (`spikes/s14-symbol-matches/DRY-RUN.md`). S14 PASS (owner's run 2026-10-15,
  `RESULTS.md`): all five criteria; next T-104, patches 0011 / 0012 per D-113.
- DECIDED D-105 (owner 2026-10-15, O-55: "(a) + (b)"; tier 2, done when to agree):
  symbols in clangd's order and `M-o` ignoring case, as CLion (RESEARCH_go_to_anything
  14, 15). (a) `M-o` and `C-c l s` list each server's `workspace/symbol` reply in the
  order the server sent it, best match first; no re-sort by the reply's `score`,
  which leaves the name match out (toy: `count` then below `count_vertices_globally`;
  CLion and clangd put `count` first). (b) `M-o`'s buffers, recent files, bookmarks,
  project files, commands and projects match ignoring case (`readme` finds
  `README.md`). Build: T-084. Built (T-084, 0072): `M-o` drops the sort; consult-eglot
  patch 0001 (D-069) drops consult-eglot's; `completion-ignore-case` t in `M-o`.
  Terminal check (toy, clangd 21.1.8): `M-o` `< s` lists `count` before
  `count_vertices_globally` and `Vector` first for `vector`; `readme` finds
  `README.md`; `C-c l s` `vector` lists `Vector` first, but `count` shows
  `count_vertices_globally` first: consult-eglot groups by symbol kind, and the
  Function group appears before the Variable one in clangd's reply (O-58).
- DECIDED D-086 (owner 2026-10-13: "the behavior of M-o <l should match C-c l s";
  done when agreed): `M-o` `< l` with no input asks clangd for "" and lists its
  first 100 symbols, as `C-c l s` does when it opens; one or two characters keep
  that list; from three, clangd's matches. Hidden, `l` gets no input, so opening
  `M-o` sends nothing more (0 requests, terminal check). `s` still asks nothing for
  an empty input (D-077): with D-082's filter and D-083's limit it would fetch up to
  10000. Terminal check on the toy, candidates after empty / `a` / `an` / `ans`: `C-c
  l s` 100 / 100 / 100 / 15, `M-o` `< l` the same (before: 0 / 0 / 0 / 15). D-077's
  0.05 s throttle stays for `l`. Built (T-063, 0059).
- DECIDED D-085 (owner 2026-10-13, O-40: "replace"; done when agreed): `M-o`'s
  project symbols match a URI against the project root without knowing how its
  server escapes: the root URI up to its first character other than a letter, digit
  or `- _ . /` is a prefix every spelling shares (cheap `string-prefix-p`; library
  URIs fail here); a URI that passes is percent-decoded (UTF-8) when it holds `%` and
  compared with the root path, as given or true name, ignoring case on macOS
  (D-083). Replaces D-083's spellings (`emacs-cpp-go--server-uri-chars`, eglot's,
  clangd's, pyright's); R's languageserver, a fourth spelling, needs nothing. Checked
  with clangd and pyright under `toy`, `TOY`, `c++ (x)@y`, `a:b` + U+00E4,
  `py a:b c++`: the project's symbols in each. Filter per 6673-symbol reply, as
  shipped (interpreted, warm, 64 MB GC threshold): 3.7 - 4.2 ms, D-083's 13.6 -
  14.2 ms. Not handled: Unicode normalization (NFD from a server; none seen),
  `file://localhost/` URIs (none seen). Built (T-062, 0058).
- DECIDED D-084 (owner 2026-10-13, tier 1): in every vertico prompt (`M-o`, `C-x b`,
  `M-x`, `C-x C-f` ...) PgDn / PgUp (`<next>` / `<prior>`) page through the
  candidates (`vertico-scroll-up` / `-down`, as `C-v` / `M-v`); the minibuffer bound
  them to the next / previous history element ("End of history; no default
  available" in `M-o`, owner report). History stays on `M-n` / `M-p`, `M-r`. Checked
  in a terminal Emacs: `M-x`, PgDn twice, PgUp once: candidate 0 -> 10 -> 20 -> 10.
- DECIDED D-071 (owner 2026-10-10): `which-key-idle-delay` 3 s instead of 1 s. ESC is
  the Meta prefix, so pressing it (e.g. to cancel) brought up the list of every `M-`
  command after 1 s. Chosen over hiding the list after ESC only, making ESC cancel in
  graphical frames, or a list only on `C-h`. Applies to every prefix (but see D-080).
- DECIDED D-080 (owner 2026-10-12, O-35: "every prompt with narrow keys; delay about
  0.2s"): in any prompt with consult's narrow keys (`M-o`, `C-x b`, `C-x p b`,
  `M-g i`, `M-g f`, `M-g e` ...), which-key lists them 0.2 s after `<`; ESC, `C-x` and
  every other prefix still wait 3 s, in prompts too (D-071). which-key has one idle
  timer for every prefix and `which-key-delay-functions` can only add delay, so
  `lisp/init-ui.el` restarts the timer at 0.2 s when a prompt opens (which-key's
  internal `which-key--start-timer`), adds 2.8 s for any prefix but the narrow key
  while one is open, and restores 3 s when the last prompt closes. Not every pop-up
  shortcut: ESC is a prefix in the minibuffer too, the reason for D-071. Built
  (0054): terminal Emacs, `C-x b`: popup 0.15 - 0.4 s after `<`, 2.5 - 3.5 s after ESC.
- DECIDED D-029 (owner 2026-10-08): `C-c t` toggles the project tree; treemacs runs
  `treemacs-project-follow-mode`, so the tree shows only the project of the selected
  buffer (projectile's, via treemacs-projectile) and follows it. Not opened at startup
  (in force again with D-049). `C-c t` opens with the current project directly
  (`treemacs` alone asks for a root while the workspace is empty). `C-x t t` stays
  Emacs's tab-bar key.
- DECIDED D-067 (owner 2026-10-10: "option to disable auto-follow in treemacs"; two
  options; then "turn off file follow, keep project follow"):
  `emacs-cpp-tree-follow-project` (default t) nil keeps the tree on the project `C-c t`
  opened it with (D-029's follow off); `emacs-cpp-tree-follow-file` (default nil) t lets
  treemacs's own `treemacs-follow-mode` (on by default in treemacs) expand to and mark
  the selected buffer's file. Set with `customize-variable`, they apply at once, also
  with the tree loaded. treemacs (2ab5a3c, also master) signals an error when the
  project follow mode turns off with no follow pending; the config gave it an unstarted
  timer to cancel (superseded the same day by D-069: patches/treemacs/0001 fixes it;
  T-041 reports it upstream).
- DECIDED D-070 (owner 2026-10-10: "treemacs changes to the deal.II tree after `M-.`";
  "C-c p should remain functional without .git or .projectile"): the tree follows only
  to a project under version control or with a `.projectile` file. A library header
  reached with `M-.` leaves it where it is: projectile also takes a directory with a
  marker file (`Makefile`, `meson.build`, `TAGS`, ...) for a project, and deal.II's
  macOS install (`/Applications/deal.II.app/Contents/Resources/`) has a `Makefile`;
  without any project treemacs would show the file's directory. `C-c p` and `C-c t`
  keep projectile's full rules, so `C-c t` still opens a Makefile-only project; the
  tree just does not follow into one from another project. Built as an advice on
  treemacs's `treemacs--do-follow-project` (internal, D-069's one-line allowance).
  Corrected 2026-11-04 (T-128): the predicate asked `projectile-root-local` and
  `projectile-root-bottom-up` only, whose markers are version control alone in this
  projectile (`projectile-project-root-files-bottom-up`), so it never followed into a
  `.projectile`-only project; it now asks `emacs-cpp-reverter-root`, which adds
  `projectile-root-marked`, the reverter's rule too (D-163 (a)).
- DECIDED D-049 (owner 2026-10-08): the tree opens only on `C-c t`, as before D-048;
  the automatic opening and its option `emacs-cpp-tree-open-automatically` are removed.
- SUPERSEDED by D-049 (2026-10-08): D-048 (owner 2026-10-08): the tree opens by itself,
  once per session, when the first file of a project is shown in a window (also a file
  given on the command line); the cursor stays in the file. Once `C-c t` has closed it,
  it stays closed. git's own files (`.git/COMMIT_EDITMSG`) do not count; a failed attempt
  leaves the next file to try (code review 0031). Option
  `emacs-cpp-tree-open-automatically` (default t). Not at startup itself: `*scratch*` has
  no project, and treemacs (70 ms) loads only with the tree.

## 11. Performance (Q-2, D-010)
Budgets, measured on the owner machine (T-008 measures, numbers land here):
- Startup: time from `before-init-time` to the end of `after-init-hook` <= 0.5 s with
  all packages built. (Supersedes "`(emacs-init-time)` <= 0.5 s", 2026-10-07:
  `emacs-init-time` stops before `after-init-hook`, where projectile, vertico and corfu
  turn on, so it understated startup; the 0.21 - 0.30 s reported for T-002 was that
  understated figure.) Measured at an `--eval` in a terminal frame with a throwaway
  HOME holding only the two symlinks, 2026-10-07, while an owner simulation ran at
  about 390 % CPU (load average 8 - 10): T-002 config 0.60 - 0.95 s, T-003 config
  0.77 - 1.21 s. Not a valid verdict on the budget; T-008 measures on an idle machine.
  T-008 (2026-10-08, idle: load 0.1 - 0.6 of 16 cores, v0.2.0 config,
  `scripts/measure-startup.sh`, 10 runs each, `emacs -nw`, native code cached):
  0.355 s median (0.350 - 0.366), of which 22 garbage collections 0.22 s; with
  `gc-cons-threshold` 64 MB during startup 0.151 s (0.147 - 0.156), 1 collection.
  Within budget either way; the threshold is adopted (D-038).
- Typing: no perceptible lag in a reference-project `.cc` buffer while clangd builds
  its preamble or background index.
- clangd: a deal.II translation unit's first parse and RSS are recorded by S1: RMO's
  `main.cc` 13.3 - 13.4 s and 776 - 779 MB with C++20 (S1 run 2); a header 6.6 - 8.0 s,
  380 MB. With the patched clangd the first `M-.` answers from the index in 1.4 s
  (S8), below jsonrpc's 10 s request timeout. The background index of a deal.II-sized
  tree must not starve the build (low priority). Typing lag: not measured, owner's
  observation (none reported up to v0.2.0).
- macOS (D-050; T-027, 0038, 2026-10-09). The owner's Mac: Apple silicon, 11 cores,
  18 GB; MacPorts Emacs 31.1; G DATA antivirus scanning in real time (80 - 150 % CPU
  during the runs); load average 5 - 9 throughout, so no run was idle.
  Startup (`scripts/measure-startup.sh 10`): median 0.852 s, min 0.496, max 1.424, in
  two groups (about 0.5 - 0.6 s and 1.1 - 1.4 s, alternating); 1 garbage collection
  each. Above the 0.5 s budget; whether the budget binds on the Mac is O-24 (b).
  First `M-.` on `std::visit` in RMO's `main.cc` (copy of the owner's `step-1`, deal.II
  9.7.1 from `deal.II.app`, preset `debug`, S8's protocol: session 1 builds the index,
  session 2 starts a fresh clangd with the index on disk):

  | clangd | session 1 (empty index) | session 2 (index on disk) | RSS after M-. |
  |---|---|---|---|
  | MacPorts 23.1.3 | 13.1 s | 8.2 s | 920 MB |
  | patched 23.1.1 (both flags) | 10.4 s | 2.6 s | 241 MB |

  The index: 4539 shards, complete about 30 - 40 s after opening (no new shard for 20 s);
  clangd peaks at 2.6 - 3.4 GB while indexing. Arch, S8: 1.4 s from the index. The patched
  clangd answers from the index only when the compile database and Emacs name the file the
  same way: under `/tmp` CMake writes `/tmp/...` and Emacs visits `/private/tmp/...` (a
  symbolic link), the shard is not found ("needs the AST: no stored index shard") and the
  first `M-.` waits 8.5 - 9.4 s as with the stock clangd. Projects under the home
  directory are not affected. `M-?` reference counts differed between runs (14, 15, 24 for
  the same name); not compared.
- Arch (T-027, 0091, 2026-10-21; the owner's workstation, 16 cores; load 0.96 - 1.23).
  Startup (`scripts/measure-startup.sh 10`, portable-bench, commit a35b8cd): median
  0.182 s, min 0.180, max 0.198, 1 garbage collection each. First `M-.` on `std::visit`
  in RMO's `main.cc` (S8's protocol, `results-run3-arch-2026-10-21.log`):

  | clangd | session 1 (empty index) | session 2 (index on disk) |
  |---|---|---|
  | system 23.1.3 | 8.4 s | 6.9 s |
  | patched 23.1.3 (pkgrel 9, both flags) | 8.8 s | 0.96 s |

  RSS on RMO (S10 run 2, a probe source, 2026-10-21): patched 990 MB, with the deal.II
  index 1208 MB; the system clangd 6994 MB (8053 MB in S10 run 1), not explained
  (UNVERIFIED cause).
- DECIDED D-057 (owner 2026-10-09, O-24 b): the budgets of this section and the
  reference project (D-009) are measured on Arch only. Mac numbers are recorded (above)
  but not judged against the budgets.
Mechanisms, each PROPOSED until measured:
- Packages byte-compiled by `make packages`; one combined autoloads file; no
  `package.el` activation at startup. Native compilation is left to Emacs's default
  just-in-time compiler (first load, in the background, cached in
  `~/.emacs.d/eln-cache`); ahead-of-time native compilation is not adopted while
  startup is within budget. (Supersedes "ahead-of-time byte- and native-compiled",
  2026-10-07.)
- Everything deferred (`use-package-always-defer` t) except the completion UI and theme.
- DECIDED D-038 (T-008, 2026-10-08): `gc-cons-threshold` 64 MB from `early-init.el`
  until `emacs-startup-hook`, then Emacs's default (800 KB) again: startup 0.355 ->
  0.151 s (above). After startup a higher value gains nothing measurable: eglot
  `documentSymbol` of a 5000-function file (5001 symbols, about 190 ms per reply), 10
  replies: median 188 ms at 800 KB, 16 MB and 64 MB; collections 2 / 1 / 1, 0.077 /
  0.035 / 0.039 s in all. (Supersedes "restored to a moderate value after startup".)
- REJECTED (T-008): `read-process-output-max` 4 MB. Same workload, 64 KB (Emacs 31
  default) / 1 MB / 4 MB: median 188 / 187 / 190 ms. Default kept.
- clangd options vs latency (2026-10-08, synthetic two-file deal.II + Boost project,
  batch, load average 14 - 16 from an owner simulation; cold / warm index). First
  `M-.`: defaults 7.2 / 8.2 s, `--pch-storage=memory` 13.3 / 10.0 s, `-j=4` with
  idle-priority index 7.1 / 6.9 s. Later `M-.` 1 - 3 ms, after an edit 150 - 330 ms,
  rename 2 - 69 ms, first `M-.` in a second file 7.0 - 12.3 s, clangd RSS 1.8 - 2.7 GB,
  in every variant. No option shortens the per-file preamble wait, so none is adopted
  (principle 7). `/tmp` is tmpfs, so `--pch-storage=disk` already keeps preambles in
  RAM; `--async-preamble` is obsolete in clangd 23. The background index already covers
  library headers and persists (RMO: 3947 shards in `build/debug/.cache/clangd/index`,
  deal.II and 2938 Boost headers among them). What remains is the per-file parse;
  spike S5 measures opening project sources ahead of time (CLion's approach), gating
  T-012. Synthetic dry run of S5: first `M-.` 7596 ms without, 1 ms after a 7.3 s
  warm-up of both files; clangd 1.2 GB vs 1.7 GB. S5 run 1 on RMO (2026-10-08, empty
  index, load 10 - 24): first `M-.` 10885 ms without, 1109 ms after a 39.7 s warm-up of
  all 10 sources; clangd 4.8 GB vs 9.6 GB (about 0.5 GB per extra source). FAIL against
  the 0.5 s criterion; run 2 measures with a persisted index and a 3-source variant.
- Memory levers (owner question 2026-10-08): clangd's `-j` sets how many files are
  parsed at once, by the background indexer as well, so it bounds indexing memory
  ("batches"); default is the machine's core count (exact default to be read from the
  clangd 23 source, not shown by `--help`). A parsed file's preamble is freed when the
  file is closed in clangd (buffer killed), so batching a warm-up frees its own
  benefit. After indexing, clangd keeps only the compact in-memory index and returns
  freed memory to the system (`--malloc-trim`, on by default on Linux); S5 run 2
  round 2 shows the size with a persisted index.
- Not a lever (owner question 2026-10-08): the background index (clangd design
  "indexing") is already on and persisted; it answers where a symbol is defined or
  used, but which symbol is under point needs the file's own parse. Static or remote
  indexes (`--index-file`, remote) serve the same cross-file queries. Source files are
  already in `compile_commands.json`; adding headers (S4 option a) addresses O-5, not
  this latency.
- LLVM PR 175209 (owner question 2026-10-08, checked via the GitHub API): open, not
  merged, last updated 2026-09-23; adds `--index-type=sharded` and `--project-root` to
  `clangd-indexer` to write background-index shards offline. Not in clangd 23.1.1;
  Arch's clang does not ship `clangd-indexer`. It addresses index build time (first
  start, and every preset switch, since each build directory has its own index), not
  the per-file parse. The patch applies cleanly to 23.1.1; spike S7 builds it.
  Owner input (Reddit, 2026-10-08): clangd's GitHub releases ship `clangd-indexer`
  prebuilt (`clangd_indexing_tools-linux-23.1.0.zip`, 2026-09-02); it writes a single
  static `.dex` for `--index-file` with the background index off, which removed
  editor stalls on a 745 MB Unreal database by moving indexing out of the session.
  Same limit: no effect on the per-file parse. Relevant at deal.II scale (D-010), not
  for RMO (12 sources, index built once and persisted). S7 variant A tests it first.
  The config never used `clangd-indexer`; clangd's background index runs inside clangd.
- S6 dry run (synthetic deal.II project, 2026-10-08): ccls first `M-.` 15.9 - 17.0 s
  with an empty cache (refused "not indexed" until the file is indexed), indexing done
  22 s, cache 293 MB; with the cache on disk, a fresh ccls answers empty for the first
  ~1 s, then correctly 1.1 s after start, RSS 0.6 - 0.9 GB; a header opened first had
  0 errors. Each ccls session logs one jsonrpc timer error
  (`wrong-number-of-arguments` in jsonrpc's receive closure): a message is dropped.
- `M-.` latency (2026-10-08, synthetic deal.II + Boost file, batch, idle clangd): the
  first request after opening the file waits for clangd's preamble, 6978 ms; later
  requests 1 - 2 ms; opening the target header in Emacs 150 - 190 ms (5000 lines).
  Risk for T-008: jsonrpc's request timeout is 10 s, and RMO's main.cc preamble took
  13.4 s in S1, so a first `M-.` right after opening may time out.
- eglot: `eglot-events-buffer-config` size 0 (no JSON logging; the eglot manual's
  first performance advice) and `eglot-autoshutdown` t, adopted in T-004.
  `eglot-sync-connect` stays at its default (not measured); `read-process-output-max`
  measured, default kept (T-008).
- clangd flags in section 7.
- Not adopted unless a measurement asks for it: `emacs-lsp-booster` (an external binary,
  would need its own D-nnn), gcmh.

### 11.1 Compiling `lisp/` (D-125, 2026-10-20; SUPERSEDED by D-134, 2026-10-21)
- DECIDED D-134 (owner 2026-10-21, O-74: "O-74 keep current interp"): `lisp/` keeps
  loading as source, interpreted; D-125 (this section's shape), D-124 (the match
  function, slower than today's regexps when interpreted, S16) and D-128 (recompiling
  stale modules) are not built. Reason: S17 run 4 (`spikes/s17-compiled-lisp/RESULTS.md`):
  compiling today's code saves 10 % of the tier sort, 7 ms per `M-o` reply and 5 ms of
  startup; only D-124 with it would roughly halve a keystroke in a deal.II-sized file
  prompt (240 -> 132 ms). Revisit when a prompt's keystroke is felt slow, with S16's
  and S17's spike code as the starting point (never promoted).

The text below is the superseded design, kept for that revisit.
Owner 2026-10-20 (review 0084, C-7, C-10, M-6: "Design for compile-lisp.patch and
spike"). Today `make packages` byte-compiles `lib/` only; `lisp/` (19 files) loads
as source, interpreted for the session (Emacs's JIT compiles `.elc`, not `.el`), so
per-candidate loops cost interpreted time (D-120's 0.5 ms per candidate; D-124's
function is slower than the regexps until compiled).

**Shape** (the review's `review/compile-lisp.patch`, to be written fresh after S17):
- `scripts/build-packages.el` compiles `lisp/*.el` after `lib/`, with init.el's
  prelude in force (generated load path and autoloads, use-package's settings, the
  platform defaults file named by init.el's `emacs-cpp-defaults-feature`, D-055):
  four modules expand `use-package` forms that read them. A warning is an error.
  Old `.elc` deleted first; `lisp/*.elc` git-ignored.
- The warnings settled in the modules, no behaviour change: `declare-function` /
  `defvar` for packages loaded on demand, docstrings rewrapped, `eval-and-compile`
  around init-cmake.el's `defconst` read by `:load-path` (review C-10: 44 lines).
- `make packages` runs in a temporary HOME like `make test` (D-104): compiling a
  module runs its `require`s, and recentf / savehist wrote into the real
  `~/.emacs.d` during the review's first build.
- `init-packages-are-built-and-fresh` covers `lisp/*.elc`.
- Open (O-71): a `.el` edited after `make packages` leaves an older `.elc` that
  `require` loads without a word (`load-prefer-newer` is nil, set nowhere here):
  wrong code silently, against principle 1. (a) startup refuses with "run make
  packages" when any `lisp/*.elc` is older than its `.el`; (b) `load-prefer-newer`
  t plus a warning naming the stale modules (the source runs, interpreted); (c)
  compile on load (a new mechanism). Recommended (a): the owner edits modules
  daily, but a refusal names its fix and costs one command.

- SUPERSEDED by D-134 (2026-10-21; no compiled `lisp/`, so no stale `.elc`): DECIDED D-128
  (owner 2026-10-20, O-71 (c): "O-71 (c) agree"): with D-125, at startup and before the
  `require`s, init.el byte-compiles each `lisp/` module whose `.elc` is older than its
  `.el` (warnings as errors, as the build) and then loads it; a module that does not
  compile stops startup with the compiler's message. Checked in S17 run 2 (a stale module
  recompiled at startup: its time, the features it loads) before code; ships with D-125 or
  not at all.

**Spike S17** (`spikes/s17-compiled-lisp`, T-113) before any code: startup by
`scripts/measure-startup.sh` (the budget's own method) in two trees, `lisp/`
interpreted and byte-compiled, each with the JIT native compiler on and off (the
review's open question: its harness saw compiled 108 ms slower, then withdrew the
harness for this configuration), and a probe of the form the modules' functions
have after startup. Pass (owner confirmed 2026-10-21, 0091): on Arch, idle, 10 runs x 2
rounds, compiled with JIT on starts within 10 ms of interpreted (median) and its
functions run native; the compile has 0 failures. A PASS adopts D-125's shape and
D-124's function; a FAIL keeps `lisp/` interpreted and the regexps.
Mac dry run (2026-10-20, `spikes/s17-compiled-lisp/DRY-RUN.md`): compile 0 failures;
startup interpreted 0.40 s, byte-compiled with the JIT off 0.36 - 0.37 s (no cost),
with the JIT on 0.91 s: native modules load magit at startup (304 features against
211) and re-queue 45 files for compilation at every start. Criterion 2 fails until
the form that loads magit is found (S17 run 2, T-113).

## 12. Packages (D-006, D-007)
- DECIDED D-006: every non-built-in package is a git submodule under `lib/<repo>/`,
  pinned to an exact commit; upgrading is a commit in this repo, rollback is
  `git revert`. Initial pin: the exact commit of the package.el version installed on
  2026-10-07 (each `*-pkg.el` records it), so behaviour is unchanged by the move.
  (Supersedes "newest release tag", 2026-10-07; for packages new in later tasks:
  newest release tag, else newest commit.) T-003 pins: vertico 2.15, orderless 1.8,
  marginalia 2.13, consult 3.10, embark 1.2, corfu 2.16, cape 2.10; all need
  `compat` 30 / 31, satisfied by the stub Emacs 31 ships.
- Per-package build data lives in `.gitmodules` as extra keys read with `git config -f
  .gitmodules`: `load-path` (repeatable, default `.`; e.g. `lisp` for magit,
  `src/elisp` + `src/extra` for treemacs) and `build-exclude` (repeatable; a file that
  needs a package not vendored, e.g. treemacs-evil; projectile-consult was excluded
  until T-003 vendored consult).
  Unknown keys, missing directories and excludes naming absent files are build errors.
  Every submodule has `ignore = untracked`, so the built `.elc` files do not show as
  changes.
- `scripts/build-packages.el` (run by `make packages`) byte-compiles every built file
  (old `.elc` deleted first; a compile error fails the build) and writes two generated,
  git-ignored files: `lib/load-path.el` (paths relative to itself) and `lib/autoloads.el`
  (generated per package directory so files are named by bare library name, as
  package.el does). `init.el` loads both and stops with "run make packages" if absent;
  `make test` fails if any `.elc` is missing or older than its `.el`.
- DECIDED D-072 (owner 2026-10-10, O-29 (a), (b); SUPERSEDED in part 2026-10-25 by
  D-145: R and ESS left, Python's cells stay): `# %%` cells in Python and R
  scripts with code-cells (GNU ELPA, pinned b99013b = 0.5, no tags), and ESS as R's
  mode and process (pinned v25.01.0, its newest release tag per D-006; manual
  `doc/ess.texi`). Two submodules, network fetch at clone (D-014). Owner choices:
  `C-c C-c` runs the cell at point, `M-n` / `M-p` move between cells (code-cells'
  suggestion; Python's send-buffer moves), R starts in the project root without a
  question. No eglot for R (no R language server packaged). R from pacman `r` on
  Arch, MacPorts `R` on the Mac (D-053). Code: T-046 (0047). Built: R's start in the
  project root is ESS's own default (`project-current`), the config only stops the
  question; ESS's lintr flymake is off (lintr is CRAN-only, as the language server);
  ESS reads its directory from where its autoloads are loaded, so `lisp/init-r.el`
  names it (our autoloads are one file in `lib/`); `make packages` runs makeinfo from
  a manual's directory, for ESS's `@include ../VERSION`.
- DECIDED D-090 (SUPERSEDED 2026-10-25 by D-145; owner 2026-10-13, O-42 (b): "texlab
  with build key, texlab + AUCTeX,
  use auctex from gnu if possible"; done when agreed): LaTeX with AUCTeX 14.2.0 from
  GNU ELPA's git repository (`elpa.git`, branch `externals/auctex`, pinned to the
  release commit cc5a477, no tags there; submodule `lib/auctex`, `shallow = true`:
  the repository holds every ELPA package, 629 MB in full, 17 MB for this branch
  alone with `git submodule update --init --single-branch`, 217 MB shallow) and
  texlab through eglot (D-091) for `LaTeX-mode` / `bibtex-mode` files of a project, as
  pyright. The ELPA branch carries AUCTeX's generated Lisp (`tex-site.el`,
  `preview.el`); its two generated Texinfo files are patch 0001 (D-069) so its
  manuals build (`auctex.info`, `preview-latex.info`); `lpath.el` (only for
  AUCTeX's own installation, `no-byte-compile`) is excluded; `style/` stays off
  `load-path` (six of its files share names with Emacs libraries: url, color, array,
  ...). `.tex` opens in AUCTeX's `LaTeX-mode` (its tex-site.el remaps `latex-mode`).
  `C-c l b` sends texlab's build request (latexmk, asynchronous, result in the echo
  area, modified LaTeX buffers saved first); texlab then shows the line in the
  viewer (`texlab.build.forwardSearchAfter`): Skim's `displayline -r -g` on macOS,
  zathura `--synctex-forward` on Arch (`emacs-cpp-default-pdf-viewer`, D-055).
  AUCTeX's own keys unchanged. Dependencies: texlab (pacman `extra`, MacPorts), a
  TeX distribution (Arch: texlive packages; Mac: MacTeX, not MacPorts), Skim
  (outside MacPorts, owner-installed) / zathura (pacman). Built (T-065, 0061).
- DECIDED D-091 (owner 2026-10-13: "avoid latex code in init-cpp.el"): eglot's one
  `use-package` form moves from `lisp/init-cpp.el` to a new `lisp/init-lsp.el`
  (loaded after `init-project`, before the languages), with what holds for every
  server and the generic `C-c l` keys; each language module names its server and
  settings through `emacs-cpp-lsp-server` / `emacs-cpp-lsp-settings` (each adds to
  `eglot-server-programs` / `eglot-workspace-configuration` once eglot loads) and
  adds its own `C-c l` keys: clangd, `o`, `P` in init-cpp; pyright in init-python;
  texlab, `b` in init-latex. DESIGN 4 principle 3 holds: eglot is configured in
  one form, the languages only register data.
- DECIDED D-101 (SUPERSEDED 2026-10-25 by D-145; owner 2026-10-14, O-51 (a), then "use
  latexindent for both buffers and
  regions, not a mix of texlab and latexindent"; done when agreed): in LaTeX buffers
  `C-c l f` and the menu's Format Buffer run latexindent itself
  (`emacs-cpp-latex-indent-program`), not texlab. The buffer's text goes to a temporary
  directory; with a region latexindent indents only its lines (`--lines MIN-MAX`,
  reading the whole document), without one the whole document; `-c` keeps its log out of
  the project; only what differs is replaced (`replace-region-contents`), in one undo
  step. latexindent's defaults, as texlab calls it (no local settings, no line-break
  changes): on the sample both give the same text. (Wrong, fixed by D-103, O-53: texlab
  passes `--local`, so it reads a project's `.latexindent.yaml`; this call does not.) A
  missing program or a non-zero exit stops with the fix or latexindent's message, the
  buffer unchanged. Dependency: latexindent, already texlab's (TeX Live: Arch
  `texlive-binextra`, MacTeX). `.bib` files keep texlab's format. Built (T-074, 0068).
- DECIDED D-102 (SUPERSEDED 2026-10-25 by D-145; owner 2026-10-14, O-46: "none"): no
  LyX keys. LaTeX buffers keep
  AUCTeX's own keys (option (c)); Emacs's and Emacs.app's bindings stay as they are
  on both machines (`RESEARCH_latex.md` 8). Options (a) and (b) closed.
- DECIDED D-103 (SUPERSEDED 2026-10-25 by D-145; owner 2026-10-14, O-53 (a), (b), (d);
  done when agreed; amends D-101):
  latexindent for `C-c l f` and Format Buffer gets `--local` and runs in the directory
  texlab 5.25.1 uses: the nearest directory upward, within the project, with
  `.latexmkrc`, `latexmkrc`, `.texlabroot` or `texlabroot`, else the file's own; so a
  project's `localSettings.yaml` / `latexindent.yaml` (dotted or not) applies as it does
  through texlab. With neither such a file there nor a user `indentconfig.yaml` (`~/`,
  `~/.`, `~/.config/latexindent/`) it adds `-y=defaultIndent:` with `LaTeX-indent-level`
  spaces, a tab with `indent-tabs-mode`, so `C-c l f` indents with the characters
  AUCTeX's `TAB` uses (texlab ignores the request's `insertSpaces`). texlab's slow
  `exit` right after opening stays as it is (O-53 (5), (d)). Built (T-078, 0070).
- DECIDED D-145 (owner 2026-10-25: "remove language servers/features/modules not related
  to C/C++ or Python (R, texlab)"; done when agreed; supersedes D-090, D-101, D-102,
  D-103 and D-072's R part): R and LaTeX leave the config. Gone: `lisp/init-r.el`,
  `lisp/init-latex.el`, the submodules `lib/ess` and `lib/auctex` with
  `patches/auctex`, R's cells (code-cells stays for Python), `C-c l b`, yasnippet in
  `LaTeX-mode` / `bibtex-mode`, `emacs-cpp-default-pdf-viewer`, and from D-089's list
  `/usr/local/bin` (only for CRAN's R) and `/Library/TeX/texbin`. `.tex` and `.R` files
  open in Emacs's built-in modes, no server. O-39 closed, T-079 dropped (its texlab
  report deleted unsent). Kept: `lisp/init-writing.el` (markdown-mode, org-journal, no
  server; owner 2026-10-25), `RESEARCH_latex.md` and `RESEARCH_r_language_servers.md`
  as findings, marked superseded. Test: init.el loads with neither module nor
  package on `load-path`. Built (0099).
- DECIDED D-095 (owner 2026-10-14, O-45 (b), keys (k2); done when agreed): yasnippet
  (GNU ELPA's `externals/yasnippet`, pinned dd570a6 = 0.14.3) and yasnippet-snippets
  (NonGNU ELPA's `elpa/yasnippet-snippets`, pinned 606ee92, the branch's tip of
  2025-12-15: its 1.0 release commit 39e640c has no `c++-ts-mode` / `python-ts-mode`
  directories, added upstream 2024-01), two submodules (network fetch at clone,
  D-014). yasnippet is on in `prog-mode` buffers (`LaTeX-mode` and `bibtex-mode`
  until D-145)
  (`lisp/init-completion.el`); with it eglot announces snippet support, so a chosen
  clangd completion arrives with a field per parameter (`area(double scale, int n)`),
  texlab's environments with their `\end`. A snippet key expands on `C-c y`
  (`emacs-cpp-snippets-expand`; none before point: an error saying so), never on
  TAB, which indents and completes as before (D-020); inside a snippet TAB / S-TAB
  go to the next / previous field, except while corfu's popup is open
  (`yas-keymap-disable-hook`), so TAB completes there. Load cost (Mac, batch):
  yasnippet 8.5 - 11 ms at the first code or LaTeX buffer, nothing at startup; the
  collection's 124 directories 130 - 150 ms (mostly reading each `.yas-parents`), so
  it loads at the first `C-c y` or `C-c & C-s` (yasnippet's insert by name; first
  `C-c y` 213 ms), not with yasnippet: patch 0001 (D-069) drops the autoload that
  loaded it with yasnippet. Own snippets: yasnippet's default directory, `snippets/`
  in `user-emacs-directory` (yasnippet creates it), loaded with the collection. A
  `.tex` file with no LaTeX in it opens in AUCTeX's plain TeX mode, without
  yasnippet. Built (T-071, 0064).
- SUPERSEDED by D-039 (2026-10-08): "Known gap: package Info manuals (magit,
  projectile) are not built; T-010."
- DECIDED D-039 (owner 2026-10-08, T-010): `make packages` builds the Texinfo manuals
  the packages ship, listed per submodule with the `.gitmodules` key `info`: magit,
  magit-section, with-editor, embark, orderless, dash. `makeinfo` and `install-info`
  (texinfo package) write `lib/info/*.info` and its `dir` (git-ignored); `C-h i` lists
  them through `Info-additional-directory-list`. A missing tool, a missing listed
  manual or a makeinfo error stops the build; makeinfo warnings pass. Not built
  (owner): projectile (AsciiDoc only; a pandoc conversion worked, 21 chapters, links
  between pages lost) and the Org READMEs (vertico, consult, corfu, ...).
- DECIDED D-069 (owner 2026-10-10, "patch files in the repo"): a fix to a vendored
  package that upstream has not taken yet is a patch file, `git format-patch` against
  the pin, in `patches/<submodule>/NNNN-*.patch`, listed in order with the repeatable
  `.gitmodules` key `patch` (relative to the repository root). `make packages` applies
  each submodule's series before compiling: a series already in (a second run) is first
  taken out whole, in reverse (superseded 2026-10-19 by D-116: the files the series
  touches are reset to the pinned commit), then applied whole; `git apply` changes
  nothing unless every patch fits, so a series that no longer applies (a pin bump, a
  hand edit; the latter superseded by D-116) stops the build with git's message.
  A listed patch that is missing and a patch file no
  `patch` line lists are build errors. A patched submodule shows "modified content" in
  `git status`, on purpose (no `ignore = dirty`, which would hide hand edits too).
  Rejected: a commit in the submodule (on no remote, a fresh clone breaks), a fork
  (network, upkeep; reconsider for many long-lived changes), and Lisp workarounds
  beyond a line or two (they lean on the package's internals). First patch:
  treemacs 0001, T-041, replacing D-067's stand-in timer. Second: consult 0001 (D-079).
  Third: projectile 0001 (D-081). Later: auctex 0001 (D-090), yasnippet-snippets 0001
  (D-095).
- DECIDED D-116 (owner 2026-10-19, after the Arch run: "make packages should
  reset patched submodule's files to the pinned commit before applying, and stop
  with a clear message when a submodule is uninitialized"): amends D-069. Before a series is
  applied, the files it changes, creates or renames (`git apply --numstat`) get the
  pinned commit's content; a file the commit lacks is deleted. A changed patch
  (consult-eglot 0001 grew in d06e07e) then replaces its older version, which
  D-069's reverse could not take out; a hand edit in such a file is lost, other
  files keep theirs. Before that, `git submodule status` over every submodule stops
  the build naming each one not checked out (`git submodule update --init <path>`;
  `lib/eglot` on Arch after D-108) or at another commit than the pin (`git
  submodule update <path>`, or `git add` to pin it), so the commit checked out is
  the pinned one. Built (T-105, 0078).
- DECIDED D-089 (owner report 2026-10-13, tier 1): on macOS the config puts
  `/opt/local/bin`, `/opt/local/sbin` (MacPorts, D-053) and `/usr/local/bin` (CRAN's
  R; dropped 2026-10-25 by D-145) in front of `exec-path` and PATH at startup when missing
  (`emacs-cpp-default-exec-path-prepend`, D-055; none on Arch). Emacs started from
  the Dock or Finder got launchd's PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) although
  Emacs.app's Info.plist sets `LSEnvironment` PATH, so D-081's check stopped startup
  ("rg is not on exec-path"), and cmake, ninja, pyright would not have been found
  either. Test: a child Emacs with launchd's PATH loads the config and finds its
  search program (fails without the fix). Amended 2026-10-13 (owner report "LaTeX found
  no preview images", tier 1; dropped 2026-10-25 by D-145): `/Library/TeX/texbin`
  (MacTeX, D-090) joins the list;
  shells get it from /etc/paths.d, launchd does not, so from the Dock pdflatex,
  latexmk and dvipng were missing for AUCTeX's preview and texlab's build. Checked
  in a graphical Emacs with launchd's PATH: `preview-buffer` made both previews of
  a toy document. Not taken: all of /etc/paths.d (it also lists system-internal and
  the virus scanner's directories).
- DECIDED D-081 (owner 2026-10-13, O-36: "patch projectile", "GNU grep on Arch"):
  `C-c p ?` / `C-c p s x` (`projectile-find-references`, a textual search) searches the
  files `projectile-project-files` lists with `xref-matches-in-files`, through
  projectile patch 0001 (D-069, `patches/projectile/0001-...`), instead of
  `xref-matches-in-directory` (find, then grep one file at a time, whatever
  `xref-search-program` says). `xref-search-program` comes from the platform's
  defaults file (D-055): `ripgrep` on macOS, `grep` on Arch (no ripgrep there,
  DESIGN 3; wrong since 2026-10-07, found 2026-10-21, O-38); a missing executable
  stops startup. git-ignored files (build directories) are no longer searched, as
  in `C-c p f`. Measured on the Mac, deal.II
  (33768 files): 130 - 156 s before, 10.6 - 11.3 s after, the same 607 / 9429
  matches; `rg` alone in the tree 5.5 - 6 s, the floor there, set by about 14 ms per
  file opened (O-24). Arch not measured (owner). After the owner's GDATA exceptions
  (2026-10-13): 4.8 - 5.5 s; the rest is `rg` given file names, which searches
  them one after another (7 runs of 5000 by BSD `xargs`: 4.7 s; `xargs -P 4` 3.7 s),
  while `rg` or `git grep --untracked` searching the directory take 1.1 - 1.4 s
  (a different file set at the edges: rg's own ignore rules, hidden files). Not
  changed; a next step if the 5 s matter. Upstream report drafted
  (`docs/upstream/projectile-find-references-file-list.md`), the owner sends it.
- DECIDED D-135 (owner 2026-10-21, O-38 (e): "O-38 (e)"): no rg.el / ag.el.
  `C-c p s r` runs `consult-ripgrep` over the project (results in the minibuffer,
  no wgrep); `C-c p s a` is unbound. No new package.
- DECIDED D-147 (SUPERSEDED 2026-10-29 by D-149; owner 2026-10-29: "Per-platform and
  do fswatch proposed tier 3 item"): `global-auto-revert-mode` (built in,
  `autorevert`) is on at startup on both machines: a buffer without unsaved edits
  follows its file when a program outside Emacs changes it (`git checkout` in a shell,
  a formatter); a buffer with unsaved edits is left alone, and Emacs asks on its first
  edit or save, as before. How changes are noticed comes from the platform's defaults
  file (D-055, `emacs-cpp-default-auto-revert-use-notify`): on Arch inotify
  notifications, with `auto-revert-avoid-polling`; on the Mac polling every
  `auto-revert-interval` (5 s), since a notification there is one kqueue descriptor
  per buffer, refused beyond 975 (D-127), and `M-.` into libraries opens many buffers
  (D-019). magit's `magit-auto-revert-mode`, which does this for git-tracked files
  only once magit is loaded, then stays off (its initial value is off when the global
  mode is on). Trigger: owner report 2026-10-29: `M-.` on `ManifoldKind` in
  RMO-drafts' `src/main.cc` landed 19 lines below its definition in `option_types.h`
  after about 15 branch switches in a 3-day-old Emacs; a fresh patched clangd answered
  right, the running one answered right when asked again, and the fault was gone.
  Cause UNVERIFIED; the suspect is a buffer that kept a header's text from before a
  checkout (no auto-revert in the config; whether magit was loaded is unknown), whose
  text eglot gives clangd in place of the file. CLion, Qt Creator and VS Code reload
  unedited buffers likewise (from memory, UNVERIFIED). Not taken: polling on both
  (Arch would lag up to 5 s for nothing), notifications on both (the kqueue cap),
  magit loaded at startup (its load cost, D-125; untracked files left out), eglot's
  fswatch reverting buffers (clangd starts none: no fswatch ran beside its server, pid
  73357), fswatch as a `file-notify` backend (needs Emacs's C code). Proposed (T-128,
  tier 3, spike S20): one fswatch per project root reverting its buffers at once on
  both machines. Built (T-127, 0100): Mac startup within run-to-run noise
  (`autorevert` alone 19 ms in a bare Emacs); Arch run dropped (D-149). Found by S20's
  Mac dry run (2026-10-29): a checkout of 190 open files blocks Emacs about 6 s and
  buffers are current 10 - 11 s after it, not within 5 s (per-buffer
  `vc-refresh-state`); O-78.
- DECIDED D-148 (owner 2026-10-29, O-78: "(d) if S20 passes"): T-128 (the per-project
  fswatch reverter) replaces `global-auto-revert-mode` in project buffers if S20
  passes; files outside project roots keep D-147's auto-revert. Until S20's verdict
  T-127 stays as built, its freeze after large checkouts included (the session's
  reading: no (c) was asked for). If S20 fails, O-78 reopens. Not taken: (a) as the
  end state, (b) revert T-127, (c) a queued VC refresh by advice. Amended by D-149:
  T-127 is reverted until then.
- DECIDED D-149 (owner 2026-10-29: "Undo T-127 for now"): T-127's code is removed
  (`autorevert` form, `emacs-cpp-default-auto-revert-use-notify`, its test); the
  config again reloads no buffer itself, magit's `magit-auto-revert-mode` once magit
  is loaded (with the same per-buffer VC refresh, O-78). Supersedes D-147 and
  amends D-148: if S20 passes, T-128's reverter covers project buffers and auto-revert
  for files outside project roots is ruled again; if S20 fails, O-78 reopens. Reason:
  the freeze of about 6 s after a large checkout on the Mac (O-78). Journal 0100 keeps
  the build and its numbers.
- DECIDED D-151 (owner 2026-11-03: "Put to DESIGN: 1a), 2(b), (3a); record (3b) and
  (1b) for later reference"): the edge cases of O-78 (e), binding T-128 if (e) is
  ruled. Under (e) T-128 reverts every unedited buffer at once; only VC state and
  diff-hl marks wait until a window shows the buffer (`window-buffer-change-functions`).
  Shown means displayed in a live window of any frame, selected or not; a buffer only
  in another `tab-bar` tab or the buffer list is hidden. Which frames count
  (`get-buffer-window` with `'visible` or `t`) is ruled with T-128's code.
  - (1a) A jump (`M-.`) into a buffer within fswatch's delay, before T-128 reverts it:
    nothing done. Text was current 0.14 - 0.15 s after `git` on the Mac (S20
    `fswatch-novc`, `-l 0.1`, 0102), faster than a jump after a checkout. Against:
    eglot's work per revert runs in the filter, unmeasured (RMO); it may stretch the
    delay.
  - (2b) A buffer with unsaved edits whose file changed: T-128 leaves it (as S20's
    `s20--revert`, `buffer-modified-p`), Emacs's prompts stay
    (`ask-user-about-supersession-threat` on the first edit, the modification-time
    check on save), and the filter adds one message per batch naming the skipped
    buffers, e.g. `2 buffers with unsaved edits changed on disk: foo.cpp, bar.h`.
    Against: the echo area is soon overwritten (`*Messages*` keeps it); one more string
    to test. Reverting would drop the edits silently (principle 1).
  - (3a) Previews (`M-o` after D-088's pause, moving through `*xref*`): a stale buffer
    pays its VC and diff-hl refresh, about 60 ms on the Mac (VC 34 - 95 ms, diff-hl
    19 ms, S20 RESULTS follow-up; the hook path unmeasured), once, the first time a
    preview shows it. Against: stepping through many files after a large checkout pays
    it per new file; whether that is felt is UNVERIFIED.
  Recorded for later reference, not taken:
  - (1b) a modification-time check on show: the `window-buffer-change-functions`
    handler runs `verify-visited-file-modtime` and reverts an unedited stale buffer
    before its VC refresh. Revisit if RMO shows eglot's share stretches the delay past
    about 0.5 s. Against: fixes only the jump's target (clangd answered from the old
    text); point is kept only where the text around it is unchanged
    (`insert-file-contents` with REPLACE); code and a test.
  - (3b) refresh after an idle pause: `run-with-idle-timer` (about 0.3 s), only if the
    buffer is still shown, so previews passing by skip it. Revisit if S20's new mode
    or daily use shows the stutter. Against: mode line and marks lag about 0.3 s after
    every jump into a stale buffer; a timer per show; more code.
- DECIDED D-152 (owner 2026-11-03: "Rule (a)"): a file deleted on disk, for T-128 if
  (e) is ruled. T-128 reverts only a file that exists and is readable (as
  `auto-revert-handler`, `autorevert.el:834` in Emacs 31.1); the deleted file's buffer
  stays as it is and (2b)'s message names it, e.g. `1 buffer's file deleted on disk:
  baz.h`. Reason: `revert-buffer` on a missing file signals `"File %s no longer
  exists!"` (`files.el:7301`); inside the fswatch filter, as S20's `s20--revert` does
  it unguarded, the error ends the filter call and the rest of the batch stays
  stale. S20's checkout deletes no file, so T-128's tests add one. Against: clangd
  keeps the open buffer's symbols, so `M-.` can still land in the deleted file. Not
  taken: (b) kill an unedited deleted file's buffer (Qt Creator closes its editor).
  Against: a buffer shown in a window disappears from under the owner, with its undo
  history and point.
- DECIDED D-153 (owner 2026-11-03: "Rule (e), new S20 mode first"; O-78 (e)):
  T-128's reverter reverts every unedited buffer at once with diff-hl's revert hook
  held back; VC state and diff-hl marks are refreshed one buffer per timer step for
  buffers shown in a window, and for a hidden buffer when a window shows it
  (`window-buffer-change-functions`); edge cases D-151, D-152.
  `magit-auto-revert-mode` goes off in the commit that ships T-128's code, never
  earlier (until then it is the only reverter), by `:init (setq
  magit-auto-revert-mode nil)` on `(use-package magit)` before magit loads (`:config
  (magit-auto-revert-mode -1)` would first turn it on in every open buffer). First a
  new S20 mode, `fswatch-shown`, measures it with diff-hl loaded on both machines
  (criteria in S20's `RUN.md`, confirmed with the session's plan 2026-11-03); eglot's
  share is measured on RMO before T-128 ships; files outside project roots are ruled
  with T-128 (D-149). Amends D-148: the reverter replaces magit's auto-revert in
  project buffers if `fswatch-shown` passes. Not taken: (f) - (i), each with its case
  against in O-78. Against: holds back a vendored package's hook by its function name
  (`diff-hl-after-revert`); a hidden buffer's VC state stays stale until shown;
  eglot's work per revert stays in the filter, unmeasured. `fswatch-shown` PASS on the
  Mac 2026-11-03 (0103): blocked at most 0.13 s, shown buffers current 0.33 s after
  `git`; PASS on Arch 2026-11-03 (0110): blocked at most 0.14 s, shown buffers
  current 0.36 s after `git`. eglot's share on RMO-drafts (0104): E1 - E3 PASS on the
  Mac (blocked at most 0.183 s with 39 eglot buffers); a checkout during clangd's
  reparse blocks 0.36 - 0.98 s, O-79.
**The reverter as built (T-128, 2026-11-04; D-153, D-156, D-161 - D-163, D-167,
D-168).**
`lisp/emacs-cpp-reverter.el`, written fresh from S20's `fswatch-shown` and the eglot
backend's process handling (7.1), its reverting rewritten from S20's
`fswatch-chunked` (D-167, D-168); loaded by init-project.
- **Which buffers.** A file buffer whose directory has a root by D-070's rule
  (`emacs-cpp-reverter-root`: projectile's first three ways, `projectile-root-local`,
  `projectile-root-marked` for a `.projectile` file, `projectile-root-bottom-up` for
  version control) and where `emacs-cpp-revert-project-buffers` is non-nil (t by
  default; a safe local variable, so `.dir-locals.el` can turn a project off).
  `emacs-cpp-reverter-covers-p` answers that for auto-revert, which asks once, when
  it adds a buffer (`auto-revert--global-add-current-buffer`), so it says "would
  cover", not "has adopted". Nested roots (a submodule) get their own fswatch; a
  change under both is reverted once (the second call finds the file verified).
- **Processes.** `find-file-hook` adopts a covered buffer and starts its root's
  fswatch if none runs; `kill-buffer-hook` releases it, stopping the fswatch with the
  root's last buffer; `after-set-visited-file-name-hook` adopts again. The command is
  the backend's (`-0 -r -x --event-flag-separator=, -l 0.1 --allow-overflow -e
  /\.git/` on the root's true name); a sentinel warns when an fswatch ends unasked and
  names `M-x emacs-cpp-reverter-restart`, which starts every adopted root's fswatch
  again.
- **Reverting.** A filter call only queues the buffers its records name, a buffer in
  a live window first (D-167); an Overflow record warns at most once a minute and
  queues every buffer of the root, since changes were lost. One one-shot timer runs
  the steps (D-168): while reverts are queued a step reverts until
  `emacs-cpp-reverter-budget` (0.05 s) is spent, one buffer at least, and the next
  follows after `emacs-cpp-reverter-pause` (0.01 s). A buffer is reverted when
  unedited, readable and newer on disk, with diff-hl's buffer-local
  `diff-hl-after-revert` held back (bound in the buffer); edited and deleted files'
  buffers are kept and named in one message once the revert queue is empty (D-151
  (2b), D-152).
- **VC state and marks.** A reverted buffer in a live window of any frame (D-162 (b))
  joins a second queue; with no revert queued, a step refreshes its oldest buffer
  (`vc-refresh-state`, then `diff-hl-update` where `diff-hl-mode` is on), the next
  0.05 s later; never a revert and a refresh in one step (D-168). A step reached inside
  a running step (a revert's send to a busy server waits, Emacs runs timers) only arms
  again ((e) D-156, (p) D-161: the filter no longer reverts, so the step carries both).
  A hidden one is marked stale and refreshed when a window shows it
  (`window-buffer-change-functions`).
- **Elsewhere.** `global-auto-revert-mode` (`autorevert`, at `after-init`) covers the
  buffers the reverter does not: its `global-auto-revert-ignore-buffer` defaults to
  `emacs-cpp-reverter-covers-p`; notified on Arch, polled every 5 s on the Mac
  (`emacs-cpp-default-auto-revert-use-notify`, D-162 (a)). The option's `:set` applies
  at once: off releases every buffer and stops every fswatch, on adopts every covered
  file buffer; then auto-revert re-adds every buffer through the predicate
  (`global-auto-revert-mode` off and on). magit's auto-revert stays off (`:init`,
  D-153). diff-hl's hook name is checked when diff-hl loads (an error naming D-153).
- REJECTED: borg (the tool this layout imitates). It assumes the package repository is
  the Emacs directory itself, which contradicts D-003; reconsider if own glue grows past
  about 100 lines. Measured after T-002: `scripts/build-packages.el` has 183 lines of
  code (excluding comments and blank lines), past that mark. Superseded 2026-10-07 by
  D-015: the own glue stays regardless of size; borg is not revisited unless the glue
  fails a task.
  REJECTED: straight.el, elpaca, package-vc (owner ruling 2026-10-07).
- DECIDED D-007 (superseded by D-014): network access happens only when the owner runs
  `git submodule update` or adds a submodule; Emacs makes no network calls at startup.
- DECIDED D-014: network access happens only when adding or updating submodules (by the
  owner, or by a session with the owner's consent for that change); Emacs makes no
  network calls at startup.
- Package set (Q-3 accepted 2026-10-07; dependencies from the 2026-09-14 archive
  snapshot). Built into Emacs 31 and not vendored: eglot, jsonrpc, project, flymake,
  transient, compat, seq, cl-lib, org, which-key. Vendored, 30 repositories (26 to T-016,
  28 to T-045; code-cells and ESS by T-046, D-072):
  - completion: vertico, orderless, marginalia, consult, embark (holds embark-consult),
    corfu, cape (vendored by T-003); consult-eglot v0.5.0 (T-004); eglot from GNU
    ELPA's mirror, shadowing the built-in one (D-108, T-090).
  - IDE: dape (vendored 0.27.1 for S2, owner consent 2026-10-08; its `use-package`
    form is in `lisp/init-debug.el`, T-006), diff-hl, breadcrumb.
- DECIDED D-042 (owner consent 2026-10-08, T-016): diff-hl vendored at tag 1.10.0
  (github.com/dgutov/diff-hl). Its marks go to the right fringe, since the left one
  holds dape's breakpoints and the debugger's arrow (D-036); the right margin in a
  terminal. Turned on per visited file from `find-file-hook` at depth 90 (after
  `vc-refresh-state`; in front of it the first update never ran), not by
  `global-diff-hl-mode` at startup (39 ms). Marks follow saves and magit refreshes;
  unsaved edits are not marked (`diff-hl-flydiff-mode` not adopted).
- DECIDED D-043 (owner consent 2026-10-08, T-017): breadcrumb vendored at commit
  bcf7f1d (github.com/joaotavora/breadcrumb; no tags upstream; version 1.0.1), on in
  C and C++ buffers (`c-ts-base-mode-hook`): the header line shows the path from the
  project root and the class / function at point (from imenu).
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
| header opened first gets wrong flags (errors) | D-028 (S4 dropped) | owner | T-011 |
| first `M-.` / rename per file waits 7 - 13 s | S5 (closed), S6 | owner | O-8 |
| index rebuilt from scratch per preset / build dir | S7 | owner | - |
| patched clangd's index navigation slower / wrong on RMO | S8 | owner | O-11 |
| header opened first after a restart gets guessed flags | S9 (PASS) | owner | - |
| deal.II sources index unused or too costly on RMO | S10 | owner | O-12 |
| go-to-anything prompt slow on RMO / deal.II | S11 (runs 2, 3 PASS) | owner | T-049 |
| CLion-style symbol matches break or slow clangd | S14 (PASS) | owner | O-57 |
| Mid-word ranking changes good fuzzy matches or slows clangd | S15 (PASS) | owner | O-67 |
| match function ranks unlike the regexps or is slower | S16 | owner | D-124 |
| compiled `lisp/` slows startup or stays bytecode | S17 | owner | D-125 |
| fswatch backend loses changes or costs Emacs too much | S18 (PASS 2026-10-21 on Arch; the Mac's cost misread, O-80) | LLM / owner | D-127 |
| per-project fswatch reverter loses changes or blocks Emacs | S20 (FAIL 2026-11-02: Mac criterion 3, VC steps; PASS on Arch; mode `fswatch-shown` for (e), D-153: PASS on the Mac 2026-11-03, 0103; FAIL on Arch 2026-11-04, criterion 3, D-166, 0115; `fswatch-chunked` D-167 PASS on Arch 0116 and the Mac 0117; module rewritten, D-168: `shipped` PASS on the Mac 0118 and on Arch 0119; refresh first, D-169: PASS on Arch 0122 and the Mac 0123) | LLM / owner | O-78 |
| own package build glue mis-orders compilation | none (tests) | - | v0.1 |
| config fails on macOS (paths, tools, tests) | none (`make test`) | owner | D-050 |
| clangd too slow / too large on deal.II scale | S1 numbers | owner | v0.1 |

## Research program
- `RESEARCH_go_to_anything.md` (owner request 2026-10-11, T-047): one prompt for
  files, symbols, bookmarks and commands like CLion's Search Everywhere; consult's
  multi-source prompt with clangd's symbols as an async source; keys. Findings in;
  O-30 ruled (D-074), S11 measured (0048), O-31 / O-32 ruled (D-076, D-075);
  prompt speed in a terminal Emacs: O-33; narrowed to symbols: O-34 (D-079);
  project-only symbols: O-37 (D-082, D-083); URIs without per-server spellings: O-40.
- `RESEARCH_latex.md` (owner request 2026-10-13): texlab (and digestif) through
  eglot in the built-in `latex-mode`; packaging; hands-on on the Mac. Findings in;
  O-42 ruled (D-090).
- `RESEARCH_r_language_servers.md` (owner request 2026-10-13): languageserver, Arity,
  Air, Ark; packaging on Arch and MacPorts; languageserver run through eglot on the
  Mac. Findings in; O-39.
- `RESEARCH_julia.md` (owner request 2026-10-25): LanguageServer.jl, JETLS, julia-mode,
  julia-ts-mode, julia-snail, DebugAdapter.jl; packaging on Arch and MacPorts. No
  hands-on (no Julia on the Mac). Findings in; O-76.
- `RESEARCH_ast_grep.md` (owner request 2026-10-31): ast-grep's language server against
  clangd's features, tree-sitter parse quality on deal.II, packaging on Arch and
  MacPorts. No ast-grep run (not installed). Findings in; O-77 -> D-146.
- `RESEARCH_other_languages.md` (owner question 2026-10-08): Python, R, Perl next to
  the C++ setup. Findings in; rulings O-19, O-20.
- `RESEARCH_notebooks_cells.md` (owner request 2026-10-10, T-045): `# %%` cells for
  Python and R (code-cells, ESS), org-babel, Jupyter kernels, `.ipynb`, Quarto.
  Findings in; O-29 ruled (D-072).
- `RESEARCH_indent_guessing.md` (owner request 2026-10-09, T-034): packages that
  guess indentation or a `.clang-format`, measured on RMO; clangd's on-type
  formatting through eglot. Findings in; O-28 ruled (D-061).
- `RESEARCH_navigation_delays.md` (owner question 2026-10-09): where `M-.` on names
  spends its time on the Mac; stale "indexed with errors" shards. Findings in; O-27.
- `RESEARCH_python_macos.md` (owner request 2026-10-09, T-025): pyright and five
  alternatives through eglot, debugpy's start against dape's wait. First round in;
  no ruling asked yet.
- `RESEARCH_python_ty.md` (owner request 2026-10-20, T-025 round 2): pyright against
  ty 0.0.90 on Arch: requests, watches, speed, what a migration touches. Findings in;
  O-72 open.
- `RESEARCH_platform_differences.md` (owner request 2026-10-14, O-50): symlinked
  paths (`/tmp` on macOS) and clangd's index, who spells which path (CMake 3.31 /
  4, Emacs, eglot), measured with stock and patched clangd; file watches (kqueue,
  inotify; section 3, T-029's findings carried over, O-26 ruled: D-054 confirmed,
  upstream report T-032); other platform differences. Findings in; O-50 open.
  Supersedes `RESEARCH_file_watches_macos.md` (T-029, 2026-10-09), removed
  2026-10-14.
- `RESEARCH_keys_build_debug_ui.md` (owner questions 2026-10-08): key hints, building
  from any buffer, breakpoint indicators. Findings in; rulings O-16, O-17, O-18.
- `RESEARCH_modules.md` (owner request 2026-10-14): turning modules on and off as Doom
  Emacs (`doom!`, flags, `doom sync`), Prelude and Spacemacs do; this config's module
  dependencies, startup cost per module, autoloads that act without their module.
  Findings in; O-48 ruled (D-098).
- `RESEARCH_snippets.md` (owner request 2026-10-14): yasnippet, its collections,
  tempel; what eglot does with snippets. Findings in; O-45 ruled (D-095).
- `RESEARCH_mouse.md` (owner request 2026-10-13): CLion's mouse and modifier-click
  bindings against Emacs 31.1's (`xref-...-at-mouse`, `context-menu-mode`). Findings
  in; O-44; sections 5 - 7: hover highlight and its cost, a plain click (O-47).
- `RESEARCH_refactoring.md` (owner request 2026-10-13): CLion's C++ refactorings
  against clangd 23.1.1's rename and tweaks and the clang command-line tools; rename
  measured across 63 files. Findings in; O-43.

## Open questions ledger (LIVING)
- O-88 (OPEN 2026-11-05, from T-121; D-140 (c)): switch the Mac's Python server from
  pyright to ty (RESEARCH_python_ty 4c). Measured: ty's first `M-.` 6 - 13 times
  sooner on a small tree, no sooner on SymPy (0.4 - 0.5 s, Arch 65 - 72 ms, cause
  UNVERIFIED); `M-?` over 5600 references 4.2 - 5.3 s through eglot against 6.8 -
  9.5 s, complete where pyright's first reply was not; half the memory. ty finds
  packages in the user site-packages only through `environment.extra-paths`.
  Options:
  (a) ty on the Mac, `defaults-darwin.el` naming `("ty" "server")` and `make
  macos-ports` as its install command, the config sending
  `environment.extra-paths` = Python's user site-packages (`python3 -m site
  --user-site`, read when ty starts) on the Mac only. Against: a 0.0.x beta the owner
  bumps by hand (D-180); the Mac's first `M-.` on a SymPy-sized tree as slow as
  pyright's; the extra path also adds packages a project's own virtual environment
  would not have (a `.venv` takes precedence for its own packages, UNVERIFIED).
  (b) as (a), without the extra path; user-installed packages unresolved. Against:
  numpy, pandas and matplotlib unresolved in RMO's scripts.
  (c) pyright stays (D-140 as is). Against: `M-?`'s incomplete first reply; 2 times
  the memory; the platforms keep two servers and two test paths.
  Recommendation: (a).
- O-87 (RESOLVED 2026-11-05 with D-181: (a); owner: "(a)"; owner 2026-11-05: "Explore
  some alternative file paths for the local ports, only writeable by root"): where
  MacPorts reads the local port tree. Found: for a `file://` source inside a git work
  tree, `port sync` and `port selfupdate` run `git pull --rebase --autostash` there
  (`macports.tcl` `GetVCSUpdateCmd`, `UpdateVCS`), so D-180's path in the repository
  would pull and rebase the owner's checkout on every selfupdate; for any `file://`
  source they re-run `portindex`. Options, all root:wheel 755 on the Mac: (a)
  `/opt/local/var/macports/sources/emacs-cpp/ports` (MacPorts' data directory; it
  might one day clean directories it does not know, UNVERIFIED); (b)
  `/opt/local/share/emacs-cpp/macports` (inside the prefix, owned by no port); (c)
  `/opt/emacs-cpp/macports` (survives MacPorts' removal); (d) `/Library/Application
  Support/emacs-cpp/macports` (a space in the `file://` URL, UNVERIFIED; group
  admin); (e) `/usr/local/share/emacs-cpp/macports` (other installers chown
  `/usr/local`).
- O-86 (RESOLVED 2026-11-05 with D-180: (d), a binary port; owner: "(d) binary port";
  owner 2026-11-05: "Can we vendor ty and ruff to make distribution easier on
  macos?"): ruff has a MacPorts port (0.17.3, D-143's source), so nothing to vendor;
  ty has none (D-140 (c), T-121). Options for ty: (a) its prebuilt binary committed
  (about 13 MB per release, six releases in a month, forever in git); (b) its source
  as a submodule built with cargo (ruff's whole workspace, 553 crates); (c) a build
  script into `~/opt` as clangd's (D-052; a second update path beside MacPorts);
  (d) a local MacPorts port in `packaging/`, binary or source (RESEARCH_python_ty 7;
  a `sources.conf` line, a system file, and bumps by hand).
- O-85 (REOPENED 2026-11-05 by D-179: (f) built and reverted, its first call 4 times
  today's listing on large trees; a remedy may not make any call slower than today's
  listing; was RESOLVED 2026-11-05 with D-177: (f); owner: "O-85 (f)"; T-133,
  RESEARCH_go_to_anything 22): projectile lists the
  project on every `C-c p f` and `M-o` (no cache by default with `alien` indexing):
  444 - 493 ms for emacs-cpp (31 submodules), 68 ms for deal.II's 34556 files, 25 - 50
  ms for RMO-drafts. Options:
  (a) Cache for the session (`projectile-enable-caching` t), files opened or deleted
  in Emacs kept current by projectile. Against: files created or removed outside
  Emacs (a checkout, a build, a shell) are missing or stale in `C-c p f` and `M-o`
  until `C-c p i`.
  (b) (a) plus projectile's own watches (`projectile-auto-update-cache-with-watches`).
  Against: experimental; one watch per directory with a limit of 512, so deal.II-sized
  trees (1805) are not watched and stay stale as in (a); on macOS one kqueue
  descriptor per directory beside eglot's and the reverter's (UNVERIFIED whether it
  fits; Emacs refused at 975 before, D-127).
  (c) (a) with the cache of a root dropped whenever the reverter's fswatch for that
  root reports a created, removed or renamed path, and when that fswatch stops; the
  next listing rebuilds it (once, 25 - 493 ms). Against: config code coupling
  init-project to the reverter (tier 2, with tests); a root the reverter does not
  watch (no file buffer yet, opted out by D-163 (b), outside version control) gets
  no cache, as today; a checkout drops the cache, so the next `M-o` pays one listing.
  (d) No cache, a cheaper listing: one `git ls-files --recurse-submodules` for git
  roots in place of projectile's per-submodule commands (8 ms for emacs-cpp).
  Against: changes projectile's file set (untracked files of submodules, fd's view)
  or needs its own listing code; the progress message still flashes on each call.
  (e) (a) with `projectile-files-cache-expire` (e.g. 30 s). Against: stale for up to
  that long and a full listing every time it expires.
  (f) (a) checked by directory times instead of a watcher (owner 2026-11-05: "Some way
  to not tie the projectile setup to the reverter?"): with each root's list kept the
  modification times of its directories, read before listing; a use reads them again
  and lists anew only if one changed (5.3 ms for emacs-cpp, 1.0 ms RMO-drafts, 31.6 ms
  deal.II, against 444 - 493, 25 - 50, 68 - 75). Catches files created, removed or
  renamed outside Emacs, on both machines and every root. Against: around
  `projectile-project-files` (advice, or a patch file, D-069); the check grows with
  the directories (deal.II only halves); a `.gitignore` edit that moves no file is
  seen at the next change of structure.
  (g) The reverter runs a hook with each root's created and removed paths, the
  projectile setup subscribes. Against: the dependency turned round, not removed;
  freshness still needs the reverter watching that root.
  Combined: (c) holds (a)'s speed with fresh lists where the reverter already
  watches; (f) does without it. Recommendation: (f) (was (c) on 2026-11-04): no
  coupling, every root, both machines.
- O-84 (RESOLVED 2026-11-04 with D-175: (a); owner: "O-84 (a)"; from S19's FAIL,
  0125): what follows for O-68's gapped
  in-word queries (`eto` -> `Vector`). S19 (D-171 .. D-174): the index side fits
  (memory +15.5 MB, build 2.21 times with names cached, queries at limit 100 under
  8 ms), but at `M-o`'s limit 10000 the field fills replies with up to 10000 gap
  matches and 16 of 26 keys on RMO-drafts take more than twice pkgrel 1's time
  (`eto` 15.9 -> 411.9 ms). Options:
  (a) Stop: no patch 0014; O-68's gap stays unfound, its later stage unscheduled.
  Against: `eto` -> `Vector` keeps finding nothing, the case O-68 started from.
  (b) A second S19 round with the tier 3 capped at the server (at most K gap
  matches per request after tiers 1 - 2, K a variable), criterion 6 rerun for K in
  {100, 500, 1000}. Against: about 1.5 h of the session's work; `dealii::Vector` came
  about 966th among `eto`'s gap matches at the server, so a K that keeps it may keep
  most of the cost (UNVERIFIED); a cap hides gap matches beyond it.
  (c) Gap matches only for queries of four or more letters (`gapMatch` 4), where the
  gap tier is small (`assemb` .. `qgau`: at most 1.7 times). Against: `eto`, `ptr`,
  `cml`, the three-letter cases O-68 named, lose the gap tier; untested at four
  letters except the long keys above.
  Combined: (b) with (c) caps both; Recommendation: (a), recorded with S19's numbers:
  neither cap restores the motivating case at an affordable cost (the 966th rank in
  (b), three letters in (c)); revisit if clangd's server ranking of tier 3 changes.
- O-83 (RESOLVED 2026-11-04 with D-174: (b); owner: "RMO-drafts with RMO; O-83 (b)";
  from S19, 0124): what S19's criterion 6 ("`M-o` on RMO in
  S11's harness: keys within S11's 2 - 30 ms") times. S11's 2 - 30 ms came from run
  1's `measure.el`, a plain `workspace/symbol` (no limit, no `middleMatch`); the
  shipped `M-o` asks limit 10000 with `middleMatch` and `looseScope` (D-083, D-113),
  and with the field the patch costs up to 22.9 ms per index on deal.II alone at
  that limit (`eto`; S19 RESULTS), two indexes per key. RMO and its machine are not
  this session's. Options:
  (a) S19's `client.py` on RMO, each key of S11's words and the 12 queries as the
  shipped `M-o` sends it plus `gapMatch`, RMO's background index and deal.II's,
  pkgrel 1 against the patch; judged: each key at most 30 ms. Against: the 30 ms
  came from a cheaper request, so the baseline itself may exceed it; the patched
  clangd must be built on that machine (about 10 min, no install) and the runs are
  the owner's.
  (b) As (a), judged against the same request without the field: each key at most
  twice pkgrel 1's, or at most 30 ms. Against: "twice" is a new number for the owner
  to set; the owner's runs as (a).
  (c) S11's terminal prompt (`prompt.sh`, run 4 with the shipped `M-o`) with a
  spike-only advice adding `gapMatch`; judged on S11 run 2's screens (each key's
  first screen within 100 ms). Against: a load hook added to S11's `prompt.sh`;
  times screens, not the replies criterion 6 names; the owner's runs as (a).
  Combined: (b) reports what (a) does. Recommendation: (b): it judges the field's
  own cost on the request `M-o` really sends, and keeps (a)'s 30 ms as an upper
  bound (UNVERIFIED whether pkgrel 1 itself stays under it on RMO at limit 10000).
- O-82 (RESOLVED 2026-11-04 with D-169: (b); owner: "(b)"; the owner: "revisit
  D-168"): the order of the module's
  steps. Evidence (0121, Arch, load 1.0 - 1.3, three runs each): as shipped
  (reverts, then refreshes) Emacs blocked 0.07 - 0.09 s, all buffers current 0.20 -
  0.30 s, the shown buffers' branch and marks 0.45 - 0.55 s after `git`;
  refresh-first (probe `refresh-first.el`) 0.07 - 0.09 s, 0.36 - 0.51 s, 0.18 -
  0.28 s; the spike's two timers 0.08 - 0.12 s, 0.21 - 0.35 s, 0.24 - 0.31 s. Options:
  (a) Keep D-168. Against: the buffers on screen get their branch and marks last,
  about 0.25 s after every other buffer's text.
  (b) Refresh first: one timer, one kind of work per step, a queued shown buffer's
  refresh before the remaining reverts. Against: the hidden buffers' text 0.15 -
  0.2 s later (still within 1.0 s, unseen until shown); a tier 2 change to the
  shipped module with its test, and `shipped` again on both machines (the Mac's runs
  the owner's while this session is on Arch).
  (c) Two timers as the spike. Against: both falling due in one pass, the block D-168
  removed (0.12 s here, 0.18 s on the Mac).
  (b) combines (a)'s bound with (c)'s shown latency. Recommendation: (b).
- O-81 (RESOLVED 2026-11-04 with D-167: (b); owner: "O-81 (b)"; from D-166): how the
  shipped reverter
  (`lisp/emacs-cpp-reverter.el`, 5316f49) reverts from a queue. Evidence: on Arch one
  filter call reverts 189 buffers in 124 - 302 ms (0110, 0115); about 0.7 - 1.6 ms per
  buffer. Options:
  (a) Change the module directly: the filter queues the call's buffers, a timer step
  reverts shown buffers first, then the rest, stopping after a time budget; judged by
  S20's `shipped` mode on both machines. Against: tier 3 code before its shape passes
  a spike (the hard rule); the spike's modes stay at the old shape.
  (b) A new S20 mode `fswatch-chunked` in `s20-run.el` first (the same queue, budget
  per step a variable), three runs per machine against `fswatch-shown`'s criteria 1 -
  6; then the module written fresh from its numbers, then `shipped` again on both
  machines. Against: two measurement rounds, the Mac's runs the owner's while this
  session is on Arch; about 1 h of the session's work.
  (c) Keep reverts at once and move the work out of them (eglot's didClose / didOpen
  and the major mode's hooks per revert). Against: unmeasured which part of the 0.7 -
  1.6 ms is whose (UNVERIFIED); still grows with the checkout.
  Recommendation: (b): the rule's order, and the budget per step is the number the
  module needs.
- O-80 (RESOLVED 2026-11-04 with D-165: (a), (c) drafted; owner: "(a), draft (c)
  report"; was OPEN 2026-11-03, found in D-160's research, 0111): Emacs 31.1's
  `process-attributes` gives CPU times 41.7 times too small on Apple silicon: its
  Darwin code takes proc_pid_rusage's times, Mach ticks of 125/3 ns, for ns
  (`sysdep.c`; a child that burned 1.0 s of CPU read as 0.027 s). S18 judged its
  criterion 3 (Emacs's CPU per 1000 records, at most 50 ms) on the Mac with it: times
  the factor, the Mac costs about 83 ms (runs 4, 6), 250 ms (run 3) and 290 - 375 ms
  (dry run), over the limit; Arch's 37 - 49 ms stand (Linux's `/proc`). D-057 judges
  budgets on Arch only, but D-127 asked for S18 on both machines. The config's
  `lisp/` reads no CPU times; S20's settle test did (fixed in the spike, 0111).
  Options:
  (a) record the Mac's cost, judge Arch only (D-057); D-127 stands. Against: the
  Mac's cost (about 1.7 s of Emacs's CPU for S18's 20000-file burst) stays
  unexamined; the factor-corrected numbers are not a run.
  (b) rerun S18's `shipped` mode on the Mac with `current-cpu-time` (`s18-run.el`
  reads it now), then rule. Against: about 15 min of the session's time on the Mac;
  the limit of 50 was set with Arch's three records per file in mind.
  (c) report the bug to Emacs (`report-emacs-bug`, the owner's to send) with the
  1 s burner as reproduction. Against: outward, the owner's time; fixes nothing here.
  Combined: (b), then (a) or a Mac cost task by its result; (c) beside it.
  Against: two steps before the Mac's verdict is restated.
  Recommendation: the combination: a verdict should rest on a measured number.
  Rerun (D-164, 0114): the Mac costs 61 - 64 ms per 1000 records (S18 run 8, five
  runs, the tree full in the last two), over the limit of 50; criteria 1, 2, 4, 5
  hold. Per created file it costs less than Arch, where criterion 3 passes: Arch
  reads three inotify records per file (2.87 - 3.15 s per 20000-file burst, 144 - 158
  ms per 1000 files), the Mac one (1.22 - 1.28 s, 61 - 64 ms per 1000 files); 46 filter
  calls of about 27 ms each, no freeze. Options:
  (a) record the Mac's cost, judge Arch only (D-057); D-127 stands. Against: the Mac
  misses criterion 3 as written by about a quarter.
  (e) a task to cut the Mac's cost under 50 ms per 1000 records (profile the
  backend's filter there). Against: session time for a cost already below Arch's per
  change, with no freeze measured.
  (f) restate criterion 3 per created file on both machines. Against: a confirmed
  criterion changed after its numbers are known.
  (c) as before (the owner's report to Emacs). Against: as before.
  Recommendation: (a), with (c) beside it if the owner wants Emacs fixed: budgets bind
  on Arch, and per change the Mac costs less than Arch's passing figure.
- DECIDED D-164 (owner 2026-11-04: "rerun S18"): O-80 (b): S18's `shipped` mode
  rerun on the Mac with Emacs's CPU from `current-cpu-time`. Result above (0114); the
  verdict's Mac half now rests on a measured number. Not taken yet: (a), (c), (e), (f).
- DECIDED D-165 (owner 2026-11-04: "(a), draft (c) report"): O-80 (a): the Mac's S18
  cost (61 - 64 ms per 1000 records) is recorded, not judged (D-057); D-127 stands on
  Arch's PASS. (c): the report to Emacs is drafted
  (`docs/upstream/process-attributes-cpu-time-apple-silicon.md`, reproduction
  `process_attributes_cpu_repro.el`), the owner sends it (H-24). No earlier report
  found; the code came with bug#48548 (2021). Not taken: (e), (f).
- O-79 (RESOLVED 2026-11-04 with D-161: (l) with (p); (s) measured; owner: "O-79 (l),
  ship T-128 with (e). [...] Add (p); (s) realtime protection is disabled for now";
  was REOPENED 2026-11-03 for (f): its premise refuted when T-130 started, see the
  correction below; (e) stands, D-156; was RESOLVED 2026-11-03 with D-156: (e) in
  T-128, (f) as a task; owner: "O-79 combined (e) in T-128, (f) as task"; was
  REOPENED 2026-11-03 by T-129, 0106, as D-155 set; was RESOLVED 2026-11-03 with
  D-155: (a) for T-128 now, (d) beside it;
  owner: "O-79 (a) for T-128 now, (d) alongside"; (c) ruled 2026-11-03, D-154,
  measured the same day (0105); found 2026-11-03 by S20's eglot runs, 0104): a
  checkout while clangd still reparses after the previous one (here the second of
  two checkouts 5 s apart) blocks Emacs 0.36 - 0.98 s in one
  filter call of 39 reverts, about 10 - 25 ms per revert against under 1 ms with
  clangd idle. Without eglot 19 - 36 ms, but that contrast ran with no clangd, so no
  CPU contention: whether the cost is eglot's sends or every revert slowed by a busy
  machine is UNVERIFIED (corrected 2026-11-03; it first read "eglot's didClose and
  didOpen cost"). Suspected: `process-send-string` of a whole file waiting on
  clangd's input pipe.
  Options:
  (a) accept: T-128 as measured. Against: up to about 1 s frozen when a large
  checkout follows another within about a minute, more with more open files.
  (b) T-128 reverts eglot-managed buffers a few per timer step. Against: buffers
  current later than E1's 1.0 s for many files; more code; the chunk size is a guess
  until the mechanism is known.
  (c) measure the mechanism first: time each didOpen's send under contention in
  S20's eglot run, then choose (a) or (b). Against: one more spike step (about
  20 min) before T-128's code.
  Combined: (c), then (b) only if the sends are the cost. Recommendation: (c).
  (c)'s result (0105, S20 RESULTS): during the reparse the writes to clangd are most
  of the block (0.46 - 1.31 s of 0.54 - 1.06 s in `revert-buffer`), and one single
  write stalls 0.26 - 1.04 s; the rest of a revert slows 2 - 4 times (68 - 151 ms
  for 39). With clangd idle the sends take under 1 ms in all. What keeps clangd from
  reading its input is UNVERIFIED (clangd 23.1.1's didClose does not wait for its
  worker). Options revisited:
  (a) accept: T-128 as measured. Against: a freeze of 0.28 - 1.12 s when a checkout
  lands during clangd's reparse (two checkouts within about a minute, a rebase's
  steps), more with more open files.
  (b) revert eglot-managed buffers a few per timer step. Against: one write alone
  stalls up to 1.04 s, so smaller batches likely keep the freeze (UNVERIFIED); buffers
  current later; more code.
  (d) find what keeps clangd from reading: rerun the back-to-back pair with stock
  flags (no `--navigation-from-index --header-flags-from-index`, D-026, D-028) and
  with clangd's `--log=verbose` timestamps around didOpen. Against: more spike time
  (about 30 min); the fix may be a clangd change (patch work, D-069) or none.
  Combined: (a) for T-128 now, (d) beside it, revisited when (d) finds a cause.
  Against: T-128 ships with the freeze known until then. Recommendation: the
  combination: (b)'s premise fails on the split, (a)'s cost is now measured and
  limited to checkouts during a reparse.
  T-129's result (0106, S20 RESULTS): the freeze has two parts. clangd with
  `--header-flags-from-index` (D-028) spends up to about 12 ms per header's didOpen
  on its main thread during the reparse (the includer lookup in its index) and
  reads nothing meanwhile, so Emacs's writes fill the pipe; with stock flags or
  `--navigation-from-index` alone no write stalls (back-to-back 2 blocked 0.104 -
  0.168 s). Emacs then waits in `send_process`, which runs due timers: the
  reverter's queue step (VC and diff-hl, up to 280 ms per run during the reparse)
  and nested timers that send again and stall on the same pipe. The flag also
  doubles the reparse (41 - 48 s against 21 - 22 s). Options after T-129:
  (e) T-128's queue step never runs while the reverter's filter runs (the step arms
  itself again when it finds the filter active). Against: other timers still run
  inside a stalled write (the nested ones, unmeasured without the step); the freeze
  shrinks by the steps only (up to about 0.45 s of 0.6 - 0.75 s here, UNVERIFIED as
  a whole).
  (f) a clangd patch: the includer lookup of `--header-flags-from-index` off the
  main thread (where clangd fetches compile commands for its workers). Against:
  patch work on clangd-index-nav (D-069) and rebuilds on both machines; the lookup
  must still finish before the header's first build.
  (g) drop `--header-flags-from-index`. Against: headers opened first lose their
  includer's flags (D-028's reason: wrong diagnostics and navigation in them).
  Combined: (e) in T-128 now, (f) as a task, the freeze measured again after each.
  Against: two pieces of work; (f) is clangd C++.
  Recommendation: the combination: (e) is small and removes the reverter's own
  share; (f) removes the cause for every eglot write, not only T-128's.
  Correction (2026-11-03, when T-130 started): the includer lookup does not run on
  clangd's main thread. `ASTWorker::update` fetches the compile command, and so
  `IncluderFromIndexCDB::getCompileCommand` and `includerOf`, inside its "Update"
  task on the file's worker thread (clangd 23.1.3 `TUScheduler.cpp:871`); the
  "Compile command ... (index)" lines in the main thread's gaps were other threads'
  logging. What stays measured: with the flag writes stall, without it none, and
  the flag doubles the reparse. Why clangd's main thread stops reading is again
  UNVERIFIED; suspected: the main thread starved of CPU while the heavier header
  builds (the includer's flags pull in deal.II) keep all 11 cores busy for twice as
  long. The stock runs do not rule that out: their back-to-back pair landed in a
  21 - 22 s reparse about 16.5 s in, near its end. So (f) as written cannot be done.
  Options for (f)'s place:
  (h) test CPU contention first: stock flags with the second checkout about 1 s
  after the first (inside the reparse), and the patched flags with clangd's `-j=5`
  (the 5 performance cores, leaving 6). Against: two more spike runs (about 15
  min); still no fix.
  (i) cap clangd's workers in the config's command (`-j`) now. Against: unmeasured;
  a slower reparse and background index on every project.
  (j) no replacement: (e) alone. Against: the nested timers' share of the freeze
  (up to about 0.3 s here) stays.
  Recommendation: (h): (i) and (j) both rest on what (h) measures.
- DECIDED D-157 (owner 2026-11-03: "O-79 (h)"): S20's eglot run tests CPU
  contention before (f)'s place is ruled: stock flags with the second checkout 1 s
  after the first, the patched flags the same as reference, and the patched flags
  with clangd's `-j=5` in the usual back-to-back pair. Not taken yet: (i), (j).
  Result (0107, S20 RESULTS): CPU contention alone does not stall clangd's reading
  (stock flags 1 s into the reparse: no stalled write; patched with `-j=5`: 209 and
  137 ms stalls); output volume does not explain it either (stock writes 6 times
  more). Cause still UNVERIFIED. Options revisited:
  (i) is refuted for this purpose (`-j=5` keeps the stalls).
  (j) (e) alone. Against: the nested timers' share stays (up to about 0.3 s).
  (g) drop `--header-flags-from-index`. Against: headers opened first lose their
  includer's flags (D-028).
  (k) sample clangd's threads during a stall (macOS `sample <pid>`, every thread's
  stack) and decide on what blocks its main thread. Against: one more spike step
  (about 15 min); the answer may need a clangd patch.
  Recommendation: (k): every other option guesses at the cause.
- DECIDED D-158 (owner 2026-11-03: "O-79 (k)"): S20's eglot run samples clangd's
  threads (macOS `sample`) during the back-to-back pair's second checkout, with the
  patched flags and with stock flags as control; O-79 is ruled on where clangd's
  main thread waits. Not taken yet: (g), (j).
  Result (0108, S20 RESULTS): during a sampled 264 ms stall clangd's main thread
  waited for input (`read`, all 831 samples); no garbage collection ran inside a
  stalled send. The freeze was Emacs's own timers, mainly the reverter's queue step
  (up to 501 ms per run during the reparse), run inside a write that met a full
  pipe. With D-156 (e) in the spike the back-to-back pair's second checkout blocks
  0.224 - 0.282 s (before: 0.42 - 1.12 s; stock flags without (e): 0.104 - 0.211 s);
  one 56 KB write still waits 74 - 173 ms with the patched flags, cause UNVERIFIED.
  Options:
  (l) close O-79: T-128 with (e) as ruled, T-130 dropped (clangd is not the cause
  found), the residual accepted. Against: 0.282 s once, over S20's 0.25 s, in the
  back-to-back case at load 7; the residual write's cause stays unknown.
  (m) sample the residual write stall (`sample` with (e) on). Against: one more
  spike step (about 15 min) for at most 0.17 s.
  (g) as before. Against: D-028's flags lost for headers opened first, for about
  0.05 - 0.1 s less freeze in this case.
  Recommendation: (l): (e) removed the part that mattered; the rest is bounded and
  only in a checkout during a reparse.
- DECIDED D-159 (owner 2026-11-03: "O-79 (m)"): S20's eglot run samples clangd's
  threads (macOS `sample`) with D-156 (e) on and the patched flags, during the
  back-to-back pair's second checkout, to place the residual 56 KB write stall.
  Not taken yet: (l), (g).
  Result (0109, S20 RESULTS): during the residual stalls (170, 162 ms) clangd's main
  thread was in `read` in 845 / 845 and 773 / 777 samples. Two readings fit: Emacs's
  `send_process` waits up to 20 ms after each blocked write and is not woken by the
  pipe draining, or clangd's reader waits for a CPU during the reparse. Neither is
  the includer lookup or anything T-128 controls; why stock flags never hit it is
  UNVERIFIED. A second patched clangd (the owner's, on RMO-drafts) ran beside every
  run of the day. Options as before: (l) close O-79 (T-128 with (e), T-130 dropped,
  the residual accepted). Against: the residual (up to about 0.17 s, 0.26 s blocked
  in the back-to-back case) stays unexplained. (g) as before. Against: D-028.
  Recommendation: (l): the remaining stall is outside both T-128 and the clangd
  patches, bounded, and only in a checkout during a reparse.
  Corrected 2026-11-03 (D-160, 0111): the residual stalls of D-158 and D-159 were
  nested filter calls; the pipe held the 56 KB write 10 - 15 ms.
- DECIDED D-160 (owner 2026-11-03: "O-79 - do more research on the leftover write
  stall"): S20's eglot run traces Emacs's side of clangd's input pipe, to split the
  residual stall into time clangd leaves the pipe full and time Emacs waits with room
  in it. `pipetrace.c` (spike code), loaded into the spike's batch Emacs only with
  `DYLD_INSERT_LIBRARIES` (the Mac; both binaries are ad hoc signed, no hardened
  runtime), records each write to a pipe (bytes asked, written or EAGAIN, the pipe's
  fill from `fstat`), each `pselect` while a write waits, and the pipe's fill polled
  about every 0.1 ms until it drains. Runs: the patched flags with D-156 (e) in the
  usual back-to-back pair, stock flags as control. Not taken yet: (l), (g).
  Result (0111, S20 RESULTS): the residual "write stall" was not the pipe. In all six
  runs that showed one (74 - 181 ms; D-158, D-159, D-160) it equals the second filter
  call to within 2 ms: waiting on the full pipe, Emacs read fswatch's next records
  and ran the reverter's filter inside the send. At the pipe the 56 KB write waited
  9.8 - 15.1 ms: clangd took bytes 2.6 - 9.8 ms after the pipe filled, then Emacs
  waited out a fixed 20 ms (Emacs 31.1's `send_process`, not woken by the pipe
  draining) with room in it; two blocked sends per checkout, patched flags only. So
  0105's "one single write stalls 0.26 - 1.04 s", on which D-155 set (b) aside,
  measured nested timers and filter calls, not the pipe. The block (0.21 - 0.29 s,
  once 0.59 s) is the reverts, mostly off the CPU in their file reads (161 - 241 ms
  at 14 - 17 ms of CPU): the first open of a just-checked-out file waits for G DATA's
  on-access scan (an endpoint security client), starved while clangd keeps 7 - 9 of
  11 cores busy. Without clangd, CPU burners alone stretch such opens to up to 0.7 s
  in this repository's tree (idle 0.2 - 0.3 ms); UNVERIFIED with the scan paused.
  clangd's `-j` caps AST builds only; its preambles build unthrottled (about 21
  threads want a CPU with the patched flags, 9 with stock). Arch has no such scan
  (its share UNVERIFIED). Options:
  (l) close O-79: T-128 with (e) as ruled, T-130 dropped, the residual recorded as
  the Mac's on-access scan under clangd's load. Against: 0.21 - 0.29 s (once 0.59 s)
  blocked on the owner's Mac when a checkout lands during a reparse, while G DATA
  scans the trees.
  (s) confirm the scan: the owner pauses G DATA's real-time protection for one run of
  the open test (an H-n, about 5 min). Against: the owner's time; protection off
  briefly.
  (n) exclude the source trees from G DATA's real-time scan (the owner's machine
  setting). Against: no on-access scan there; the setting may be centrally managed;
  the pipe part (20 - 45 ms) stays.
  (p) T-128's filter never runs inside itself: a call that finds it running leaves
  its records to a timer. Against: more code; it splits the block only when a
  second batch arrives during the first (6 of 11 runs with (e); traced 1: 0.29 s
  into about 0.11 and 0.18 s, UNVERIFIED).
  (o) T-128 reverts a few buffers per timer step ((b), its premise corrected).
  Against: buffers current later; one first open under load can still take hundreds
  of ms; more code than (p).
  Combined: (l) with (p) in T-128, (s) beside it, (n) by (s)'s result. Against: the
  block stays on the Mac until the owner acts on (n).
  Recommendation: the combination: what remains is outside Emacs and clangd on this
  Mac; (p) is small and bounds the reverter's own share.
- DECIDED D-161 (owner 2026-11-04: "O-79 (l), ship T-128 with (e). [...] Add (p); (s)
  realtime protection is disabled for now"): O-79 closes with (l). T-128 ships with
  D-156 (e) and with (p): its filter never runs inside itself; a call that finds it
  running leaves its records to a timer. T-130 is dropped. (s) ran with G DATA's
  real-time protection off (the owner, 2026-11-04; 0112): the open test's first
  opens take 0.02 - 0.08 ms in all three places, idle and under CPU burners (with it
  on 0.2 - 5.8 ms idle, up to 0.7 s under load); S20's back-to-back 2 blocks 0.116
  and 0.075 s (on: 0.21 - 0.29 s, once 0.59 s), the reverts' 39 reads 21.7 - 23.6 ms
  (on: 161 - 241 ms) while clangd runs 3 - 8 cores. The scan was the residual. With
  it off clangd published for about 33 s after back-to-back 1, so its pair's second
  checkout landed later in the reparse than with it on (about 5 s). Not taken: (n)
  (moot while protection is off; with it on the measured freeze returns), (o), (g).
  Amends D-153 and D-156.
- DECIDED D-162 (owner 2026-11-04, the session's four questions, each its recommended
  option): T-128's shape.
  (a) Files outside project roots (D-149): `global-auto-revert-mode` covers the file
  buffers the reverter does not (`global-auto-revert-ignore-buffer` set in the
  reverter's buffers), polling every 5 s on the Mac, notifications on Arch (D-147's
  split, from the platform defaults files). Against: a second mechanism beside the
  reverter; a VC refresh per such revert (O-78's cost, rare outside projects); the
  Mac stats each such buffer every 5 s.
  (b) Shown (D-151): `get-buffer-window` with `t`, a live window of any frame,
  visible or not. Against: buffers in iconified or invisible frames pay their refresh
  (about 60 ms each on the Mac).
  (c) The root: project.el's `project-current`, as eglot and its fswatch backend use
  (D-127). Against: a projectile-only project (no VC, a `.projectile` file) counts as
  outside any root, so (a) covers it. Corrected 2026-11-04 (D-163): with
  `projectile-mode` on, `project-current` asks projectile first (`project-projectile`
  in `project-find-functions`, `projectile.el:16955`), so such a project has a root;
  narrowed by D-163 (a).
  (d) Done when: `lisp/emacs-cpp-reverter.el` (NEW, written fresh from S20's
  `fswatch-shown`) runs one patched fswatch per project root while the root has file
  buffers; reverts unedited buffers at once with diff-hl's revert hook held back;
  refreshes VC and diff-hl one shown buffer per timer step, a hidden one when shown
  (D-153); with D-156 (e) and D-161 (p); D-151 (2b) and D-152's messages; magit's
  auto-revert off (D-153); ERT tests in a temporary git repository for each; `make
  test` passes on both machines; S20 gains a `shipped` mode that loads the module and
  passes `fswatch-shown`'s criteria on the Mac (the session) and on Arch (an H-n).
  Against: one more owner item; about 15 min more of the session's time.
  Not taken: nothing outside project roots; visible frames only; projectile's root;
  tests without the shipped run.
  (d)'s "reverts unedited buffers at once" superseded by D-166 - D-168: from a queue,
  in timer steps (0118).
- DECIDED D-163 (owner 2026-11-04, two plan-mode questions, each its recommended
  option): (a) the reverter watches only roots under version control or with a
  `.projectile` file, D-070's rule (`projectile-root-local`, `projectile-root-marked`
  or `projectile-root-bottom-up`); a directory projectile takes for a project by another
  marker (deal.II's install has a `Makefile`) is outside any root and left to
  auto-revert. Against: a project with neither (a plain CMake directory) is polled
  every 5 s on the Mac instead. Not taken: every root `project-current` returns.
  Against it: one fswatch per library tree reached with `M-.`. (b) The reverter is
  opt-out (owner: "Make the reverter configurable (opt-out)"): the user option
  `emacs-cpp-revert-project-buffers`, t by default; nil hands project buffers to
  auto-revert (D-162 (a)'s mechanism); turned off globally from Customize, applied
  at once, or per project in `.dir-locals.el` (a safe local variable). Against:
  O-78's cost returns where it is off (on the Mac a VC refresh per reverted buffer);
  a project's `.dir-locals.el` change reaches its buffers when they are visited
  again. Not taken: nothing in projects when off; a global switch only. Amends
  D-162 (c).
- DECIDED D-166 (owner 2026-11-04: "S20 (a)"): S20 mode `fswatch-shown` FAILS on
  Arch on criterion 3: the session's runs 4 - 6 (load 1.3 - 1.9) blocked Emacs 0.23,
  0.15 and 0.30 s, the one filter call that reverts all 189 buffers 145 - 302 ms; the
  owner's runs 1 - 3 (0110) blocked at most 0.14 s and are kept as evidence, not as a
  verdict. The reverter reverts from a queue, not all in one filter call, and that is
  measured before its code changes. Supersedes 0110's verdict; amends D-153 (reverts
  "at once") and D-162 (d). Premise corrected the same day: (a) was offered as "before
  any T-128 code", but T-128's module had shipped that morning (5316f49), unseen by the
  session; its `shipped` mode on Arch then also blocked 0.25 s (filter 250.6 ms, run 3
  of 3, load 3.1 - 3.4, 0115). How the queue lands in the shipped module: O-81.
  Against: buffers become current later than 0.13 s; another measurement round on
  both machines. Not taken: (b) keep runs 1 - 3's PASS (choosing runs), (c) three more
  idle runs first (more samples, same 0.30 s).
- DECIDED D-181 (owner 2026-11-05: "(a)"; O-87; amends D-180): MacPorts reads the
  local ports from a root-owned copy, `/opt/local/var/macports/sources/emacs-cpp/ports`,
  not from the repository: a `file://` source in a git work tree gets `git pull
  --rebase --autostash` on every `port selfupdate`. The repository's
  `packaging/macports` stays the source of record; the owner reviews it (`diff -r`),
  copies it with `sudo cp -R` (root-owned, no `-p`) and runs `sudo portindex` in the
  copy, all by `make macos-ports` (`scripts/install-macos-ports.sh`: shows the diff or
  the Portfiles, asks, copies, indexes, adds the `sources.conf` line once, installs
  or upgrades each port; H-29). `sources.conf` names
  `file:///opt/local/var/macports/sources/emacs-cpp/ports`
  above the `rsync` line. Against: a copy step per change that can be forgotten (the
  installed version then lags the repository's, `port info ty` shows it); MacPorts
  might one day clean unknown directories under `sources/` (UNVERIFIED; the install
  would then fail on the missing source). Not taken: (b) - (e).
- DECIDED D-180 (owner 2026-11-05: "(d) binary port"; O-86): ty on the Mac comes
  from a local MacPorts port in this repository, `packaging/macports/devel/ty/Portfile`
  (NEW): Astral's release asset `ty-aarch64-apple-darwin.tar.gz` (Developer ID signed,
  hardened runtime), checksums checked against its published `.sha256`, installed to
  `/opt/local/bin/ty`; one distfile directory per version (the asset's name has no
  version). MacPorts finds it by a `file://` line above the `rsync` line in
  `/opt/local/etc/macports/sources.conf` and `portindex` run in `packaging/macports`
  (the owner's, H-29). Where MacPorts reads it: amended by D-181 (a root-owned copy).
  A network call (the asset from GitHub, at install) and a file
  outside the repository (`/opt/local/bin/ty`), both MacPorts'. ruff stays MacPorts'
  own port (D-143). The Mac's Python server stays pyright until T-121 tests ty there
  (D-140 (c)). Against: the owner bumps the version and checksums by hand (ty 0.0.93 -
  0.0.97 in eight days); a binary, not MacPorts' build-from-source convention; arm64
  only. Not taken: (a) the binary in git, (b) a source submodule, (c) a build script.
- DECIDED D-179 (owner 2026-11-05: "Revert the feature and decision that the perf
  impact (4x on large projects) is acceptable"): T-133's kept project file lists and
  their option are reverted (code of d4276bf and 540a0aa); the slower first call
  (deal.II 178 ms against 64, LLVM's sources 1366 ms against 336, RESEARCH 22) is not
  acceptable, so a call may not cost more than today's listing on any tree. projectile
  lists on every `C-c p f` and `M-o` again. O-85 reopened with that constraint.
  Supersedes D-177 and D-178. Against: emacs-cpp's 411 - 493 ms per call and the
  "Projectile is indexing" message stay. S21's harness and findings stay in
  `spikes/s21-projectile-cache/`. POSTMORTEM 2026-11-05.
- SUPERSEDED by D-179 (2026-11-05, reverted): DECIDED D-178 (owner 2026-11-05: "Opt-out
  setting"): the kept project file lists
  (D-177) are opt-out: the user option `emacs-cpp-keep-project-files`, t by default;
  nil has projectile list on every call, as before T-133. Globally from Customize
  (applied at once, the kept lists forgotten) or for one project in its
  `.dir-locals.el`, read for the project's root on each call (`C-c p p` lists
  another project than the current buffer's), safe as a boolean; as D-163 (b) for
  the reverter. Cost: the current call 1.9 -> 2.1 ms (emacs-cpp), 10.2 -> 11.0 ms
  (deal.II). Against: one more option; reading the root's `.dir-locals.el` on every
  call.
- SUPERSEDED by D-179 (2026-11-05, reverted): DECIDED D-177 (owner 2026-11-05: "O-85
  (f)"): the projectile setup keeps each
  root's file list and the modification times of its directories (read before the
  listing) and serves the list while every time is unchanged; one changed time and
  the root is listed anew. No watcher, no tie to the reverter; every root, both
  machines. Measured (RESEARCH_go_to_anything 22): the check 1.0 - 31.6 ms against
  listings of 25 - 493 ms. Against: wraps `projectile-project-files`; the check grows
  with the directories (deal.II 68 -> 32 ms); a `.gitignore` edit that moves no file
  waits for the next change of structure. Not taken: (a) - (e), (g) of O-85. Build:
  T-133, tier 3 (owner 2026-11-05: "Tier 3 with short spike"): spike S21 first; found
  before it, Emacs's lock files change directory times on every edit (RESEARCH 22).
  S21 PASS 2026-11-05 (0126) with `m2`: a changed directory's names read again, Emacs's
  own lock, auto-save and backup names ignored; current call 4.1 ms (emacs-cpp), 27.7 ms
  (deal.II); the plain check failed (60 listings in 60 editing calls). Built (T-133,
  0127): current call 1.9 / 0.4 / 10.2 ms (emacs-cpp / RMO-drafts / deal.II); first
  call 420 / 29 / 190 ms against 444 - 493 / 25 - 50 / 68 - 75 today; remote roots
  listed as before. deal.II's slower first call accepted (owner 2026-11-05), then not
  (D-179); more trees and `M-o` measured (RESEARCH_go_to_anything 22): at LLVM's size
  (16532 directories) a current call is 100 ms, a first call 4 times the old listing.
  Reverted 2026-11-05 (D-179).
- DECIDED D-176 (owner 2026-11-04: "leave reverter filter"): the reverter's filter
  keeps looking each record's buffer up (761 records, about four per file, for a
  190-file checkout: 10 - 11 ms on Arch, 0120); no merge of a call's records per
  path (4.0 ms). Against: the filter does about 2.5 times the lookups it needs, more
  in larger projects (each lookup walks the buffer list). Not taken: the tier 1
  change (a hash of the call's paths before `--handle`). Reason: far under the
  0.25 s limit, and the module passed on both machines as it is (0122, 0123).
- DECIDED D-175 (owner 2026-11-04: "O-84 (a)"): no clangd patch 0014; gapped in-word
  symbol queries (`eto` -> `Vector`) stay unfound, O-68's later stage unscheduled.
  S19 failed on its criterion 6 (0125): the gap tier fills `M-o`'s replies and 16 of
  26 keys on RMO-drafts take more than twice pkgrel 1's time. Supersedes D-171 (not
  built). Against: the case that started O-68 keeps finding nothing in `M-o` and
  `C-c l s`; files and buffers keep D-120's tier 3. Not taken: (b) a capped second
  round, (c) four letters and more. Revisit if clangd's ranking of a third tier at
  the server changes; S19's patch, harness and numbers stay in
  `spikes/s19-gap-trigrams/`.
- DECIDED D-174 (owner 2026-11-04: "RMO-drafts with RMO; O-83 (b)"): S19's criterion
  6 runs on hp-elitedesk with `~/source/repos/RMO-drafts` as RMO. It times each key
  `M-o` sends a symbol request for (every prefix of three or more letters) of S11's
  words (main, vec, Tri, assemble, Sol) and the 12 queries, as the shipped `M-o`
  sends it (limit 10000, `middleMatch` 3, `looseScope`), RMO-drafts' background
  index and deal.II's library index in one clangd; judged: with `gapMatch` each key
  at most twice pkgrel 1's time for the same request and at most 30 ms. RMO-drafts is
  used as a copy in the session's scratch directory with the installed fmt 12.2.0
  (`find_package`) in place of its uninitialised `fmt` submodule: no network, nothing
  written into RMO-drafts. Against: a copy is not the owner's tree in place; "twice"
  is the owner's new number; RMO-drafts' sources stand for RMO (56 files, no
  `class_multilevel_experiment`). Not taken: (a) 30 ms alone, (c) S11's terminal
  prompt. Resolves O-83; amends D-172. Run 2026-11-04 (0125): criterion 6 FAILS (16
  of 26 keys over twice pkgrel 1 with the field), S19 FAIL; next step O-84.
- DECIDED D-173 (owner 2026-11-04: "D-120's rule"): S19's tier 3 is D-120's: the
  query's letters in order, the first anywhere, gaps only over letters and digits
  (across camel-case boundaries, never a separator, D-141), one tier below tier 2.
  Gap trigrams: every in-order letter triple inside one run of letters and digits,
  stored only where the symbol's ordinary trigrams lack it; with the request field a
  query trigram's candidates are its ordinary list or its gap list, intersected over
  the query's trigrams, so tier 1 - 2 matches across separators stay. Counted on
  deal.II 9.8's index here (186162 symbols, `count_trigrams.py`): ordinary 4.53 M
  posting entries, gap lists 11.56 M more (13.32 M as a whole set, x 2.94; section
  20's generator x 3.51, both rules x 4.20, a segment start first x 1.17); `eto`
  31017 candidates. Criterion 1's `cml` half is struck: D-120 does not match it
  (`emacs-cpp-match-tier` gives tier 4). Against: `cml` -> `class_multilevel_experiment`
  stays unfound, as in files; memory near criterion 3's 20 MB (UNVERIFIED until
  built). Not taken: section 20's generator, both combined, a segment start first.
  Amends D-171, D-172.
- DECIDED D-172 (owner 2026-11-04: "All here"): S19 runs on hp-elitedesk (Intel Core
  i5-6500, 4 cores, 15 GB, Arch), the session's machine, not the Xeon W-2145
  workstation section 20 measured on. Network and a file outside the repo: deal.II's
  repository is cloned once from https://github.com/dealii/dealii at tag v9.8.0
  (shallow) into `~/source/repos/dealii`, where `scripts/build-library-index.sh`
  expects it, and `indexes/dealii.dex` built from it. Criteria 4 and 5 become ratios
  of this machine's own pkgrel-1 numbers (the baseline measured first, medians of
  21): 4. `Dex::build` at most 2.31 times the baseline (2.5 / 1.08 s); 5. each of the
  12 queries at most 5 ms times f, f = this machine's sum of the 12 baseline medians /
  6.68 ms (section 20's sum). Criteria 1 (deal.II half), 2 and 3 as confirmed. RMO is
  not on this machine (`RMO-drafts` holds no `class_multilevel_experiment` and no
  compile database), so criterion 1's `cml` half and criterion 6 wait for a machine
  with RMO (an H-n once the patch builds); S19's verdict waits for them. Run
  2026-11-04 (0124): criteria 1 (deal.II), 2 - 5 PASS, 4 only with names cached;
  criterion 6's request is O-83. Against:
  changes owner-confirmed criteria; this machine is not the one D-057's budgets were
  set on; deal.II's index build peaks at about 10 GB on 16 cores (fewer jobs here).
  Not taken: the split (Xeon runs 3 - 6), a session on the Xeon. Amends D-171.
- SUPERSEDED by D-175 (2026-11-04; S19 FAIL, not built): DECIDED D-171 (owner 2026-11-04:
  "O-68 (c)"): clangd gets a third match tier for
  letters in order with gaps inside a word (`eto` -> `Vector`), found through gap
  trigrams, a second trigram kind holding every jump inside a word and to the next
  segment's first letter, intersected in place of the ordinary trigrams only when a
  request field that `workspace/symbol` alone sets asks for it; tier 3 in
  `tieredMatch` ranks below every tier-2 match (RESEARCH_go_to_anything 20). A 14th
  clangd patch (D-069), tier 3: spike S19 passes first; its criteria, proposed in
  T-132, confirmed by the owner 2026-11-04 ("Confirm S19, run on Arch"); it runs on
  Arch (`spikes/s19-gap-trigrams/RUN.md`). Against: the largest clangd patch;
  about 8 - 12 MB more per deal.II-sized index and four times `Dex::build`'s trigram
  work on every rebuild (both UNVERIFIED, S19 measures them); short queries may crowd
  `M-o`'s 10000 with weak gap matches (`get`: 6025 in deal.II). Not taken: (a) full
  scan (up to 52 ms per key with two indexes), (b) a letter mask (up to 17 ms for
  common letters), (d) none. S19 FAIL 2026-11-04 (0124, 0125): criterion 6, the field's
  replies at `M-o`'s limit; O-84.
- DECIDED D-170 (owner 2026-11-04: "O-76 (a)"): no Julia support; D-145's scope stands
  (C++ and Python). Against: Julia files open in fundamental-mode, no highlighting or
  indentation (Emacs has no Julia mode built in). Not taken: (b) julia-mode only,
  (c) LanguageServer.jl, (d) JETLS, (e) julia-snail and eat. `RESEARCH_julia.md`
  keeps the findings.
- DECIDED D-169 (owner 2026-11-04: "(b)"; O-82 (b)): the module's step refreshes a
  queued shown buffer's VC state and marks before the remaining reverts; one timer,
  one kind of work per step (D-168's bound kept), 0.01 s between steps while either
  queue holds a buffer. Done when: `emacs-cpp-reverter-steps` checks the order, `make
  test` passes, and S20 `shipped` passes `fswatch-shown`'s criteria 1 - 6 in three
  runs on each machine (Arch the session's, the Mac an H-n). Measured with the probe
  (0121): shown buffers complete 0.18 - 0.28 s after `git`, Emacs blocked 0.07 -
  0.09 s. Against: hidden buffers' text 0.15 - 0.2 s later; refresh steps 0.01 s
  apart where D-168 had 0.05 s. Amends D-168. Not taken: (a) D-168 unchanged, (c) two
  timers. Built (T-131, 0122): Arch PASS (blocked 0.07 - 0.09 s, shown 0.20 - 0.25 s);
  the Mac PASS (blocked 0.08 - 0.11 s, shown 0.23 - 0.31 s; 0123).
- DECIDED D-168 (session 2026-11-04, within D-167's rewrite; owner confirmed
  2026-11-04 through D-169: "confirm D-168 through D-169"): the
  module's steps from S20 `fswatch-chunked` (0116, 0117) with one change: one timer
  runs both queues and a step does one kind of work, reverts while any are queued,
  else one shown buffer's refresh. The spike ran them on two timers, and both falling
  due in one pass blocked Emacs up to 0.18 s on the Mac. D-161 (p)'s deferred filter
  output goes: the filter only queues (about 1 ms), so no blocking send runs inside
  it; the step's own guard keeps a revert out of another. Measured: S20 `shipped` on
  the Mac blocks 0.07 - 0.13 s (0118). Against: a shown buffer's VC state and marks
  wait for the last revert (0.49 - 0.58 s after `git`, against 0.33 - 0.38 s); not
  measured on Arch yet (H-26; measured 2026-11-04: Arch blocks 0.07 - 0.09 s, shown
  buffers current 0.45 - 0.54 s, 0119). Revisited 2026-11-04: O-82. Not taken: two
  timers with a shared budget (more state, same bound).
- DECIDED D-167 (owner 2026-11-04: "O-81 (b)"): a new S20 mode `fswatch-chunked`
  first: the filter only queues the call's buffers, shown ones first; a timer step
  reverts until a budget per step is spent (`S20_BUDGET`, default 0.05 s) and arms
  itself again; VC and diff-hl for shown buffers as in `fswatch-shown`; the skipped
  buffers' message once the queue is empty. Three runs per machine against
  `fswatch-shown`'s criteria 1 - 6; then `lisp/emacs-cpp-reverter.el` written fresh
  from its numbers, then `shipped` again on both machines. Against: two measurement
  rounds; the Mac's runs the owner's while this session is on Arch; about 1 h of the
  session's work. Not taken: (a) the module changed first, (c) work moved out of
  each revert.
- DECIDED D-154 (owner 2026-11-03: "O-79 (c)"): before T-128's code, S20's eglot run
  times each revert under clangd's reparse, split into eglot's didClose, didOpen (its
  `process-send-string` calls to clangd, their bytes) and the rest of the revert;
  (a) or (b) is then ruled on that split. Not taken yet: (a), (b). Measured 2026-11-03
  (0105): the sends are the cost; O-79's options revisited.
- DECIDED D-155 (owner 2026-11-03: "O-79 (a) for T-128 now, (d) alongside"): T-128 is
  built with eglot's revert hooks as they are, accepting a freeze of 0.28 - 1.12 s
  when a checkout lands during clangd's reparse (0105); T-129 finds what keeps clangd
  from reading its input (stock flags against the patched ones, clangd's verbose log
  around didOpen), and O-79 reopens if it finds a cause T-128 or a clangd patch
  (D-069) can remove. Not taken: (b) (one write alone stalls up to 1.04 s; premise
  refuted 2026-11-03, 0111: that time was nested timers and filter calls, the pipe
  held a write at most about 25 ms). Amended by D-156 after T-129 (0106).
- DECIDED D-156 (owner 2026-11-03: "O-79 combined (e) in T-128, (f) as task"): T-128's
  VC and diff-hl queue step never runs while the reverter's filter runs: a step that
  finds the filter active arms its timer again instead (O-79 (e)). T-130 moves the
  includer lookup of `--header-flags-from-index` (D-028) off clangd's main thread
  (O-79 (f)), a patch to clangd-index-nav (D-069); refuted the same day, the lookup
  already runs on the worker thread (O-79's correction), T-130 blocked. The freeze
  during a reparse is
  measured again after each with S20's eglot run (`eglot-share.sh`, back-to-back
  pair). Not taken: (g) (headers opened first would lose their includer's flags).
  Amends D-155.
- O-78 (RESOLVED 2026-11-03 with D-153: (e); owner: "Rule (e), new S20 mode first";
  was REOPENED 2026-11-02: S20 failed on the Mac, 0102, as D-148 and D-149 set;
  was RESOLVED 2026-10-29 with D-148: (d); owner: "(d) if S20 passes"; found
  2026-10-29 by S20's Mac dry run): T-127 (D-147) stops Emacs for
  seconds after a large checkout. After each revert `auto-revert-handler` runs
  `vc-refresh-state`, one `git` process per buffer (Emacs 31.1 `autorevert.el`); with
  D-147's Mac polling, a checkout changing 190 open files blocked a bare Emacs 5.9 -
  6.5 s in one timer tick, and the buffers were current 10 - 11 s after `git`. Arch's
  notifications run the same handler (UNVERIFIED there; Linux starts processes faster).
  magit's `magit-auto-revert-mode` reverts through the same handler, so a loaded magit
  had this cost before T-127 (UNVERIFIED, read from the source). Options:
  (a) keep T-127 as built. Against: a freeze of several seconds after every large
  checkout on the Mac.
  (b) revert T-127. Against: stale buffers mislead clangd again (the 2026-10-29
  report), and a loaded magit keeps the freeze anyway.
  (c) keep T-127; advice on `auto-revert-handler` defers its `vc-refresh-state` to a
  queue, one buffer per 0.05 s timer step (S20's `fswatch-queued` refresh: blocked at
  most 0.15 - 0.80 s, VC states current 9.5 s after `git`). Against: advice on an
  autorevert internal (a new Emacs may move the call); the mode line's branch lags
  about 10 s after a large checkout; own Lisp and tests (tier 2).
  (d) T-128 sooner: S20's criteria confirmed, its runs, then the reverter replacing
  `global-auto-revert-mode` in projects. Against: tier 3, a new subsystem; files
  outside project roots (library headers) still need auto-revert, so (c)'s problem
  stays for them.
  Combined: (c) now, (d) if S20 passes. Recommendation: (c), then (d) on S20's verdict.
  (Options (a) - (d) superseded 2026-11-02 by the options below; T-127 is out, D-149.)
  Reopened 2026-11-02 (0102); options revisited the same day after follow-up
  measurements on the Mac (`spikes/s20-fswatch-reverter/RESULTS.md`, follow-up). S20
  passes on Arch and fails on the Mac on criterion 3 alone. Premises:
  - The 0.20 - 0.35 s blocks are S20's queue, not slow `git`: inside S20 one wait
    runs 2 - 4 VC timer steps back to back (the repeating 0.05 s timer is due again
    when a 40 ms step ends; why it stacks only there is UNVERIFIED); the runs' 0.35 s
    fits 8. One `vc-refresh-state` (4 `git` commands, each run twice) takes 34 - 95
    ms, as fast right after a checkout as on a quiet tree; no GC in the steps.
  - S20 ran `emacs -Q`; the shipped profile does more per revert. diff-hl runs
    `diff-hl-update` from `after-revert-hook`, synchronously (`diff-hl-update-async`
    nil): 2 `git` processes, 19 ms per revert against 0.6 ms without, so 189 reverts
    in the filter would block about 3.6 s. eglot sends didClose and didOpen per
    revert (Emacs 31.1 `eglot.el`); its cost and clangd's reparse are unmeasured (no
    compile database in the generated repository).
  - `magit-auto-revert-mode` starts on once magit loads (`:init-value` non-nil when
    interactive and `global-auto-revert-mode` is off; the config leaves it) and reverts
    through `auto-revert-handler`, VC refresh included. Read from the source,
    UNVERIFIED live.
  Every option but (i) turns `magit-auto-revert-mode` off and is measured first by a
  new S20 mode with diff-hl loaded (tier 3); eglot's share needs a real project
  (RMO, the owner's). Options:
  (e) shown buffers only: the filter reverts with diff-hl's revert hook held back; a
  buffer shown in a window gets its VC state and diff-hl marks at once, one per
  step, the others when `window-buffer-change-functions` (in Emacs 31.1) shows them:
  1 - 3 steps of about 60 ms on the Mac per checkout instead of 189. Against: holds
  back a vendored package's hook by its function name (`diff-hl-after-revert`); a
  hidden buffer's cached VC state stays stale until shown (UNVERIFIED whether any VC
  command or prompt reads another buffer's); criterion 3's "VC states current within
  15 s" becomes "shown buffers'" (the owner's criteria); eglot's per-revert work
  stays in the filter.
  (f) every buffer through a fixed queue: a one-shot timer re-armed after each step,
  one buffer per step, VC state and diff-hl (about 60 ms on the Mac). Against: Emacs
  busy about two thirds of the time for 15 - 17 s after a 190-file checkout (189 x
  (0.06 + 0.02 - 0.03 s)), criterion 3's 15 s at its edge; about 1900 `git`
  processes per checkout, most for buffers nobody looks at; one step per wait with a
  re-armed timer is UNVERIFIED inside S20.
  (g) asynchronous `git`: VC state from `make-process` output, diff-hl with
  `diff-hl-update-async`. Against: reimplements part of `vc-git`'s state and caches
  (`vc-file-setprop`), which a new Emacs may change; diff-hl's async mode runs `git`
  in a Lisp thread, and whether Emacs reads keys during that thread's `call-process`
  is UNVERIFIED; the most new Lisp.
  (h) raise criterion 3 and build the queue as measured. Against: the blocks come from
  the queue's timer, which (f)'s re-armed timer likely removes (UNVERIFIED); diff-hl's
  3.6 s in the filter fails any limit under seconds.
  (i) drop T-128, no reverter (today's state, D-149). Against: stale buffers mislead
  clangd (the 2026-10-29 report); once magit has loaded, `magit-auto-revert-mode`
  already reverts with a per-buffer VC refresh, O-78's freeze (UNVERIFIED live), so
  (i) alone does not avoid it.
  Combined: (e) for shown buffers and (f) at a slow pace for hidden ones keeps every
  buffer current without blocking. Against: the code of both; (f)'s `git` volume
  stays. Recommendation: (e): 1 - 3 steps per checkout instead of 189 and no `git`
  for buffers nobody looks at; S20's new mode with diff-hl first, eglot's share on
  RMO before T-128 ships; the combination only if a stale hidden buffer shows up.
  (e)'s edge cases ruled 2026-11-03 (D-151): (1a), (2b), (3a); (1b), (3b) recorded;
  deleted files kept and named (D-152).
- O-77 (RESOLVED 2026-10-31 with D-146: (a); owner: "O-77 (a)"; was OPEN, owner
  request 2026-10-31: "Research ast-grep instead of clangd for LSP
  functionality in C/C++"): findings in `RESEARCH_ast_grep.md`. ast-grep is syntax
  only (its FAQ: no scope, no types); `ast-grep lsp` serves rule diagnostics, their
  fixes as code actions and rule notes as hover, nothing else (0.51.0's
  capabilities), and needs an `sgconfig.yml` with rules. tree-sitter-cpp 0.23 leaves
  146 ERROR nodes in deal.II's `tensor.h` around its macros. Packaged: pacman 0.44.1,
  MacPorts 0.51.0. Options:
  (a) none: clangd stays, no ast-grep. Recommended. Against: no structural search or
  rewrite; text search (`M-s r`) and clang's tools (D-094) remain the only routes.
  (b) ast-grep in place of clangd. Against: loses definition, references, rename,
  symbols, hierarchies, completion, types and compiler diagnostics (RESEARCH 3);
  undoes D-001 / D-026 and every patch built on them.
  (c) clangd stays; ast-grep as a structural search / rewrite command into a grep-edit
  list (D-097's shape). Against: a new dependency on both machines (0.44 against 0.51);
  patterns written in tree-sitter's node terms; misses code inside deal.II's macros;
  scope-blind, so not a rename.
  (d) (c) plus `ast-grep scan` rules as a flymake backend (D-143's shape). Against: (c)'s,
  plus per-project rule files to write, overlapping clang-tidy (D-094).
  (e) (d) through rassumfrassum (`rass -- clangd -- ast-grep lsp`, Emacs 31's eglot
  manual). Against: rass is AUR / pip only, outside pacman and MacPorts (D-053); a
  0.3.x relay in front of the patched clangd's navigation path.
- O-76 (RESOLVED 2026-11-04 with D-170: (a); owner: "O-76 (a)"; was OPEN, owner
  request 2026-10-25: "Research julia language server interfacing
  and other functionality"): findings in `RESEARCH_julia.md`. Julia 1.13 is packaged
  on both machines (pacman `julia`, MacPorts `julia`, not installed on the Mac);
  both servers, the debugger and julia-snail's Julia side come from Julia's own
  package manager into `~/.julia` (network, outside the repository). LanguageServer.jl
  is the mature one but broke with each Julia minor release and changed API in 6.0
  (2026-09); JETLS is experimental, Julia 1.12.2 - 1.13 only, with a documented
  memory leak. julia-mode is on NonGNU ELPA; julia-ts-mode and its grammar are not
  packaged (MELPA, AUR). Options:
  (a) none: D-145's scope stands. Against: Julia files get no mode at all (Emacs has
  none built in).
  (b) julia-mode only (one NonGNU ELPA submodule), no server. Against: no
  navigation beyond imenu and `M-s r`; little gained over editing elsewhere.
  (c) (b) plus LanguageServer.jl through eglot, pinned in a server environment the
  config installs on request. Against: first start indexes for minutes; a Julia
  update has broken the pinned server before; a Pkg install is a network call and
  files outside the repository (needs its D-nnn).
  (d) (b) plus JETLS through eglot. Against: experimental, its own docs say not
  production-ready; memory grows per re-analysis; Julia 1.14 unsupported when it
  comes; same Pkg install as (c).
  (e) (b) plus julia-snail and eat (two more submodules; MELPA for snail) for a REPL,
  `# %%` cells, session-based `M-.` and plots, dape debugging from the REPL.
  Against: navigation only for code loaded in the session; a terminal emulator and a
  second completion source next to eglot's if combined with (c) / (d).
  Combined: (b) + (d) + (e) gives the most, also the most moving parts.
  Recommendation: (b), with (d) as a spike before any server is configured
  (tier 3: a real-data path through a server with a known leak), and (e) only if the
  owner runs Julia interactively. Premises from documentation only, UNVERIFIED by
  hand; the first step would be installing MacPorts `julia` on the Mac, a system
  action to agree first.
- O-75 (RESOLVED 2026-10-21 with D-142 and D-143: (b) opt-in, (r2); owner: "O-75 make
  return-type inference opt-in with a per-project .dir-locals.el switch. Draft the
  flymake backend + ruff format changes"; was OPEN, owner request 2026-10-21:
  "Research vendoring ty and patches such that
  type information can be inferred reliably, even without type annotations"; "also do
  a detailed comparison with ruff server"): findings in RESEARCH_python_ty 8, 9. ty
  0.0.89 added return type inference, off by default
  (`analysis.return-type-inference = "always"`, which the config can send as ty's
  `configuration` setting; checked over LSP). On: `ret()` `Literal[1]`, `opt(False)
  .upper()` reported as pyright does; SymPy's first `M-?` 1.79 -> 22.3 s and the
  server 1.15 -> 8.3 GB, `ty check` 2.5 -> 9.2 s with errors 13076 -> 27653;
  theme_setter unchanged. Still pyright's alone: parameter types from defaults (ty's
  rule, specified in its tests), call-site return types, pseudo-generic classes (ty
  issue 833). Vendoring: 7 min 14 s build, 1.2 GB, patches in ty's inference core,
  weekly releases. ruff's server lints, formats and fixes but answers no navigation;
  with ty in one buffer through rass (Emacs 31's eglot lists it first; AUR, pip).
  Options, each with its case against:
  (a) return type inference on for every Python project (one `emacs-cpp-lsp-settings`
  call). Against: large unannotated trees pay (SymPy 12 times the first `M-?`, 7
  times the memory) and get twice the reports, many unchecked.
  (b) (a) with a per-project switch to turn it off (`.dir-locals.el`). Against: one
  more option to know; the owner's large trees need it set.
  (c) vendor ty with patches for the three missing kinds. Against: each is a new
  feature in ty's inference core, the parameter one against ty's specified rule, a
  rebase per weekly release, 7 min and 1.2 GB per build.
  (d) none, as today. Against: unannotated returns stay `Unknown`.
  For ruff: (r1) rass with ty and ruff on Arch; (r2) `ruff check` as a flymake
  backend and `ruff format` on `C-c l f`; (r3) none (cases against in RESEARCH 9).
  Combined: (b) and (r2). Recommended: (b), and (r2), since ruff is in pacman and
  MacPorts. Against the combination: two Python mechanisms to keep, and the flymake
  backend is config code. Owner rules.
- O-5 (RESOLVED 2026-10-08 with D-028 for headers the index knows): cold-header flags
  (DESIGN 7) -> S4, and S6 (ccls) round 3. Owner 2026-10-08: also after `M-.` into a
  project header no open source includes ("rmo/lac.h not found"), not only for headers
  opened first. O-7 is probably the same case. After patch 0004 the `#include` jump
  opened `rmo/option.h` before `main.cc` was parsed: many errors (owner report).
  Cause (TUScheduler): the command is chosen once, at open; the includer cache fills
  only from parsed open files. Fmt toy: 2 errors -> 0 with D-028, by jump and opened
  first. Left: headers no source includes keep the guess.
- O-10 (CLOSED 2026-10-08 with D-026; ccls not adopted, report draft kept): ccls
  0.20250815.1 (Arch build, assertions compiled in)
  aborts intermittently: `query.cc:275 ... DB::applyIndexUpdate ... Assertion 'v >= 0'
  failed` (captured from ccls's stderr, 2026-10-08), about one full `make test` run in
  five, during indexing; coredumpctl lists nine ccls SIGABRTs since 00:54, one inside
  the owner's S6 run window. Not found in ccls's issue tracker. Options: ccls built
  with assertions off (upstream release builds define NDEBUG; the miscount then goes
  unnoticed), automatic restart with a visible warning, upstream report, or back to
  clangd. T-013 waits on branch `t013-ccls-hybrid`; main keeps clangd.
  Owner pointer: ccls issue #197 (2019, same assertion at query.cc:244), fixed then by
  the maintainer (a by-reference loop over `symbol2refcnt`); a further report in
  Dec 2019; ours is in the 2025 release, so likely a remaining cause. Measured
  2026-10-08 (ccls tests of T-013, 15 runs each): default indexer threads 6 failed
  runs and 12 aborts; `index.threads` 1: 0 failed runs, 0 aborts. A race between
  indexer threads; one thread is a workaround, cost: slower first indexing (not yet
  measured on RMO; 110 s with all cores in S6).
  Root cause (2026-10-08): ccls re-indexes all files on
  `workspace/didChangeConfiguration`, which eglot sends at connect; standalone repro
  `docs/upstream/ccls_race_repro.py`: 11/25 aborts with it, 0/25 without, 0/25 with one
  thread. Fix on branch `t013-ccls-hybrid`: ccls gets its own eglot server class and
  is not sent that notification (reduces, does not remove: ccls tests with the fix,
  15 runs, 2 failed runs and 2 aborts vs 6 and 12 before; a second trigger remains,
  index.threads 1 remains the safe setting). Issue draft:
  `docs/upstream/ccls-didChangeConfiguration-race.md`.
- O-11 (RESOLVED 2026-10-08 with D-026, D-027, T-014): clangd answering navigation from
  its index while the file is not parsed yet. Findings in
  `RESEARCH_clangd_index_navigation.md`: the per-file shards already hold every reference
  with its position and a content digest; missing are a by-position lookup, a validity
  check against the digest and a fast path in `ClangdServer::locateSymbolAt` /
  `findReferences` (precedent: `--completion-parse`). An upstream change, a few hundred
  lines plus tests. Implemented locally 2026-10-08 (D-025): `~/source/repos/llvm-clangd`,
  commits 8b73a0490 and 2c0b7bf32 on clangd 23.1.1, hidden flag
  `--navigation-from-index`; a task polls the index while the AST path runs, whichever
  answers first wins. ClangdTests 1409 / 1409 (4 new). Synthetic deal.II project through
  eglot, second session: first `M-.` 6623 ms -> 606 ms, same target. Not covered (AST as
  before): function-local symbols, `auto`, `#include` lines, edited files, the first
  session of a build directory. Spike S8 measures RMO. S8 run 1 (RMO): first `M-.` 9281
  -> 1356 ms, same target; references bug (two symbols recorded at one range, one kept)
  fixed in bd81165ed; afterwards the index answer contains all 15 distinct locations of
  the AST answer plus the call under the cursor. S8 run 2 PASS: first `M-.` 9282 -> 1358
  ms, same target, references contain the system answer. RESOLVED: D-026, D-027, T-014.
  Owner report 2026-10-08 (after installing pkgrel 1): `M-.` on an `#include` line still
  waited; now answered from the shard's include graph (8df32dbe5, patch 0004; synthetic
  project 6226 -> 1 ms). Second report: O-13.
- O-13 (CLOSED 2026-10-08, owner: works with pkgrel 3): on RMO, `M-.` on a name in a
  second file still
  waits for the parse. Not reproduced on the synthetic project (2 ms in a second
  source and in a header). Candidates: the file was indexed with errors, has no
  stored shard, changed since indexing, or the name has no indexed reference (e.g. a
  member through a dependent type). Patch 0004 logs the reason; owner run with
  `CLANGD_FLAGS=--log=verbose`, see TASKS T-014. Owner run 2026-10-08: only the
  `#include` request was logged (answered from the index); the errors seen after it
  were O-5 (D-028). With pkgrel 3 the owner reports `M-.` on a name works; no cause
  beyond the `#include` case was found.
- O-14 (RESOLVED 2026-10-08 with D-030; printers: D-032, option off): which gdb
  setup T-006 ships: full symbols at start
  (17 s to the first stop on RMO, deal.II code steppable) or on demand (2.3 s, deal.II
  symbols loaded when needed); and whether deal.II's printers are loaded from the
  owner's deal.II checkout. Owner rules before T-006's done-when.
- O-15 (RESOLVED 2026-10-08 with D-037): D-004 keeps the debugger keys on dape's prefix
  and its repeat map, but a repeat map works only with `repeat-mode`, which is off. Turning
  it on also enables Emacs's other repeat maps (`C-x o o`, `C-x u u`, `C-x { {`). Until
  ruled, every step is `C-x C-a n` again. Owner rules: `repeat-mode` on, or not.
- O-16 (RESOLVED 2026-10-08 with D-034): visual hints for key sequences (`C-c p p`;
  compare org's dispatchers). Proposed: built-in `which-key-mode`, `C-h` after a prefix
  kept, projectile's transient on `C-c p m` documented (RESEARCH_keys_build_debug_ui 1).
- O-17 (RESOLVED 2026-10-08 with D-035): `C-c p c c` runs `cmake --build build` in the
  root, which RMO's preset layout cannot build; CLion builds from any buffer. Proposed
  for T-005: projectile's cmake commands use the active preset's build directory
  (RESEARCH_keys_build_debug_ui 2). Not `C-x C-a b`, which toggles a breakpoint.
- O-18 (RESOLVED 2026-10-08 with D-036): breakpoint indicators. dape draws a fringe
  circle (GUI) or "B" (terminal) in the keyword colour; gutter clicks need
  `dape-breakpoint-global-mode` (off); the stopped line is not highlighted. Proposed:
  that mode on, red breakpoints, highlighted stop line (RESEARCH_keys_build_debug_ui 3).
- O-21 (RESOLVED 2026-10-08 with D-046, D-047; S9 run 3, T-019): a header opened first
  right after a restart (`iteration.h` from `C-x C-r`) gets the guessed flags and "too
  many errors"; opening another file first, then the header, is fine.
  `staging/test/lumping.cc` includes it and is in the database, so the index knows an
  includer. Cause found by reading clangd (D-028, patch 0005): the header's command is
  asked for before the project is handed to the background index. The compile database
  announces a newly found project on its own broadcast thread (`BroadcastThread`), which
  calls `BackgroundIndex::enqueue`, where the load counter rises; `includerOf` waits only
  while that counter is above 0, so it sees 0, does not wait and finds no includer.
  Proposed patch 0006: in `IncluderFromIndexCDB`, first `blockUntilIdle` on the database
  (the broadcast has run, the load is counted), then wait for the load, both within the
  same 5 s. Owner ruled spike first (S9, tier 3). S9 dry run (toy shaped like RMO): 1 of
  5 header-first sessions got the guess (5 errors), its decision in the same millisecond
  as "Enqueueing"; source first always from the index. S9 run 1 on RMO PASS, hypothesis
  confirmed (0027): header first 10 / 10 guessed (`fmt/src/os.cc`, 21 errors), decision
  at or 1 ms before "Enqueueing"; source first 10 / 10 from `staging/test/lumping.cc`, 0
  errors; loading the 3950 stored shards takes 0.4 s, so the 5 s cap is not involved.
  Patch 0006 (D-046, T-019) built and tested locally; left: pkgrel 4 installed and S9
  rerun on RMO (owner).
- O-24 (b) data (T-027, 2026-10-09): Mac startup median 0.852 s against the 0.5 s
  budget (Arch 0.151 s); first `M-.` from the index 2.6 s (Arch 1.4 s). If the budgets
  bind on the Mac, startup needs work there first (antivirus and native-code loading
  are the suspects, not measured). 2026-10-13 (O-36): on the Mac, reading every file
  of deal.II (33768) one at a time took 480 s, `stat` on each 0.2 s: about 14 ms per
  file opened, page cache or not, which points at a scanner checking each open.
  The owner added exceptions to the GDATA scanner the same day: 5.2 s for all
  33768 files (0.15 ms each), `rg` over the tree 5.6 -> 1.07 s. Startup not
  measured again. Later the same day (O-41): loading native code (`.eln`) costs about
  15 ms per file here against about 1 ms for byte-code; the config loaded in batch
  1.37 - 1.71 s native, 0.40 - 0.42 s byte-code, a likely part of the Mac's startup.
- O-37 (RESOLVED 2026-10-13 with D-082: (a) with no limit, `l` for all symbols;
  owner 2026-10-13: "research first"): symbols of the project only in
  `C-c l s` and `M-o` `<` `s` (today every symbol of clangd's index, deal.II's and the
  standard library's too). Options: (a) a larger `limit` per request (clangd
  extension, no patch) and a filter by project root in Emacs, a key showing library
  symbols too (CLion's "Include non-project items"); (b) clangd patch 0010 filtering
  or ranking by workspace root. Findings: `RESEARCH_go_to_anything.md` 10. S11 run 5
  (T-059, owner's deal.II project `step-1`, Mac, 40 queries): filtering today's 100
  loses project symbols in 14 queries (373 symbols), 1000 in 2 (30), no limit in
  none, slowest reply 15.9 ms (2458 symbols), median 0.3 ms. To the owner.
- O-50 (RESOLVED 2026-10-15 with D-114: (c), patch 0010 with T-104; S13 criteria
  confirmed; found 2026-10-14 in S12, finding 6): in a project under `/tmp` on
  macOS the index loses every cross-file reference (3 instead of 201), with the
  patched and the stock clangd 23.1.3 alike: CMake writes `/tmp/...` into the compile
  database, Emacs opens the true name `/private/tmp/...`. Owner 2026-10-14: research
  this and the other platform differences (file watches among them) in one
  RESEARCH document superseding `RESEARCH_file_watches_macos.md`. Findings in
  `RESEARCH_platform_differences.md` 2: clangd's background index drops each TU's
  main-file symbols and references when the database's spelling of a file differs
  from its real path (any symlink; upstream clangd/clangd#503, open since 2020);
  CMake 3.31 always writes `/tmp`, CMake 4 and Emacs keep `$PWD`'s spelling, eglot
  sends true names; a database rewritten to real paths restores every reference,
  `--path-mappings` does not. Options (2.5): (a) warn loudly at eglot's start; (b)
  hand clangd a real-path copy of the database; (c) clangd patch 0010, spike first;
  (d) document, maybe `find-file-visit-truename`; (e) report on #503 (owner). Arch
  (owner's run of 2.6, 2026-10-14): 3 results (`src/combine.cpp`,
  `include/calc/api.h`), the same loss. Owner 2026-10-14: research (c); findings in
  2.8: the background index asks for each command by the database's spelling, so the
  include graph names the main file that way while the symbol collector names its
  symbols by the real path, and the main file's real-path shard is never stored. A
  patch 0010 in `index/Background.cpp` only: real paths for the index's translation
  units (one lookup per directory), `Cmd->Filename` set to the requested path; one
  re-index per project after the update. Tier 3, spike first. Owner 2026-10-14:
  "spike for (c)": S13 (T-077, `spikes/s13-symlinked-paths`, 0069), PASS on Arch:
  through a symlink 201 references in 26 files (without the patch 3 in 2), restarts
  index nothing, a header opened first keeps its includer's flags; one re-index from
  unpatched shards. Left: the owner confirms the criteria and runs criterion 5
  (macOS under `/tmp`); then patch 0010 written fresh (tier 3). Owner rules.
  Revisited 2026-10-15 (owner request): unchanged since 2026-10-14; still left: the
  criteria confirmed and criterion 5. Criterion 5 runs on S12's generated project,
  not the owner's data, so it can run here; it needs S13's patch built on the Mac
  (S13's `build.sh` is Arch-only; S14's clone-and-build on the Mac tree serves,
  about 25 minutes), then `S13_BUILD=/tmp/s13 bash spikes/s13-symlinked-paths/run.sh`.
  Recommended: run it now, then write 0010 with T-104's 0011 / 0012, one pkgrel
  and one Mac rebuild for all three. Owner 2026-10-15: "Run criterion 5 now": PASS
  (`spikes/s13-symlinked-paths/RESULTS.md`): under `/tmp` on the Mac the baseline
  gives 3 references in 2 files for both projects (CMake 3.31 writes `/tmp` for the
  real one too), the patched build 201 in 26 in all three runs; restarts index
  nothing; a header first takes its includer's command. Left: the owner confirms
  S13's criteria and rules patch 0010 (option (c)).
- O-51 (RESOLVED 2026-10-14 with D-101: option (a), buffers too; found 2026-10-14,
  owner: "verify region/buffer formatting for LaTeX documents"): `C-c l f`
  (`eglot-format`) formats a whole LaTeX buffer through texlab (latexindent 4.0 on the
  Mac: environment bodies indented by one tab), but refuses a region: texlab 5.25.1
  announces no `documentRangeFormattingProvider` ("[eglot] Unsupported or ignored LSP
  capability ':documentRangeFormattingProvider'"). AUCTeX's `indent-region` (`C-M-\`)
  indents by other rules (spaces; `\item` at the environment's column,
  `LaTeX-item-indent` -2), so region and buffer disagree. Checked in batch with the
  shipped config, real texlab, a git project. Options: (a) a region through latexindent
  itself (`--lines MIN-MAX`); (b) region by AUCTeX, its variables set to latexindent's
  defaults; (c) document the gap. Owner rules.
- O-52 (RESOLVED 2026-10-13 with D-082 through O-37: no patch; owner request
  2026-10-12, T-075, `RESEARCH_go_to_anything.md` 13): `M-o`
  symbols only from the project's files, all symbols behind narrow key `a`, filtered
  in clangd. A filter after the index sees only its top `limit` (100), which library
  symbols can fill; Dex's path lists stop 4 directories above a file; excluding at
  indexing breaks `M-.` into libraries (D-026 .. D-028). Options: (a) no patch, Emacs
  asks for `limit` 1000 and filters; (b) clangd patch 0010, a request field of
  directories, symbols outside skipped while scoring in `Dex` and `MemIndex`, `Dex`'s
  cap off while set; (c) as (b), a list per directory set built in `Dex` and
  intersected; tier 3, spike first. Also open: definition or declaration decides;
  build directory; `C-c l s`.
- O-53 (RESOLVED 2026-10-14 with D-103: (a), (b), (d); found 2026-10-14, owner: "revisit
  the errors with texlab that led to problems with region/buffer formatting"). texlab
  5.25.1 (Mac; source read at tag v5.25.1 and v5.26.0, events logged with the shipped
  config):
  (1) no range formatting in either version (`documentFormattingProvider` only), the
  cause of O-51.
  (2) texlab runs `latexindent --local file.tex` (copy in a temporary directory) from
  the nearest directory upward with `.latexmkrc` / `latexmkrc` / `.texlabroot` /
  `texlabroot`, else the document's (5.26.0: texlab's own working directory), so a
  project's `.latexindent.yaml` applies. D-101's call passes no `--local`: with
  `defaultIndent: "  "` in the project texlab indents two spaces, `C-c l f` a tab.
  A defect in D-101 as built.
  (3) the request's `insertSpaces` / `tabSize` are ignored for LaTeX (only texlab's own
  BibTeX formatter reads them): eglot sent `insertSpaces: true`, texlab answered with
  tabs (latexindent's `defaultIndent`), while AUCTeX's `TAB` indents with spaces; so
  one file gets both. D-101 inherits this.
  (4) texlab drops latexindent's stderr and returns no edits on any failure,
  latexindent missing included: a silent no-op. D-101 already fails loudly.
  (5) not formatting: within about 1 s of opening a document texlab delays `exit`
  until its "Parsing Dependencies" job ends (up to 0.4 s measured), past jsonrpc's
  0.3 s grace, so eglot kills it: "Sentinel ... still hasn't run, deleting it!",
  "Server exited with status 9". Harmless (closing a LaTeX buffer at once).
  Options: (2) (a) `--local`, run from texlab's directory (5.25.1 rule); (3) (b)
  without a project yaml pass `-y=defaultIndent:` with `LaTeX-indent-level` spaces
  (tab when `indent-tabs-mode`), (c) leave latexindent's tab; (5) (d) nothing, (e)
  report upstream (owner). Owner rules.
- O-54 (RESOLVED 2026-10-14 with D-104, (b); from POSTMORTEM, "Tests wrote into the
  owner's ~/.emacs.d"): `make test` appended its temporary projects to
  `~/.emacs.d/projects.eld` (fixed in 7416ce8), the second isolation leak after the tmux
  one (2026-10-07). Proposed: the suite records the real `~/.emacs.d`'s file list, sizes
  and times before the run and fails when they changed after it. Options: (a) that check
  in `make test`; (b) run the tests with `HOME` set to a temporary directory; (c)
  neither. Owner rules.
- O-55 (RESOLVED 2026-10-15 with D-105: (a) + (b); the extra symbol matches CLion makes
  researched as O-57; owner request 2026-10-15, T-081): fuzzy matching in `M-o` and
  `C-c l s` (`RESEARCH_go_to_anything.md` 14). Found: `M-o`'s buffers and files match by
  consult's regexps, case sensitive, no orderless; symbols by clangd's segment-wise fuzzy
  matcher, from the third character, no spaces; both prompts re-sort clangd's reply by a
  score without the name match (toy: `count` below `count_vertices_globally`). Options:
  (a) keep clangd's order, (b) ignore case in `M-o`, (c) orderless for `M-o`'s static
  sources, (d) initials / flex, (e) several words to clangd, (f) two-letter symbol input.
  Owner rules.
  Compared with CLion 2026.2 (2026-10-15, T-083, `RESEARCH_go_to_anything.md` 15,
  from IntelliJ's sources, not typed into CLion): case ignored, lower-case humps
  from the first letter, a space as an in-order wildcard, exact name first. Closest
  to it: (a), (b), (e) joined, (f); (c) and (d) do not give humps; new (g) one typo
  (IntelliJ's `TypoTolerantMatcher`, use in CLion's popups not confirmed). Owner's
  hand check in CLion 2026-10-15 (eight inputs, same section): Go to Symbol and
  clangd agree on five; CLion alone matches mid-word (`ector`, 3+ characters), a
  lower-case letter inside a word after a gap (`cml` in `class_multilevel_...`) and
  a loose qualifier (`geom::vec`); `count() const` first in both, re-sorted away
  here; no typo seen. Search Everywhere's files: case ignored, humps, space in
  order.
- O-74 (RESOLVED 2026-10-21 with D-134: none of (a) - (c), `lisp/` stays interpreted;
  owner: "O-74 keep current interp"; was OPEN, 2026-10-21, S17 run 2 / 3, T-113; D-125):
  how `lisp/`'s modules get init.el's use-package settings when they are compiled. Emacs's
  JIT compiles each `.eln` in its own Emacs, which never runs init.el, so
  `use-package-always-defer` is nil there and every deferred package loads at start (+222
  ms on Arch, magit and about 100 features; `spikes/s17-compiled-lisp/RESULTS.md`). With
  the two settings set at compile time in each module the start is 5 ms faster than
  interpreted. Options, each with its case against:
  (a) one file `lisp/emacs-cpp-use-package.el` (NEW) sets both settings inside
  `eval-and-compile`; init.el requires it in place of its `setq` (init.el:32-33), and
  each module starts with `(eval-when-compile (require 'emacs-cpp-use-package))`, with
  a test that every module has the line. Against: one line in 19 modules; a new module
  without it compiles wrong without a word, which only the test catches.
  (b) `native-comp-async-env-modifier-form` in early-init.el sets the two settings in
  every JIT worker. Against: it applies to every file the JIT compiles, the vendored
  packages too (any that uses use-package then expands differently, UNVERIFIED how
  many); the settings then live in three places (init.el, the build's prelude, the
  worker form).
  (c) native-compile `lisp/` ahead of time in `make packages` with the build's
  prelude, and keep the JIT off for `lisp/` (`native-comp-jit-compilation-deny-list`).
  Against: the largest build change; a module edited after `make packages` has a
  stale `.eln`, which D-128's recompile (bytecode) does not cover.
  Combined: (a) with the build's prelude reduced to the same `require`, so the settings
  exist once. Recommended: the combined (a). Owner rules.
  (a)'s case against, revisited 2026-10-21 (owner: "can the Against be addressed?"):
  the silent failure can be made loud by behaviour, not by looking for the line: a
  test loads each module's source in a fresh `emacs -Q --batch` (the JIT worker's
  conditions: no init.el, use-package's settings nil) and compares the features it
  brings with the same load under init.el's settings; a module without the line
  differs and the test names it and the packages it pulled in. Measured on copies:
  `init-git.el` without the line 114 features more with magit, with it 4;
  `init-completion.el` 25 against 22 (UNVERIFIED which 3). This also catches any other
  compile-time setting a module comes to depend on. Left against (a): the one line in
  each of 19 modules, and a module the test does not load (none today: it takes every
  `lisp/*.el`).
  Worth it? (S17 run 4, 2026-10-21, owner: "do more thorough benchmarks"): compiling
  today's code saves 10 % of the tier sort (149 -> 134 ms on 12344 deal.II names),
  7 ms per `M-o` symbol reply, 5 ms of startup and nothing in indentation (treesit's
  own time). It pays through D-124 only: its function sorts the same set in 41 ms
  native (S16), so a keystroke in a deal.II-sized file prompt drops from about 240 to
  about 132 ms; interpreted that function is slower than today (309 ms). So (a) is
  worth its cost only together with D-124; without D-124, leaving `lisp/` interpreted
  loses little.
- O-73 (RESOLVED 2026-10-21 with D-131: (a); owner: "O-73 (a), with proper user
  diagnostics"; was OPEN, owner 2026-10-21: "research patch clangd for waiting for library
  index, and possible downsides"; D-130, T-117): the first `M-.` after opening gives the
  declaration while the library index loads (`RESEARCH_library_sources_index.md` 7).
  clangd loads an `--index-file` index only on the first query, in 1.1 - 1.3 s; patch
  0002's shard path answers in 0.95 s, before it. Options, each with its case against:
  (a) no patch: the config sends one `workspace/symbol` when clangd connects, which
  starts the load. Against: relies on clangd's lazy load (an implementation detail);
  the shard path still answers wrong within about 1.2 s of connecting.
  (b) patch: load the `--index-file` index at clangd's start. Against: the same 1.2 s
  window as (a), and one patch more to carry across LLVM updates (D-123).
  (c) patch: 0002's poll waits, up to its 5 s, while an external index is still
  loading, for an answer with a definition. Against: the most code in the patches
  rebased most often (0001 - 0004), a loaded-or-failed signal clangd lacks, a worker
  thread held while waiting.
  Combined: (a) + (c) closes the window with the wait under 0.3 s in practice.
  Recommended: (a) with D-130's code, since a person reaches the window only by `M-.`
  within a second of opening the first file; (c) only if the owner's hand check hits
  it. Owner rules.
- O-72 (RESOLVED 2026-10-21 with D-132: (a); owner: "O-72 pyright, until ty can check
  unannotated code"; was OPEN, owner 2026-10-20: "Research migration from pyright to ty,
  installed as extra/ty on Arch, macos installation unknown/deferred"; D-045, T-025):
  pyright or ty for Python (`RESEARCH_python_ty.md`). Measured on Arch: ty 0.0.90 answers
  every request the config uses, about six times faster to the first diagnostics, fills
  `workspace/symbol` where pyright returns nothing yet, survives a refused watch
  registration (pyright stops answering), no MacPorts port found. Options, each with its
  case against:
  (a) keep pyright everywhere. Against: the watch advice and its pyright tests stay
  for a server that exits on a refusal; `M-o` symbols stay empty early in Python
  projects.
  (b) ty on Arch, pyright on the Mac (per platform, D-055's defaults files). Against:
  two servers to keep working, the Python tests run a different server per machine;
  ty is a 0.0.x beta, its rules change between releases; on argparse.py it reports 7
  errors to pyright's 15 (RESEARCH_python_ty 4a: 5 shared, 2 from rules ty has off
  by default, 8 from pyright's inference of unannotated code; 2 ty alone).
  (c) ty everywhere, installed on the Mac outside MacPorts. Against: needs a ruling
  against D-053 (MacPorts only), the owner deferred the Mac.
  Combined: (b) now, with (c) or (a) on the Mac once a port exists or the owner rules
  the Mac. Recommended: (b), after a hand check on one real Python project of the
  owner's (RESEARCH_python_ty 6). Owner rules.
  Measured 2026-10-21 (owner: "Verify performance of M-. and M-? with pyright vs.
  ty", RESEARCH_python_ty 4b): ty's first `M-.` 20 - 72 ms against pyright's 300 -
  617 ms; on SymPy (5600 references) ty's `M-?` 1.7 - 1.9 s cold and 82 ms warm in the
  server against 9 s and 1.09 s, half the memory; through eglot about 2.9 s of a warm
  `M-?` there is eglot's own; pyright's first `M-?` through eglot was incomplete (358
  of 5631) in all three runs, cause UNVERIFIED. Owner ruled D-140 (b) the same day.
- O-71 (RESOLVED 2026-10-20 with D-128: (c); owner: "O-71 (c) agree"; D-125,
  2026-10-20; revisited the same day, owner: "Revisit O-70 and O-71"): a `lisp/*.elc`
  older than its `.el` after an edit loads without a word
  (`load-prefer-newer` is set nowhere here). It matters only once D-125 compiles
  `lisp/`, which waits on S17 (native modules load magit at startup). Options, each
  with its case against:
  (a) startup refuses with "run make packages" naming the stale modules. Against: one
  command after every edit of a module, which the owner edits daily.
  (b) `load-prefer-newer` t plus a warning naming the stale modules. Against: the
  source runs interpreted, slower without anyone noticing (D-124's function is 1.3 -
  1.9 times the regexps' time interpreted, S16), and the warning repeats every start.
  (c) at startup, before the `require`s, byte-compile each stale module (warnings as
  errors, as the build), then load it. Against: an interactive start writes `.elc`
  files into the repository; the first start after an edit pays the compile
  (UNVERIFIED: about 40 ms per module, the review's 0.57 s for 15); compiling loads
  the module's `require`s early, which init.el's order (D-098) makes harmless but S17
  has not checked (UNVERIFIED); a warning a new Emacs release adds stops startup.
  Combined: (c), and where (c) fails the compiler's message stops startup as (a)
  would. Recommended: the combined (c), checked in S17 run 2 (a stale module
  recompiled at startup: time, features loaded). Owner rules.
- O-70 (RESOLVED 2026-10-20 with D-127: (b); owner: "O-70 (b) agree"; 0084 review:B-2,
  2026-10-20; revisited the same day, owner: "on both Mac
  and Arch, watches should work on very large projects, which was the initial point of
  fswatch"): the goal is a project tree of LLVM's size (about 17000 directories,
  187000 files) watched for the servers that ask (pyright, texlab), on both machines.
  Premises, checked 2026-10-20:
  - Mac: kqueue, one descriptor per watched directory, 975 per Emacs at most
    (RESEARCH_platform_differences 3.1, measured); the config caps eglot at 500
    (`lisp/init-lsp.el:59`) and the advice keeps partial watches past it
    (`lisp/emacs-cpp-eglot-watch.el:148-152`): a large tree is watched in part.
  - Arch: inotify; eglot's cap is its default 10000, and past it the built-in eglot
    fails the whole registration and pyright exits (3.3, 3.14), so an LLVM-sized tree
    loses pyright today; the kernel's `fs.inotify.max_user_watches` is about 318000 at
    32 GB by the kernel's formula (the owner's value UNVERIFIED); a burst while Emacs
    is busy can overflow the kernel queue (16384 events) and drop changes unnoticed
    (3.14; how Emacs's `inotify.c` reports `IN_Q_OVERFLOW` UNVERIFIED).
  - fswatch: FSEvents needs 8 descriptors for LLVM's checkout (3.12); patch 0001's
    writer thread and queue (all platforms) drain the monitor while the reader
    pauses; fswatch's inotify monitor reports `IN_Q_OVERFLOW`
    (`libfswatch/c++/inotify_monitor.cpp:443`, 1.22.0) and watches directories
    created later (`:369`); 0002 / 0003 are FSEvents only.
  Options, each with its case against:
  (a) `file-notify` on both: on Arch the advice too (partial watches instead of a
  failed registration) and the cap from the kernel's limit (half of
  `max_user_watches`, O-64 (b)). Against: the Mac stays at kqueue's 975, so the goal
  fails there; Arch keeps the unnoticed overflow loss.
  (b) an fswatch backend on both: config Lisp over the built-in eglot (overriding
  `eglot--watch-globs` per server and project root, as `emacs-cpp-eglot-watch.el`
  does today), the patched fswatch of `packaging/fswatch-no-loss` on both (the Arch
  PKGBUILD and `build-macos.sh` exist). Against: one more eglot internal under the
  version pin, re-read at every Emacs release (review:B-6's cost grows); a patched C++
  program built and kept on two platforms (D-109's cost stays); Emacs's share was 3.7 -
  4.1 s of CPU per 20000 records with the prototype (3.12) until glob matching is one
  regexp per pattern; real paths mapped back (O-50); on Arch fswatch still takes one
  inotify watch per directory from the same per-user pool: eglot's cap goes, the
  kernel's stays.
  (c) (b) on the Mac, (a) on Arch. Against: two mechanisms to test and keep; Arch keeps
  the overflow loss and still needs the kernel-limit reading.
  (d) Watchman on both. Against: a daemon of about 100 MB at LLVM's size, a crawl at
  first watch, cookie files written into the project root, AUR only on Arch (a
  dependency outside Arch's repositories).
  Combined: (b) is the union of what each machine needs (FSEvents on the Mac, the
  no-loss queue on both), so no further combination. Recommended: (b), tier 3, spike
  S18 first on both machines: a generated LLVM-sized tree (3.12's recipe), pyright on
  it, a burst of 20000 changes while Emacs is blocked for 5 s, every change reaching
  `workspace/didChangeWatchedFiles`, Emacs's CPU per 1000 records, startup unchanged;
  then DESIGN 7.1 rewritten for the built-in eglot. `packaging/fswatch-no-loss` stays
  in main meanwhile (the review's "park it" withdrawn with the owner's goal). Owner
  rules.
- O-69 (RESOLVED 2026-10-20 with D-121: (c) + (d); owner 2026-10-20: "how the fork
  on eglot may be dropped"): the vendored eglot
  (D-108) carries patches 0001 / 0002 for file watches, needed on macOS for pyright
  and texlab (clangd registers no watches), and 0003 only because the vendored
  devel eglot needs Emacs master's xref (`RESEARCH_eglot_fork.md`). pyright does not
  watch files itself when the client offers no watching (pyright 1.1.412: outside
  changes missed). Upstream master equals the pin; nothing reported yet (T-032).
  Options: (a) upstream first (send T-032 with 0001, 0002 as a suggestion, and the
  devel regression of 0003), then an unpatched ELPA release or a later Emacs's
  built-in eglot; (b) the built-in eglot now on both machines (Arch unaffected; on
  the Mac pyright exits for trees over about 166 directories, or loses outside
  changes with watching off); (c) built-in on Arch, vendored on the Mac; (d) the
  fixes as Lisp in the config (about 100 lines on eglot's internals, against D-069);
  (e) keep the fork on ELPA's 1.24 release instead of devel, dropping 0003.
  Recommendation (a); (e) meanwhile if the release commit is easy to pin.
- O-68 (RESOLVED 2026-11-04 with D-171: (c), behind spike S19; owner: "O-68 (c)";
  owner 2026-10-20, after `eto` found no `Vector`: "Go with LSP 3.18 as far as
  possible--in particular the consistent config--but leave changing the three-letter
  pre-filter for a later stage"): clangd's index keeps only symbols containing the
  query's three-letter fragments, and its matcher wants the first letter at a word
  start, so letters in order with a gap inside a word (`eto` -> `Vector`) never reach
  the ranking. Later stage: a clangd change past the pre-filter (a third tier, tier
  3, a spike on RMO first: scan time, reply sizes). Not scheduled.
  Reviewed 2026-10-21 (owner request): still later, not scheduled. Against waiting:
  gapped in-word queries (`eto`) keep finding nothing.
  Researched 2026-10-21 (owner: "research patches for O-68 and possible performance
  implications", RESEARCH_go_to_anything 20): every way needs a third tier in
  `tieredMatch` and a request field only `workspace/symbol` sets. Options: (a) full
  scan, 15 - 26 ms per key per index of deal.II's size (128391 symbols) on Arch,
  against today's 0.02 - 1.8 ms; (b) a letter mask per symbol, 0.3 - 17 ms, 1 MB
  per index; (c) gap trigrams, a second trigram kind: posting entries x 4.0 (2.53 ->
  10.17 million), about 8 - 12 MB more per index and four times the trigram work in
  `Dex::build` (UNVERIFIED, not built), queries at today's cost (UNVERIFIED); (d)
  none. Recommendation: (c), behind spike S19 (tier 3): Dex memory, build time and
  query times with gap trigrams on RMO's and deal.II's indexes, and `M-o`'s replies.
  Against (c): the largest patch (a 14th clangd patch), memory and build time on
  every index, completion's untouched only through the field. Against (a): up to
  52 ms per key with two indexes, past S11's 2 - 30 ms. Against (b): 17 ms for
  common letters, a table kept beside each index. Against (d): the misses stay.
  Owner rules.
- O-67 (RESOLVED 2026-10-19 with D-119: (a); owner 2026-10-19: "Research preferring
  mid-word matches"): clangd ranks a
  mid-word match after every fuzzy one (patch 0012), and mid-word matches tie
  among themselves; scattered fuzzy matches such as Kokkos's
  `EBOBaseImpl<..., CtorNotOnDevice>` (`E` + `Ctor` for `ector`) head the list and
  the project's `Vector` falls outside `C-c l s`'s 100
  (`RESEARCH_go_to_anything.md` 19). Options: (a) clangd patch 0013, rule R4: a
  fuzzy match contiguous from a word start keeps its place; scattered fuzzy and
  mid-word matches rank together by how much of the name they cover (doubled at
  a word end) times quality; behind a request field; both prompts; tier 3, a
  spike on step-1 first (replies and times for mid-word and fuzzy queries against
  pkgrel 8), pkgrel 9 and a Mac rebuild. (b) R4 in Emacs: `M-o` re-sorts what it
  receives; `C-c l s` sends a limit and re-sorts too (consult-eglot patch 0001
  grows); contiguous fuzzy matches keep clangd's order; no rebuild; Lisp cost per
  reply to measure. (c) R1 only (mid-word by coverage, still after every fuzzy
  match), clangd or Emacs: the scattered fuzzy matches stay on top. (d) Keep
  CLion's order (mid-word last). Recommendation (a): one rule for both prompts,
  and `C-c l s`'s cut then keeps the better matches.
- O-66 (RESOLVED 2026-10-19 with D-118: (a); owner 2026-10-19: "Research: Symbol
  (clangd) -> Project Symbol (clangd)"):
  the heading of `M-o`'s `s` symbols, which with a project root are the project's
  only (D-082) (`RESEARCH_go_to_anything.md` 18). Options: (a) "Project Symbol
  (server)" and narrow label "Project Symbol" when there is a root, "Symbol
  (server)" without one (then every symbol); "All Symbols" unchanged; matches
  "Project File"; tier 1 (one function, four test assertions). (b) Keep "Symbol".
  Recommendation (a).
- O-65 (RESOLVED 2026-10-19 with D-117: (a); owner report 2026-10-19, native-compiler
  warnings "the function
  `xref-read-identifier' / `xref-find-by-kind' is not known to be defined"): the
  vendored eglot (D-108, c79f727) took upstream's 2026-09-08 rewrite of its finders
  (2677293), which calls two functions only Emacs master's xref has; Emacs 31.1
  ships xref 1.7.0 without them, although eglot declares `(xref "1.7.0")`. So
  `C-c l i`, `C-c l d` and the implementation click (D-093) stop with
  `(void-function xref-read-identifier)`, since T-090. The same rewrite renamed
  `eglot-find-typeDefinition` to `eglot-find-type-definition`, but eglot's own menu
  and command list and our type-definition click (`init-lsp.el`) still name the old
  one. The tests check the key bindings only. Options: (a) eglot patch 0003 (D-069):
  the finders fall back, when `xref-find-by-kind' is missing, to showing
  `xref-backend-xrefs-by-kind' through `xref-show-xrefs' (both in 1.7.0), and the
  old name becomes an alias; ERT runs each finder against clangd; reported upstream
  with T-032. (b) vendor xref from emacs-straight/xref as well: shadows the built-in
  xref for every package (project, consult, dape), new dependency. (c) pin eglot
  before 2677293 and rebase patches 0001 / 0002: loses about five weeks of fixes
  that D-108 chose c79f727 for. (d) our own finder commands in `init-lsp.el`: the
  Lisp workaround D-069 rejects. Recommendation (a).
- O-64 (RESOLVED 2026-10-19 with D-115: (a); owner 2026-10-19: "Revisit maximum file
  watches (Arch, different variables) and eglot restarting in a loop, if the watches
  are exceeded"): two limits on Arch,
  eglot's `eglot-max-file-watches` (10000) and the kernel's per-user
  `fs.inotify.max_user_watches` (1% of RAM, 8192 .. 1048576); a failed watch request
  makes pyright exit, and stock eglot reconnects in a loop when the round lasts over
  `eglot-autoreconnect` (3 s); the vendored eglot (D-108) answers success, no loop
  (reproduced, RESEARCH_platform_differences 3.14). Options: (a) keep as is; (b) cap
  eglot at half the kernel's limit on Arch; (c) name the kernel limit in patch
  0001's warning; (d) guard the stock eglot. Recommendation (a), plus (b) if the
  owner's `sysctl` numbers show the kernel limit near 10000.
- O-63 (RESOLVED 2026-10-15 with D-113: (b); owner question 2026-10-15 on S14: "Can be new
  behavior be configured?"): how patches 0011 / 0012 (if S14 passes) are switched. The
  spike has them always on for workspace symbols. clangd reads `workspace/symbol`
  parameters with an `ObjectMapper` that maps the keys it knows and ignores others, and
  has one extension there already (`limit`, `Protocol.cpp`). Options: (a) hidden startup
  flags, off by default, as patches 0001 - 0009 (`--navigation-from-index`): an Emacs
  option adds them to the clangd command; a change needs a restart; `M-o` and `C-c l s`
  alike. (b) request fields next to `limit` (e.g. `middleMatch`, with the minimum length,
  and `looseScope`), off unless sent: Emacs options decide per request, `M-o` and
  `C-c l s` may differ, no restart, a stock clangd ignores them; `C-c l s` needs our
  consult-eglot patch extended (it sends only `query`). Recommended (b). Owner rules.
- O-62 (RESOLVED 2026-10-15 with D-110: (a) - (e) as designed, details in DESIGN
  7.1; (f) build order: after T-090, done when to agree; owner request 2026-10-15,
  T-099): the fswatch backend for eglot as
  designed in DESIGN 7.1. To rule: (a) the switch is eglot's `eglot-fswatch-program`,
  set by the user (designed), or the config sets it when ~/opt/fswatch-no-loss
  exists; (b) a stock fswatch runs with one warning (designed), or is refused; (c) on
  `Overflow` a warning naming `M-x eglot-reconnect` (designed), or a reconnect by
  itself; (d) `eglot-watch-file-patterns` as a pre-filter, yes (designed) or no; (e)
  a dead fswatch is reported, not restarted (designed), or restarted once; (f) build
  it after T-090 is agreed, as tier 2 with its own done when. Owner rules.
- O-61 (RESOLVED 2026-10-15 with D-111: DESIGN 7.2 recommendations; (h1) as D-109,
  D-110; owner 2026-10-15 with D-108, T-091): which files eglot watches, and
  large repositories (`RESEARCH_platform_differences.md` 3.9). Found: besides
  `.gitignore`, `.git/info/exclude`, `.ignore`, `.fdignore` and `.projectile` keep a
  tree out of the list (checked with `fd`); deal.II has 1754 tracked directories (6
  with Python), LLVM 14419 (1779): pyright asks for all, three times. Options: (a)
  tracked-only lists (undecided); (b) per-project exclusions, documented; (c) a
  language filter in the vendored eglot; (d) open buffers' directories first under
  the cap; (e) shared watches across registrations; (f) nothing beyond D-108.
  Owner 2026-10-15: draft (c) (T-092, research 3.10): `eglot-watch-file-patterns`,
  base-name wildcards per major modes, 32 lines on top of 0001; on a toy pyright
  keeps 11 watches instead of 500; LLVM still 1779 Python directories. Found: with
  0001 alone pyright ends with 0 watches once it unregisters its first two
  registrations, which had taken the cap: (g) re-run a truncated registration when
  another is removed, or (e). Owner rules.
  Owner 2026-10-15: drafts for (e) and (g) (T-093, research 3.11): toy of 400
  directories, cap 500: 0001 ends with 0 watches, (g) with 401, (e) never needs
  more than 401; neither reaches LLVM. CLion, Qt Creator (and, by Apple's own
  advice, Xcode) watch trees on macOS with one FSEvents stream, not a descriptor per
  directory; CLion watches `/` and filters, excluded folders included (IJPL-2175);
  Qt Creator keeps partial watches at half the file limit and offers servers no
  file watching at all (T-094). New option (h): a tree watcher process for eglot
  (`fswatch` or Watchman, FSEvents on macOS), a new dependency, not prototyped.
  Owner 2026-10-15: both installed (MacPorts), research (h) (T-095, research
  3.12): on an LLVM-sized tree `fswatch` holds 8 descriptors and 6 MB, starts at
  once, delivers all of 20000 changes while read, but loses changes silently once
  its reader pauses (about 1000 buffered); Watchman crawls 1.9 s, holds 101 MB,
  loses nothing (all 20000 after a 20 s pause), writes cookie files into the root,
  AUR-only on Arch. Both report real paths (`/private/tmp`). Options: (h1)
  `fswatch` backend, (h2) Watchman backend, (h3) either on macOS only, (h4)
  neither. Owner 2026-10-15 on (h1): can fswatch be patched? (T-096, research
  3.13): yes, prototype (`docs/upstream/fswatch-fsevents-no-loss-present-state.patch`):
  a writer thread keeps the FSEvents callback from blocking (paused reader: 10001
  records against stock's 959), drops reported as overflow, `lstat` decides
  removed or present (created-then-removed: `Removed` only). Ways: (i) upstream
  pull request, (ii) a local build as for clangd, (iii) only the writer thread in
  fswatch, the stat in Emacs. Owner 2026-10-15: (ii) (D-109). Checked (T-097):
  change 2 names a real drop (`TREE Overflow`; without `--allow-overflow` fswatch
  aborts); 100000 unread records cost 18.7 MB, kept after draining, unbounded
  without a cap; the prototype applies to 1.22.0 and behaves the same; fswatch
  misreads `-l 0.1` in a comma locale when built with NLS. Still open in (h1): the
  eglot backend itself. Revisited 2026-10-15 (DESIGN 7.2): recommended close (a),
  README note for (b), (c) as the backend's pre-filter, drop (d), adopt (e), drop
  (g); the backend designed in 7.1, ruled as O-62.
- O-60 (RESOLVED 2026-10-15 with D-108: (b) vendor eglot; tracked-only lists still
  undecided, moved to O-61; owner 2026-10-15 with D-107, T-089): (b) tracked-only file
  lists and (c) an eglot patch keeping partial watches (`RESEARCH_platform_differences.md`
  3.8). Found: eglot watches projectile's list (projectile is project.el's backend here;
  `project-vc-include-untracked` has no effect); tracked-only is `projectile-git-use-fd`
  nil plus `git ls-files -zc`, and an untracked `.py` buffer still gets eglot, pyright and
  its symbols, but untracked files leave `M-o` and `C-c p f`. The eglot change
  (`docs/upstream/eglot-watch-cap-partial-watches.patch`, 13 lines in, 9 out) keeps
  pyright running at the cap and at kqueue's refusal (repro: exits before, runs after);
  upstream eglot is unchanged. Options for the patch: (a) upstream only, with T-032's
  report; (b) vendor eglot (`emacs-straight/eglot`) with the patch; (c) override
  `eglot--watch-globs` in the config, loud on another eglot version; (d) none. For (b) of
  O-59: adopt tracked-only, or not. Owner rules.
- O-59 (RESOLVED 2026-10-15 with D-107: (a), `build*/`; (b) and (c) continue as
  O-60; owner report 2026-10-15, T-088): pyright exits in deal.II's step-1 at
  eglot's watch cap (`RESEARCH_platform_differences.md` 3.7). Found: `project-files`
  includes untracked files git does not ignore; `build_cpu/` (results, 14244 files,
  1787 directories) is such, so 1811 directories against D-054's cap of 500; the
  later warnings and timer errors are eglot answering a dead pyright. Options: (a)
  the owner ignores `build_cpu/` in step-1's `.gitignore` (24 directories left); (b)
  watch tracked files only (`project-vc-include-untracked` nil); (c) send T-032's
  eglot report; (d) a higher cap, no help here. The auto-save file
  `#plot_theta.py#` holds unsaved `# %%` markers of 2026-10-14: recovering is the
  owner's call. Owner rules.
- O-58 (RESOLVED 2026-10-15 with D-106: (d) and (h); owner 2026-10-15 approving T-084,
  T-086): order of several servers'
  symbols, and `C-c l s`'s kind groups (`RESEARCH_go_to_anything.md` 17). Found:
  pyright and texlab answer `workspace/symbol` without `score`; since D-105 replies
  follow in arrival order, which can differ per key; `C-c l s` lists whole kind
  groups in order of first appearance, so `count_vertices_globally` (Function)
  shows before `count` (Variable) on the toy. Options: (a) arrival order, as built;
  (b) the calling buffer's server first, then newest first; (c) (b) shown once all
  answered or after a timeout; (d) one `M-o` source per server; (e) the calling
  buffer's server only; (f) interleave, not recommended; for `C-c l s`: (g) no kind
  groups (patch 0001 gains a hunk; kind narrowing stays), (h) keep them. Owner
  rules.
- O-57 (RESOLVED 2026-10-15 with D-112, S14 PASS: (b) + (c) as patches 0011 / 0012
  (T-104), (d) dropped; owner
  2026-10-15 with D-105: "research Optional", T-085): the symbol
  matches CLion makes and clangd refuses (`RESEARCH_go_to_anything.md` 16): mid-word
  (`ector`; clangd's trigrams admit it, only its matcher refuses), a gap inside a
  word (`cml`; its trigrams refuse it), a loose qualifier (`geom::vec`; only the
  scope check in `FindSymbols.cpp` refuses). Options: (a) loose qualifier in `M-o`
  only, no clangd change; (b) patch 0010, loose qualifier in clangd; (c) patch,
  mid-word for 3+ letters under a request field; (d) gaps inside a word, largest
  cost; (e) none. A clangd patch is tier 3: spike first. Owner rules.
  Reviewed 2026-10-15 (owner request): unchanged by D-105 / D-106, except that
  `M-o` symbols now come per server, so (a) would split the qualifier for clangd's
  source only. Patch 0010 is taken by O-50 (S13, symlinked paths), so (b) / (c)
  would be 0011 / 0012; one rebuild of the patched clangd (Arch package, Mac
  `build-macos.sh`, about 15 minutes) could carry all three. Recommendation: (b)
  and (c) in one spike S14 on deal.II's index (replies and times for mid-word and
  qualified queries against today), built with O-50's 0010; (d) dropped (trigrams
  refuse it before the matcher; a full scan or far larger index); (a) only if no
  clangd change is wanted.
- O-56 (CLOSED 2026-10-21 with D-139: none; owner "O-59 close", meaning O-56 (asked the
  same day); was OPEN, owner request 2026-10-15, T-082): a theme following macOS's dark /
  light setting (`RESEARCH_dark_theme.md`). Found: the NS build of Emacs 31.1 sets no
  `toolkit-theme` and runs no hook on a change; `defaults read -g AppleInterfaceStyle`
  reads it in 6.4 ms. Options: (a) once at startup, (b) and polling, (c) and a command,
  (d) auto-dark package, (e) another Emacs build. Owner rules; Arch is stage 2.
  Reviewed 2026-10-15 (owner request): nothing changed; Emacs 31.1's NS build still
  has no appearance hook. Recommendation: (a) + (b) + (c): the pair
  `modus-operandi-tritanopia` / `modus-vivendi-tritanopia` chosen at startup, a
  timer reading `defaults` asynchronously (`make-process`, so Emacs never waits;
  every 10 s is enough for "Automatic" switching at dusk), and `M-x
  emacs-cpp-ui-follow-system` for at once; all only while no theme was saved with
  Customize (D-040) and only on macOS (the reading in init-ui, D-055). (d) adds a
  dependency for the same polling; (e) contradicts D-053. Stage 2 (Arch): Emacs 31's
  `toolkit-theme-set-functions` works only in a PGTK build; for the GTK / X11 build
  the freedesktop portal's `color-scheme` setting over D-Bus would be the source;
  which build the owner runs there decides, not researched.
  Reviewed 2026-10-21 (owner request): recommendation unchanged, (a) + (b) + (c) on
  macOS. Against it: a `defaults` process every 10 s for the session (6.4 ms,
  asynchronous) and up to 10 s late. Stage 2 premise checked: the Arch Emacs is the
  GTK3 / X11 build (`emacs` 31.1-2, no PGTK), so `toolkit-theme-set-functions` does
  not apply; the portal's `color-scheme` over D-Bus (DBUS built in) would be the
  source, not researched.
- O-49 (RESOLVED 2026-10-14 with D-099: (a); found 2026-10-14 checking order
  dependencies, D-098): `M-o`
  (`emacs-cpp-go-to-anything`, init-completion) calls projectile
  (`projectile-project-root`, `-project-files`, `-relevant-known-projects`) and
  eglot / consult-eglot when run, packages configured by init-project and init-lsp,
  which load after init-completion; DESIGN 5 says a module may only use modules
  above it. It works because every module has loaded before a command runs.
  Options: (a) move go-to-anything into its own module after init-lsp; (b) DESIGN 5
  binds load time only, commands may use any module; (c) leave it. Owner rules.
- O-48 (RESOLVED 2026-10-14 with D-098: (e), none; owner request 2026-10-14:
  "research a separate configuration for
  enabling/disabling modules, similar to doom emacs"): findings in
  `RESEARCH_modules.md`. Doom: a `doom!` block outside its directory, modules with
  flags, `doom sync` after each change (installs and removes packages, regenerates
  autoloads). Here: the modules that only ride along (python, r, latex, cells,
  writing) cost 21 ms of startup together (Mac, batch); leaving one out of `init.el`
  leaves its packages' autoloads on (`.tex` still opens in AUCTeX, `.R` in ESS);
  tests cover only the full set; DESIGN 2 names "no Doom / Spacemacs layer" as a
  non-goal. Options: (a) as now, a commented `require`; (b) a module list outside
  the repository, read by `init.el`, core modules fixed, loud on unknown names and
  missing prerequisites; (c) (b) plus `make packages` leaving the packages of
  modules that are off out of the load path and autoloads; (d) Doom's flags; (e)
  none. Owner rules.
- O-47 (RESOLVED 2026-10-21 with D-137: (c); was OPEN, owner request 2026-10-14:
  "visual indicator when hovering over a symbol, and/or mouse pointer that changes
  when pressing a modifier"): findings in
  `RESEARCH_mouse.md` 5. A modifier alone gives Emacs no event, so no pointer
  change while it is held. Options: (a) hand pointer and highlight on symbols
  under the mouse in eglot buffers, always; (b) (a) plus the server's hover text as
  a tooltip; (c) none. Owner 2026-10-14: research (a) and a plain click: section 6
  (tree-sitter tagging 5.9 ms for a 4927-line header; a click already shows eglot's
  hover in the echo area after 0.5 s; options c1 tooltip, c2 child frame (posframe),
  c3 shorter delay). Owner 2026-10-14: (c2) asked, then closed as it is (D-096);
  (a): further research on its performance first. Measured 2026-10-14
  (`RESEARCH_mouse.md` 7): per 1500-character chunk shown, tagging adds 0.02 - 0.09
  ms median (font-lock itself 0.16 - 0.59 ms); 0.08 ms after an edit against
  font-lock's 3 - 8.5 ms; query compilation 10 ms once per session; 56 bytes per
  tagged identifier, shown parts only (0.7 MB for all of deal.II's largest header);
  mouse movement itself not measured (needs a graphical session). Owner rules.
  Reviewed 2026-10-21 (owner request): nothing new. Recommendation: (c), close as
  it is. Against (c): no sign that a symbol is clickable. Against (a): highlight on
  every identifier under the mouse, always, where CLion shows it only with the
  modifier held, which Emacs cannot see; mouse-movement cost not measured.
  Against (b): (a) plus a tooltip the owner closed with D-096.
- O-46 (RESOLVED 2026-10-14 with D-102: (c), none; owner request 2026-10-14:
  "keybindings/shortcuts similar to LyX"):
  findings in `RESEARCH_latex.md` 8 (LyX's bind files: Ctrl+M math, Ctrl+Shift+M display
  math, Ctrl+Alt+B bold, Ctrl+E emphasis, Ctrl+L TeX code, Ctrl+R view; Mac: Command+M,
  Command+Shift+M, Command+B, Command+Ctrl+E, Command+L, Command+R). Emacs's `C-m`,
  `C-b`, `C-e`, `C-k`, `C-l` are taken; Emacs.app's `s-m`, `s-e`, `s-l` too. Options:
  (a) LyX's keys on Command in `LaTeX-mode` on the Mac; (b) under a prefix on both
  machines; (c) AUCTeX's only. Owner rules.
- O-45 (RESOLVED 2026-10-14 with D-095: (b), keys (k2); owner request 2026-10-14:
  "research yasnippet"): findings in
  `RESEARCH_snippets.md`. With yasnippet eglot announces snippet support: clangd
  then completes calls with argument placeholders, texlab environments with
  `\end`. Options: (a) yasnippet for the servers' snippets; (b) plus
  yasnippet-snippets; (c) tempel with eglot-tempel; (d) none. Compared 2026-10-14
  (`RESEARCH_snippets.md` 6): yasnippet works with eglot as it is; tempel completes
  through corfu but needs eglot-tempel (MELPA only, patches eglot, conflicts with
  yasnippet); collections: yasnippet-snippets on NonGNU ELPA, tempel-collection
  MELPA only. Keys (`RESEARCH_snippets.md` 7): (k1) TAB expands, (k2) a key of its
  own, (k3) from the completion popup, (k4) no TAB at all.
- O-44 (RESOLVED 2026-10-21 with D-138: (c), buttons 8 / 9; was OPEN, owner request
  2026-10-13: "research additional mouse bindings, e.g.
  Command+M1 for going to symbol (M-.), compare to Clion key+mouse bindings"):
  findings in `RESEARCH_mouse.md`. Cmd+Click (`s-<mouse-1>`) is unbound; Emacs has
  `xref-find-definitions-at-mouse` / `xref-find-references-at-mouse`, and
  `context-menu-mode` (off) would put both in a right-click menu. Options: (a)
  Cmd+Click definition, a second click for references, Cmd+Opt+Click implementation,
  Cmd+Shift+Click type (Ctrl on Arch); (b) `context-menu-mode`; (c) back / forward on
  the mouse's side buttons, after checking their events; (d) none. Owner 2026-10-13:
  (a) and (b2) built as D-093; (c) waits for the owner's `C-h k` on a side button.
  Reviewed 2026-10-21 (owner request): (c) waits on the owner's `C-h k` (T-067),
  which had no `TODO_human.md` item; H-16 added. Nothing else open here.
- O-43 (RESOLVED 2026-10-21 with D-136: (b3); was OPEN, owner request 2026-10-13:
  "research further C++ refactorings from CLion, e.g. signature change, refactor in
  project files"): findings in
  `RESEARCH_refactoring.md`. clangd renames across files from its index but refuses
  beyond 50 files by default (`--rename-file-limit`; measured: 63 files refused,
  with 0 renamed in 224 ms); no change signature, inline, safe delete, pull up / push
  down; extract function / variable, define outline / inline, populate switch,
  special members, override pure virtuals, scopify enum and more as code actions.
  Options: (a) `--rename-file-limit=0`; (b) a clangd change-signature tweak, spike
  first; (c) commands around clang-move, clang-change-namespace, run-clang-tidy -fix;
  (d) document the by-hand route for signature changes. Owner 2026-10-13: all four;
  (a) built as D-092; (b) a spike first (S12, T-069, `spikes/s12-change-signature`):
  FAIL 2026-10-14 (0066): a tweak edits every call the index lists precisely (0 wrong
  edits in 2502 over two runs, macros' bodies included, from raw tokens in 57 - 259
  ms), but calls depending on a template parameter cannot be settled: a dependent
  call of an overloaded name is listed for every overload, a member call through a
  template parameter not at all; both reported, not edited; 5 of 9 operations then
  fail to build or change the output. eglot opens each edited file, about 95 ms
  each (1.7 - 5.1 s in all). Options (b1) a patch along the spike, with the list of
  reported calls for the user; (b2) a second round settling reported calls by
  parsing their files; (b3) stop, MANUAL 8 stays. Owner rules;
  (c) built as D-094 without clang-change-namespace, which came with D-097
  (patched); (d) done 2026-10-14: MANUAL 8, "Changing a function's signature by
  hand", after running the route on 63 files.
  Reviewed 2026-10-21 (owner request), (b) still waits: recommendation (b3), stop;
  MANUAL 8 stays. Against (b3): no change signature, CLion's most used refactoring
  after rename. Against (b1): 5 of 9 spike operations broke the build or the output,
  and a 14th clangd patch to carry. Against (b2): a dependent call's target is
  unknowable until instantiation, a large spike with no bound. Combining option
  (b4): (b1) refusing loudly whenever any call is reported, so it edits only what it
  settles; against: on deal.II code most functions may have dependent calls
  (share UNVERIFIED, RMO not measured).
- O-42 (RESOLVED 2026-10-13 with D-090: (b), build on a key; owner request
  2026-10-13: "research latex (LSP) support, in particular
  texlab"): findings in `RESEARCH_latex.md`. texlab is packaged on both machines
  (Arch `extra`, MacPorts) and works through eglot in the built-in `latex-mode`:
  cross-file `\ref` / `\cite` / `\newcommand` definitions and references, citation
  hover and completion, workspace symbols, latexindent formatting, and a build
  request running latexmk (eglot has no command for texlab's build and forward
  search requests). digestif, eglot's first default, has none of the cross-file
  features. A colon in the project path breaks texlab's cross-file features. Forward
  search to Skim (installed by the owner, outside MacPorts) works through texlab:
  154 - 234 ms per jump. Options:
  (a) texlab named in `eglot-server-programs` for `latex-mode` / `bibtex-mode`,
  started for project files as pyright, plus a small build command (or
  `texlab.build.onSave`) and forward search to Skim / zathura; (b) the same with
  AUCTeX vendored for editing; (c) eglot's default (digestif first); (d) none.
  Owner rules.
- O-41 (RESOLVED 2026-10-13 with D-088 for (b); (c1) done by the owner; owner
  2026-10-13: "research the stall ... images in the project
  directory as possible cause"): the first `M-o` of a session can freeze while
  consult previews the first file candidate (`RESEARCH_go_to_anything.md` 12): every
  session's first preview 0.3 - 0.4 s; first `.org` preview 5.2 s (Org loads, much
  of it as byte-code), first `.R` 0.9 s (ESS), first image 0.16 s plus decoding in
  the GUI (not measured); step-1 lists 286 `.org` and 111 images, all fully
  previewed. Options: (a) no preview of images and PDFs; (b) debounced preview in
  `M-o`; (c) native-compile Emacs's own Org ahead of time; (d) load Org at idle
  (rejected unless (c) makes it short). Owner 2026-10-13: (b) and (c). (c) found
  moot the same day: Org is native-compiled already (121 of 128 files); loading
  native code is what is slow on the Mac (Org 2.9 - 3.8 s native, 1.2 s byte-code;
  the config in batch 1.37 - 1.71 s against 0.40 - 0.42 s). In its place: (c1) GDATA
  exceptions for Emacs.app and the eln-cache, measured again; (c2) byte-code on macOS
  (`load-no-native`). Asked again; owner chose (c1): exception for
  `/Applications/MacPorts` (GDATA cannot select hidden directories such as the
  eln-cache). Then Org native 1.18 - 1.42 s, byte-code 0.27 - 0.33 s; the config in
  batch native 0.54 - 0.65 s, byte-code 0.21 s. Possible next: the eln-cache moved
  to a visible directory under `~/source` (`startup-redirect-eln-cache`), not
  ruled. The owner then excepted the eln-cache as well: no further change (config
  native 0.52 - 0.62 s, byte-code 0.22 s; Org native 1.30 - 1.40 s); the rest is
  not the scanner (macOS's loading of each native file, not measured further).
- O-40 (RESOLVED 2026-10-13 with D-085: (a); owner 2026-10-13: "research more general
  mechanisms"): D-083 matches
  the project root in one spelling per server encoding (eglot, clangd, pyright); R's
  languageserver would be a fourth. Found (`RESEARCH_go_to_anything.md` 11): every
  encoder leaves letters, digits and `- _ . /` alone, so the root URI up to its
  first other character is a prefix all spellings share; only URIs that pass it
  are percent-decoded and compared with the root path. All four spellings under
  three awkward roots match, siblings and libraries do not; 3.8 - 5.0 ms per 6673
  symbols interpreted, against the shipped filter's 16.7 ms. Options: (a) replace
  D-083's spellings with it (tier 2: tests, toy checks with clangd and pyright);
  (b) keep the tables. Owner rules.
- O-39 (CLOSED 2026-10-25 by D-145: R left the config; owner request 2026-10-13:
  "research R language servers"): findings in
  `RESEARCH_r_language_servers.md`. Candidates: languageserver (R package, full
  feature set, cross-file only in a package with `DESCRIPTION`; on the Mac already
  installed with CRAN's R; Arch: AUR), Arity (standalone Rust binary, navigation
  and lint, pre-1.0; AUR, no MacPorts), Air (formatting only), Ark (Positron only).
  None in pacman's repositories or MacPorts (D-053). Options: (a) eglot with
  languageserver in `ess-r-mode` for project files, as pyright (needs R's CRAN
  packages on Arch); (b) Arity (a binary from outside both package managers); (c)
  Air for formatting only; (d) stay with ESS's session-based completion and xref
  (D-072). `M-o` needs nothing more for (a) or (b) since D-085.
  Also found: the Mac's R is CRAN's R.framework, not the MacPorts port D-072 names.
  Owner rules.
  Reviewed 2026-10-21 (owner request): Arch has R 4.6.1 (pacman `r`), without the
  languageserver package (`requireNamespace` FALSE) and no pacman package for it;
  the Mac's install not rechecked since 2026-10-13 (UNVERIFIED). Recommendation:
  (a) per platform (D-055): on the Mac now, on Arch once `install.packages` is
  agreed (a download outside both package managers, its own D-nnn). Against (a):
  cross-file features only inside an R package with `DESCRIPTION`, and two
  platforms behaving differently until Arch has it. Against (b): a binary from
  outside both package managers, pre-1.0. Against (c): formatting only. Against
  (d): no navigation beyond ESS's running session.
  Verified 2026-10-21 (owner: "verify aur r-languageserver",
  RESEARCH_r_language_servers 7): the AUR route is 48 AUR packages, two orphaned and
  two flagged out of date; the owner has since installed languageserver 0.3.20 from
  CRAN into R's user library on Arch, and it answers `initialize` in 1.08 s. So (a)
  can start on both machines from `install.packages` (Arch premise above
  superseded); a file outside the repository, so (a) needs its D-nnn. Owner rules.
- O-38 (RESOLVED 2026-10-21 with D-135: (e); was OPEN, owner 2026-10-13: "vendor
  rg.el / ag.el if no downsides"): `C-c p s a`
  (projectile-ag) and `C-c p s r` (projectile-ripgrep) stop with "not available":
  they need the Emacs packages ag.el / rg.el, not vendored. Downsides found: rg.el
  2.5.0 also needs wgrep (a third new submodule; transient is built in); Arch has
  no `rg`, and once rg.el loads, projectile's `auto` search backend (`C-c p s s`)
  picks ripgrep there and fails, so `projectile-search-backend` would need a
  per-platform value (D-055); ag.el 0.48 needs dash and s (vendored) and the `ag`
  program (on the Mac in MacPorts, on Arch not surveyed). Each is a new dependency
  (needs its D-nnn) and a network clone. `M-s r` (consult-ripgrep) and `M-s G`
  (consult-git-grep) already search. Owner rules.
  Reviewed 2026-10-21 (owner request): premise corrected: Arch has `rg` (pacman
  ripgrep 15.2.0, installed explicitly 2026-10-07 23:42, after DESIGN 3's survey) and
  `ag` (the_silver_searcher 2.2.0). The `auto` backend would then work on Arch too.
  New option (e): no new package, `C-c p s r` bound to `consult-ripgrep` in the
  project, `C-c p s a` unbound. Recommendation: (e). Against (e): a minibuffer list,
  not projectile's grep buffer, so no wgrep editing of the results. Against (a):
  rg.el plus wgrep, two submodules, a D-nnn and a network clone for what `M-s r`
  does. Against (b): ag.el for a slower ag. Against (d): two keys keep failing.
- O-36 (RESOLVED 2026-10-13 with D-081: patch projectile, GNU grep on Arch; owner
  report 2026-10-13): `C-c p ?` ("Find references to:") very slow. Cause: projectile
  3.4.0 searches with find and grep, one file at a time, ignoring
  `xref-search-program`; on the Mac each file opened costs about 14 ms. Options: (a)
  a projectile patch searching projectile's file list through `xref-search-program`;
  (b) an own command with the same mechanics; (c) clangd's references in C++
  buffers. Owner's side question (a symbol-to-references command, patched clangd,
  JSON): `RESEARCH_clangd_index_navigation.md` 8.
- O-35 (RESOLVED 2026-10-12 with D-080: every prompt with narrow keys, about 0.2 s;
  owner 2026-10-12): which-key lists consult's narrow keys only 3 s after `<`
  (D-071), too late in the go-to-anything prompt. Scope: `M-o` only, every prompt
  with narrow keys, or every shortcut in pop-ups (ESC brings D-071's problem back).
- O-34 (RESOLVED 2026-10-11 with D-079: (a) and (c); owner report 2026-10-11, T-052,
  `RESEARCH_go_to_anything.md` 9): `M-o`
  narrowed to symbols feels less responsive than `C-c l s` in deal.II-sized trees.
  Measured (stand-in, 100 ms per key): 15 - 35 ms per update against 3 ms, because a
  hidden source's candidates stay in consult's merged list after narrowing (async
  prompts only) and vertico checks them at every update; and 2 - 3 updates per key
  against one after the pause. Options: (a) a consult patch (D-069, `patches/consult/
  0001`): a hidden source that receives input flushes its candidates; checked in
  scratch: 0.6 - 4.7 ms per update; upstream report as a task; (b) symbol requests
  after a pause, as `C-c l s` (0.2 s debounce): one update after typing stops,
  results about 0.25 s after the last key instead of 0.11 s; (c) document narrowing
  with `<` `s` (the narrow key; no first-letter filter over all files: 36 ms against
  93 ms for `s` space).
- O-33 (RESOLVED 2026-10-11 with D-077: all four, and skip `""`; owner request
  2026-10-11, T-050, `RESEARCH_go_to_anything.md` 8): how
  T-049 makes the prompt fast. Measured in a terminal Emacs (34602 stand-in files,
  toy clangd), key to screen: consult's defaults 310 - 900 ms for the first letter,
  69 % of it garbage collection (`gc-cons-threshold` back at 800 KB after startup),
  symbols 440 - 670 ms after the third key (consult's 0.2 s refresh, consult-eglot's
  0.5 s / 0.2 s throttle; clangd itself 6 - 8 ms). Options, each measured: (a)
  `gc-cons-threshold` 64 MB while the prompt is open: first letter 108 ms; (b)
  `:sort nil` (source order, no history order); (c) highlight only the first 100
  hits (let-bound `consult--regexp-compiler`, internal); (d) refresh 0.05 s and
  symbol throttle / debounce 0.05 s for this prompt. All four: every key 55 - 67 ms,
  symbols 138 ms. Also: skip consult-eglot's `""` request at opening.
- O-32 (RESOLVED 2026-10-11 with D-075: (b); S11 run 1, 0048): one letter typed in a
  deal.II-sized project filters
  about 25000 matches in 32 ms (criterion 20 ms; RMO 6.7 ms; two letters 13 ms).
  Options: (a) project files join from the second letter (an async source with
  `consult--async-min-input` 2; checked in batch: one letter lists buffers, recent
  files, bookmarks and commands, two add files; deleting back to one letter keeps
  the last file matches listed until the next letter); (b) accept: below the 100 ms
  of a reply that feels immediate, only in deal.II-sized trees, T-049's hand check
  on the deal.II tree decides whether (a) follows; (c) project files only behind the
  narrow key `f`.
- O-31 (RESOLVED 2026-10-11 with D-076: `M-o`; owner 2026-10-11 with D-074:
  "explore alternative keybinds to M-M";
  `RESEARCH_go_to_anything.md` 4): the key for the go-to-anything prompt. Free in
  every mode the config uses (checked): `M-M`, `M-o` (both one chord, also in a
  terminal), `C-c` plus a letter such as `C-c j` (reserved for users, two keys),
  `<f5>` .. `<f9>` (reserved for users, one key; CLion's debugger keys are F7 - F9),
  `C-S-n` / Mac `s-O` (CLion's file keys; graphical frames only), `M-g a`. Taken:
  `C-,` and `C-'` (org). Double Shift needs a key remapper outside Emacs (keyd or
  xcape on Arch, Karabiner-Elements on the Mac; not checked; its own D-nnn).
  Several keys may share the command.
- O-30 (RESOLVED 2026-10-11 with D-074: (b), measured first; owner request
  2026-10-11, T-047, `RESEARCH_go_to_anything.md`): one
  "go to anything" prompt like CLion's Search Everywhere. Shift twice cannot be bound
  (Emacs has no event for a lone modifier); `M-M` is free. Options: (a) project files,
  clangd symbols and commands added to `consult-buffer` on `C-x b` (buffer switching
  then filters by consult's regexps, not orderless); (b) a new command on `M-M`, about
  60 to 80 lines with `consult--multi`: buffers, project files, recent files and
  bookmarks from the first key, symbols from the third, commands behind a narrow key;
  it calls consult-eglot's internal functions or copies them; (c) `M-M` as a prefix
  map over the existing commands, no new Lisp; (d) consult-project-extra (MELPA, new
  submodule) plus (c). Research recommends nothing yet; owner rules.
- O-29 (RESOLVED 2026-10-10 with D-072: (a) and (b); owner request 2026-10-10, T-045,
  `RESEARCH_notebooks_cells.md`): how to
  run Python and R code in pieces. Options: (a) `# %%` cells in plain scripts with
  code-cells (GNU ELPA, one file, verified with `run-python`); (b) the same for R, plus
  ESS as R's mode and process (verified; R has no mode today, D-045); (c) notebooks as
  org files with org-babel (built in; Python sessions verified; R sessions need ESS,
  loaded before the first session block); (d) Jupyter kernels through emacs-jupyter
  (`zmq` native module, Jupyter install; not checked); (e) Quarto through quarto-mode
  and polymode (quarto CLI packaged neither on Arch nor in MacPorts: conflicts with
  D-053); (f) `.ipynb` editing: EIN is sunset, jupytext not ported for the Mac's
  Python. Each package is a new submodule and a D-nnn (D-006). Ruled: (a), (b).
- O-28 (RESOLVED 2026-10-10 with D-061: (b) new line only, and (e); (b) superseded
  by D-065 the same day; owner request
  2026-10-09, T-034, `RESEARCH_indent_guessing.md`): `TAB`
  and `RET` in `c++-ts-mode` indent by Emacs's tree-sitter rules, not by the
  project's `.clang-format`, and Emacs 31.1's rules indent a `{` on its own line after
  `namespace` or `class` in every style. On RMO, re-indenting changes 7624 of about
  10,100 lines, 2955 with three added rules in its `.dir-locals.el` (MANUAL 8).
  clangd re-indents the new line on RET (on-type formatting) and gets it right, but
  electric indentation runs after it and undoes it. Options: (a) per-project
  `.dir-locals.el` as now; (b) in eglot-managed C++ buffers, turn electric indentation
  off so RET follows clangd (TAB unchanged; time per RET not measured); (c) indent
  rules for the owner's style in the config (namespace, class, `case`, argument
  continuation), tier 2; (d) dtrt-indent, a new dependency that guesses only step and
  tabs, which fixes none of RMO's differences; (e) report the namespace / class rule
  gap upstream (outward, so the owner sends it). Ruled 2026-10-10: (b) taking only the
  new line's indentation from clangd (the line above as typed), and (e); T-035, T-036.
- O-27 (RESOLVED 2026-10-09 with D-060, option (b); owner question 2026-10-09,
  `RESEARCH_navigation_delays.md`): the first `M-.` in a file after a restart waits 7 -
  13 s for clangd's parse on the Mac because the patched clangd refuses shards flagged
  "indexed with errors"; 5 of RMO's 11 sources carried that flag although they compile
  now (indexed during an edit). A flag heals at the next start only if the flagged
  source itself changed; a fixed header heals one includer, a header created later none;
  clangd re-indexes nothing for an edit during a session (research 4). Options: (a)
  delete the index by hand when it happens, (b) patch 0009: re-run the indexer on
  flagged sources at startup (no flagged shard is trusted; a still-broken source stays
  flagged and answered from the parse), (c) missing headers as dependencies, (d) the
  Emacs side (`vc-refresh-state` about 70 ms per opened file). Owner to rule.
- O-26 (RESOLVED 2026-10-09: (a) D-054 confirmed, (d) upstream report, T-032; T-029,
  revisited 2026-10-09): what D-054 should be. Revisit: the premise of a 207-watch limit
  for an Emacs started from the Dock was wrong; Emacs.app started through Launch
  Services holds 975 watches, as a terminal start does (then
  `RESEARCH_file_watches_macos.md` 1, now `RESEARCH_platform_differences.md` 3.1).
  New: at eglot's cap eglot fails the whole watch request and pyright exits,
  measured with D-054 on a 600-directory project; "project files only" is what keeps
  pyright up at all (with the library watched it exits on any project); without eglot's
  watches pyright does not see changes made outside Emacs (research 5). Options
  (research 6): (a) keep D-054 (projects up to about 500 directories), (b) raise the cap
  to about 800, (c) offer no watching on macOS (never exits, silently stale), (d) ask
  eglot upstream to keep partial watches at the cap, with (a) or (b). Owner to rule.
- O-25 (RESOLVED 2026-10-09 with D-056, owner: CMake file API): read a preset's
  executable targets from CMake's file API instead of `build.ninja` (D-033)? The
  `build.ninja` regular expressions depend on how CMake names link rules and where it
  writes the build type, which changed between CMake 3.31 and 4 (0034). The file API's
  `codemodel-v2` reply is versioned JSON: every target with its `type` (EXECUTABLE),
  name and artifact paths, for any generator (Makefiles too). It exists only after a
  configure with a query file in `<build>/.cmake/api/v1/query/`; CLion writes one, so
  the owner's CLion builds of RMO already have replies (checked on the Mac). D-033
  rejected it for the query file plus reconfigure; the configure command (`C-c p c o`,
  D-035) could write the query first. Owner to rule.
- O-22 (RESOLVED 2026-10-09 with D-051: lldb in addition to gdb): the C++ debugger on
  macOS. Apple silicon has no gdb, and `gdb-preset` (D-031, D-033) starts only gdb.
  Options: an `lldb-preset` doing the same with `lldb-dap` (Command Line Tools or the
  `lldb-23` port); dape's own `lldb-dap` configuration by hand, no preset program
  picker; or no C++ debugging on macOS. D-032 (gdb scripts) and D-030 (symbol loading)
  have no lldb counterpart yet.
- O-23 (RESOLVED 2026-10-09 with D-052: a build script): the patched clangd (D-026 ..
  D-028, D-046, D-047) on macOS. Its PKGBUILD is Arch-only (makepkg, pacman's
  `llvm-libs` / `clang`). Options: a local MacPorts portfile against `llvm-23`; a build
  script outside any package manager; or the MacPorts clangd only
  (`emacs-cpp-clangd-program` nil), losing index navigation and header flags from the
  index on macOS.
- O-24 (RESOLVED 2026-10-09: (a) D-053 MacPorts only, (b) D-057 Arch only, (c) D-058
  machine at hand; D-050):
  scope of macOS support. (a) Package source: MacPorts only (the owner's Mac), or
  Homebrew too. (b) Which machine the performance budgets (section 11) and the
  reference project (D-009) are measured on: Arch only, or both. (c) Whether `make
  test` must pass on both before every commit.
- O-19 (RESOLVED 2026-10-08 with D-045): which of Python, R and Perl ride along, and
  how far: mode only, plus a language server, plus a debugger
  (`RESEARCH_other_languages.md` 3). Python needs only Arch packages; Perl's server is
  CPAN-only; R needs ESS as a new submodule.
- O-20 (RESOLVED 2026-10-08 with D-044): gud (`M-x pdb`, `M-x perldb`, `M-x gdb`) binds
  its map on `C-x C-a` globally when it loads, which takes dape's prefix for the session.
  Proposed: `gud-key-prefix` on a free key (`C-x M-a`, `C-x M-d` or `C-x C-y`).
- O-12 (RESOLVED 2026-10-21 with D-130: (b); owner: "O-12 (b)"; was OPEN, owner
  2026-10-09: run S10 on Arch, `spikes/s10-library-index/RUN.md`;
  owner 2026-10-08: adopt, spike S10 first; T-020 folded into the same
  clangd rebuild): S10 run 1 (owner, Arch, 2026-10-20): FAIL, its name was
  RMO's own; it found that the external index's `MountPoint: /` switches off the
  project's background index (`M-?` 7 -> 2), so run 2 adds a later config fragment
  and a deal.II name (`spikes/s10-library-index/RESULTS.md`). S10 run 2 (session,
  Arch, 2026-10-21): FAIL on the first `M-.` only (declaration; the definition 10 s
  later, the deal.II index still loading), `M-?` 2 -> 19, +218 MB; the mount-point
  fix confirmed by a second fragment and by `--index-file` alike. Options for giving
  clangd the library index, each with its case against:
  (a) the user config `~/.config/clangd/config.yaml`: the index with `MountPoint: /`,
  then a second fragment `Index: {Background: Build}`. Against: a file outside the
  repository (needs its D-nnn), read by every clangd of the machine, so every project
  loads the deal.II index (about 200 MB each); the second fragment also overrides a
  project config placed before it (user fragments come first, so a project's own
  `.clangd` still wins: UNVERIFIED by a run).
  (b) the config adds `--index-file=<index>` to clangd's command for a project that
  names an index (a `.dir-locals.el` value, as D-062's indentation values). Against:
  clangd calls the flag experimental and "will be removed eventually" (still in
  23.1.3; the patched build is pinned, the system clangd is not); one index per
  clangd; a project-specific absolute path in a dir-locals file.
  (c) a `.clangd` in the project with the index and the second fragment. Against:
  written into the owner's project (RMO), per project, an absolute machine path in a
  tracked file, and both machines need different paths.
  Combined: (b) with the index's path per machine in the platform defaults file
  (D-055) and the project naming only which library. Recommended: (b), plus a fix for
  the first request (criterion 1): load the index before the first `M-.`, or the
  patched clangd's index-first path waiting for the static index too (a clangd patch,
  was planned as 0009). Owner rules. S10 dry run (synthetic
  project): the patched clangd with the deal.II
  index answers the first `M-.` with the definition (`vector.templates.h:477`,
  `tria.cc:15874`), `M-?` 2 -> 8 and 2 -> 18, +30 MB; no clangd patch needed (the
  research's miss was a config without `MountPoint`). Was DEFERRED, revisit after v0.4:
  Bear (4.2.2, installed) to make
  compile databases for dependent libraries instead of patching clangd. Bear records the
  compiler calls of a build that is run; it helps build systems that cannot export a
  database (make, autotools, b2). Findings: the installed deal-ii and boost packages
  carry headers and binaries, no library sources (deal-ii: 93 example `.cc`, boost: 2
  `.cpp`), so there is nothing to record; deal.II would have to be built from source
  (`~/source/repos/dealii`, CMake, which exports a database itself, Bear not needed),
  at the installed version (9.8.0) so that headers and sources match. It would let
  clangd index library sources: definitions in deal.II `.cc` files and uses inside the
  library. It does not change the per-file parse of RMO's files, so it complements the
  patch rather than replacing it. Costs: D-016 passes one database directory, so
  library sources would get RMO's flags unless the databases are merged or the
  directory is chosen per file; indexing deal.II's sources in the session is hours of
  CPU and GB of index (D-010), so it would be indexed offline as a static index (O-9).
  Measured 2026-10-08 (`RESEARCH_library_sources_index.md`): no Bear and no build
  needed (CMake database 38 s, instantiation files 1.2 s); the whole library indexes
  offline in 142 s wall / 35 min CPU / 10.1 GB peak into a 40 MB index; with it, `M-.`
  reaches definitions in deal.II (`vector.templates.h`, `tria.cc`) instead of header
  declarations, `M-?` includes uses inside the library; clangd +116 MB. Gaps: the
  index loads on the first query (that one misses it); the patched clangd's index-first
  path ignores it (no file config context). Bear only for non-CMake libraries (b2
  Boost). Open for the owner: adopt (offline build step, kept source copy, a patch for
  the index-first path) or not.
- O-8 (RESOLVED 2026-10-08, D-023): ccls instead of clangd, clangd, or a hybrid. S6 on RMO:
  ccls answers `M-.` 1.2 s after start from its on-disk index (clangd: 10.5 s per
  file), headers opened first are clean (O-5), memory 0.7 - 0.9 GB; first indexing per
  build dir 110 s, 437 MB cache. ccls lacks clang-tidy, clangd's refactoring code
  actions, type hierarchy and inlay hints. Hybrid: ccls through eglot plus clang-tidy
  as a separate flymake backend (one eglot server per buffer). Details:
  `spikes/s6-ccls/RESULTS.md`. Earlier text kept below for the reasoning.
  Candidate: ccls
  (extra/ccls 0.20250815, built on the system clang), which keeps a per-file index with
  token positions on disk (`.ccls-cache`) and can answer `M-.` from it without parsing
  the open file again. Not adopted without a spike (S6: first `M-.`, memory, cache size
  and correctness on RMO). Not candidates: GNU Global / ctags (not installed; not
  semantic, no template or overload resolution); C++20 modules (the system deal.II
  9.8 is not built with module support).
- O-9 (CLOSED 2026-10-08, owner: not wanted): static index (`clangd-indexer` .dex) for
  system libraries under `/usr/include`, background index for projects. Possible: clangd
  config `Index: External: File: <dex>, MountPoint: /usr/include` (absolute mount
  points only in the user config, which Qt Creator owns and overwrites; a separate
  config via `XDG_CONFIG_HOME` for our clangd would be needed); `--index-file` is
  experimental and slated for removal. Does not change the per-file parse or project
  indexing (each project TU still parses its library headers; their shards are
  already shared in `~/.cache/clangd/index`, 3783 header shards, 38 MB). Adds library
  symbols the project does not include yet: workspace-symbol search over all of
  deal.II / Boost and completion with automatic `#include`. Costs: a synthetic TU per
  header to index, rerun after library updates, the static index held in clangd's
  memory from the start (D-021 concern). Not pursued unless the owner wants that
  feature (would be spike S8).
- O-7 (CLOSED 2026-10-08, owner: not seen since pkgrel 3; reopen with the buffer name and
  its clangd command): owner 2026-10-08: after `eglot-rename` answered N, "file not
  found" errors return. Not reproduced (synthetic project: N opens no file, main.cc stays
  at 0 diagnostics). Needs the buffer name and its clangd command from the owner.
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
- 2026-10-08, owner: Q-5 no warm-up through additional open files, it raises memory
  from the start (D-021, S5 and T-012 closed); Q-6 Emacs is not run as a server
  (D-022); spike ccls (S6) and test PR 175209 with a PKGBUILD (S7).
- 2026-10-07, owner after S1 PASS: O-1 Emacs passes `--compile-commands-dir` (D-016).
- 2026-10-07, owner: O-6 keep the own package build glue (183 code lines, tested)
  instead of spiking borg (D-015).

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
| D-014 | 2026-10-07 | network only on submodule add / update, owner consents | 12 | owner |
| D-015 | 2026-10-07 | keep own package build glue; borg not revisited by size | 12 | O-6 |
| D-016 | 2026-10-07 | clangd gets the preset build dir (to be superseded, D-023) | 7 | S1 |
| D-017 | 2026-10-07 | active preset: first visible; `C-c l P` switches it | 8 | owner |
| D-018 | 2026-10-07 | eglot refused loudly without database or `-std` | 7 | T-004 |
| D-019 | 2026-10-08 | eglot only in preset projects; library headers via xref | 7 | T-004 |
| D-020 | 2026-10-08 | completion popup on request (TAB, C-M-i) | 1 | owner |
| D-021 | 2026-10-08 | no warm-up through extra open files (memory) | 11 | Q-5 |
| D-022 | 2026-10-08 | Emacs is not run as a long-lived server | 11 | Q-6 |
| D-023 | 2026-10-08 | ccls + clang-tidy hybrid (superseded by D-026) | 7 | O-8 |
| D-024 | 2026-10-08 | clang-tidy trigger for D-023 (superseded by D-026) | 7 | owner |
| D-025 | 2026-10-08 | local clangd tree ~/source/repos/llvm-clangd (O-11) | 11 | owner |
| D-026 | 2026-10-08 | patched clangd via emacs-cpp-clangd-program, loud | 7 | O-11 |
| D-027 | 2026-10-08 | patched clangd packaged to /opt, pinned to LLVM 23.1.1 | 7 | owner |
| D-028 | 2026-10-08 | header compile command from an includer in the index | 7 | O-5 |
| D-029 | 2026-10-08 | `C-c t` toggles treemacs, following the project | 10 | owner |
| D-030 | 2026-10-08 | gdb with full symbols; on-demand symbols as an option | 9 | O-14 |
| D-031 | 2026-10-08 | dape `gdb-preset`: pick a preset program, build, gdb | 9 | T-006 |
| D-032 | 2026-10-08 | gdb scripts (deal.II printers) by option, default none | 9 | O-14 |
| D-033 | 2026-10-08 | `gdb-preset` targets from build.ninja, not a scan | 9 | owner |
| D-034 | 2026-10-08 | built-in which-key-mode on for key hints | 10 | O-16 |
| D-035 | 2026-10-08 | projectile cmake commands use the active preset's dir | 8 | O-17 |
| D-036 | 2026-10-08 | gutter clicks set breakpoints; red marks, stop line lit | 9 | O-18 |
| D-037 | 2026-10-08 | repeat-mode on; only dape's stepping commands repeat | 10 | O-15 |
| D-038 | 2026-10-08 | gc-cons-threshold 64 MB during startup only | 11 | T-008 |
| D-039 | 2026-10-08 | `make packages` builds shipped Texinfo manuals | 12 | T-010 |
| D-040 | 2026-10-08 | default theme only when Customize saved none | 5 | owner |
| D-041 | 2026-10-08 | recentf on; `C-x C-r` picks a recent file | 5 | owner |
| D-042 | 2026-10-08 | diff-hl 1.10.0 vendored, marks in the right fringe | 12 | T-016 |
| D-043 | 2026-10-08 | breadcrumb vendored at bcf7f1d | 12 | T-017 |
| D-044 | 2026-10-08 | gud's prefix on `C-x M-a`, not dape's `C-x C-a` | 9 | O-20 |
| D-045 | 2026-10-08 | Python rides along: ts-mode, pyright, debugpy | 5 | O-19 |
| D-046 | 2026-10-08 | patch 0006: header waits for the project handover | 7 | O-21 |
| D-047 | 2026-10-08 | patch 0007: header wait ends once includers are known | 7 | T-019 |
| D-048 | 2026-10-08 | tree opens with the first project file (option) | 10 | owner |
| D-049 | 2026-10-08 | tree opens only on `C-c t` again (D-048 withdrawn) | 10 | owner |
| D-050 | 2026-10-09 | macOS supported next to Arch Linux | 2 | owner |
| D-051 | 2026-10-09 | lldb supported in addition to gdb | 9 | O-22 |
| D-052 | 2026-10-09 | macOS: patched clangd built by a repository script | 7 | O-23 |
| D-053 | 2026-10-09 | macOS: system tools from MacPorts only | 2 | O-24 |
| D-054 | 2026-10-09 | macOS: eglot watches project files only, at most 500 | 7 | T-021 |
| D-055 | 2026-10-09 | per-platform files: defaults only; mechanics in modules | 5 | T-024 |
| D-056 | 2026-10-09 | debug presets read targets from CMake's file API | 9 | O-25 |
| D-057 | 2026-10-09 | performance budgets measured on Arch only | 11 | O-24 |
| D-058 | 2026-10-09 | make test passes on the machine at hand before a commit | 4 | O-24 |
| D-059 | 2026-10-09 | patch 0008: known includer answered at once (pkgrel 6) | 7 | T-020 |
| D-060 | 2026-10-09 | patch 0009: re-index sources whose shards had errors | 7 | O-27 |
| D-061 | 2026-10-10 | RET: new line indented by clangd; namespace gap upstream | 7 | O-28 |
| D-062 | 2026-10-10 | C++ indentation from plain .dir-locals.el values | 7 | owner |
| D-063 | 2026-10-10 | line numbers in code, text and configuration buffers | 5 | owner |
| D-064 | 2026-10-10 | clangd's out-of-line action left as upstream offers it | 7 | owner |
| D-065 | 2026-10-10 | RET by Emacs's rules; clangd on-type format ignored | 7 | owner |
| D-066 | 2026-10-10 | tab stops at the C++ indent step (M-i, C-x TAB) | 5 | owner |
| D-067 | 2026-10-10 | options to turn off the tree's project, file following | 10 | owner |
| D-068 | 2026-10-10 | warning for a C++ source missing from the database | 7 | owner |
| D-069 | 2026-10-10 | fixes to vendored packages as patch files in the repo | 12 | owner |
| D-070 | 2026-10-10 | tree follows only to version-controlled projects | 10 | owner |
| D-071 | 2026-10-10 | which-key popup after 3 s instead of 1 s | 10 | owner |
| D-072 | 2026-10-10 | `# %%` cells (code-cells), ESS for R; R part SUPERSEDED by D-145 | 12 | O-29 |
| D-073 | 2026-10-10 | line number column keeps its width while scrolling | 5 | owner |
| D-074 | 2026-10-11 | one go-to-anything prompt, measured first (S11) | 10 | O-30 |
| D-075 | 2026-10-11 | go to anything: first letter's cost on deal.II accepted | 10 | O-32 |
| D-076 | 2026-10-11 | go to anything on `M-o` | 10 | O-31 |
| D-077 | 2026-10-11 | go to anything: GC, sort, highlight, delays for speed | 10 | O-33 |
| D-078 | 2026-10-11 | go to anything without consult's `#` | 10 | owner |
| D-079 | 2026-10-11 | consult patch: hidden sources leave the list | 12 | O-34 |
| D-080 | 2026-10-12 | which-key lists narrow keys 0.2 s after `<` in prompts | 10 | O-35 |
| D-081 | 2026-10-13 | `C-c p ?` searches projectile's files, ripgrep on macOS | 12 | O-36 |
| D-082 | 2026-10-13 | `M-o` symbols: the project's; all on `l` | 10 | O-37 |
| D-083 | 2026-10-13 | project symbols capped (10000), URI encoding and case | 10 | owner |
| D-084 | 2026-10-13 | PgDn / PgUp page through vertico's candidates | 10 | owner |
| D-085 | 2026-10-13 | project symbols: one URI matcher for every server | 10 | O-40 |
| D-086 | 2026-10-13 | `M-o` `< l` lists clangd's first 100 for empty input | 10 | owner |
| D-087 | 2026-10-13 | `M-o` symbol requests with `C-c l s`'s timing | 10 | owner |
| D-088 | 2026-10-13 | `M-o` previews after a pause in typing | 10 | O-41 |
| D-089 | 2026-10-13 | macOS: MacPorts, /usr/local/bin on exec-path and PATH | 12 | owner |
| D-090 | 2026-10-13 | LaTeX: AUCTeX from GNU ELPA, texlab, build on `C-c l b`; SUPERSEDED by D-145 | 12 | O-42 |
| D-091 | 2026-10-13 | eglot's form in init-lsp.el; languages register servers | 5 | owner |
| D-092 | 2026-10-13 | clangd with `--rename-file-limit=0` | 7 | O-43 |
| D-093 | 2026-10-13 | CLion's navigation clicks; right-click menu | 10 | O-44 |
| D-094 | 2026-10-13 | clang-tidy fixes, clang-move on `C-c l T` / `M` | 7 | O-43 |
| D-095 | 2026-10-14 | yasnippet, yasnippet-snippets; expand on `C-c y` | 12 | O-45 |
| D-096 | 2026-10-14 | a plain click shows no tooltip; eldoc as before | 10 | O-47 |
| D-097 | 2026-10-14 | patched clang-change-namespace, `C-c l N` | 7 | O-43 |
| D-098 | 2026-10-14 | no module switch; modules load alone (test) | 5 | O-48 |
| D-099 | 2026-10-14 | `M-o` in its own module after init-lsp | 5 | O-49 |
| D-100 | 2026-10-14 | macOS: patched clangd at LLVM 23.1.3, own release | 7 | owner |
| D-101 | 2026-10-14 | LaTeX: `C-c l f` by latexindent, buffer and region; SUPERSEDED by D-145 | 12 | O-51 |
| D-102 | 2026-10-14 | LaTeX: no LyX keys, AUCTeX's own only; SUPERSEDED by D-145 | 12 | O-46 |
| D-103 | 2026-10-14 | latexindent as texlab runs it; indent as AUCTeX's TAB; SUPERSEDED by D-145 | 12 | O-53 |
| D-104 | 2026-10-14 | `make test` in a temporary HOME; REAL_HOME=1 opts out | 4 | O-54 |
| D-105 | 2026-10-15 | symbols in clangd's order; `M-o` ignores case | 10 | O-55 |
| D-106 | 2026-10-15 | `M-o` symbols per server; `C-c l s` keeps kind groups | 10 | O-58 |
| D-107 | 2026-10-15 | untracked output trees in the project's `.gitignore` | 7 | O-59 |
| D-108 | 2026-10-15 | eglot vendored (GNU ELPA mirror) with a watch patch | 7 | O-60 |
| D-109 | 2026-10-15 | fswatch built locally with a no-loss patch | 7 | O-61 |
| D-110 | 2026-10-15 | eglot fswatch backend as DESIGN 7.1 | 7 | O-62 |
| D-111 | 2026-10-15 | file-watch items as DESIGN 7.2 recommends | 7 | O-61 |
| D-112 | 2026-10-15 | spike S14 for mid-word and loose-scope symbols | 10 | O-57 |
| D-113 | 2026-10-15 | symbol matches switched per request, a capability | 10 | O-63 |
| D-114 | 2026-10-15 | clangd patch 0010, real paths, built with T-104 | 7 | O-50 |
| D-115 | 2026-10-19 | Arch file-watch limits kept as they are | 7 | O-64 |
| D-121 | 2026-10-20 | Emacs's own eglot; macOS watch fixes as config Lisp | 7 | O-69 |
| D-122 | 2026-10-20 | MIT license for own work; patch files keep theirs | 2 | owner |
| D-123 | 2026-10-20 | Arch clangd `pkgver` from the installed LLVM (pkgrel: D-150) | 7 | owner |
| D-124 | 2026-10-20 | match tiers as a function (option C), spike S16 first; SUPERSEDED by D-134 | 7 | owner |
| D-125 | 2026-10-20 | compile `lisp/` as DESIGN 11.1, spike S17 first; SUPERSEDED by D-134 | 11 | owner |
| D-126 | 2026-10-20 | DESIGN 1 rows DECIDED with their decisions, gaps kept | 1 | owner |
| D-127 | 2026-10-20 | fswatch backend for eglot on both machines, spike S18 | 7 | O-70 |
| D-128 | 2026-10-20 | stale `lisp/` modules recompiled at startup; SUPERSEDED by D-134 | 11 | O-71 |
| D-129 | 2026-10-20 | standard 2.15.1 `B-n` ids not adopted; `review:` prefix kept | Conventions | owner |
| D-130 | 2026-10-21 | library index through clangd's `--index-file` (O-12 (b)) | 7 | O-12 |
| D-131 | 2026-10-21 | index load started by a request at connect; failures told (O-73 (a)) | 7 | O-73 |
| D-132 | 2026-10-21 | pyright stays; ty when it checks unannotated code; SUPERSEDED by D-140 | 5 | O-72 |
| D-133 | 2026-10-21 | library indexes by the patched package's clangd-indexer, into indexes/ | 7 | T-118 |
| D-134 | 2026-10-21 | `lisp/` stays interpreted; D-124, D-125, D-128 not built (O-74) | 11 | O-74 |
| D-135 | 2026-10-21 | `C-c p s r` is consult-ripgrep; no rg.el / ag.el | 12 | O-38 |
| D-136 | 2026-10-21 | no change-signature tweak; MANUAL 8 by hand (S12 FAIL) | 7 | O-43 |
| D-137 | 2026-10-21 | no hover highlight or pointer change | 10 | O-47 |
| D-138 | 2026-10-21 | mouse buttons 8 / 9: xref back / forward | 10 | O-44 |
| D-139 | 2026-10-21 | no theme following macOS appearance (O-56 closed) | 5 | O-56 |
| D-140 | 2026-10-21 | Python server per platform: ty on Arch, pyright on the Mac | 5 | D-132 |
| D-141 | 2026-10-21 | gaps only inside a word; `M-o` words match the file name (CLion) | 12 | D-120 |
| D-142 | 2026-10-21 | ty return type inference opt-in per project (`.dir-locals.el`) | 5 | O-75 |
| D-143 | 2026-10-21 | ruff as flymake backend and `C-c l f` formatter, no ruff server | 5 | O-75 |
| D-144 | 2026-10-21 | fswatch patch 0005: `Created` once per file on the Mac | 7 | T-125 |
| D-145 | 2026-10-25 | R and LaTeX removed: no ESS, AUCTeX, texlab; Python's cells stay | 12 | owner |
| D-146 | 2026-10-31 | clangd stays; no ast-grep (server, search or flymake) | 7 | O-77 |
| D-147 | 2026-10-29 | unedited buffers follow their files: inotify on Arch, 5 s polling on the Mac | 12 | owner |
| D-148 | 2026-10-29 | the fswatch reverter (T-128) replaces auto-revert in projects if S20 passes | 12 | O-78 |
| D-149 | 2026-10-29 | T-127 reverted until S20's verdict; no auto-revert of the config's own | 12 | owner |
| D-150 | 2026-11-02 | clangd-index-nav `pkgrel` resets to 1 per LLVM release; 23.1.4-1 | 7 | D-123 |
| D-151 | 2026-11-03 | O-78 (e)'s edge cases: no check on a jump, a message for edited buffers, previews pay | 12 | O-78 |
| D-152 | 2026-11-03 | T-128 skips a deleted file; its buffer stays, named in D-151's message | 12 | O-78 |
| D-153 | 2026-11-03 | O-78 (e): VC and diff-hl refresh for shown buffers; S20 `fswatch-shown` first | 12 | O-78 |
| D-154 | 2026-11-03 | O-79 (c): time eglot's sends and the revert's parts under clangd's reparse first | 12 | O-79 |
| D-155 | 2026-11-03 | O-79: T-128 accepts the freeze during clangd's reparse; T-129 finds its cause | 12 | O-79 |
| D-156 | 2026-11-03 | O-79: T-128's queue step waits out the filter; T-130 moves clangd's includer lookup off its main thread | 12 | O-79 |
| D-157 | 2026-11-03 | O-79 (h): test CPU contention (stock with a 1 s gap, patched with `-j=5`) first | 12 | O-79 |
| D-158 | 2026-11-03 | O-79 (k): sample clangd's threads during the stall first | 12 | O-79 |
| D-159 | 2026-11-03 | O-79 (m): sample clangd during the residual write stall, (e) on | 12 | O-79 |
| D-160 | 2026-11-03 | O-79: trace Emacs's side of clangd's input pipe during the residual stall | 12 | O-79 |
| D-161 | 2026-11-04 | O-79 closed: T-128 ships with (e) and a filter that never runs inside itself; T-130 dropped | 12 | O-79 |
| D-162 | 2026-11-04 | T-128's shape: auto-revert outside roots, any frame shows, project.el's root, done when | 12 | D-149, D-151 |
| D-163 | 2026-11-04 | the reverter: VC or `.projectile` roots only; opt-out, globally or per project | 12 | D-162 |
| D-164 | 2026-11-04 | O-80 (b): rerun S18 on the Mac with `current-cpu-time` | 7 | O-80 |
| D-165 | 2026-11-04 | O-80 closed: the Mac's S18 cost recorded, not judged; report to Emacs drafted | 7 | O-80 |
| D-166 | 2026-11-04 | S20 `fswatch-shown` FAIL on Arch, criterion 3; the reverter reverts from a queue | 12 | D-153, O-81 |
| D-167 | 2026-11-04 | O-81 (b): S20 mode `fswatch-chunked` first, a time budget per revert step | 12 | O-81 |
| D-168 | 2026-11-04 | (confirmed through D-169) the reverter's steps: one timer, reverts first, never a revert and a refresh in one step | 12 | D-167 |
| D-169 | 2026-11-04 | O-82 (b): a shown buffer's refresh before the remaining reverts | 12 | D-168, O-82 |
| D-170 | 2026-11-04 | O-76 (a): no Julia support; D-145's scope stands | 2 | O-76 |
| D-171 | 2026-11-04 | O-68 (c): gap trigrams and a third match tier in clangd, behind spike S19 (superseded by D-175) | 10 | O-68 |
| D-172 | 2026-11-04 | S19 on hp-elitedesk: deal.II cloned, criteria 4 - 5 as ratios, RMO's half later | 10 | D-171, T-132 |
| D-173 | 2026-11-04 | S19's tier 3 is D-120's: gap trigrams within letter-digit runs; `cml` struck | 10 | D-120, D-171, D-172 |
| D-174 | 2026-11-04 | O-83 (b): S19 criterion 6 on RMO-drafts, each key at most twice pkgrel 1's and 30 ms | 10 | O-83, D-172 |
| D-175 | 2026-11-04 | O-84 (a): no clangd patch 0014; gapped in-word symbol queries stay unfound | 10 | O-84, D-171 |
| D-176 | 2026-11-04 | the reverter's filter keeps one lookup per record (0120's dedupe not taken) | 12 | D-168 |
| D-177 | 2026-11-05 | O-85 (f): projectile's lists cached per root, checked by directory times (superseded by D-179) | 12 | O-85, T-133 |
| D-178 | 2026-11-05 | the kept project file lists are opt-out (`emacs-cpp-keep-project-files`) (superseded by D-179) | 12 | D-177, D-163 |
| D-179 | 2026-11-05 | T-133 reverted: no call slower than today's listing; supersedes D-177, D-178 | 12 | O-85 |
| D-180 | 2026-11-05 | ty on the Mac from a local binary MacPorts port in `packaging/macports` | 5 | O-86 |
| D-181 | 2026-11-05 | local ports read from a root-owned copy under MacPorts' `sources/`, not the repository | 5 | O-87 |
| D-120 | 2026-10-20 | LSP 3.18's letters-in-order match, tiers, every prompt | 10 | owner |
| D-119 | 2026-10-19 | spike S15: mid-word matches ranked by shape in clangd | 10 | O-67 |
| D-118 | 2026-10-19 | `M-o`'s project symbols headed "Project Symbol" | 10 | O-66 |
| D-117 | 2026-10-19 | eglot patch 0003: finders with Emacs 31's xref | 7 | O-65 |
| D-116 | 2026-10-19 | `make packages` resets patched files; pins checked | 12 | owner |

## Parity verdicts (from RESEARCH_*.md)
Per row in section 1 (D-126). From research: refactorings, `RESEARCH_refactoring.md`
(change signature, inline, pull members up stay gaps; S12 FAIL). Not researched yet:
static analysis against CLion's data flow, the debugger's memory view.

## Conventions
ASCII; no invented abbreviations; commits with Reasoning and tier; journal with code;
tests with logic; docs-sync same commit and `docs-check` before a docs commit; decisions
cite D-nnn; Makefile/justfile default target = help.

- DECIDED D-129 (owner 2026-10-20, standard 2.15.1: "Ignore B- standard"): the
  standard's `B-n` benchmark ids (its rule 16, upgrade step 8) are not adopted; past
  timed runs keep their spike names (`S11 run 4`), no "Benchmarks by id" table. Another
  document's look-alike ids carry its prefix (`review:B-6`) only so `docs-check`'s
  check 5b, which ships with the tooling, passes.
