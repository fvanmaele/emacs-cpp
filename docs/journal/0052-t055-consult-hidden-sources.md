# 0052 - T-055: consult patch, a source hidden by narrowing leaves the list

- **Date:** 2026-10-11
- **Commits:** the commit that adds this entry (`patches/consult/0001-...`,
  `.gitmodules`, `test/init-completion-test.el`, `lisp/init-completion.el` docstring,
  `docs/upstream/consult-async-hidden-sources.md`, S11 run 4 harness)
- **Tier:** 2
- **Decisions:** D-079 (built here), D-069 (patch files), O-34 (a), (c)
- **Done when:** narrowed to symbols on the stand-in tree, updates at most about 5 ms
  per key; widening brings the files back; a test fails without the patch (from the
  owner's choice of O-34 (a), whose measured outcome it restates).
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The owner found `M-o` narrowed to symbols (`s` then space) less calm than `C-c l s`
in deal.II-sized trees. The cause sat in consult: when one source of a combined
prompt is asynchronous, narrowing hides the other sources but keeps their old
candidates in the list, and the completion UI checks every one of them at every key
(15 - 35 ms with 34583 hidden files). A two-part patch to consult makes a hidden
source drop its candidates as soon as input reaches it, and compute them again when
the prompt is widened. Narrowed, each key now costs 0.2 - 4.2 ms, as in `C-c l s`.
Narrowing with `<` then the letter avoids filtering the files by that letter first
(38 ms against up to 97 ms); the command's docstring says so.

## Concepts explained
- **Patch file instead of an edited submodule:** consult stays pinned to its release;
  `make packages` applies `patches/consult/0001-...` before compiling (D-069). It was made
  with `git format-patch` from a temporary commit, after which the submodule went back
  to the pin.
- **`flush`:** in consult's async machinery each source sends its candidates down to a
  merge step; `flush` tells the merge step to drop that source's part of the list.
- **Why two hunks:** the first sends `flush` when a hidden source gets input. The
  second is needed because the file source remembers the last input it computed and
  skips the same input again: type `vec`, narrow, type `t`, delete it, widen, and the
  files would stay missing. Forgetting the last input on `flush` makes widening
  compute it again.

## Key files walked
- `patches/consult/0001-Drop-a-hidden-source-s-candidates-in-asynchronous-co.patch` -
  `consult--async-predicate` and `consult--async-dynamic`.
- `test/init-completion-test.el` - `init-completion-go-narrowing-drops-hidden-candidates`
  drives that sequence through consult's real pipeline; checked to fail unpatched.
- `docs/upstream/consult-async-hidden-sources.md` - the report for consult, with a
  stand-alone reproduction (checked against 3.10 with and without the patch).
- `spikes/s11-go-to-anything/prompt.sh`, `prompt.el` - run 4 (`S11_NARROW=1`).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** only async multi prompts pass input through `consult--async-predicate`
  (in consult 3.10 only `consult--multi-async` uses it). **Would break if:** another
  caller relies on a hidden source keeping its list. **DESIGN bet:** D-079.
- **Assumed:** nothing upstream of `consult--async-dynamic` sends `flush` except the
  patched predicate. **Would break if:** a new step does; it would then recompute an
  unchanged input once (a cost, not a wrong result).
- **Risk:** a consult pin bump with a different upstream fix makes the patch fail to
  apply; `make packages` then stops with git's message (D-069), and the test shows
  whether the new release still needs it.

## How to verify
- `make packages` reports "2 patches in force"; `make test`.
- `M-o` in a big project, `<` `s`, type: the list follows each key without stutter;
  `<` `<` widens and the files for the typed text are back.
- Owner: S11 run 4 (RUN.md), T-054; send the upstream report, T-053.

## Open questions (optional)
None; the deal.II benchmark's setup is the owner's choice (RUN.md run 4).
