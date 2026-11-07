# 0131 - T-135: Markdown to PDF through pandoc and LaTeX

- **Date:** 2026-11-07
- **Commits:** `0fca720` (make test's HOME), the commit adding this entry
- **Tier:** 2
- **Decisions:** D-184 (O-89 (b), math half deferred), amends D-145 and D-089
- **Done when:** T-135's line, agreed 2026-11-07 ("Defer mathjax, agree otherwise"):
  `C-c C-c x` writes and shows the PDF, a second run reverts it, errors signal; the
  Mac's `exec-path` has `/Library/TeX/texbin`; ERT tests; `make test` on the Mac; Arch
  by an H-n item.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner asked for LaTeX export and preview of Markdown files. D-145 had removed
LaTeX from the config, so the request went to the owner as O-89; the ruling was (b):
a PDF through pandoc, plus math drawn inside the buffer by math-preview. The math
half was then deferred (T-136), because it would bring a submodule, node and an npm
install. What is built: `C-c C-c x` in a Markdown buffer saves the file, runs
`pandoc doc.md -o doc.pdf --pdf-engine=xelatex` in the background, and shows the PDF
in doc-view in another window. The preview is the PDF itself: pressing the key again
rewrites it and refreshes the window.

While testing, every LaTeX run inside `make test` hung for minutes. The cause was in
the Makefile, not in the feature: on the Mac `TMPDIR` ends in `/`, so the test HOME
was `.../T//emacs-cpp-test-home...`, and TeX's path library (kpathsea) reads `//` as
"search every subdirectory". Each run walked all of TMPDIR. The Makefile now strips
the trailing slash (tier 1, `0fca720`).

## Concepts (Emacs Lisp) explained
- `make-process` starts a program without waiting for it; Emacs stays usable. Its
  `:sentinel` is a function Emacs calls when the program's state changes, here when
  it exits. The sentinel hands the exit code to `emacs-cpp-markdown--pdf-finished`, a
  named function, so the tests can call it directly.
- An error inside a sentinel cannot reach the person who pressed the key (that call
  has long returned); Emacs prints it as "error in process sentinel: ...". That is
  still loud, and the output buffer is shown next to it.
- `find-buffer-visiting` finds the buffer already showing the PDF, so a second export
  reverts that buffer instead of opening a second one.
- `keymap-set` on `markdown-mode-command-map` (the keys after `C-c C-c`) inside
  `use-package`'s `:config`, which runs once markdown-mode has loaded.

## Key files walked
- `lisp/init-writing.el` - `emacs-cpp-markdown-pdf` (the command),
  `emacs-cpp-markdown--pdf-command` (pandoc's arguments, file names relative to the
  file's directory, so images beside it are found), `emacs-cpp-markdown--check-tools`
  (the error with the install command), `emacs-cpp-markdown--pdf-finished`.
- `lisp/defaults-darwin.el`, `lisp/defaults-gnu-linux.el` - the install commands;
  the Mac's `exec-path` list gains `/Library/TeX/texbin` (MacTeX).
- `test/init-writing-test.el` - six tests; the two that run pandoc are skipped where
  pandoc or the engine is missing.
- `Makefile` - the test HOME without `//`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** pandoc's default LaTeX template compiles with xelatex on both
  machines. **Would break if:** Arch's `texlive-xetex` lacks a package the template
  loads; the Arch run (H-n, pending the owner's install) shows it. **DESIGN bet:** D-184.
- **Assumed:** the TeX on the Mac is MacTeX in `/Library/TeX/texbin`, outside
  MacPorts (D-053). **Would break if:** MacTeX is removed; the command then signals
  with the install hint. **DESIGN bet:** D-184, D-089.
- **Assumed:** a few seconds per export is acceptable as a preview (3 s measured for
  a short file). **Would break if:** long documents make it tedious; then T-136 or a
  `latexmk` engine is the next step. **DESIGN bet:** D-184.
- **Assumed:** Arch's TMPDIR is unset or has no trailing slash. **Would break if:**
  not; the Makefile strips it either way.

## How to verify
- `make test` on the Mac: 162 run, 0 unexpected, 2 gdb tests skipped (2026-11-07).
- By hand: open a `.md` file with `$x^2$` in it, `C-c C-c x`; the PDF appears in
  another window after a few seconds. Arch: the H-n item, after the install is agreed.

## Fix after the owner's first real file (D-185, 2026-11-07)
On RMO-drafts' `md/exact_coarse_model.md` the PDF showed no formulas. That file has
no LaTeX math: it writes formulas as code spans in Unicode (Greek letters, partial,
greater-equal). pandoc sets code in Latin Modern Mono, which has none of those
glyphs; xelatex leaves each one out, and pandoc still exits 0, printing one
`[WARNING] Missing character` line per drop, which the command never showed. Now
pandoc gets `-V monofont=DejaVuSansMono.ttf` (TeX Live ships the font; 0 missing on
that file), and after a successful run the output is searched for missing
characters, which become a warning naming them. Two tests: the parse of those lines,
and an export of Greek in a code span, clean with the default font and warned about
with pandoc's own. POSTMORTEM has the short entry.
The low resolution in DocView is gs rendering 100 dpi PNGs on a Retina screen;
DocView uses MuPDF's SVG output on its own once `mutool` is on `exec-path`, an
install for the owner to agree.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Helped: "a choice offered to the owner, premises verified or marked UNVERIFIED";
  the option text's npm package was marked UNVERIFIED and was wrong.
