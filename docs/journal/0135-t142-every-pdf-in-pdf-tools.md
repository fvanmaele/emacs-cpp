# 0135 - T-142: every PDF in pdf-tools

- **Date:** 2026-11-09
- **Commits:** see `git log --grep "T-142"`
- **Tier:** 2
- **Decisions:** D-199, D-192
- **Done when:** T-142's seven points (TASKS). The Mac's done; Arch's run and the hand check
  of link and selection are on H-36.

> Plain English: PDFs now open in one viewer that scrolls from page to page. It needs a
> small compiled helper program; without it, no PDF opens and Emacs says how to build it.

## What + why
S22 showed pdf-tools works on both machines, so it replaces DocView, for every PDF by the
owner's ruling. `lisp/init-writing.el` loses D-187's fit code, since pdf-tools fits pages
itself, and the export no longer needs `mutool`.

The spike's clamp was not enough. S22 ran with the PDF in the selected window, but `C-c C-c
x` keeps the Markdown window selected. There S22's clamp reads the wrong window's page and
the PDF window stays blank; `init-writing-gui-clamp-unselected-window` shows it. The clamp
now walks every window that has shown the buffer, and clears each one's record of pages
drawn: otherwise roll mode tries to undraw a page that no longer exists and stops.

Measured on the Mac (`scripts/measure-pdf.sh`, 1002 pages, frame 597 x 508 px; recorded, no
budget): first page drawn 969 ms from the visit's start, 906 ms of it the visit, which loads
pdf-tools and checks the server; 300 `C-n` mean 3.3 ms, median 2.5 ms, slowest 88 ms; a jump
to page 500 27 ms; a revert until page 500 is drawn 71 ms. 4008 overlays. Arch: H-36.

## Concepts (Emacs Lisp) explained
- **Windows have their own page.** `image-mode-winprops-alist` keeps, per window, which page
  it shows. "The current page" without a window means the selected window's.
- **`normal-mode` catches a mode function's error** and prints it as a message. So a PDF
  without a server stays raw text with the fix on the message line (D-199's case against).
- **`signal-hook-function`** runs at the moment of a signal. It found the sentinel error
  below when wrapping each process's sentinel made the error disappear.
- **Batch Emacs draws nothing.** `pre-redisplay-functions` never run there, so roll mode's
  drawing can only be tested in a window: `make test-gui`, `test/gui/`. Its runner always
  exits, even on an error, so that `make` never waits on an idle window.

## Key files walked
- `lisp/init-writing.el` - `emacs-cpp-pdf-view-mode`, the mode of every PDF, and
  `emacs-cpp-pdf--clamp-page`.
- `scripts/build-epdfinfo.sh` - `make epdfinfo`; stops naming the install command.
- `test/gui/init-writing-gui-test.el` - pages really drawn;
  `init-writing-gui-defect-without-the-clamp` fails once pdf-tools fixes its defect, the
  sign that D-192's clamp can go.
- `scripts/measure-pdf.sh`, `.el` - the long PDF's times, in the shipped profile.

## Found while testing
`error in process sentinel: Selecting deleted buffer`, also seen by the owner in the test
window: the sentinel of native compilation's background processes, whose log buffer the
tests' cleanup had killed (POSTMORTEM, 2026-11-09). A test's fault, not the config's.
Three weakened clamps were run against the tests (S22's, one keeping the record of pages
drawn, one for shown windows only): each fails at least one test.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 906 ms for the session's first PDF is acceptable; later visits skip the load
  and the check. **Would break if:** the owner finds it slow. **DESIGN bet:** D-199.
- **Assumed:** a reverter's revert meeting a half-written PDF is rare and harmless; three
  exports in a temporary git project, the reverter on, gave no error. **Would break if:**
  a large PDF's slower write shows errors from the reverter's timer. **DESIGN bet:** D-199.
- **Assumed:** `M-o`'s preview of a PDF behaves; UNVERIFIED, it starts pdf-view-mode with
  mode hooks delayed. **Would break if:** the preview errors or stays blank. **DESIGN bet:**
  D-088, D-199.
- **Assumed:** link click and selection work in roll mode (code paths read, S22 did not
  run them). **Would break if:** H-36's hand check fails. **DESIGN bet:** D-199.

## How to verify
`make epdfinfo && make test && make test-gui` (a window opens, do not touch it);
`sh scripts/measure-pdf.sh`. By hand: H-36's step 4.
