# 0045 - T-042: a warning for a source the database does not list

- **Date:** 2026-10-10
- **Commits:** the commit that adds this entry (`lisp/emacs-cpp-presets.el`,
  `lisp/init-cpp.el`, two tests)
- **Tier:** 2
- **Decisions:** D-068 (built here); follows the D-018 extension of the same day
- **Done when:** opening an existing C++ source that the active preset's database does
  not list shows one warning per session naming the file and the fix, clangd still
  manages it; listed sources, headers and files not yet saved get none; `make test`
  passes (agreed 2026-10-10).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
The owner asked whether eglot still starts clangd on broken presets or a missing
database. A probe of seven broken projects showed it does not (D-018), with one gap
left: a `.cc` that CMakeLists.txt does not build. clangd starts for the project and,
for that file, borrows the compile command of a listed file nearby. Often that works;
when the file needs other include paths or definitions, the diagnostics are false and
nothing says why. The common cause is a new file not yet added to CMakeLists.txt, or
added but not configured.

Now, when eglot starts managing such a file, a warning names it and says what to do.
clangd is not stopped: the rest of the project is fine, and the borrowed flags are
often right. The warning comes once per file per Emacs session, so revisiting the file
does not nag.

## Concepts (Emacs Lisp) explained
- **`eglot-managed-mode-hook`.** Runs in a buffer when eglot starts (and stops)
  managing it, after the server has answered. The function checks `eglot-managed-p`
  to act only on the start.
- **Errors in a hook.** An error in this hook would leave eglot half set up in the
  buffer, so the function catches errors and shows them as an error-level warning:
  visible, but the buffer still gets its server.
- **Cache by modification time.** The database is parsed into a hash table of file
  names, kept with the file's modification time; the next check parses again only
  when CMake has rewritten the file (the same pattern as the clangd flag check).
- **True names.** On macOS `/var` is a link to `/private/var`; comparing true names
  of the directories makes the database's paths and the buffer's path agree.
  Resolving each directory once, not each file, keeps the parse fast.
- **`case-fold-search`.** Emacs regular expressions ignore case by default; bound to
  nil so `.C` (C++) matches but `.c` (C) does not.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets-source-missing-p` (the rule),
  `emacs-cpp-presets-warn-if-not-in-database` (the hook function, once per session).
- `lisp/init-cpp.el` - the hook, in eglot's `use-package` form.
- `test/emacs-cpp-presets-test.el` - `emacs-cpp-presets-source-missing-from-database`:
  listed, unlisted, header, unsaved, `.c`, and a rewritten database.
- `test/init-cpp-test.el` - `init-cpp-warns-once-for-a-source-not-in-the-database`:
  real cmake and clangd; fails with the hook removed (checked).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** CMake lists every built source with an absolute or directory-relative
  path, and never a header. **Would break if:** a generator lists headers (no harm,
  they are never checked) or relative paths against another base (false warnings).
  **DESIGN bet:** D-068.
- **Assumed:** a source outside the database is a mistake worth a popup. **Would break
  if:** a project keeps sources CMake never builds (examples, scratch files); then
  the popup comes once per file per session. If that bites, a per-project exemption
  is the next step, not silence.
- **Risk:** the first check after CMake rewrites the database parses all of it:
  0.12 s for 5000 entries on the Mac (0.46 s before true names were resolved per
  directory instead of per file). A source that is itself a symbolic link is
  compared under its own name and could be warned about wrongly.

## How to verify
`make test`. By hand: in a preset project, create `src/x.cc` with any content, save,
close and reopen it: `*Warnings*` names it. Add it to CMakeLists.txt, `C-c p c o`,
restart Emacs, reopen: no warning.
