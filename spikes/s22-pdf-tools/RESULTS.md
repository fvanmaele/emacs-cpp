# S22 results

Verdict: FAIL on Arch as written (2026-11-08, session): criterion 4 on a PDF that
shrank below the shown page; criteria 1 - 3 PASS; with a page clamp after the revert
(measured, below) 1 - 4 PASS. Criterion 5 and the Mac: not run (H-n).

## Environment
Arch, Emacs 31.1 (graphical, `-Q`), pdf-tools v1.3.0 (5245f09), tablist 01f065e,
poppler-glib 26.10.0, frame 2402 x 1306 px. Test PDFs: `docs/CHEATSHEET.md` through
the export's pandoc options, 6 pages (3 cm margins) and 5 pages (1 cm).

## Measurements (`arch-run1.log`, `s22.el`)
1. `epdfinfo` built with `./autogen.sh && ./configure && make` in 11 s
   (`build-arch.log`: deprecation warnings only, linked to the system's
   `libpoppler-glib.so.8`); `pdf-info-check-epdfinfo` succeeded. PASS.
2. Roll mode, real `C-n` keys from a timer: 742 steps from page 1 to the end of page
   6; 261 of 742 samples show two pages at once; no step left the page and vscroll
   unchanged before the last page. PASS.
3. `pdf-view-display-size` `fit-width`: page 2370 px in a 2370 px body; after
   `split-window-right` 1171 in 1171; back to one window 2370 in 2370. Exact, so the
   page is drawn at the window's resolution (not scaled up as DocView's PNGs were).
   PASS.
4. The file rewritten on disk (6 -> 5 pages) while the window showed page 6, then
   `revert-buffer` as the export does: 5 pages, roll mode on, but no page drawn after
   1 s, 3 s; one `C-p` draws page 5 (`arch-revert-page6.log`). From page 3 the revert
   keeps page 3 drawn (`arch-revert-page3.log`), from page 1 page 1
   (`arch-revert-probe.log`). FAIL as written: a re-export that shortens the document
   while its end is shown leaves the window blank until a key.
   With an `after-revert-hook` moving to the last page when the shown one no longer
   exists (`S22_CLAMP` in `s22-revert-probe.el`): page 5 drawn 1 s after the revert
   (`arch-revert-page6-clamp.log`).

## Decision
For the owner: amend criterion 4 to count the clamp (a few lines of app code, written
fresh, with a test) and go on to the Mac run, or stay on DocView. The defect is
pdf-tools' (`pdf-roll-initialize` keeps a page past the new end); reported upstream
only if the owner wants.

## Gotchas
- A spike script's read error leaves a graphical Emacs open and idle: `s22.el` runs
  under a guarded `load` and a 240 s watchdog.
- Without `pdf-tools-install`, `find-file` opens a PDF in DocView; the spike calls
  `pdf-view-mode` itself.
