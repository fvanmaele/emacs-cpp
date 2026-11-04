# 0113 - T-128: project buffers follow their files through one fswatch per root

- **Date:** 2026-11-04
- **Commits:** this entry's commit (the module, its wiring and tests); the S20
  `shipped` mode follows in its own commit
- **Tier:** 3 (S20 PASS on both machines, 0103, 0110)
- **Decisions:** D-153, D-156 (e), D-161 (p), D-162, D-163; D-070 corrected
- **Done when:** D-162 (d): the module with (e) and (p), D-151 (2b), D-152, magit's
  auto-revert off, auto-revert outside roots, ERT tests for each, `make test` on both
  machines, S20 `shipped` passing `fswatch-shown`'s criteria on both machines. This
  entry covers the code and the Mac's `make test`.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
A buffer that shows a file should change when the file changes on disk, for
instance after `git checkout` in a shell; otherwise eglot sends clangd the old text
and jumps land on the wrong line (D-147). Emacs's own auto-revert does this by
polling on the Mac and refreshes the version-control state of every reverted buffer
right away, which froze Emacs for seconds after a large checkout (O-78).

`lisp/emacs-cpp-reverter.el` starts one patched fswatch for each project root that
has open files. When fswatch reports changed paths, the module reverts the matching
buffers that have no unsaved edits, all at once, and leaves the slower part (the
branch name in the mode line, diff-hl's change marks) to a queue that refreshes one
visible buffer every 0.05 s; a buffer nobody sees is refreshed when a window shows
it. Two rules from O-79 keep Emacs responsive while clangd is busy: the queue waits
while the reverter is reverting (e), and a reverter call never starts inside another
one (p); a second batch arriving meanwhile is handled right after.

Buffers it does not cover follow their files through auto-revert, as before T-127:
files outside any project, library headers reached with `M-.`, and every buffer of
a project where `emacs-cpp-revert-project-buffers` is turned off (Customize, at once,
or the project's `.dir-locals.el`). magit's own auto-revert stays off.

Writing the tests found that the project tree's rule for "a project" never matched
a project marked only by a `.projectile` file: this projectile lists only version
control markers for its bottom-up search and finds `.projectile` with a separate
function. The tree and the reverter now share one function with the three searches
in projectile's own order.

## Concepts explained
- Process filter: the Lisp function Emacs calls with whatever a subprocess writes;
  here fswatch writes one NUL-ended record per changed path.
- `global-auto-revert-ignore-buffer` as a predicate: auto-revert asks the function
  once, when it takes a buffer on, whether to leave it alone. So the reverter answers
  "would I cover this buffer", and switching the option turns auto-revert off and on
  so it asks again for every buffer.
- A user option with `:set`: Customize calls the function, which applies the change
  at once (fswatch processes stopped or started); `:safe #'booleanp` lets
  `.dir-locals.el` set it without a prompt.
- Holding a buffer-local hook back: diff-hl adds its revert function to the buffer's
  own `after-revert-hook`; binding that hook without it around `revert-buffer` keeps
  its marks for the queue.

## Key files walked
- `lisp/emacs-cpp-reverter.el` - `emacs-cpp-reverter-root`, `emacs-cpp-reverter--adopt`,
  `emacs-cpp-reverter--filter`, `emacs-cpp-reverter--revert`, `emacs-cpp-reverter--step`.
- `lisp/init-project.el` - the `autorevert` form; the tree's predicate now calls
  `emacs-cpp-reverter-root`.
- `lisp/init-git.el` - magit's `:init`.
- `test/emacs-cpp-reverter-test.el` - the real fswatch in a temporary git repository.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the code behaves as S20's spike measured (the numbers came from spike
  code). **Would break if:** the `shipped` mode misses `fswatch-shown`'s criteria; it
  is the next commit. **DESIGN bet:** D-162 (d).
- **Assumed:** one fswatch per root is cheap enough with several projects open.
  **Would break if:** many roots (submodules each get their own) cost descriptors or
  memory beyond S20's 6 per process. **DESIGN bet:** D-163 (a).
- **Assumed:** diff-hl keeps the name `diff-hl-after-revert`. **Would break if:** an
  update renames it; the module then errors when diff-hl loads, and a test fails.
  **DESIGN bet:** D-153.

## How to verify
`make test </dev/null`; the `emacs-cpp-reverter-*` tests, `init-project-auto-revert`,
`init-git-magit-auto-revert-off`. By hand: open two files of a git project, run `git
checkout` on another branch in a shell, see both buffers change within a second.
