Title:
pdf-view-roll-minor-mode: window blank after revert when the PDF has fewer pages

Body:

pdf-tools 1.3.0 (5245f09), Emacs 31.1, Arch Linux, poppler-glib 26.10.0.

Steps:
1. Open a 6-page PDF in pdf-view-mode, enable `pdf-view-roll-minor-mode`.
2. Go to page 6: `(pdf-roll-goto-page 6)`.
3. Replace the file on disk with a 5-page PDF, then `M-x revert-buffer`.

Expected: page 5 (the new last page) is shown.
Actual: the window stays blank (still blank 3 s later); point stays at a position past
the new last page. One `C-p` (pdf-roll-scroll-backward) draws page 5.

Reverting while a page that still exists is shown (page 3, page 1) keeps that page drawn.

Workaround, buffer-local:

    (add-hook 'after-revert-hook
              (lambda ()
                (let ((last (pdf-info-number-of-pages)))
                  (when (> (pdf-view-current-page) last)
                    (pdf-roll-goto-page last))))
              nil t)

With it page 5 is drawn 1 s after the revert. `pdf-roll-initialize` (run after
`revert-buffer-function`) might clamp the page the same way.
