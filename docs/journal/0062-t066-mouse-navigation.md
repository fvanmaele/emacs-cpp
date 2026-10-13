# 0062 - T-066: navigation clicks and the right-click menu

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-lsp.el`, `lisp/init-ui.el`,
  `lisp/defaults-*.el`, `test/init-lsp-test.el`)
- **Tier:** 2
- **Decisions:** D-093 (built here), O-44 (a), (b2)
- **Done when:** Cmd+Click (Mac) / Ctrl+Click (Arch) definition, or references on the
  definition; Opt / Alt implementations; Shift type; right click a menu with the
  server's entries; tests for the bindings per platform, the definition / references
  choice, the menu; owner's hand check in the GUI, Arch by the owner.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
CLion navigates with Cmd+Click (Ctrl+Click on Linux): a click on a use goes to the
definition, a click on the definition lists the uses. Emacs had the pieces
(`xref-find-definitions-at-mouse` and friends) but no binding. Now the same click
does the same, with Opt / Alt for implementations and Shift for the type, and right
click opens a menu with Emacs's Find Definition / References and the language
server's Rename, Code Actions, Go to Implementation and Format.

## Concepts explained
- **Press and click:** a mouse click is two events, the press (`down-mouse-1`) and the
  release (`mouse-1`). If the press has a binding (Ctrl's buffer menu on Arch), Emacs
  runs it and the click never arrives, so the press of each navigation click is
  unbound.
- **Modifier order:** Emacs writes modifiers in a fixed order (`M-s-<mouse-1>`, not
  `s-M-<mouse-1>`); the keys are built with `event-convert-list`, so any platform
  modifier comes out right.
- **Definition or references:** the click asks the xref backend (eglot) for the
  definitions of the symbol; when every one is on the clicked line, the click is on
  the definition, and it lists references instead.
- **Context menu:** `context-menu-mode` asks every function in
  `context-menu-functions` to add entries for the spot clicked; ours adds the
  server's entries only in a buffer eglot manages, each moving point to the click
  first.

## Key files walked
- `lisp/init-lsp.el` - the three click commands, their bindings, the menu function.
- `lisp/init-ui.el` - `context-menu-mode` on.
- `lisp/defaults-*.el` - `emacs-cpp-default-mouse-modifier` (super / control).
- `test/init-lsp-test.el` - bindings per platform, the choice with a stubbed xref
  backend, the menu with and without a managed buffer.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** macOS hands Cmd+Click to Emacs. **Would break if:** a system or app
  shortcut takes it; the owner's hand check shows it.
- **Lost on Arch:** Ctrl's buffer menu and Ctrl+Alt rectangle drag (the presses are
  unbound). **DESIGN bet:** D-093, to be ruled if missed.
- **Right click no longer extends the selection;** Shift+click does (Emacs's
  `mouse-save-then-kill`, which cuts on a quick second click at the same spot).

## How to verify
- `make test`: `init-lsp-mouse-bindings`, `init-lsp-mouse-definition-or-references`,
  `init-lsp-context-menu`.
- Done here (batch, toy with clangd): a click event on `answer` in `main.cc` went to
  `answer.h` line 2; a click there took the references branch. Arch's key names:
  `C-<mouse-1>`, `C-M-<mouse-1>`, `C-S-<down-mouse-1>`.
- Owner (GUI): Cmd+Click a call in RMO: its definition; Cmd+Click the definition: its
  usages; right click: the menu with Rename and Code Actions.
