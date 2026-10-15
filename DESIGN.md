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
- Code completion -> corfu + eglot completion-at-point, on request with TAB or `C-M-i`
  (D-020). Gap: none. DECIDED.
- Inlay / parameter hints -> `eglot-inlay-hints-mode`. Gap: none. PROPOSED.
- Reformat -> `eglot-format-buffer` (clangd reads `.clang-format`). Gap: none. PROPOSED.
- Switch header / source -> `projectile-find-other-file`. Gap: name-based, not
  clangd-based. PROPOSED.
- Search everywhere, go to file / symbol / action -> vertico + orderless + marginalia +
  consult: `projectile-find-file`, `consult-buffer`, `consult-eglot-symbols`,
  `consult-imenu`, `consult-ripgrep`, `M-x`; one combined prompt on `M-o` (D-074 ..
  D-078, T-049): buffers, recent files, bookmarks, project files, clangd symbols,
  commands and projects behind narrow keys. Gap: no settings or git items. PROPOSED.
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

## 3. Owner constraints (filled 2026-10-07)
Observed on the owner machine, 2026-10-07:
- Arch Linux, Emacs 31.1 (native-comp, treesit available), 16 cores, 31 GB RAM.
- clangd 22.1.8 at the survey, 23.1.1 by the S1 run the same day (rolling release; the
  design must not depend on one clangd version), clang-tidy, clang-format, gcc, clang,
  gdb 17.2, lldb-dap, cmake 4.4.3 (ships `/usr/share/emacs/site-lisp/cmake-mode.el`),
  ninja, fd, valgrind, rsync, python3. Not installed: ripgrep (corrected 2026-10-07:
  the survey's `which rg` found a shell function, not a binary), bear, cppcheck, GNU
  time.
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
  does, as init-cpp and init-latex do, and the test `init-modules-load-alone` loads
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
  through eglot in project files, debugpy through dape's own config; all from the Arch
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
| block | location | tag | notes |
|---|---|---|---|
| early init | `early-init.el` | KEEP | T-002, owner-confirmed |
| platform defaults | `lisp/defaults-<platform>.el` | PROTOTYPE | T-031 (D-055) |
| init | `init.el` | KEEP | T-002, replaces `~/.emacs` (D-003) |
| packages | `lib/<repo>/` submodules | KEEP | 31 repositories after T-065 (section 12) |
| clangd, macOS | `packaging/clangd-index-nav/build-macos.sh` | PROTOTYPE | T-023, D-052 |
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
| R | `lisp/init-r.el` | PROTOTYPE | T-046: ESS, no eglot (D-072) |
| LaTeX | `lisp/init-latex.el` | PROTOTYPE | T-065: AUCTeX, texlab (D-090) |
| cells | `lisp/init-cells.el` | PROTOTYPE | T-046: code-cells, Python and R (D-072) |
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
  Arch only; on macOS D-052.
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
  the PKGBUILD. Arch stays at 23.1.1, pacman's LLVM (D-027): each platform follows its
  system's LLVM, so the two releases can differ. Amends D-052. Patches 0001 - 0009
  apply to 23.1.3 without fuzz; clangd's sources differ from 23.1.1 only in
  `CodeComplete.cpp` and its test. Built (T-073, 0067).
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
- DECIDED D-096 (owner 2026-10-14, O-47 (c2) asked, then "leave as-is, close"): a
  plain click on a symbol gets no tooltip or child frame; as before, eglot's hover
  for the symbol at point reaches the echo area through eldoc 0.5 s after the click
  (`RESEARCH_mouse.md` 6). Options c1 - c4 closed. O-47 (a), the hover highlight,
  stays open for further research on its performance.
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
- DECIDED D-072 (owner 2026-10-10, O-29 (a), (b)): `# %%` cells in Python and R
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
- DECIDED D-090 (owner 2026-10-13, O-42 (b): "texlab with build key, texlab + AUCTeX,
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
- DECIDED D-101 (owner 2026-10-14, O-51 (a), then "use latexindent for both buffers and
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
- DECIDED D-102 (owner 2026-10-14, O-46: "none"): no LyX keys. LaTeX buffers keep
  AUCTeX's own keys (option (c)); Emacs's and Emacs.app's bindings stay as they are
  on both machines (`RESEARCH_latex.md` 8). Options (a) and (b) closed.
- DECIDED D-103 (owner 2026-10-14, O-53 (a), (b), (d); done when agreed; amends D-101):
  latexindent for `C-c l f` and Format Buffer gets `--local` and runs in the directory
  texlab 5.25.1 uses: the nearest directory upward, within the project, with
  `.latexmkrc`, `latexmkrc`, `.texlabroot` or `texlabroot`, else the file's own; so a
  project's `localSettings.yaml` / `latexindent.yaml` (dotted or not) applies as it does
  through texlab. With neither such a file there nor a user `indentconfig.yaml` (`~/`,
  `~/.`, `~/.config/latexindent/`) it adds `-y=defaultIndent:` with `LaTeX-indent-level`
  spaces, a tab with `indent-tabs-mode`, so `C-c l f` indents with the characters
  AUCTeX's `TAB` uses (texlab ignores the request's `insertSpaces`). texlab's slow
  `exit` right after opening stays as it is (O-53 (5), (d)). Built (T-078, 0070).
- DECIDED D-095 (owner 2026-10-14, O-45 (b), keys (k2); done when agreed): yasnippet
  (GNU ELPA's `externals/yasnippet`, pinned dd570a6 = 0.14.3) and yasnippet-snippets
  (NonGNU ELPA's `elpa/yasnippet-snippets`, pinned 606ee92, the branch's tip of
  2025-12-15: its 1.0 release commit 39e640c has no `c++-ts-mode` / `python-ts-mode`
  directories, added upstream 2024-01), two submodules (network fetch at clone,
  D-014). yasnippet is on in `prog-mode`, `LaTeX-mode` and `bibtex-mode` buffers
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
  taken out whole, in reverse, then applied whole; `git apply` changes nothing unless
  every patch fits, so a series that no longer applies (a pin bump, a hand edit) stops
  the build with git's message. A listed patch that is missing and a patch file no
  `patch` line lists are build errors. A patched submodule shows "modified content" in
  `git status`, on purpose (no `ignore = dirty`, which would hide hand edits too).
  Rejected: a commit in the submodule (on no remote, a fresh clone breaks), a fork
  (network, upkeep; reconsider for many long-lived changes), and Lisp workarounds
  beyond a line or two (they lean on the package's internals). First patch:
  treemacs 0001, T-041, replacing D-067's stand-in timer. Second: consult 0001 (D-079).
  Third: projectile 0001 (D-081). Later: auctex 0001 (D-090), yasnippet-snippets 0001
  (D-095).
- DECIDED D-089 (owner report 2026-10-13, tier 1): on macOS the config puts
  `/opt/local/bin`, `/opt/local/sbin` (MacPorts, D-053) and `/usr/local/bin` (CRAN's
  R) in front of `exec-path` and PATH at startup when missing
  (`emacs-cpp-default-exec-path-prepend`, D-055; none on Arch). Emacs started from
  the Dock or Finder got launchd's PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) although
  Emacs.app's Info.plist sets `LSEnvironment` PATH, so D-081's check stopped startup
  ("rg is not on exec-path"), and cmake, ninja, pyright would not have been found
  either. Test: a child Emacs with launchd's PATH loads the config and finds its
  search program (fails without the fix). Amended 2026-10-13 (owner report "LaTeX found
  no preview images", tier 1): `/Library/TeX/texbin` (MacTeX, D-090) joins the list;
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
  DESIGN 3); a missing executable stops startup. git-ignored files (build
  directories) are no longer searched, as in `C-c p f`. Measured on the Mac, deal.II
  (33768 files): 130 - 156 s before, 10.6 - 11.3 s after, the same 607 / 9429
  matches; `rg` alone in the tree 5.5 - 6 s, the floor there, set by about 14 ms per
  file opened (O-24). Arch not measured (owner). After the owner's GDATA exceptions
  (2026-10-13): 4.8 - 5.5 s; the rest is `rg` given file names, which searches
  them one after another (7 runs of 5000 by BSD `xargs`: 4.7 s; `xargs -P 4` 3.7 s),
  while `rg` or `git grep --untracked` searching the directory take 1.1 - 1.4 s
  (a different file set at the edges: rg's own ignore rules, hidden files). Not
  changed; a next step if the 5 s matter. Upstream report drafted
  (`docs/upstream/projectile-find-references-file-list.md`), the owner sends it.
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
    corfu, cape (vendored by T-003); consult-eglot v0.5.0 (T-004).
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
- O-50 (OPEN, found 2026-10-14 in S12, finding 6): in a project under `/tmp` on
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
- O-58 (OPEN, owner 2026-10-15 approving T-084, T-086): order of several servers'
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
- O-57 (OPEN, owner 2026-10-15 with D-105: "research Optional", T-085): the symbol
  matches CLion makes and clangd refuses (`RESEARCH_go_to_anything.md` 16): mid-word
  (`ector`; clangd's trigrams admit it, only its matcher refuses), a gap inside a
  word (`cml`; its trigrams refuse it), a loose qualifier (`geom::vec`; only the
  scope check in `FindSymbols.cpp` refuses). Options: (a) loose qualifier in `M-o`
  only, no clangd change; (b) patch 0010, loose qualifier in clangd; (c) patch,
  mid-word for 3+ letters under a request field; (d) gaps inside a word, largest
  cost; (e) none. A clangd patch is tier 3: spike first. Owner rules.
- O-56 (OPEN, owner request 2026-10-15, T-082): a theme following macOS's dark / light
  setting (`RESEARCH_dark_theme.md`). Found: the NS build of Emacs 31.1 sets no
  `toolkit-theme` and runs no hook on a change; `defaults read -g
  AppleInterfaceStyle` reads it in 6.4 ms. Options: (a) once at startup, (b) and
  polling, (c) and a command, (d) auto-dark package, (e) another Emacs build. Owner
  rules; Arch is stage 2.
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
- O-47 (OPEN, owner request 2026-10-14: "visual indicator when hovering over a
  symbol, and/or mouse pointer that changes when pressing a modifier"): findings in
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
- O-44 (OPEN, owner request 2026-10-13: "research additional mouse bindings, e.g.
  Command+M1 for going to symbol (M-.), compare to Clion key+mouse bindings"):
  findings in `RESEARCH_mouse.md`. Cmd+Click (`s-<mouse-1>`) is unbound; Emacs has
  `xref-find-definitions-at-mouse` / `xref-find-references-at-mouse`, and
  `context-menu-mode` (off) would put both in a right-click menu. Options: (a)
  Cmd+Click definition, a second click for references, Cmd+Opt+Click implementation,
  Cmd+Shift+Click type (Ctrl on Arch); (b) `context-menu-mode`; (c) back / forward on
  the mouse's side buttons, after checking their events; (d) none. Owner 2026-10-13:
  (a) and (b2) built as D-093; (c) waits for the owner's `C-h k` on a side button.
- O-43 (OPEN, owner request 2026-10-13: "research further C++ refactorings from
  CLion, e.g. signature change, refactor in project files"): findings in
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
- O-39 (OPEN, owner request 2026-10-13: "research R language servers"): findings in
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
- O-38 (OPEN, owner 2026-10-13: "vendor rg.el / ag.el if no downsides"): `C-c p s a`
  (projectile-ag) and `C-c p s r` (projectile-ripgrep) stop with "not available":
  they need the Emacs packages ag.el / rg.el, not vendored. Downsides found: rg.el
  2.5.0 also needs wgrep (a third new submodule; transient is built in); Arch has
  no `rg`, and once rg.el loads, projectile's `auto` search backend (`C-c p s s`)
  picks ripgrep there and fails, so `projectile-search-backend` would need a
  per-platform value (D-055); ag.el 0.48 needs dash and s (vendored) and the `ag`
  program (on the Mac in MacPorts, on Arch not surveyed). Each is a new dependency
  (needs its D-nnn) and a network clone. `M-s r` (consult-ripgrep) and `M-s G`
  (consult-git-grep) already search. Owner rules.
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
- O-12 (OPEN, owner 2026-10-09: run S10 on Arch, `spikes/s10-library-index/RUN.md`;
  owner 2026-10-08: adopt, spike S10 first; T-020 folded into the same
  clangd rebuild): S10 dry run (synthetic project): the patched clangd with the deal.II
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
| D-072 | 2026-10-10 | `# %%` cells (code-cells), ESS for R | 12 | O-29 |
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
| D-090 | 2026-10-13 | LaTeX: AUCTeX from GNU ELPA, texlab, build on `C-c l b` | 12 | O-42 |
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
| D-101 | 2026-10-14 | LaTeX: `C-c l f` by latexindent, buffer and region | 12 | O-51 |
| D-102 | 2026-10-14 | LaTeX: no LyX keys, AUCTeX's own only | 12 | O-46 |
| D-103 | 2026-10-14 | latexindent as texlab runs it; indent as AUCTeX's TAB | 12 | O-53 |
| D-104 | 2026-10-14 | `make test` in a temporary HOME; REAL_HOME=1 opts out | 4 | O-54 |
| D-105 | 2026-10-15 | symbols in clangd's order; `M-o` ignores case | 10 | O-55 |

## Parity verdicts (from RESEARCH_*.md)
None yet; see section 1 (R) rows.

## Conventions
ASCII; no invented abbreviations; commits with Reasoning and tier; journal with code;
tests with logic; docs-sync same commit and `make check` before commit; decisions cite
D-nnn; Makefile/justfile default target = help.
