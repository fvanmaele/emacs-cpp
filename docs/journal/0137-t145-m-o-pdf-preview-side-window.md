# 0137 - T-145: `M-o` previews PDFs in a side window

- **Date:** 2026-11-09
- **Commits:** see `git log --grep T-145`
- **Tier:** 2
- **Decisions:** D-201
- **Done when:** T-145's row (agreed 2026-11-09, owner: "A").

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
Since every PDF opens in pdf-tools (D-199), `M-o`'s preview of a PDF filled the whole
window at its width. The owner asked for a narrower side window. consult shows a preview
by switching the buffer of the window `M-o` started from, with `switch-to-buffer`, which
normally ignores `display-buffer-alist`, Emacs's table of rules for where buffers appear.
Emacs has a public option, `switch-to-buffer-obey-display-actions`, that makes it follow
those rules. `M-o` turns it on only while its prompt is open and adds two rules: a PDF
goes into a side window on the right; anything else first removes that side window. No
consult internals are touched (the owner ruled out wrapping `consult--file-state`).

The rules also check that the minibuffer is open: consult opens the chosen file after the
minibuffer has closed, still inside `M-o`'s bindings, and `RET` must open the PDF where
it always did. consult restores the starting buffer from `minibuffer-exit-hook`, while
the minibuffer is still active, so the closing rule runs on `C-g` too.

## Concepts (Emacs Lisp) explained
- `display-buffer-alist`: a list of (CONDITION ACTION...) entries; CONDITION can be a
  function of the buffer name and the action; ACTION functions return the window used,
  or nil to let the next one try. The closing rule deletes the side window and returns
  nil, so the buffer then shows in the same window as before.
- `let` on a global variable binds it only while the body runs, also for code the body
  calls, such as consult's preview: the rules are gone the moment `M-o` returns.
- Window parameters: a side window is marked with `emacs-cpp-go-pdf-preview`, so the
  closing rule deletes that window and no other side window.

## Key files walked
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--display-rules`, the two rules;
  `emacs-cpp-go--display-pdf-preview` also puts the starting buffer back into the
  original window, which may still show the last text file previewed.
- `test/gui/init-go-to-anything-gui-test.el` - runs the real `M-o`: timers type keys into
  the prompt and record the windows while it is open.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** no other package's `display-buffer-alist` entry matches a candidate while
  the prompt is open or on `RET` on a buffer (the config itself sets none). **Would break
  if:** a buffer chosen in `M-o` appears somewhere unexpected. **DESIGN bet:** D-201.
- **Assumed:** the preview's single page (consult delays the hooks that turn roll mode
  on) is enough for a preview; it fits 1 px under the window's width. **Would break if:**
  the owner wants scrolling in the preview. **DESIGN bet:** D-201, D-199.
- **Assumed:** 0.4 of the frame is a usable width on the Mac's screen. **Would break
  if:** pages are too small; `emacs-cpp-go-pdf-preview-width` takes columns too.
  **DESIGN bet:** D-201.

## How to verify
`make test-gui` (a window opens, do not touch it): the three
`init-go-to-anything-gui-pdf-*` tests. By hand: `M-o`, type a PDF's name: it shows on the
right; type another file's name: the side window goes; `C-g`: the layout as before.
