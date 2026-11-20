# 0140 - T-150: an icon tool bar for the common commands

- **Date:** 2026-11-20
- **Commits:** the commit carrying this entry
- **Tier:** 2
- **Decisions:** D-210 (resolves O-92 with option (b))
- **Done when:** (1) after startup the frame's tool bar shows six buttons (sidebar, go to
  anything, text search, git status, build, debug), Emacs's stock buttons none; (2) each
  tooltip names the key of its command and the key runs that command; (3) while a debug
  session runs, Debug gives way to continue, step over, step into, step out and stop, the
  steps greyed out unless the program is stopped, and dape is not loaded for it;
  (4) `make test` passes on the Mac and startup there is measured before and after;
  (5) on Arch `make test` passes and startup stays within the 0.5 s budget (H-39);
  (6) the owner has looked at the bar on both machines (H-39). The session wrote this
  line from O-92's recommendation, which the owner took with "O-92 (b)".

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The configuration had no button anywhere: every command was a key, a which-key list or
an entry of the right-click menu. The owner asked for an icon bar for the commands used
all day. No package offers one for magit, projectile and dape together
(RESEARCH_icon_toolbar 7), so `lisp/init-toolbar.el` (new, the last module) fills Emacs's
own tool bar with eleven buttons of its own and turns the bar on once startup is over.

The icons are eleven SVG files of the Lucide set (release 1.69.0, ISC license) copied
into `icons/lucide/`. They are line drawings with no color of their own: the file says
`currentColor`, and the module puts the theme's text color there before handing the
picture to Emacs. A theme change draws them again.

On the Mac the bar is the window's own toolbar, in the title area, which macOS paints
light or dark by the system's setting, not by Emacs's theme. With the dark default theme
on a light system the icons would have been white on a light bar. So the module also
sets each frame's `ns-appearance` to the theme's side, dark or light: the title area now
follows the theme. That is a visible change beyond the bar and is part of D-210.

## Concepts (Emacs Lisp) explained
- **`tool-bar-map`**: a keymap whose entries are not keys but buttons. Each entry is a
  "menu item": a label, a command, and properties such as `:image`, `:help` (the
  tooltip), `:visible` and `:enable`. Emacs evaluates the last two each time it redraws
  the bar, which is how the debugger's buttons appear and grey out by themselves.
- **`fboundp`**: "is a function of this name defined?". dape loads only at its first
  use. Its function `dape--live-connection` therefore does not exist before, and the
  bar's state checks answer "no session" without loading anything.
- **`with-eval-after-load`**: code that runs once a package has loaded. Here it checks
  that dape still has the internal function the bar reads, and asks dape to tell the bar
  when its state changes (`dape-update-ui-hook`).
- **`create-image` with data**: an image made from text in memory, here the SVG with the
  color filled in, not from a file name.
- **`after-init-hook`**: functions run when `init.el` has finished. The theme is loaded
  there; the bar is set up after it, so the icons take the theme's color at once.

## Key files walked
- `lisp/init-toolbar.el` - `emacs-cpp-toolbar-items` is the table of buttons (id, label,
  command, key, icon, when shown); `emacs-cpp-toolbar--map` turns it into the keymap;
  `emacs-cpp-toolbar-refresh` rebuilds it for the current theme;
  `emacs-cpp-toolbar-setup` runs after startup and stops with an error if this Emacs
  cannot draw SVG.
- `icons/lucide/` - the eleven icons and Lucide's `LICENSE`.
- `early-init.el` - still draws the first frame without a bar, so Emacs never builds
  its stock buttons; only the comment changed.
- `init.el` - requires the module last: it names commands of the modules above it.
- `test/init-toolbar-test.el` - seven tests: the bar after startup, each button's icon,
  command and key, the debugger states through a stub, colors, a missing icon.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a title area that follows the theme is wanted on the Mac. **Would break
  if:** the owner prefers the system's appearance there; then the icons need the
  system's side instead, which Emacs 31.1 does not report (`ns-system-appearance` is
  not bound). **DESIGN bet:** D-210.
- **Assumed:** on Arch the GTK bar is dark under the dark theme, or the icons still show
  on it. **Would break if:** the desktop's GTK theme is light: white icons on a light
  bar. `emacs-cpp-toolbar-icon-color` is the way out. **DESIGN bet:** D-210; H-39 looks.
- **Assumed:** dape keeps `dape--live-connection` with the types `parent` and `stopped`.
  **Would break if:** a pin bump renames it; the check after dape loads then stops with
  the file to fix. **DESIGN bet:** D-210.
- **Assumed:** dape runs `dape-update-ui-hook` at every change of state the bar shows.
  **Would break if:** a session ends without it; the buttons would then change at the
  next redraw of the bar. Not tried with a real session. **DESIGN bet:** D-210.
- **Assumed:** the bar costs startup little on Arch. Measured on the Mac only, in a
  terminal Emacs, which draws no bar: median 0.508 s before, 0.497 and 0.508 s after
  (10 runs each, load average about 6, so within the noise); building the map takes
  2.4 ms. The drawing of the bar in a graphical frame is unmeasured. **Would break if:**
  Arch crosses 0.5 s. **DESIGN bet:** D-057; H-39 measures.
- **Assumed:** the bar appearing after startup does not disturb. **Would break if:** the
  frame visibly jumps when the GTK bar is added on Arch (on the Mac the bar takes no
  rows of the frame, measured). H-39 looks.

## How to verify
- `make test </dev/null`: 197 tests, 2 skipped on the Mac, the seven `init-toolbar-*`
  among them.
- Start Emacs: six icons at the top; hover for the tooltips; click each.
- `C-x C-a d` in a C++ project: the debugger's five buttons replace Debug.
- How it looks, and everything on Arch: H-39.

## Open questions (optional)
None.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: rule 31, the search found lucide-toolbar, whose tinting of `currentColor` the
  module follows.
- Never applied: spike rule, tier 2.
