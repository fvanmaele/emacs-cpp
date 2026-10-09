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

## 5. Load model (the core contract)
- `early-init.el`: frame / UI settings, startup garbage-collection threshold,
  `package-enable-at-startup` nil. Nothing else.
- `init.el`: adds the generated load path and autoloads (below), loads `use-package`
  and sets its defaults, then `require`s `lisp/init-*.el` in a fixed, listed order.
  Module order is the contract; a module may depend only on modules loaded before it.
- Each module ends with `(provide 'init-<name>)`; a missing module is a load error.
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

## 6. Architecture
| block | location | tag | notes |
|---|---|---|---|
| early init | `early-init.el` | KEEP | T-002, owner-confirmed |
| platform defaults | `lisp/defaults-<platform>.el` | PROTOTYPE | T-031 (D-055) |
| init | `init.el` | KEEP | T-002, replaces `~/.emacs` (D-003) |
| packages | `lib/<repo>/` submodules | KEEP | 28 repositories after T-017 (section 12) |
| clangd, macOS | `packaging/clangd-index-nav/build-macos.sh` | PROTOTYPE | T-023, D-052 |
| package build | `scripts/build-packages.el` | KEEP | T-002, `make packages` |
| theme | `lisp/init-ui.el` | KEEP | T-002 |
| writing | `lisp/init-writing.el` | KEEP | T-002: markdown, org-journal |
| completion UI | `lisp/init-completion.el` | KEEP | T-003, owner-confirmed |
| project, tree | `lisp/init-project.el` | KEEP | T-002: projectile, treemacs |
| C++, LSP | `lisp/init-cpp.el` | PROTOTYPE | T-004: c++-ts-mode, eglot |
| presets | `lisp/emacs-cpp-presets.el` | PROTOTYPE | T-004: D-016 - D-018 |
| CMake build | `lisp/emacs-cpp-presets.el`, projectile form | PROTOTYPE | T-005 (D-035) |
| CMake mode | `lisp/init-cmake.el` | PROTOTYPE | system cmake-mode (D-013) |
| Python | `lisp/init-python.el` | PROTOTYPE | T-018: ts-mode, pyright, debugpy (D-045) |
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
  PKGBUILD's sha256; the same patches; clang and clang-tools-extra built with CMake and
  Ninja from MacPorts (D-053); clangd and its builtin headers installed to
  `~/opt/clangd-index-nav`, a directory outside the repository. Self-contained, not
  built against the system LLVM as D-027: MacPorts' `llvm-23` is 23.1.3, not 23.1.1.
  Extends D-014: the script downloads the tarball, only when the owner runs it.
  Built in T-023 (0036, 2026-10-09): `packaging/clangd-index-nav/build-macos.sh` reads
  version, patches and checksums from the PKGBUILD; `--tarball` uses a downloaded
  file. Test run on the Mac: 14 min wall, 3.3 GB build tree; the clangd links
  MacPorts' libedit, zlib and zstd.
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
- DECIDED D-034 (owner 2026-10-08, O-16): built-in `which-key-mode` is on: after any
  prefix (`C-c p`, `C-x C-a`, `C-c l`) its keys appear once you pause 1 s
  (`which-key-idle-delay` default); `C-h` after a prefix still searches them (embark);
  projectile's own menu stays on `C-c p m`. Turning it on costs about 11 ms at start.
- DECIDED D-029 (owner 2026-10-08): `C-c t` toggles the project tree; treemacs runs
  `treemacs-project-follow-mode`, so the tree shows only the project of the selected
  buffer (projectile's, via treemacs-projectile) and follows it. Not opened at startup
  (in force again with D-049). `C-c t` opens with the current project directly
  (`treemacs` alone asks for a root while the workspace is empty). `C-x t t` stays
  Emacs's tab-bar key.
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
  transient, compat, seq, cl-lib, org, which-key. Vendored, 28 repositories (26 to T-016):
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
| own package build glue mis-orders compilation | none (tests) | - | v0.1 |
| config fails on macOS (paths, tools, tests) | none (`make test`) | owner | D-050 |
| clangd too slow / too large on deal.II scale | S1 numbers | owner | v0.1 |

## Research program
- `RESEARCH_other_languages.md` (owner question 2026-10-08): Python, R, Perl next to
  the C++ setup. Findings in; rulings O-19, O-20.
- `RESEARCH_navigation_delays.md` (owner question 2026-10-09): where `M-.` on names
  spends its time on the Mac; stale "indexed with errors" shards. Findings in; O-27.
- `RESEARCH_python_macos.md` (owner request 2026-10-09, T-025): pyright and five
  alternatives through eglot, debugpy's start against dape's wait. First round in;
  no ruling asked yet.
- `RESEARCH_file_watches_macos.md` (owner question 2026-10-09, T-029): kqueue's
  descriptor per watch, Emacs's limits on the Mac, who watches in a C++ session.
  Findings in; O-26 ruled (D-054 confirmed, upstream report T-032).
- `RESEARCH_keys_build_debug_ui.md` (owner questions 2026-10-08): key hints, building
  from any buffer, breakpoint indicators. Findings in; rulings O-16, O-17, O-18.
- `RESEARCH_refactoring.md`: which CLion refactorings clangd code actions cover in
  clangd 22 (fills the (R) rows of section 1). After v0.1.

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
  are the suspects, not measured).
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
  Services holds 975 watches, as a terminal start does (`RESEARCH_file_watches_macos.md`
  1). New: at eglot's cap eglot fails the whole watch request and pyright exits,
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

## Parity verdicts (from RESEARCH_*.md)
None yet; see section 1 (R) rows.

## Conventions
ASCII; no invented abbreviations; commits with Reasoning and tier; journal with code;
tests with logic; docs-sync same commit and `make check` before commit; decisions cite
D-nnn; Makefile/justfile default target = help.
