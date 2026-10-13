# RESEARCH - Mouse bindings: CLion against Emacs

Question (owner, 2026-10-13): additional mouse bindings, e.g. Command+click to go to a
symbol's definition (`M-.`), compared with CLion's key and mouse bindings. Findings
only; verdicts go to DESIGN.

Sources: JetBrains' help (CLion "Source code navigation", "Keyboard shortcuts",
"Multiple cursors"; IntelliJ's predefined macOS keymap) and JetBrains support threads,
read 2026-10-13; Emacs 31.1's lisp (`xref.el`, `prog-mode.el`, `mouse.el`) and key
lookups in the shipped config, batch, on the Mac.

## 1. CLion (macOS keymap; Windows / Linux in brackets)
- Cmd+Click (Ctrl+Click): "Go to Declaration or Usages": on a use, to its declaration;
  on a declaration, its usages. The click takes the modifier of the keyboard command
  (Cmd+B), so a remapped command moves the click too (JetBrains support).
- Following that rule, Cmd+Opt+Click would be "Go to Implementation(s)" (Cmd+Opt+B)
  and Cmd+Shift+Click "Go to Type Declaration" (Cmd+Shift+B); the keymap page lists
  no mouse entries for them.
- Cmd+hover: "Brief info", a short popup (signature); Quick Documentation is F1 or
  hover with a setting.
- Opt+Shift+Click: add / remove a caret; Opt+Click and drag: rectangular selection;
  Opt+Shift+middle click, Cmd+Opt+Shift+Click: further rectangular variants.
- Back / Forward: Cmd+[ / Cmd+]; the keymap page lists no mouse buttons for them.
- Right click: the context menu (Go To, Find Usages, Refactor, Generate ...).
- Ctrl+Click on a Mac is a right click, which is why the Mac keymap uses Cmd.

## 2. Emacs 31.1 and this config today (Mac: Command = `super`, Option = `meta`)
- `s-<mouse-1>` (Cmd+Click): unbound.
- `xref-find-definitions-at-mouse` and `xref-find-references-at-mouse` exist (xref.el,
  Emacs 28+): `M-.` / `M-?` at the clicked spot; eglot answers through xref, so clangd,
  pyright and texlab all work with them.
- `context-menu-mode` (Emacs 28+) is off; on, right click opens a menu, and
  `prog-context-menu` puts "Find Definition" and "Find References" (the two commands
  above) in it for programming modes. Off, `mouse-3` extends the selection
  (`mouse-save-then-kill`).
- `C-<down-mouse-1>`: the buffer menu; `M-<mouse-1>` / `M-<down-mouse-1>` (Opt+Click):
  the secondary selection; `C-M-<down-mouse-1>`: rectangular selection by drag
  (`mouse-drag-region-rectangle`).
- Back / forward after `M-.`: `M-,` / `C-M-,` (`xref-go-back` / `xref-go-forward`);
  no mouse button. The side buttons arrive as `mouse-8` / `mouse-9` on X / Wayland;
  what the macOS build sends was not checked (`C-h k` then the button shows it).
- Hover: eglot's information about the symbol at point goes to the echo area
  (eldoc), at point, not at the mouse.
- Multiple carets: none (the `multiple-cursors` package is not vendored).
- The fringe: a click toggles a breakpoint (lisp/init-debug.el).

## 3. A mapping (for O-44)
- Cmd+Click, declaration: `s-<mouse-1>` -> `xref-find-definitions-at-mouse`; a
  binding.
- Cmd+Click on a declaration, usages: a separate click (e.g. `s-M-<mouse-1>`) or the
  menu -> `xref-find-references-at-mouse`; a binding.
- Cmd+Opt+Click, implementations: set point, `eglot-find-implementation`; a small
  command.
- Cmd+Shift+Click, type: set point, `eglot-find-typeDefinition`; a small command.
- Right click, menu: `context-menu-mode` on (Find Definition / References, undo,
  cut / copy / paste); changes `mouse-3`.
- Side buttons back / forward: `xref-go-back` / `xref-go-forward`; check the macOS
  events first.
- Cmd+hover brief info: nothing in Emacs without a package (eldoc at point only);
  not proposed.
- Opt+Shift+Click carets: none built in; a package, not proposed.
- Opt+drag rectangle: `C-M-` drag exists.
- Linux, Ctrl+Click: `C-<mouse-1>` instead of the buffer menu (Super+click is often
  taken by the desktop); a D-055 platform default.

Options: (a) the first four items (definition, references, implementation, type on
Cmd / Cmd+Opt / Cmd+Shift clicks; Ctrl on Arch); (b) `context-menu-mode`; (c) the
side buttons, after `C-h k` on each machine; (d) none.

## 4. Not checked
- The macOS events of the mouse's side buttons.
- Whether macOS gives Emacs Cmd+Click at all on the owner's setup (no system shortcut
  is known to take it).
- Arch: the desktop's use of Super+click and Ctrl+click.
