# S22 - pdf-tools (T-138, D-190)

Risk: pdf-tools' compiled server `epdfinfo` fails to build on one machine, or its
continuous scrolling (`pdf-view-roll-minor-mode`, new in 1.3.0) misbehaves; either
leaves DocView (D-186, D-187, D-189) as the Markdown PDF's viewer.

Sources (D-190, the spike's only network): pdf-tools v1.3.0 and tablist, cloned into
`src/` (ignored by git). Nothing goes to `lib/` until S22 passes on both machines.

## Criteria (PASS = all, on each machine)
1. `epdfinfo` builds from v1.3.0 with the system's poppler-glib (Arch: pacman; the
   Mac: MacPorts, no Homebrew) and `pdf-info-check-epdfinfo` succeeds.
2. Roll mode on a PDF of at least 5 pages: scrolling down line by line from the first
   page reaches the last page's end; at a page break the end of one page and the start
   of the next show at the same time; no stop at a page's top.
3. `pdf-view-display-size` `fit-width`: a page fills the window's width (within 2 %),
   also after the window is resized.
4. After the PDF is rewritten on disk (as `C-c C-c x` does), its buffer shows the new
   content within 2 s, roll mode still on.
5. Text is sharp on the machine's screen (the Mac: Retina, `pdf-view-use-scaling`):
   the owner's look, compared with DocView's SVG pages.

## The session (Arch)
`s22.el` in a graphical Emacs, from a timer: loads pdf-tools from `src/`, opens
`test.pdf` (a long PDF exported from `docs/CHEATSHEET.md`), checks 2 - 4, logs to
`arch-run1.log`. Results: RESULTS.md.
