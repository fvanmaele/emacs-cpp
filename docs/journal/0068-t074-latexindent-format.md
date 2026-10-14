# 0068 - T-074: LaTeX buffers and regions formatted by latexindent

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`lisp/init-latex.el`,
  `test/init-latex-test.el`, DESIGN, CHEATSHEET, README, TASKS)
- **Tier:** 2
- **Decisions:** D-101 (built here), O-51 (a)
- **Done when:** `C-c l f` in a LaTeX buffer with an active region writes the buffer
  to a temporary directory, runs `latexindent -c DIR --lines A-B` (the region's
  lines) and replaces only those lines (the rest and point kept, one undo step);
  without a region latexindent formats the whole buffer (owner, amended: latexindent
  for both, not texlab); latexindent missing or exit != 0: user-error with the fix
  or its stderr, buffer untouched. Tests: real latexindent (skipped if absent)
  changes only the region's lines and matches the buffer result there; stubbed
  failure and missing program; make test on the Mac. Met on the Mac.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c l f` asks the language server to format. For LaTeX that server is texlab, and
texlab only formats whole documents: with a region selected, eglot stopped with
"Unsupported or ignored LSP capability ':documentRangeFormattingProvider'" (O-51).
texlab itself formats by running latexindent, which can indent chosen lines
(`--lines 3-6`) while still reading the whole document, so it knows which
environment each line sits in. Emacs now runs latexindent directly, for a region and,
at the owner's request, for the whole buffer too, so both always use one program
with the same settings.

## Concepts explained
- **Remapping a command:** `<remap> <eglot-format>` in `LaTeX-mode-map` says "in
  LaTeX buffers, whatever key runs `eglot-format` runs this instead". `C-c l f`
  stays one key for every language; only LaTeX buffers get the other command. The
  right-click menu's Format Buffer (`eglot-format-buffer`) is remapped the same way.
- **`replace-region-contents`:** replaces the buffer's text with latexindent's
  output but changes only what differs, so point, marks and unchanged lines stay.
  (Emacs 31's name; the older `replace-buffer-contents` is obsolete.)
- **Change groups:** `prepare-change-group` ... `undo-amalgamate-change-group` makes
  the several small edits a single undo step.
- **`use-region-p`** is true only with an active, non-empty region and
  `transient-mark-mode` on; batch Emacs runs with that mode off, so the tests turn
  it on in their buffer.

## Key files walked
- `lisp/init-latex.el` - `emacs-cpp-latex-format` (region lines or whole buffer),
  `emacs-cpp-latex-format-buffer` (the menu's), `emacs-cpp-latex--indent` (temporary
  file, latexindent, replacement); the remaps in the `tex` form's `:config`.
- `test/init-latex-test.el` - region, buffer, refusals.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** latexindent's defaults are what texlab used, so nothing changes for
  anyone who formatted whole buffers before. **Would break if:** someone sets
  texlab's `latexindent.local` or `modifyLineBreaks`; those settings no longer apply
  to `C-c l f`. **DESIGN bet:** D-101.
- **Assumed:** latexindent exists wherever texlab's formatting worked (same
  program). **Would break if:** a TeX Live install without it (Arch:
  `texlive-binextra` missing); `C-c l f` then says so. **DESIGN bet:** D-101.
- **Risk:** latexindent is a Perl program and starts in about 0.1 - 0.5 s; on a very
  long document a format takes a moment, as it did through texlab.

## How to verify
Batch, with the shipped config and the real texlab in a git project (2026-10-14): a
region over the first list indented only those lines, exactly as the whole-buffer
format indents them; the second list stayed as it was. Hand check on the Mac (owner):
open a `.tex` file of a project, select a few lines inside an environment, `C-c l f`;
then without a region `C-c l f`; `C-/` undoes each in one step.
