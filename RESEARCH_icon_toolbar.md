# RESEARCH - An icon toolbar for the common commands

Question (owner, 2026-11-20): "meaningful icon toolbar for common functionality (magit,
M-o, M-s r, C-c p c c, debug, sidebar, etc.)". Findings only; verdicts go to DESIGN
(O-92).

Sources, read 2026-11-20: Emacs 31.1's own files on the Mac (`tool-bar.el`,
`window-tool-bar.el`, `etc/images/`, `etc/NEWS.30`, `tab-bar-format`'s docstring);
`src/nsmenu.m` of Emacs's `emacs-31` branch; lucide-toolbar (a63c1ff, 2026-10-28) and
visual-emacs (a9a2622, 2025-04-03), cloned and read; Lucide's and Codicons' repositories
(icon files by name, licenses); CLion's help "User interface"; one trial in a graphical
`emacs -Q` on the Mac (section 5). Nothing run on Arch.

## 1. Today
- The tool bar is off: `early-init.el` sets `tool-bar-lines` 0 and `tool-bar-mode` nil,
  as the owner's earlier config did (DESIGN 3). The menu bar is on. No tab bar.
- Commands are reached by keys, which-key after a prefix (D-071), `M-o` (`x` narrows to
  commands) and the right-click menu (D-093).
- No vendored package defines a tool bar (`tool-bar-map`, `tool-bar-add-item`,
  `tool-bar-local-item`: no hit under `lib/`). dape, magit, treemacs and projectile
  bring none.

## 2. CLion
- The window header holds three widgets, left to right: "Project widget" (switch
  project), "VCS widget" (branch, common VCS actions), "Run widget" (pick a
  configuration, run, debug). It is customizable.
- The classic main toolbar (open, save, undo, redo) is hidden by default.
- Tool windows (Project, Terminal and others) open from icons on the left, right and
  bottom bars.
- So CLion's default icons cover: project tree, git, run / debug, search. The owner's
  list matches it; "build" is CLion's hammer beside the Run widget (from memory, not
  re-read).

## 3. Where Emacs can show icon buttons
| Place | What it is | Limits |
|---|---|---|
| frame tool bar | `tool-bar-map`, one bar per frame; native NSToolbar on macOS, a GTK widget on Arch (GTK3 / X11 build) | see 4 |
| window tool bar | built in since Emacs 30 (`window-tool-bar-mode`): the buffer's `tool-bar-map` drawn in each window's tab line | a row per window; cost, see 5 |
| tab bar | `tab-bar-format` takes functions returning menu items: a button per item, label text or an image | a frame row used for buttons only; the tab bar is otherwise unused here |
| header line / mode line | propertized strings with `local-map` and `mouse-face` | per window; hand-made buttons; breadcrumb uses the header line |
| menu bar | a menu of the same commands | text, no icons |

## 4. The frame tool bar, in detail
- An item is `(menu-item LABEL COMMAND :image IMAGE :help TEXT :enable FORM :visible
  FORM)` in `tool-bar-map`. `:visible` and `:enable` are evaluated when the bar is
  rebuilt, so buttons can follow state: debugger steps only during a session.
- `tool-bar-add-item` and `tool-bar-local-item` take an icon name and look for
  `NAME.xpm` / `.pbm` / `.xbm` only (`tool-bar--image-expression`); an SVG needs the
  menu item written out with an image from `create-image` or `find-image`. Both
  lucide-toolbar and visual-emacs do that.
- A buffer-local `tool-bar-map` (Info, Help, EWW, DocView, Log-Edit, Compilation, GUD)
  replaces the global one while that buffer is selected.
  `tool-bar-always-show-default` (Emacs 30) keeps the global one instead.
