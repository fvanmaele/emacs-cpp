# 0072 - T-084: symbols in clangd's order, `M-o` ignores case

- **Date:** 2026-10-15
- **Commits:** see `git log --grep T-084` (the code and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-105 (O-55 (a) + (b)); D-069 (a vendored fix as a patch file)
- **Done when:** `emacs-cpp-go--symbol-request` keeps each reply's order (no sort by
  `:score`), servers' replies one after the other in arrival order; `C-c l s` the same
  through consult-eglot patch 0001, `:sort nil` kept; `M-o` binds
  `completion-ignore-case` t while its prompt is open. Tests for both orders and for
  `readme`; the patch applies at the pin; terminal check on the toy (`count` before
  `count_vertices_globally` in `M-o` `< s` and `C-c l s`); `make test` on the Mac.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
clangd answers a `workspace/symbol` request with its best matches first; its ranking
counts how well the name matches. Each symbol also carries a `score`, but that number
leaves the name match out (clangd says it is "for client-side re-ranking") and halves
for a symbol inside a namespace when the query names none. Both symbol prompts sorted
by that number, so for `vector` a global `vector_n_rows_1d` came above
`dealii::Vector`, the exact name clangd had sent first (RESEARCH_go_to_anything 14).
Now `M-o` and `C-c l s` keep clangd's order, as CLion does (section 15).

`M-o`'s buffers and files were matched case-sensitively, because consult filters them
with its own regexps and `completion-ignore-case` is nil by default; `readme` missed
`README.md`. The prompt now binds it to t, so case is ignored, also as CLion does.

## Concepts (Emacs Lisp) explained
- **`let` binding a global variable.** `(let ((completion-ignore-case t)) ...)` gives
  the variable a new value only while the body runs, the minibuffer prompt included,
  and restores it afterwards. consult reads it at every typed key, inside that time.
- **`append` with a vector.** A JSON array arrives as a vector; `(append list vector
  nil)` copies both into one new list in their order, so a second server's symbols
  land after the first one's.
- **A patch file for a vendored package (D-069).** `consult-eglot` is a git submodule
  pinned to upstream; `make packages` applies
  `patches/consult-eglot/0001-*.patch` (listed in `.gitmodules`) to its working tree,
  so the fix survives a fresh checkout and shows up on a pin bump.

## Key files walked
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--symbol-request`: the reply handler
  appends instead of sorting; `emacs-cpp-go-to-anything` binds
  `completion-ignore-case`.
- `patches/consult-eglot/0001-Keep-each-server-s-workspace-symbol-reply-in-the-ord.patch`
  - drops the `cl-sort` by `score` in `consult-eglot--make-async-source`.
- `test/init-go-to-anything-test.el` - three tests: clangd's order and a second
  server's reply after it, in `M-o`'s source and in consult-eglot's; `readme` finds
  `README.md` through consult's static filter inside the prompt, not outside it.
  Each fails on the code before this change (checked).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** clangd's reply order is its best order. **Would break if:** a clangd
  release returns symbols unordered (the reply comes from a `TopN`, sorted, today).
  **DESIGN bet:** D-105.
- **Assumed:** ignoring case never hides a candidate. It only adds matches; an
  input with capitals now also matches lower case names (no smart case).
  **Would break if:** the owner relies on capitals to narrow; then smart case.
  **DESIGN bet:** D-105.
- **Risk:** with clangd and pyright (or texlab) in one project, the order of their
  replies is arrival order and can change between keys (O-58).
- **Risk, found:** `C-c l s` still reorders by symbol kind: consult-eglot groups the
  list (`:group`) and vertico shows whole groups in order of first appearance; on
  the toy `count_vertices_globally` (Function) shows above `count` (Variable).
  `M-o` has no kind groups. Open as O-58 (g) / (h).

## How to verify
- `make packages` (says 6 patches in force), `make test`.
- Toy (any CMake project with a preset): `M-o` `< s` `count` lists `count` before
  `count_vertices_globally`; `M-o` `readme` finds `README.md`; `C-c l s` `vector`
  lists `Vector` first.
- Owner, on RMO: `M-o` `< s` and `< l` with `vector`, `count`; `C-c l s` the same,
  noting the kind groups.

## Open questions (optional)
O-58 in DESIGN: order of several servers' symbols; `C-c l s`'s kind groups.
