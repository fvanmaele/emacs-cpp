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

## 5. Hover indicator, pointer on a modifier (owner question 2026-10-14)
- **What Emacs can show on hover** (Elisp manual, "Special Properties"): a text or
  overlay property `mouse-face` highlights the text under the mouse; `pointer`
  sets the pointer's shape there (e.g. `hand`); `help-echo` (a string or a
  function) shows a tooltip. Links in help buffers use these.
- **A modifier alone:** Emacs's input events are keys and mouse actions with
  modifiers attached; pressing Command or Control by itself delivers no event to
  Lisp, so the pointer cannot change while a modifier is held and the mouse is
  still (from Emacs's input model; the manual has no statement of it; not
  demonstrated). CLion's "hold Cmd, the symbol under the mouse becomes a link" is
  therefore not reachable as is.
- **What is reachable:** (a) in eglot buffers, symbols under the mouse highlighted
  with a hand pointer at all times (a `mouse-face` and `pointer` on the symbol the
  mouse is over, set when the mouse moves, `track-mouse` / `mouse-movement` events,
  or on all identifiers of the visible part through font-lock); (b) (a) plus a
  tooltip with the server's hover text (`help-echo` function asking eglot; a
  blocking request per hover, clangd answers in milliseconds, others slower); (c)
  none. Cost of (a) / (b) not measured (motion events in Emacs are frequent).

## 6. Hover highlight measured; a plain click on a symbol (owner 2026-10-14)
**(a) Highlight and hand pointer on hover, how it would be built.** Emacs highlights
text carrying `mouse-face` while the mouse is over it and shows the `pointer` shape
there, in redisplay, without running Lisp per mouse movement. So the cost is
putting the two properties on the identifiers, once per part of the buffer shown
(jit-lock, as fontification). Measured on deal.II's `grid/tria.h` (4927 lines,
c++-ts-mode, Mac, batch):
- tree-sitter query for identifier nodes (`identifier`, `field_identifier`,
  `type_identifier`, `namespace_identifier`) over the whole file: 5.9 ms; over its
  first 123 lines 4.0 ms (most of it the query's fixed cost);
- a regexp for identifiers: 29.8 ms whole file, but it also tags words in comments
  and strings; with a `syntax-ppss` check per hit to skip those it ran for more than
  two minutes and was stopped.
So: tree-sitter, per shown chunk, well under a millisecond per screen. Languages
without a tree-sitter mode here (LaTeX, CMake) would need their own rule; eglot's
semantic tokens (clangd sends them) are another source, not measured.
Tracking the mouse instead (`track-mouse`, `mouse-movement` events) runs a command
for every movement: not measured, avoided by the above.

**A plain click (no modifier) on a symbol.** A click sets point; eglot's hover is
already one of eldoc's sources (`eglot-hover-eldoc-function` first in
`eldoc-documentation-functions`), so 0.5 s after a click (`eldoc-idle-delay`) the
echo area shows the symbol's signature and documentation. clangd answers a hover
request in 0.4 - 3.7 ms (toy project, five tries each). Ways to show it at the click:
- (c1) a tooltip at the mouse after a click on a symbol, from eldoc's text or a hover
  request (`tooltip-show`, the system's tooltip; plain text);
- (c2) the same in a child frame at the click (posframe, vendored, as ace-window and
  cfrs use it), with Markdown rendered as eldoc's buffer is;
- (c3) the echo area as now, with a shorter eldoc delay after a click;
- (c4) double click: Emacs selects the word there, so a tooltip on double click
  would change that; not proposed.
A tooltip on every click (c1, c2) also appears when placing the cursor to type; it
would need to vanish at the next key or movement. Not built or tried in the GUI.


## 7. Hover highlight (a): performance (owner 2026-10-14)
Question: what (a) costs, in time and memory, before it is ruled. Measured with a
scratch prototype (not shipped): a jit-lock function that runs a tree-sitter query
for identifier nodes (`identifier`, `field_identifier`, `type_identifier`,
`namespace_identifier`) on the chunk being shown and puts `mouse-face` and
`pointer` on each, removing old ones in the chunk first. Mac, batch, the shipped
config, Emacs 31.1, `c++-ts-mode`, `jit-lock-chunk-size` 1500 characters; deal.II
9.7.1's `grid/tria.h` (4963 lines, mostly comments), `matrix_free/fe_evaluation.h`
(8470 lines, its largest header) and that header ten times over (84700 lines,
3.4 MB). Per chunk, median / 95th percentile, in ms:

| file | font-lock | tagging | identifiers | intervals added (MB) |
|---|---|---|---|---|
| tria.h | 0.16 / 0.57 | 0.02 / 0.08 | 1659 | 386 (0.02) |
| fe_evaluation.h | 0.52 / 0.77 | 0.08 / 0.12 | 11184 | 12910 (0.7) |
| ten times over | 0.59 / 0.89 | 0.08 / 0.12 | 111898 | 129158 (6.9) |

- **Showing text:** the tagging adds about 15 % to what the mode's own fontification
  already costs per chunk, under 0.15 ms at the 95th percentile; a screen is one or
  two chunks.
- **Once per session:** the query's compilation, 9.7 - 10.3 ms, at the first chunk
  (or at mode start if compiled eagerly).
- **Typing:** after an edit the changed chunk is shown again: font-lock (tree-sitter's
  reparse included) 3.0 / 7.9 / 8.5 ms median for the three files, tagging 0.02 /
  0.09 / 0.08 ms (300 edits each).
- **Memory:** a text-property interval per tagged run, 56 bytes each: 0.7 MB for all
  of fe_evaluation.h, 6.9 MB for the 3.4 MB file, but only for the parts shown:
  `jit-lock-stealth-time` is nil here, so nothing fontifies (or tags) text never
  shown. font-lock's faces already add more intervals than the tagging (217327
  against 129158 in the large file).
- **Mouse movement:** not measured. Emacs draws the highlight in redisplay (C) when
  the mouse enters a run with `mouse-face`, without running Lisp per movement; its
  cost is redrawing the rows under the mouse. Needs a graphical session to measure
  (profiler while sweeping the mouse over a large file).
- **Another source:** eglot 31 turns on `eglot-semantic-tokens-mode` in managed
  buffers (clangd sends tokens; eglot applies them as a font-lock keyword). Their
  ranges would also mark identifiers, macros included, but only through eglot's
  internal functions; tree-sitter's query is public API. Not measured.
- **Not covered:** LaTeX and CMake buffers (no tree-sitter mode here), as in 6.
