# S22 results

Verdict: PASS on both machines, 2026-11-08, criterion 4 as amended (D-192). Arch:
criteria 1 - 4 by the session (run 2; run 1 FAIL on criterion 4 as first written),
criterion 5 the owner's look. The Mac: criteria 1 - 4 by the session (`mac-run1.log`,
`mac-run2.log`), criterion 5 the owner's look.

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

Run 2 (`arch-run2.log`, `S22_CLAMP=1`, a 1141 px wide frame): 1 - 4 PASS; criterion 4
in 1.02 s, page 5 shown; 334 `C-n` to the end, 261 samples with two pages. Run 3
(`arch-run3.log`, the expected page count read from `test-new.pdf` for the Mac):
1 - 4 PASS.
Criterion 5, owner, 2026-11-08, on Arch: "pdf-tools as sharp as DocView". PASS.

## The Mac (`mac-run1.log`, `build-mac.log`, 2026-11-08, session)
Apple silicon, Emacs 31.1 (`emacs-app` port, graphical, `-Q`), pdf-tools v1.3.0 (5245f09),
tablist 01f065e, MacPorts poppler 26.02.0, frame 597 x 508 px, `S22_CLAMP=1`. Test PDFs:
6 and 5 pages, as on Arch.
1. `epdfinfo` built by the same commands, exit 0, linked to MacPorts'
   `libpoppler-glib.8.dylib`; `pdf-info-check-epdfinfo` succeeded. PASS.
2. 295 `C-n` from page 1 to the end of page 6; 164 of 295 samples show two pages; no
   stop. PASS.
3. Page 560 px in a 560 px body; after `split-window-right` 266 in 266; back to one
   window 560 in 560; after the revert 560 in 560. PASS.
4. 6 -> 5 pages while page 6 was shown: 1.02 s, 5 pages, roll mode on, page 5 shown.
   PASS.
5. Run 2 (`mac-run2.log`: the same figures, 0 failures, the PDF left shown), compared
   with DocView's pages of the same file, `pdf-view-use-scaling` at its default `t`.
   Owner, 2026-11-08: "pdf-tools text is as sharp". PASS.

## Decision
Owner 2026-11-08 (D-192): criterion 4 counts with the clamp; the defect goes upstream
(H-33, `upstream-issue.md`); the Mac run next (H-32). S22 PASS on both machines,
2026-11-08: D-190's replacement of DocView follows (T-142).

## Gotchas
- A spike script's read error leaves a graphical Emacs open and idle: `s22.el` runs
  under a guarded `load` and a 240 s watchdog.
- Without `pdf-tools-install`, `find-file` opens a PDF in DocView; the spike calls
  `pdf-view-mode` itself.
- On the Mac a graphical Emacs whose stdin is not a tty starts in HOME (probe 2026-11-08:
  `</dev/null` -> `~/`; a tty -> the directory it was started in; `--chdir` -> the one
  named). `mac-run.sh`'s first run looked for `~/s22.el` and logged there; it now passes
  `--chdir`.
