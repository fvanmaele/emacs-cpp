# RESEARCH - a dark or light theme following the OS setting (T-082)

Findings only; verdicts go to DESIGN (O-56). Owner request 2026-10-15: "automatic
switch to a dark theme, depending on OS settings - stage 1, macOS". Arch is stage 2,
not covered here. Owner's Mac (Apple silicon, Darwin 27, MacPorts `emacs-app`
31.1_0, NS build: `--with-ns`, native compilation), 2026-10-15. Emacs facts from the
installed `etc/NEWS` and docstrings, and from `src/nsterm.m`, `src/nsfns.m` and
`src/frame.c` of `emacs-31.1.tar.gz` in MacPorts' distfiles (unpacked in a scratch
directory).

## 1. What the config does today
- `lisp/init-ui.el`: `emacs-cpp-ui-default-theme` loads `modus-vivendi-tritanopia`
  (dark) from `after-init-hook`, only when `custom.el` enabled no theme (D-040).
  Nothing reads the OS appearance.
- Its light counterpart ships with Emacs: `modus-operandi-tritanopia`.

## 2. What Emacs 31.1 offers
- New in 31.1 (NEWS, "Toolkit"): the variable `toolkit-theme` (`light` or `dark`)
  and the hook `toolkit-theme-set-functions`, called with the new value when the
  system theme changes. Their docstring and NEWS: "only set on PGTK, Android, and
  MS-Windows builds". Source: `frame.c` defines both; `nsterm.m` / `nsfns.m` never
  set them. Batch on the Mac: `toolkit-theme` nil. **The NS build gets no
  notification of an appearance change.**
- The NS frame parameter `ns-appearance` (`dark`, `light`, or nil for the system's)
  sets only the window's `NSAppearance`, i.e. the title bar
  (`[EmacsWindow setAppearance]`, `nsterm.m` line 10358). The config does not set
  it, so the title bar already follows the system. It changes no face.
- `ns-system-appearance` and `ns-system-appearance-change-functions` are not in
  this build (both unbound): they come from emacs-plus's patch (Homebrew), not
  from GNU Emacs.
- The Mac port (Mitsuharu Yamamoto's, MacPorts `emacs-mac-app` 10.1) has its own
  appearance events. Its Emacs base version was not checked; switching builds
  touches D-050 / D-053.

## 3. Reading the setting from outside Emacs
- `defaults read -g AppleInterfaceStyle` prints `Dark` (exit 0) in dark mode; in
  light mode the key is absent (exit 1, a "does not exist" message on stderr).
  With System Settings on "Automatic" the key follows the current mode
  (`AppleInterfaceStyleSwitchesAutomatically` 1 here; the key read `Dark` at the
  time). The light case and the switch at sunset were not observed.
- Cost: 6.4 ms per call (`call-process`, 10 calls 64 ms, warm), blocking. An
  asynchronous `make-process` would not block Emacs; not timed.
- `osascript` (System Events, `dark mode` of `appearance preferences`) also
  reads it; asks for the Automation permission at first use; not timed.

## 4. Switching the theme
- Batch, `emacs -Q`, disable the enabled theme then `load-theme`:
  `modus-operandi-tritanopia` 14 ms, `modus-vivendi-tritanopia` 7 ms (second
  load). Redrawing faces in a graphical frame not measured.
- The D-040 rule has to stay: a theme saved with Customize wins; following the
  OS would apply only while no theme was saved, or the owner names a pair.
- Faces that inherit the theme's (dape's breakpoints inherit `error`, D-036)
  follow a switch; packages that cache colours (treemacs icons) not checked.

## 5. Options (not ruled, O-56)
- (a) Read once at startup: the default theme becomes vivendi or operandi by
  `defaults read` (one 6.4 ms call, macOS only; the reading is mechanics, so in
  init-ui, not a platform defaults file, D-055). A change while Emacs runs needs a
  restart or a command.
- (b) (a) plus polling: a timer (for example every 5 s, idle-only or not) reads
  the setting asynchronously and swaps the pair when it changed. Follows the
  "Automatic" switch within the interval; one process per interval.
- (c) (a) plus a command (`M-x emacs-cpp-ui-follow-system`) the owner runs after
  a change; no timer.
- (d) The `auto-dark` package (MELPA): a new submodule (D-006) and D-nnn; its
  macOS detection not read.
- (e) Another Emacs build with an appearance hook (emacs-mac-app, or emacs-plus,
  which is Homebrew only): contradicts D-053 (MacPorts only); not pursued
  unless the owner asks.
- Open within each: which pair (modus tritanopia, or others); what happens when
  Customize saved a theme; whether terminal frames (`emacs -nw`) follow too, as
  the terminal's own colours already may.
