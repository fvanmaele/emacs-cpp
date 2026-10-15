# 0073 - T-087: `M-o` symbol sources per server

- **Date:** 2026-10-15
- **Commits:** see `git log --grep T-087` (the code and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-106 (O-58 (d) and (h))
- **Done when:** per server an `s` source (the project's symbols) and a hidden `l`
  source (all), each asking that server alone; the calling buffer's server first,
  then eglot's order; headings `Symbol (NAME)` / `All Symbols (NAME)`, NAME the
  server program's file name; narrow keys `s` and `l` shared, one entry each. Tests;
  terminal check with clangd and pyright on a toy; `make test` on the Mac.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
With clangd and pyright (or texlab) running in one project, `M-o` mixed their symbols
in one list, in whichever order the replies arrived (D-105), so the top of the list
could change from one key to the next. Now each server has its own sources, so its
symbols sit under their own heading, and the headings come in a fixed order: the
server of the buffer you called `M-o` from first. `C-c l s` is unchanged: it keeps
consult-eglot's groups by symbol kind (D-106 (h)).

## Concepts (Emacs Lisp) explained
- **A consult source per server.** `consult--multi` takes a list of sources (plists);
  each one's `:name` is the heading vertico shows above its candidates, and the
  sources appear in list order. Building the list with `mapcar` over the servers
  gives one source each.
- **Shared narrow keys.** A source's `:narrow` may be a pair `(KEY . LABEL)`.
  consult shows every source whose key equals the one typed after `<`, and drops
  duplicate pairs from the list it offers, so `s` stays one entry that shows every
  server's symbols.
- **`copy-sequence` before `delq`.** `delq` changes the list it is given; the list
  of servers comes from consult-eglot, so the function copies it first rather than
  alter a list someone else may hold.

## Key files walked
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--servers` (order),
  `emacs-cpp-go--server-name` (the program's file name), and
  `emacs-cpp-go--symbol-sources`, which now makes two sources per server.
- `test/init-go-to-anything-test.el` - `init-go-to-anything-symbol-sources` (four
  sources, order, headings, keys, what `< s` and `< l` show) and
  `init-go-to-anything-symbol-source-asks-its-server`; both fail on the code before.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the server program's file name tells the servers apart.
  **Would break if:** two servers run the same program (two clangd in one project
  does not happen: eglot runs one per language). **DESIGN bet:** D-106.
- **Risk, accepted in the done when:** a server ranked higher that answers later
  pushes the rows below its heading down while you look at them.
- **Risk:** `emacs-cpp-go--server-name` uses `jsonrpc--process`, an internal
  accessor of jsonrpc (the tests used it already); a jsonrpc change would show as
  an error opening `M-o` with a server running.

## How to verify
- `make test`.
- A project with C++ and Python files, both servers running: `M-o` `vector` from a
  C++ buffer lists `Symbol (clangd)` above `Symbol (pyright-langserver)`, from a
  Python buffer the other way round; `<` lists `s` and `l` once each.
