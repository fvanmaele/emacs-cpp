# 0050 - T-049: go to anything on `M-o`

- **Date:** 2026-10-11
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`, `spikes/s11-go-to-anything/prompt.el` run 3 mode)
- **Tier:** 2
- **Decisions:** D-074 .. D-078 (built here)
- **Done when:** `M-o` opens one prompt from any buffer; buffers, recent files,
  bookmarks and the project's files (listed before the prompt opens) from the first
  key, clangd symbols from the third, no request for an empty input, commands and
  project roots behind narrow keys; D-077's settings bound only around the prompt;
  `make test` covers the sources, the empty-input rule and the key; S11 run 2's
  criteria hold on RMO when `prompt.sh`'s timing is repeated against the shipped
  command; owner's hand check on RMO and the deal.II tree. (Agreed 2026-10-11.)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
CLion's "search everywhere" finds files, classes, symbols and actions from one
popup. Emacs had a command per kind (`C-x b`, `C-c p f`, `C-c l s`, `M-x`). The new
command `emacs-cpp-go-to-anything` on `M-o` lists, in one prompt: open buffers,
recent files, bookmarks, every file of the current project, and from the third
character clangd's symbols. Commands (`x` then space) and known projects (`p` then
space) are there too but hidden until you narrow to them; `b`, `r`, `m`, `f`, `s`
narrow to the others. Spike S11 measured how to keep it fast (D-077): on RMO each key
shows its results within about 25 ms. Built on Arch; all 80 tests pass; startup
median 0.179 s (10 runs).

## Concepts (Emacs Lisp) explained
- **Sources:** consult's `consult--multi` takes a list of sources, each a property
  list: a name, a narrow key, the items (a list, or a function computing it), or for
  symbols an `:async` pipeline that gets each input and sends results later.
- **Async pipeline:** a chain of small functions, each passing actions to the next.
  Here: `consult--async-min-input 3` lets inputs of three characters or more through,
  `consult--async-throttle` waits 0.05 s between requests,
  `emacs-cpp-go--symbol-request` asks clangd, `consult--async-map` turns clangd's
  answers into lines. The request step sends nothing for an empty input and drops a
  reply whose input has since changed.
- **Dynamic `let`:** a `let` around the prompt changes a global variable only while
  the prompt runs. The command uses it for the garbage-collection threshold (64 MB),
  the highlight limit, the refresh delay and the hidden `#`. Anything the prompt
  starts after it closes (a chosen command, a project switch) sees the usual values;
  that is why those two sources carry their action under `:emacs-cpp-action`, run
  after the `let`, instead of consult's `:action`, which consult runs inside.
- **Pairs as items:** the project files are `(DISPLAY . FILE)` pairs: the prompt shows
  the path from the project root, the action gets the absolute name.

## Key files walked
- `lisp/init-completion.el` - section "Go to anything": `emacs-cpp-go-to-anything`
  builds the sources (`emacs-cpp-go--sources`) and opens the prompt with the bindings;
  `emacs-cpp-go--symbol-source` uses consult-eglot's servers, line format and preview,
  with its own request step; `emacs-cpp-go--highlight-first` limits highlighting.
- `test/init-completion-test.el` - the key; sources, narrow keys and hidden ones; the
  bindings inside the prompt and a command run after it (with a stub prompt); the
  empty-input rule, the third character and late replies (with a stub clangd); the
  highlight limit.
- `spikes/s11-go-to-anything/prompt.el` - `S11_SHIPPED=1` times this command (run 3).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** consult's internal names stay: `consult--multi`, the async steps,
  `consult--regexp-compiler`, `consult--default-regexp-compiler`,
  `consult--file-state`; and consult-eglot's `consult-eglot--servers`, `--state`,
  `--transformer`. **Would break if:** a pin bump renames them; the tests call the
  command and the steps, so `make test` fails then. **DESIGN bet:** D-074, D-077.
- **Assumed:** the first 100 hits in source order are what is on screen. **Would
  break if:** the user scrolls past 100: those lines show without highlighting.
- **Risk:** without the `#` (D-078) a second filter over the symbol results
  (`#vec#push`) is not available.
- **Risk:** symbols appear only when the project's eglot server runs; in a buffer of
  another project or none the prompt has no symbol group, without a message.

## How to verify
- `make test` (80 tests).
- In a C++ file of RMO: `M-o`, type `main`: buffers, recent files and files first,
  then the symbols group; `s` space narrows to symbols, RET jumps. `x` space lists
  commands.
- Owner: S11 run 3, the shipped command timed on RMO:
  `S11_SHIPPED=1 sh spikes/s11-go-to-anything/prompt.sh
  ~/source/repos/RMO-gross-pitaevskii ~/source/repos/dealii src/main.cc`, hand back
  `results-run3.log`; and the hand check on RMO and in a deal.II source file.

## Open questions (optional)
None.
