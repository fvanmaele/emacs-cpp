# 0141 - T-151: the tool bar after an adversarial review

- **Date:** 2026-11-22
- **Commits:** the commit carrying this entry
- **Tier:** 2
- **Decisions:** D-211 (amends D-210)
- **Done when:** (1) each fix in D-211 has a test, the stale cache test failing without
  the fix; (2) `make test` passes on the Mac; (3) a graphical start and a daemon with
  `emacsclient -c` on the Mac show the theme's colour and `ns-appearance`; (4) the
  owner's look and debug session on both machines (H-39). The session wrote this line
  from the owner's list ("Fix items 1 to 4 and 6, 7-8, 9 comment, 10-12, 13-16").

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner asked for an adversarial review of 71c6122 (the icon tool bar, 0140) by three
reviewing agents: API and internals, edge cases, user interface and simplicity. The
session checked their claims against Emacs 31.1's Lisp sources, dape 0.27.1 and magit,
and reran two reproductions. The owner then named the items to fix; all but item 5
(GTK's colours on Arch, which H-39 looks at first) are in D-211.

Two were real bugs a user would meet. Emacs's `tool-bar.el` keeps the bar it builds in
a cache keyed by the address of `tool-bar-map`; the module put a fresh map in place at
each theme change, and after a garbage collection a fresh map can sit at a dead one's
address and get its cached bar, so the third colour change showed the first's colour
(reproduced: `#444444` set, `#222222` shown). And under `emacs --daemon` the theme's
colours were read from the daemon's terminal frame, which has none: the icons got the
placeholder `gray50`, which librsvg does not know (it reads CSS colours, not Emacs's
names) and drew blank, and `ns-appearance` went light under the dark theme.

## Concepts (Emacs Lisp) explained
- **`:foreground` on an SVG image**: Emacs sets the SVG's CSS `currentColor` from it
  (Emacs 31 NEWS). Lucide draws its strokes in `currentColor`, so the file needs no
  editing, and Emacs turns any colour name into a colour librsvg understands.
- **`after-make-frame-functions`**: functions run with each new frame. A daemon's
  first graphical frame (`emacsclient -c`) arrives here; the bar is drawn again then,
  once.
- **`defcustom` with `:set`**: Customize calls the `:set` function to change an option;
  here it also draws the bar again. `:initialize #'custom-initialize-default` keeps that
  function from running while the file loads.
- **`add-hook` with a depth**: 90 puts the function at the end of `after-init-hook`. An
  error in a hook function stops the functions after it; at the end, there are none.

## Key files walked
- `lisp/init-toolbar.el` - `emacs-cpp-toolbar-refresh` clears `tool-bar-keymap-cache`,
  then builds the map from the first graphical frame's colours;
  `emacs-cpp-toolbar--frame-made` redraws for a daemon's first graphical frame;
  `emacs-cpp-toolbar-git-status` refuses outside a repository; the items table gains
  Pause, the WHEN values `stopped`, `running` and `step`, and an optional NOTE.
- `icons/lucide/pause.svg` - Lucide 1.69.0's `pause`, from unpkg's `lucide-static@1.69.0`
  with the license comment and class line removed, as the other eleven.
- `early-init.el` - the comment now says startup still builds Emacs's stock buttons.
- `test/init-toolbar-test.el` - 14 tests (7 new): the cached bar after five refreshes
  with garbage collections, Customize, the first graphical frame, the title opt-out,
  Git status outside a repository, dape's `stopped` TYPE, the hook's last place.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** Emacs draws `:foreground` into the SVG's `currentColor` on the NS and GTK
  tool bars as in a buffer. **Would break if:** a tool bar image ignores it; the icons
  would be black. Not seen drawn (macOS refuses the session a screenshot): the image
  spec and its 20 x 20 size are checked in a graphical Emacs, the pixels on H-39.
  **DESIGN bet:** D-211.
- **Assumed:** clearing all of `tool-bar-keymap-cache` costs nothing visible. **Would
  break if:** many frames on several terminals make the rebuild slow; each is rebuilt
  once at its next redisplay. **DESIGN bet:** D-211.
- **Assumed:** dape's `dape-active-mode` is on exactly while a session runs (dape.el
  2390, 2537, 2622, 2627). **Would break if:** a pin bump changes that; the
  `init-toolbar-debug-buttons-follow-the-session` test binds it, so only a real session
  shows it. **DESIGN bet:** D-211.
- **Assumed:** a test reading `('stopped ` in dape's source catches a renamed TYPE.
  **Would break if:** dape keeps the word but changes its meaning. dape is pinned
  (D-006), so only a pin bump can. **DESIGN bet:** D-211.
- **Assumed:** startup is unchanged. On the Mac, terminal Emacs, 10 runs, load average
  about 3: median 0.475 s (0140: 0.497 - 0.508 s at load average 6). **Would break if:**
  Arch crosses 0.5 s; H-39 measures. **DESIGN bet:** D-057.

## How to verify
- `make test </dev/null`: 204 tests, 2 skipped on the Mac, 14 `init-toolbar-*`.
- Graphical start on the Mac in a throwaway HOME (session, 2026-11-22): 12 entries,
  built colour `#ffffff`, `ns-appearance` dark, no warnings.
- `emacs --daemon=NAME`, then `emacsclient -s NAME -c` (session, 2026-11-22): before the
  frame `gray50` and no `ns-appearance`; after it `#ffffff` and `dark`.
- The cache test with `clrhash` of the cache disabled: fails, `#555555` set and
  `#333333` shown.
- The look, a real debug session, Arch: H-39.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: the rule to verify a choice's premises; two of the reviewers' claims were
  rerun before they were reported, one (`gray50` drawn blank) with a pixel count.
- Never applied: spike rule, tier 2.
