# 0136 - T-143: roll-mode scrolling in step without a redisplay

- **Date:** 2026-11-09
- **Commits:** see `git log --grep T-143`
- **Tier:** 2
- **Decisions:** D-200 (applies D-069 to pdf-tools)
- **Done when:** a test that fails today: scroll steps without a redraw between them reach
  the same place as the same steps with redraws (agreed 2026-11-09).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner saw continuous scrolling in pdf-tools jump at page breaks on the Mac, with the
trackpad, under CPU load. Roll mode lays the PDF out as one buffer line per page, each
line showing the page's image; scrolling is the window's start line plus a pixel offset
inside it (the "vscroll"). The two scroll commands changed the page and the offset but
left the window's start line on the old page; only the code that runs just before Emacs
draws the screen moved it. Under load, trackpad events queue up and Emacs does not draw
while input waits, so the next scroll command started from the old page with the new
page's offset: the view went back a page, or, after the next draw, sat elsewhere.

A probe in a graphical Emacs showed it step by step: step 16 moved to page 2 with 14 px
of offset, step 17 back to page 1. Fixing only that exposed the second half: a page not
yet drawn is a placeholder, a blank space 1000 lines tall, and the forward command
measured it instead of the page, so it never found the next break (page 2 at 724 px of a
700 px page). The backward command already drew a page before measuring it. The patch
does both: set the window's start to the page the command ends on, and draw a page before
measuring it, recording it so the next screen draw can drop it again.

## Concepts (Emacs Lisp) explained
- `set-window-start WINDOW POS t`: which buffer position is at the window's top; the `t`
  asks redisplay to keep it unless point would be off screen.
- `pos-visible-in-window-p POS WINDOW t`: with `t` it returns how many pixels of the line
  at POS are hidden above and below and how tall the visible part is; roll mode reads the
  visible height to know how much of a page is left to scroll through.
- `pre-redisplay-functions`: run just before Emacs draws a window; roll mode draws the
  page images there. A command that runs between two draws sees the state the last draw
  left, which is why the commands now keep it right themselves.

## Key files walked
- `patches/pdf-tools/0001-Keep-continuous-scroll-in-step-when-scroll-commands-.patch` -
  the change to `lisp/pdf-roll.el`'s `pdf-roll-scroll-forward` and
  `pdf-roll-scroll-backward`; listed in `.gitmodules`, applied by `make packages`.
- `test/gui/init-writing-gui-test.el` - `init-writing-gui-scroll-steps-without-redraw`
  runs 40 steps of 3 lines forward from page 1 and backward from page 4, once with a
  redraw after each step and once without, and wants the same page and offset.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the test's "no redraw between steps" is what queued trackpad events do;
  the probe and the code agree, the owner's trackpad under load is not rerun by the
  session. **Would break if:** jumps remain on the owner's Mac. **DESIGN bet:** D-200.
- **Assumed:** drawing a page inside the command costs no more than the draw it saves
  (the same page would be drawn at the next redisplay). **Would break if:** fast
  scrolling over many pages gets slower. **DESIGN bet:** D-200.
- **Assumed:** each half is needed: without the backward change the test ends on page 4
  for page 1; without the drawing, page 2 at 724 px for page 3 at 230. **Would break
  if:** a pdf-tools release changes these functions; the patch then stops applying and
  `make packages` says so (D-069). **DESIGN bet:** D-069, D-200.

## How to verify
`make packages && make test-gui` (a window opens, do not touch it): 11 of 11. Without
the patch (`.gitmodules`' `patch` line removed, `make packages`), the new test fails.
By hand: a long PDF, the trackpad, scroll across page breaks while the machine is busy.

## Open questions (optional)
None. The upstream report for this and D-192's defect is not drafted (H-33 holds
D-192's).
