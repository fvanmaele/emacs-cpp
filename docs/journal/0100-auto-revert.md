# 0100 - Unedited buffers follow their files

- **Date:** 2026-10-29
- **Commits:** see `git log --grep T-127`
- **Tier:** 2
- **Reverted:** 2026-10-29 by D-149 (owner), after S20's dry run found the freeze (O-78);
  the code is gone, this entry keeps what was built and measured.
- **Decisions:** D-147
- **Done when:** `global-auto-revert-mode` is on after startup; both defaults files
  define `emacs-cpp-default-auto-revert-use-notify` (t on Arch, nil on the Mac); a test
  shows an unedited buffer reverting after its file changes on disk and an edited one
  keeping its edits; `make test` passes on the Mac; the startup cost is measured on the
  Mac, Arch's by the owner (H-16) (agreed 2026-10-29 with the tier).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner reported `M-.` on `ManifoldKind` in RMO-drafts landing 19 lines below the
definition after about 15 branch switches in a 3-day-old Emacs. It could not be
traced: a fresh clangd answered right, the running one answered right when asked, and
the fault was gone. The suspect: the config never reloaded a buffer whose file changed
on disk, and eglot gives clangd an open buffer's text in place of the file, so a
header buffer left from before a checkout feeds clangd old lines. magit reloads
git-tracked files, but only once magit has been loaded in that Emacs.

Now Emacs's built-in auto-revert reloads every buffer without unsaved edits when its
file changes, as CLion, Qt Creator and VS Code do. Buffers with edits are left alone.
On Arch changes arrive as inotify notifications; on the Mac buffers are checked every
5 s, because each notification there costs a kqueue descriptor and Emacs stops at
975 (D-127).

## Concepts (Emacs Lisp) explained
- `global-auto-revert-mode` turns `auto-revert-mode` on in every file buffer. A buffer
  is reverted (reloaded) only when its file's modification time is newer than the
  buffer's and the buffer is unmodified.
- `auto-revert-use-notify`: watch files with the OS's notifications (inotify, kqueue)
  instead of only polling. `auto-revert-avoid-polling`: with notifications on, skip the
  5 s poll as well. The config sets both from one platform value.
- `:hook (after-init . global-auto-revert-mode)` turns the mode on after init.el, as
  projectile's mode is.

## Key files walked
- `lisp/init-project.el` - the `autorevert` `use-package` form.
- `lisp/defaults-gnu-linux.el`, `lisp/defaults-darwin.el` -
  `emacs-cpp-default-auto-revert-use-notify`.
- `test/init-project-test.el` - `init-project-auto-revert`: settings, then one clean
  and one edited buffer, both files rewritten with a later time, one poll
  (`auto-revert-buffers`). Batch Emacs delivers no notifications (S18), so the test
  polls on both machines.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a stale buffer caused the report. **Would break if:** the fault
  recurs with every buffer current; then the next step is the `M-:` request recorded
  in D-147. **DESIGN bet:** D-147.
- **Assumed:** startup cost stays small. Mac: `require` of `autorevert` in a bare
  Emacs 19 ms (14 ms of it `filenotify`); full startup with and without the mode
  within run-to-run noise (medians 0.50 / 0.55 s on, 0.52 / 0.63 s off; machine not
  idle). **Would break if:** Arch's measurement (H-18, dropped by D-149) shows it
  past the 0.5 s budget (D-057). **DESIGN bet:** D-147.
- **Assumed:** inotify watches stay well under the system limit (one per directory of
  a visited file). **Would break if:** thousands of library directories are visited.
- **Assumed:** a checkout across about 190 files reverts open buffers without
  blocking Emacs long. **Broken** the same day by S20's Mac dry run: about 6 s
  blocked, buffers current 10 - 11 s after `git`, from one `vc-refresh-state` (a git
  process) per reverted buffer; O-78.

## How to verify
- `make test` (143 tests on the Mac, 3 skipped).
- In Emacs: open a tracked header, `git checkout` a branch that changes it in a shell;
  the buffer shows the new text (Arch at once, Mac within about 10 s); with an unsaved edit
  it does not change.
