# RESEARCH - key hints, building from any buffer, breakpoint indicators

Questions (owner, 2026-10-08, during T-006):
1. Visual indicators for key sequences such as `C-c p p` (compare org mode's keys).
2. `C-c p c c` works only from a build directory; CLion builds from any open buffer.
   Is that what `C-x C-a b` is meant to cover?
3. Visual indicators for breakpoints.
Findings only; verdicts go to DESIGN (O-16, O-17, O-18). Checked against Emacs 31.1,
projectile v3.4.0, dape 0.27.1 and the RMO checkout (read only). CLion behaviour is
from its documentation as remembered, not measured here.

Short answer to 2: no. `C-x C-a b` is `dape-breakpoint-toggle`. `gdb-preset` (D-031,
D-033) builds only the target it is about to debug, and only on `C-x C-a d`. Building
from any buffer is T-005 (DESIGN 8), see section 2.

## 1. Key hints
What exists today:
- `C-h` after any prefix (`C-c p C-h`) runs `embark-prefix-help-command`
  (`lisp/init-completion.el`): a completing list of that prefix's keys, filtered as
  you type. Nothing appears unless asked.
- `which-key` is built into Emacs since 30 (`/usr/share/emacs/31.1/lisp/which-key.elc`)
  but `which-key-mode` is not turned on anywhere in `lisp/`. T-007's done-when ("which-key
  lists every DESIGN 10 key") already assumes it.
- Projectile 3.4 ships a transient menu, `projectile-dispatch`, on `C-c p m`: every
  projectile command in groups (Find, Buffers, Search / Replace, Project, Lifecycle,
  Subproject, Shells / Run, Session, Cache) with its key, plus switches (`-i`
  invalidate cache, `-d` display in another window). It is the style of magit's `?`
  menu.
- dape has no menu of its own; its `C-x C-a` map has 29 keys (`d b n s o c r ...`).

Org mode, for comparison: its menus for export (`C-c C-e`) and agenda (`C-c a`) are
dispatchers: a window with one line per choice and a single key each, shown at once
(not after a delay). That is the transient style, not the which-key style.

Compared:
- `which-key-mode`: shows after any prefix once `which-key-idle-delay` (1 s) passes;
  covers every prefix, also `C-x C-a` and `C-c l`; built in, one line of config.
- A transient menu: shows at once, on its own key; covers one package's commands;
  exists for projectile, would be one menu to write per other prefix.
- `C-h` after a prefix: on request; every prefix; exists.

- PROPOSED (O-16): turn on `which-key-mode` (built in, no package, no network;
  `which-key-idle-delay` left at 1 s, so it shows only when you hesitate), keep
  `C-h` for searching, and list `C-c p m` in the cheat sheet. Own transient menus
  (for `C-c l` or dape) only if which-key is not enough.

## 2. Building from any buffer
What `C-c p c c` (`projectile-compile-project`) does today, for RMO's `src/main.cc`:
- project type `cmake`, run in the project root, default command
  `cmake --build build` (`projectile--cmake-manual-command-alist`), because
  `projectile-enable-cmake-presets` is nil (DESIGN 8 only PROPOSED turning it on).
- RMO's `build/` holds only `debug/` and `release/` (presets' `binaryDir` is
  `${sourceDir}/build/${presetName}`), so the default command cannot work. Edited by
  hand (`--build build/debug`) it works, and projectile then remembers the edited
  command per project.
- With `projectile-enable-cmake-presets` t the command becomes `cmake --build --preset
  debug`, after a "Use preset:" prompt (`debug`, `release`, `*no preset*`) on every
  run. That prompt is independent of the active preset (D-017, `C-c l P`), so eglot
  can follow `debug` while the build goes to `release`.

CLion: Build (`Ctrl+F9`) builds the target of the selected run configuration in the
selected CMake profile, from any editor tab; profile and target are shown in the
toolbar and changed there.

Facts for a design:
- The active preset's build directory is already known (`emacs-cpp-presets-binary-dir`,
  D-016); `cmake --build <binaryDir> [--target T]` needs no build preset and works in
  any directory.
- The executable targets come from build.ninja (D-033, `emacs-cpp-debug-programs`,
  today in `lisp/init-debug.el`); libraries and custom targets are not in that list.
- Ninja passes absolute source paths to the compiler in RMO's build.ninja
  (`/home/alad/source/repos/RMO-gross-pitaevskii/src/main.cc`), so compiler errors
  jump to the source from any compilation directory (T-005's done-when).
- Projectile allows replacing a project type's command with a function
  (`projectile-update-project-type 'cmake :compile FUNCTION`); `C-c p c c` and its
  history and per-project compilation buffer would then stay.

- PROPOSED (O-17), for T-005: `C-c p c c` builds the active preset from any buffer of
  the project (`cmake --build <binaryDir>`), shown at the prompt so it can be edited
  (`--target X`); `C-c p c t` runs `ctest --test-dir <binaryDir>`; `C-c p c o`
  configures the active preset (`cmake --preset <name>`). A target picker (as in
  `gdb-preset`) and the active preset in the mode line (CLion's toolbar) are
  options for the owner. The build.ninja reader then moves to `emacs-cpp-presets.el`.

## 3. Breakpoint and current-line indicators
What dape 0.27.1 draws:
- A breakpoint: in a graphical frame the fringe bitmap `breakpoint` (an 8x8 filled
  circle from `gdb-mi.el`, which dape requires),
  in a terminal the string `dape-breakpoint-margin-string` ("B") in a 2-column left
  margin (seen in the T-006 tmux check). Face `dape-breakpoint-face`, which inherits
  `font-lock-keyword-face`: the theme's keyword colour, not CLion's red. Log,
  expression, hits and until breakpoints have their own faces (`dape-log-face` ...).
- Clicking the fringe or margin (mouse-1 toggle, mouse-2 condition, mouse-3 log) works
  only with `dape-breakpoint-global-mode`, which is off in this config.
- The stopped line: an overlay arrow (`=>` in a terminal, a triangle in the fringe)
  and the face `dape-source-line-face`, which is empty: the line itself is not
  highlighted. CLion highlights the execution line (blue) and draws red dots.

- PROPOSED (O-18): turn on `dape-breakpoint-global-mode` (click the gutter like
  CLion); give `dape-breakpoint-face` the theme's error colour (red) and
  `dape-source-line-face` the theme's highlight background, both through
  `modus-themes` colour names so they follow the theme. Kept: the fringe circle in
  the GUI, "B" in a terminal.

## 4. Not checked
- which-key with dape's repeat map (O-15) and with transient menus.
- `ctest --test-dir` on RMO (its CMakeLists registers 6 tests with `add_test`; not run).
- How the fringe circle looks at the owner's font size.