- macOS (`nsmenu.m`): icons only (`NSToolbarDisplayModeIconOnly`, small size), labels
  never shown, `:help` is the tooltip; separators are skipped ("Newer macOS don't show
  them"); disabled images are computed by AppKit; the bar sits at the top only
  (`tool-bar-position` bottom: "all window systems other than macOS", NEWS.30).
- Arch (GTK): `tool-bar-style` (image, text, both) and `tool-bar-position` (top, bottom,
  left, right) apply. UNVERIFIED here: read from the manual's names, not run.
- The two machines therefore show the same items in different chrome.

## 5. Trial on the Mac (graphical `emacs -Q`, 2026-11-20)
Six items with Lucide SVGs (20 px, tinted with the default foreground) as the default
`tool-bar-map`; then the same map through `window-tool-bar`.
- NS took the SVG images: no "Could not prepare toolbar image" on stderr, 6 items in
  the keymap.
- The native bar costs no text rows: window body 476 px with and without it,
  `tool-bar-height` 0 (the bar lies in the window's title area).
- `tool-bar-make-keymap`: 16 ms per 1000 calls (cached).
- `window-tool-bar-string`: 4.85 s per 1000 calls, 4.8 ms each, for 6 items; it is an
  `:eval` in `tab-line-format`. The tab line took 24 px per window.
- Not checked: how the icons look (no screenshot taken), dark / light appearance,
  startup cost in the shipped config, anything on Arch.

## 6. Icons
| Source | License | Fit | Against |
|---|---|---|---|
| Emacs's `etc/images` | GPL, shipped | `gud/` has run, cont, step, next, finish, stop, break; `search`, `commit`, `diropen`, `refresh` | 24 px XPM bitmaps, 2000s look; no build, branch or sidebar icon; fixed colors |
| Lucide | ISC | `git-branch`, `search`, `text-search`, `hammer`, `bug`, `bug-play`, `play`, `square`, `panel-left`, `folder-tree`, `redo-dot`, `arrow-down-to-dot`, `arrow-up-from-dot`, `step-forward` all exist; one stroke style; `currentColor`, so tinted from the theme | files copied into the repository with their license |
| Codicons (VS Code) | CC BY 4.0 (icons) | made for an IDE: `debug-start`, `debug-step-over`, `debug-step-into`, `debug-step-out`, `debug-continue`, `debug-stop`, `source-control`, `search`, `go-to-file`, `tools`, `layout-sidebar-left` exist | attribution required; files copied in |
| nerd-icons, all-the-icons | fonts | glyphs for tab bar, header line, mode line | not images: no use in the frame tool bar; a font to install on both machines; not vendored |
| svg-lib | GPL (GNU ELPA) | fetches icons from online collections | a network call at run time; not vendored |

## 7. Existing packages
- **lucide-toolbar** (MIT, 288 lines, 64 Lucide icons, Emacs 29.1+, read): re-skins
  the stock tool bars; adds no button. It advises `tool-bar-make-keymap-1`, replaces
  each stock image by a Lucide SVG made with `create-image` at
  `lucide-toolbar-size` (20), `currentColor` replaced by the `tool-bar` face's
  foreground, and rebuilds on `enable-theme-functions`. Its bundled icons lack
  `git-branch`, `hammer`, `bug`, `panel-left`.
- **visual-emacs** (a config, read): adds explorer, build, debug, run to the default
  `tool-bar-map` with `keymap-set-after` and SVG files of its own through `find-image`;
  sets `tool-bar-position` bottom or left. Its last commit is from 2025-04.
- **window-tool-bar** (built in, read): section 3 and 5.
- Not read from their repositories: modern-tab, centaur-tabs, tab-line-nerd-icons
  (tab bar / tab line looks), modern-icons.el (file icons), the "Emacs SVG Toolbar"
  gist (buttons drawn into a buffer), ESS's `ess-toolbar.el`.
- No package found that ships an IDE toolbar for magit, projectile and dape.

## 8. A button set that follows the owner's list
| Button | Command | Key | Lucide icon | Shown |
|---|---|---|---|---|
| Sidebar | `emacs-cpp-treemacs-toggle` | `C-c t` | `panel-left` | always |
| Go to anything | `emacs-cpp-go-to-anything` | `M-o` | `search` | always |
| Search text | `consult-ripgrep` | `M-s r` | `text-search` | always |
| Git status | `magit-status` | `C-x g` | `git-branch` | always |
| Build | `projectile-compile-project` | `C-c p c c` | `hammer` | in a project |
| Debug | `dape` | `C-x C-a d` | `bug-play` | no session |
| Continue | `dape-continue` | `C-x C-a c` | `play` | in a session |
| Step over | `dape-next` | `C-x C-a n` | `redo-dot` | in a session |
| Step into | `dape-step-in` | `C-x C-a s` | `arrow-down-to-dot` | in a session |
| Step out | `dape-step-out` | `C-x C-a o` | `arrow-up-from-dot` | in a session |
| Stop | `dape-quit` | `C-x C-a q` | `square` | in a session |

A tooltip can carry the key ("Git status (C-x g)"), so the bar also teaches the keys.
"In a session" needs dape's state; its only test is the internal
`dape--live-connection`.

## 9. Open points for any build
- Startup cost on Arch, where the budget binds (D-057): unmeasured.
- The look on both machines, light and dark, on a Retina display: unchecked.
- Whether mode tool bars (Info, Help, Compilation) should replace the bar in their
  buffers or `tool-bar-always-show-default` keeps it fixed.
- pdf-tools and DocView: DocView has its own tool bar since Emacs 30; pdf-tools none.

## 10. Found while building (2026-11-20, T-150)
- The Mac was in light appearance (`defaults read -g AppleInterfaceStyle`: no such
  key) with the dark default theme: the `tool-bar` and `default` faces' foreground is
  `#ffffff`, so theme-tinted icons would be white on the light title area. Emacs
  31.1 has no `ns-system-appearance`; the frame parameter `ns-appearance` (`dark`,
  `light`, nil for the system's) sets the title area's side.
- A screenshot of the trial frame was refused (`screencapture` exit 1, no screen
  recording permission): the look is unchecked by the session.
- The shipped config, graphical, throwaway HOME: bar on, six buttons, `ns-appearance`
  dark, dape not loaded, no `*Warnings*`; with `modus-operandi` loaded the parameter
  turned `light` and the color `#000000`; with a stubbed session the five debugger
  buttons replaced Debug.
- Startup, `scripts/measure-startup.sh 10` (terminal Emacs, draws no bar; load
  average about 6): median 0.508 s (0.473 - 0.665) before, 0.497 s (0.465 - 0.616)
  and 0.508 s (0.487 - 0.576) after. Building the map: 2.4 ms (100 builds 0.245 s).

## Sources
- Emacs 31.1 (MacPorts): `lisp/tool-bar.el`, `lisp/window-tool-bar.el`, `etc/NEWS.30`,
  `etc/images/`.
- https://raw.githubusercontent.com/emacs-mirror/emacs/emacs-31/src/nsmenu.m
- https://github.com/shogi-dojo/lucide-toolbar
- https://github.com/DevelopmentCool2449/visual-emacs
- https://github.com/lucide-icons/lucide (icons by name, ISC)
- https://github.com/microsoft/vscode-codicons (icons by name, CC BY 4.0)
- https://www.jetbrains.com/help/clion/guided-tour-around-the-user-interface.html
- https://gist.github.com/rougier/80d4926d522594235107743db880ecff
- https://github.com/MArpogaus/modern-tab
- https://github.com/ema2159/centaur-tabs
- https://github.com/emacs-ess/ESS/blob/master/lisp/ess-toolbar.el
