# 0043 - T-035: RET indents the new line by clangd

- **Date:** 2026-10-10
- **Commits:** the commit that adds this entry (`lisp/init-cpp.el`,
  `test/init-cpp-test.el`)
- **Tier:** 2
- **Decisions:** D-061 (built here), O-28 (b)
- **Done when:** ERT with clangd on a toy project carrying RMO's `.clang-format`: RET
  after a declaration in an unindented namespace lands at column 0, after `public:` at
  4, inside a function body at 8, and the hand-aligned line above (`int  x   = 1;`) is
  unchanged; typing `}` is still re-indented by Emacs's rules; without eglot, and after
  `eglot-shutdown`, RET indents as before (electric indentation, newline among its
  characters); an error from clangd's reply is shown, not swallowed; MANUAL 8 and the
  cheat sheet say what RET and TAB follow; `make test` passes on Arch; RET on RMO
  (owner, `src/main_coarse.cc`) feels immediate (agreed 2026-10-10: owner's
  "implement (b)" after the proposal).
- **Tag:** none

> Plain English for an owner who reads Emacs Lisp only in part.

## What + why
Pressing RET in a C++ file put the new line where Emacs's tree-sitter rules say, and
those rules do not read the project's `.clang-format`. On RMO they are wrong on almost
every line: they indent the `{` after `namespace` and `class`, and everything inside
(`RESEARCH_indent_guessing.md` 3). clangd knows the project's style, and eglot already
asks it on every newline where the new line belongs ("on-type formatting"). The answer
was right, but Emacs's electric indentation ran after it and moved the line back.

Now, in a C++ buffer that eglot manages with a server that formats on newline,
electric indentation no longer reacts to newline, so clangd's indentation stays.
clangd also reformats the line that RET ended (`int  x   = 1;` becomes `int x =
1;`); the owner chose to keep that line as typed (O-28, 2026-10-10), so it is put
back. Everything else is unchanged: TAB, and the re-indentation when typing `}`, `;`
and the other electric characters, still follow Emacs's rules; buffers without
eglot (no presets, or Python) behave as before.

## Concepts (Emacs Lisp) explained
- **`post-self-insert-hook`.** A list of functions Emacs runs after inserting a typed
  character; RET's command `newline` runs it too, with the character set to newline.
  Eglot's on-type request and electric indentation both live there. Each function can
  carry a depth: lower runs first. Eglot's is at 0, electric indentation's at 60; this
  change adds one at -50 (save the line above) and one at 50 (put it back).
- **`electric-indent-chars`.** The characters after which electric indentation
  re-indents the line. Newline is one of them by default; removing it buffer-locally
  (`setq-local`) stops only that reaction.
- **`eglot-managed-mode-hook`.** Runs when eglot starts managing a buffer and again
  when it lets go (server shut down or lost), so one function both sets up and undoes.
- **Markers.** A marker is a buffer position that moves with edits; the saved line
  start stays on the right line while clangd's edits land.

## Key files walked
- `lisp/init-cpp.el` - `emacs-cpp-ret-by-server` (set up / undo, from
  `eglot-managed-mode-hook`), `emacs-cpp-ret--save-line-above`,
  `emacs-cpp-ret--restore-line-above`; the hook is added in eglot's `use-package`
  `:config`.
- `test/init-cpp-test.el` - `init-cpp-ret-indents-by-clangd` (columns, line above,
  `}`, after shutdown), `init-cpp-ret-shows-server-errors`, `init-cpp-ret-without-eglot`.
  With `emacs-cpp-ret-by-server` disabled the first two fail, the third passes (it
  checks behaviour that must not change).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** clangd keeps announcing on-type formatting with newline as trigger and
  answers in a few milliseconds (batch: 2 - 6 ms on a toy file). **Would break if:** a
  slow answer on a large file makes RET lag; each RET waits for it. **DESIGN bet:**
  D-061.
- **Assumed:** clangd's edits on newline touch only the line above and the new line,
  and do not join or split lines. **Would break if:** an edit removes the line break
  above the saved marker; the restore would then rewrite the wrong text. Not seen.
- **Risk:** a failed request leaves the newline inserted and the line above as clangd
  left it (nothing changed yet, since the request failed); the error shows, and the
  next keystroke clears the saved line (tested).
- **Risk:** the new line follows `.clang-format` but TAB on it follows Emacs's rules, so
  TAB right after RET can move it; on RMO the three rules in `.dir-locals.el`
  (MANUAL 8) keep the two close.

## How to verify
`make test` (57 tests; the three `init-cpp-ret-*` cover this). Owner, on RMO: open
`src/main_coarse.cc`, wait for clangd (the mode line shows eglot), press RET at the
end of a line inside the namespace and inside a function: the cursor lands where
`.clang-format` puts it, the line above is unchanged, and RET feels immediate.
