# 0143 - T-159: line numbers toggle breakpoints

- **Date:** 2026-11-22
- **Commits:** the commit carrying this entry
- **Tier:** 2
- **Decisions:** D-215 (amends D-036)
- **Done when:** a click on the number toggles the clicked line's breakpoint, a click
  in the text still moves the cursor, tested in batch and in a graphical Emacs on the
  Mac; `make test` passes. The session wrote this line from the owner's "Numbers toggle
  too".

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
On H-39 step 4 the owner clicked a line number to set a breakpoint, as in CLion, and
nothing happened: only the fringe, an 8-pixel strip left of the numbers, toggled
breakpoints (D-036). Now a click on the number does too.

## Concepts (Emacs Lisp) explained
- **Line numbers live in the text area.** Emacs draws `display-line-numbers` inside the
  window's text area, left of the text, so a click on them is an ordinary `mouse-1` in
  the text area, unlike a click in the fringe (`[left-fringe mouse-1]`). The new command
  compares the click's x with `line-number-display-width` in pixels.
- **Falling through.** The command is bound to `mouse-1` in dape's breakpoint keymap,
  which is active in C and C++ buffers. For a click elsewhere it looks up what
  `mouse-1` would run with that keymap off (usually `mouse-set-point`) and runs it with
  the same event.

## Key files walked
- `lisp/init-debug.el` - `emacs-cpp-debug--on-line-number-p`, `emacs-cpp-debug-mouse-1`,
  the binding in dape's `:config`.
- `test/init-debug-test.el` - `init-debug-line-number-click-toggles-breakpoint`, with
  hand-made click events.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** `posn-x-y` of a text-area click counts from the left edge of the text
  area, line numbers included. Checked in a graphical Emacs on the Mac: numbers 28 px
  wide, a click at x 2 toggled the line's breakpoint, one at x 58 moved the cursor.
  **Would break if:** an Emacs moves line numbers into a margin; the click would then
  need the margin binding. **DESIGN bet:** D-215.
- **Assumed:** no other mode in C++ buffers needs a plain `mouse-1` on the numbers.
  **Would break if:** one does; it would no longer get the click there.

## H-39 notes (owner, 2026-11-22, the Mac)
Six icons fine; the git icon looked cut off: Lucide's `git-branch` leaves the top of the
branch line open by design (screenshot and a 160-pixel render agree), so nothing is cut.
`modus-operandi` and `modus-vivendi` switch the title area and the icons. `C-x C-a d`
ran `gdb-preset`, absent on the Mac: the projects' `.dir-locals.el` names it
(`dape-command`), which overrides the platform default (D-055) as designed; how a
project should name its debugger for both machines is open (the session's message).

## How to verify
- `make test </dev/null`: the new test among them.
- Click a line number in a `.cc` file: a red mark; click again: gone.
