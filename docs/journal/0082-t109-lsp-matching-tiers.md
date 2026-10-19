# 0082 - T-109: LSP 3.18 matching with tiers in every prompt

- **Date:** 2026-10-20
- **Commits:** see `git log --grep T-109` (the code, the tests and this entry)
- **Tier:** 2
- **Decisions:** D-120
- **Done when:** orderless's matching styles literal, regexp, initialism and flex,
  case always ignored (`orderless-smart-case` nil, `completion-ignore-case` t),
  `C-x C-f` unchanged (`partial-completion`); `M-o`'s static sources filtered by
  orderless's compiler (consult's regexp compiler replaced, the first-100
  highlighting kept); a tier function (`emacs-cpp-match-tier`) and a stable sort by
  tier for vertico's prompts and `M-o`, `M-o` sorting within each source and leaving
  symbol sources in clangd's order. ERT: `eto` finds `Vector.cc` in `C-c p f` and
  `M-o`, below unbroken matches; `VT` and `vt` find `VectorTools.cc`; tier order on a
  fixed list; `M-o`'s groups stay in source order; `C-x C-f` still completes
  `/u/s/e`. Speed: S11's harness on RMO on Arch meets run 2's criteria (opening under
  150 ms, each key's results under 100 ms); `make test`.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`eto` found no `Vector`, and the config had three matchers with three definitions
(`RESEARCH_go_to_anything.md` 14). LSP 3.18 says a match is the input's letters in
order, ignoring case; the owner chose that for every prompt, ranked in the tiers
clangd uses since patch 0013 (D-120). orderless now matches letters in order
(`orderless-flex`) and initials besides literal text and regexps, case is always
ignored, `M-o`'s buffers and files go through orderless too, and every list is sorted
by tier, keeping its own order inside a tier. clangd's symbols keep clangd's order
and do not reach tier 3 until its pre-filter changes (O-68).

## Concepts (Emacs Lisp) explained
- **orderless matching styles.** Each word of the input is turned into a regexp by
  each style in `orderless-matching-styles` and a candidate matches if any of them
  matches. `orderless-flex` makes `eto` into "e, anything, t, anything, o";
  `orderless-initialism` makes `vt` into "a word starting with v, later one starting
  with t".
- **Regexps compiled once per input.** The tier of a candidate needs "does the word
  start at a word start?". A first version walked each candidate's characters in
  Lisp and took 0.5 ms per candidate (0.3 s for RMO's 2767 files, 5 s for 35000);
  `lisp/` is not byte-compiled. Now each input word becomes three regexps, cached
  while the input stays the same, and Emacs's C regexp engine does the work: 1 - 7
  ms for 2767 names, at most 89 ms for 35000.
- **Word starts in a regexp.** Case-sensitive character classes stand for clangd's
  rule: after the start or a non-alphanumeric character (any case), a capital after
  a small letter or digit, or the last capital of a run before a small letter
  (`[[:upper:]]S[[:lower:]]` for `S` in `HTTPServer`). `case-fold-search` must be nil
  there, or `[[:upper:]]` matches every letter.
- **Stable sort with a key.** Emacs 31's `sort` takes `:key` and keeps equal
  elements in their order, so "by tier, then as before" is one call.
- **`vertico-sort-override-function`.** Vertico uses it instead of a prompt's own
  sort; ours first calls the prompt's own (`display-sort-function`, else vertico's
  history / length order), then sorts by tier. Prompts whose order is the point
  (lines of a buffer, grep hits, xref, errors, the kill ring) and paths in
  `C-x C-f` are left alone.
- **`M-o`'s sources.** consult marks each candidate with its source's number in an
  invisible last character (its "tofu"); `M-o` sorts by that number first, so the
  groups keep their order, and gives symbol candidates one tier, so they stay in
  clangd's order.

## Key files walked
- `lisp/init-completion.el` - `emacs-cpp-match-tier`, `emacs-cpp-match-sort-by-tier`,
  `emacs-cpp-completion-sort`, `emacs-cpp-match-ordered-categories`; orderless's and
  vertico's settings.
- `lisp/init-go-to-anything.el` - `emacs-cpp-go--highlight-first` (orderless's
  compiler), `emacs-cpp-go--sort`.
- `test/init-completion-test.el`, `test/init-go-to-anything-test.el` - six new tests,
  one changed (`readme` finds README.md outside `M-o` too).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** letters in order is wanted in every name prompt. **Would break if:**
  long lists in `M-x` or `C-x b` bury what was found before; tiers put those first.
  **DESIGN bet:** D-120.
- **Assumed:** vertico's internal `vertico--metadata` and consult's
  `consult--tofu-get` stay as they are (pinned submodules). **Would break if:** an
  update renames them; the tests call both paths.
- **Risk:** on a deal.II-sized tree `eto` sorts in up to 89 ms on Arch, near S11's
  100 ms per key; RMO is far below. The owner's S11 run decides.
- **Risk:** orderless's dispatchers (`!` to exclude) still do nothing in `M-o`, as
  before: the compiler's predicate part is not used there.

## How to verify
- `make test`: 132 tests, 0 unexpected (Arch, 2026-10-20).
- By hand: `C-c p f eto` lists `Vector.cc`, files with `eto` unbroken first;
  `M-x VT` or `vt` finds `vertico-...`-style commands by initials.
- Speed (owner): `S11_SHIPPED=1 S11_LOG=spikes/s11-go-to-anything/results-run6.log
  S11_WORDS="main vec eto Tri assemble Sol main vec eto Tri assemble Sol" sh
  spikes/s11-go-to-anything/prompt.sh ~/source/repos/RMO-gross-pitaevskii
  ~/source/repos/dealii src/main.cc`.
