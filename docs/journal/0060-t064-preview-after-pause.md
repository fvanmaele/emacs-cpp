# 0060 - T-064: `M-o` previews after a pause in typing

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`lisp/init-completion.el`,
  `test/init-completion-test.el`)
- **Tier:** 2
- **Decisions:** D-088 (built here), O-41 (b)
- **Done when:** `M-o` binds a preview key that waits 0.3 s after typed keys and
  previews at once after keys moving through the list; other prompts unchanged;
  terminal check: `answer` at 50 ms per key on a session's first `M-o` handles every
  key without the freeze, preview after the pause, `<down>` previews at once; test
  that the setting is bound; `make test`.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
consult shows the selected candidate as you go ("preview"); for a file it opens the
file in the background. The first file of a kind in a session loads its mode, and
that load cannot be interrupted: an Org file took seconds on the Mac, any first file
0.3 - 0.4 s (O-41). Keys typed meanwhile waited. Now `M-o` previews only once typing
has paused for 0.3 s, so a burst of keys is handled at once; the load, if any, comes
when you stop. Moving through the list (arrows, `C-n` / `C-p`, PgUp / PgDn, `C-v` /
`M-v`) still previews at once, as the owner asked.

## Concepts explained
- **`consult-preview-key`:** a list of keys with a debounce time each; `any` stands
  for every key not listed. consult looks up the key that ran last: a typed letter
  falls under `any` (0.3 s), `<down>` is listed with 0. `M-o` binds the variable
  around its prompt, like its other settings (D-077), so other prompts keep consult's
  default (preview at once).
- **Why not an option to `consult--multi`:** it builds the preview key from each
  source's `:preview-key` or the global variable, and an option passed in would be
  ignored.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-go--preview-key`; the binding in
  `emacs-cpp-go-to-anything`.
- `test/init-completion-test.el` - `init-completion-go-sources-settings-and-action`
  checks the variable inside the prompt, and that typed keys wait 0.3 s while
  `<down>` and `<next>` wait 0.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** 0.3 s is past the gap between keys when typing a word and short
  enough not to feel late. **Would break if:** the owner types slower; then a first
  load can still land between keys. **DESIGN bet:** D-088.
- **Assumed:** the listed navigation keys are the ones used; a key not listed
  (e.g. `M-<`) previews after 0.3 s.

## How to verify
- `make test`.
- Done here (terminal Emacs, toy with clangd, two runs): keys at 0, 50 ... 250 ms
  handled at 0 - 255 ms, symbol request at 456 ms, first preview 812 / 821 ms,
  `<down>` at 1515 / 1526 ms previewed at 1516 / 1527 ms.
- Owner: step-1, `M-o`, type quickly: no stall while typing; arrows preview at once.
