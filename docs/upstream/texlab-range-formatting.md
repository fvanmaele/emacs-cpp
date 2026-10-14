# texlab report draft: no range formatting; FormattingOptions ignored for LaTeX

Draft for texlab's issue tracker (github.com/latex-lsp/texlab/issues, "New issue").
Not sent; outward, so the owner sends it (T-079). Reproduction script:
`texlab_range_formatting_repro.py` in this directory (Python 3, no editor needed).
Searched the tracker on 2026-10-14 ("rangeFormatting", "range formatting",
"insertSpaces", "latexindent lines"): no report of either; #497 (a formatter of
texlab's own) and #365 (extra latexindent arguments) are related, not the same.
Why it matters here: emacs-cpp now runs latexindent itself for LaTeX formatting
(D-101, D-103), because of the two points below.

---

**Title:** Range formatting (latexindent `--lines`) and honouring `insertSpaces` /
`tabSize` for LaTeX

### Environment
- texlab 5.25.1 (MacPorts, macOS 27.0.1, Apple silicon); the code paths read are the
  same in v5.26.0.
- latexindent 4.0 (2026-03-15, TeX Live 2026).
- Client: Emacs 31.1 with eglot 1.24.31; the script below shows the same without an
  editor.

### 1. No `textDocument/rangeFormatting`
texlab announces `documentFormattingProvider` only, so an editor cannot format a
selection: Emacs's `eglot-format` on a region stops with "Unsupported or ignored LSP
capability ':documentRangeFormattingProvider'"; a request sent anyway gets
`-32601 method not found`.

latexindent can already do this: `--lines MIN-MAX` (since 3.5) reads the whole file,
so it knows which environment each line is in, and indents only those lines. On the
document below, `latexindent --lines 3-6` indents the `itemize` items exactly as the
whole-document run does and leaves the `enumerate` list alone.

**Suggestion:** for LaTeX with `latexFormatter: "latexindent"`, announce
`documentRangeFormattingProvider` and run latexindent as for formatting, adding
`--lines <start+1>-<end'+1>` (LSP lines are 0-based; `end'` is the end line, minus
one when the range ends at character 0 of a line). The reply can stay one edit over
the whole document, as today. For `texfmt` / `none` keep it unannounced or answer
with no edits.

### 2. `insertSpaces` / `tabSize` ignored for LaTeX
`format_source_code` (`features/formatting.rs`) passes the request's
`FormattingOptions` only to the BibTeX formatter; `format_with_latexindent` calls
`latexindent --local file.tex`, so the indentation is latexindent's default,
`defaultIndent: "\t"`, whatever the editor asks for. An editor that indents with
spaces (Emacs/AUCTeX by default, two spaces) then gets tabs from formatting and
spaces from its own indentation in the same file.

**Suggestion:** when no local settings file sets `defaultIndent`, pass
`-y=defaultIndent:"<tabSize spaces>"` for `insertSpaces: true` (and `"\t"` for
false). A project's `latexindent.yaml` should still win, so add `-y` only when none
of `localSettings.yaml`, `.localSettings.yaml`, `latexindent.yaml`,
`.latexindent.yaml` exists in latexindent's working directory (or behind an option,
e.g. `texlab.latexindent.useEditorIndent`). Tested by hand: `latexindent --local
'-y=defaultIndent:"  "' main.tex` indents by two spaces; with a project
`.latexindent.yaml` setting four spaces and no `-y`, four.

### Reproduction
```
python3 texlab_range_formatting_repro.py            # texlab on PATH
```
It starts texlab over stdio in a temporary directory with this file:
```latex
\documentclass{article}
\begin{document}
\begin{itemize}
\item one
\item two
\end{itemize}
\begin{enumerate}
\item three
\end{enumerate}
\end{document}
```
Output (texlab 5.25.1, latexindent 4.0):
```
server: TexLab 5.25.1
  documentFormattingProvider: true
  documentRangeFormattingProvider: null

textDocument/rangeFormatting, lines 3 - 6 (0-based 2 - 5):
  {"code": -32601, "message": "method not found"}

textDocument/formatting, insertSpaces true, tabSize 2:
  '\\documentclass{article}'
  '\\begin{document}'
  '\\begin{itemize}'
  '\t\\item one'
  '\t\\item two'
  '\\end{itemize}'
  '\\begin{enumerate}'
  '\t\\item three'
  '\\end{enumerate}'
  '\\end{document}'

latexindent --lines 3-6 main.tex:
  '\\documentclass{article}'
  '\\begin{document}'
  '\\begin{itemize}'
  '\t\\item one'
  '\t\\item two'
  '\\end{itemize}'
  '\\begin{enumerate}'
  '\\item three'
  '\\end{enumerate}'
  '\\end{document}'
```
Expected: a range formatting capability whose reply matches the last block (with
`insertSpaces: true, tabSize: 2`, two spaces instead of `\t`); formatting with two
spaces as well.

(Separately, smaller: `format_with_latexindent` discards latexindent's stderr and
returns no edits when latexindent is missing or fails, so the user sees nothing
happen; a `window/showMessage` with the error would help.)
