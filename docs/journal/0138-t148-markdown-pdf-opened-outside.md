# 0138 - T-148: the Markdown PDF opened outside Emacs on `C-c C-c o`

- **Date:** 2026-11-09
- **Commits:** see `git log --grep T-148`
- **Tier:** 2
- **Decisions:** D-202
- **Done when:** T-148's row (agreed 2026-11-09, owner: "Agree 1").

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c C-c x` writes the Markdown file's PDF and shows it in pdf-tools inside Emacs. The
owner also wanted the same export opened as Finder would, in the system's PDF viewer.
markdown-mode already has a key for "open in an external program", `C-c C-c o`, driven by
the option `markdown-open-command`, which this configuration had left unset (the key only
complained). The option accepts a function, so it is now `emacs-cpp-markdown-pdf-open`:
the same export, and on success the platform's opener on the PDF, `open` on the Mac and
`xdg-open` on Arch, named in the per-platform defaults files.

The export was split so both commands share it: `emacs-cpp-markdown--export` takes the
function that receives the finished PDF, pdf-tools' display for `x`, the opener for `o`.

## Concepts (Emacs Lisp) explained
- A sentinel is the function Emacs calls when a process changes state, here when pandoc
  exits. It runs later, outside the command, so any value it needs is captured when the
  command starts: an early version read the opener's name in the sentinel, after a test's
  temporary binding had ended, and so ran the real `open`.
- An error raised inside a sentinel reaches the owner only as a line in the echo area, and
  ends a batch Emacs. The opener's failure is therefore a warning at level `:error`, which
  opens the `*Warnings*` buffer, as D-185's missing-glyph warning does.

## Key files walked
- `lisp/init-writing.el` - `emacs-cpp-markdown-pdf-open`, `emacs-cpp-markdown--open-pdf`,
  and `markdown-open-command` in markdown-mode's `use-package` form.
- `lisp/defaults-darwin.el`, `lisp/defaults-gnu-linux.el` -
  `emacs-cpp-default-pdf-open-command`.
- `test/init-writing-test.el` - the `init-writing-pdf-open-*` tests: a shell script stands
  in for the opener and records the path it gets.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** `open` shows the PDF in Preview from the owner's Emacs; the session's run
  exited 0 but Preview did not list the file, likely the session's command sandbox.
  **Would break if:** H-37 shows nothing. **DESIGN bet:** D-202.
- **Assumed:** Preview shows a rewritten PDF when opened again (UNVERIFIED; H-37 asks).
  **Would break if:** the owner sees the old version. **DESIGN bet:** D-202.
- **Assumed:** Arch's desktop maps PDFs to a viewer for `xdg-open` (UNVERIFIED; H-36).
  **Would break if:** `xdg-open` opens nothing or a browser. **DESIGN bet:** D-202.

## How to verify
`make test`: the four `init-writing-pdf-open-*` tests. By hand: H-37 on the Mac, H-36's
step 4 on Arch.
