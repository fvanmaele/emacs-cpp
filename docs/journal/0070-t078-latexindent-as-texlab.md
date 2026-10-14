# 0070 - T-078: latexindent run as texlab runs it, indenting as AUCTeX does

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry (`lisp/init-latex.el`,
  `test/init-latex-test.el`, DESIGN, CHEATSHEET, TASKS)
- **Tier:** 2
- **Decisions:** D-103 (built here), amends D-101; O-53 (a), (b), (d)
- **Done when:** C-c l f (buffer and region) passes --local and runs latexindent
  from the nearest directory upward (within the project) with .latexmkrc /
  latexmkrc / .texlabroot / texlabroot, else the file's directory. Without a yaml
  there and without a user indentconfig.yaml it adds -y=defaultIndent: with
  LaTeX-indent-level spaces, a tab when indent-tabs-mode. Tests: project yaml
  defaultIndent "    " gives 4 spaces (also from a subdirectory with .latexmkrc
  above); no yaml gives 2 spaces; indent-tabs-mode gives a tab; existing tests
  adjusted; make test on the Mac. Met on the Mac.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
Revisiting texlab's errors (O-53) by reading its source showed that 0068's
latexindent call was not the one texlab makes. texlab adds `--local`, which makes
latexindent read a settings file from its working directory (`latexindent.yaml`,
`localSettings.yaml`, with or without a leading dot), and texlab picks that
directory itself: the nearest one upward with a `.latexmkrc` (or a `texlabroot`
marker), else the document's own. So a project that set, say, two-space indentation
got it through texlab and a tab from `C-c l f`. The call now does the same.

The same reading showed texlab ignores the editor's "use spaces, width N" request
for LaTeX, so latexindent's built-in default, a tab, went into files where AUCTeX's
`TAB` and `RET` indent with spaces. When neither the project nor the user has
latexindent settings, `C-c l f` now tells latexindent to indent like the buffer:
`LaTeX-indent-level` spaces (2), or a tab when the buffer uses tabs.

## Concepts explained
- **`locate-dominating-file`** walks from a directory towards `/` and returns the
  first directory for which a test succeeds; here: one of the marker files exists.
  The result counts only inside the project (`project-root`), so a stray
  `.latexmkrc` in the home directory does not move the working directory.
- **`default-directory` around `call-process`:** a process starts in the current
  buffer's `default-directory`; binding it for the call sets latexindent's working
  directory without touching the buffer.
- **`-y=defaultIndent:"  "`:** latexindent's command-line settings, written as YAML.
  They override settings files, which is why they are added only when no settings
  file exists: a project's or user's choice wins.
- **Mutation check:** each new test was run once with the code it guards turned off
  (an `:override` advice); the tests failed then, so they test what they claim.

## Key files walked
- `lisp/init-latex.el` - `emacs-cpp-latex--indent-directory` (texlab's directory
  rule), `emacs-cpp-latex--indent-arguments` (`--local`, `-y=defaultIndent:`),
  both used by `emacs-cpp-latex--indent`.
- `test/init-latex-test.el` - `init-latex-test--formatted` builds the expected
  text; `init-latex-format-project-settings` covers the three directory cases.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** texlab 5.25.1's directory rule is the one to copy. **Would break
  if:** texlab 5.26.0 (already released, not yet in MacPorts) runs latexindent in
  its own working directory, which eglot sets to the project root; a yaml at the
  root then applies to every file there but not here for a file in a subdirectory
  without a `.latexmkrc` above it. **DESIGN bet:** D-103.
- **Assumed:** the three user settings paths are all latexindent reads. **Would
  break if:** `indentconfig.yaml` elsewhere (latexindent also reads one named by
  `-g`); then `-y` overrides it. **DESIGN bet:** D-103.
- **Risk:** AUCTeX puts `\item` at the environment's column, latexindent indents
  it one level; the characters match now, the layout of items still differs.

## How to verify
`make test` (the latexindent tests skip without latexindent). By hand: in a project
with `.latexindent.yaml` containing `defaultIndent: "    "`, `C-c l f` indents by
four spaces, as texlab's own formatting does; without it, by two spaces.
