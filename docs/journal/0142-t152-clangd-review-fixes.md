# 0142 - T-152 .. T-154: clangd patches 0014 - 0019 after an adversarial review

- **Date:** 2026-11-22
- **Commits:** the commit carrying this entry
- **Tier:** 2
- **Decisions:** D-212, D-213, D-214; O-93 opened (deferred, T-155)
- **Done when:** (1) each fix has a ClangdTests test, two checked to fail without their
  fix; (2) ClangdTests pass on the Mac; (3) the patches apply to the 23.1.5 tarball and
  give the tested tree; (4) `make test` passes with the built clangd; (5) Arch
  `makepkg` pkgrel 2 and `make test` (H-40). The session wrote this line from the
  owner's ruling "Tier 2, all 'fix' verdicts".

> Plain English for someone who does not read C++ or clangd's code fluently.

## What + why
The owner asked for a multi-agent adversarial review of the clangd patches. Three
reviewing agents read patches 0001 - 0013 in groups: navigation from the index
(0001 - 0004), header flags and reindexing (0005 - 0010), workspace symbols
(0011 - 0013). The session checked the main claims in the code, gave a verdict on
each finding (fix, defer, skip), and the owner ruled "all 'fix' verdicts", tier 2.
Six new patches carry the fixes; the Lisp side changed for workspace symbols.

The serious ones were in navigation from the index. At startup the background index
loads its stored shards one project batch at a time, and the patched clangd answered
`M-?` as soon as the index knew any reference: after a restart it could list 3 of 40
references, and the full answer from the parsed file lost the race. It also waited on
one of clangd's worker threads, in 50 ms sleeps, so two quick `M-.` on an unindexed
symbol could hold the threads the parse it raced needed. Now the index path waits on
its own thread until the shards are loaded, then asks once (0014). References that only
point at the cursor (a constructor called through `make_unique`) are no longer targets
(0015); methods' references, which need overrides, come from the parse (0016); a shard
indexed with another compile command does not answer (0017).

The errored-file retry of patch 0009 turned out to be a design question of its own: six
agents simulated use cases and reviewed a gated design; the owner deferred it
(O-93, T-155, `RESEARCH_errored_retry.md`).

## Concepts (C++ / clangd) explained
- **Shard:** the background index's stored result for one file, in
  `.cache/clangd/index`; loading the shards at startup fills the index before any file
  is parsed again.
- **TUScheduler and its semaphore:** clangd runs parses and requests on a fixed number
  of worker threads; a task that sleeps while holding one keeps a parse from running.
  `AsyncTaskRunner::runAsync` starts a thread outside that pool; it does not carry the
  request's `Context`, so the patch passes it on, and `isCancelled()` then sees a
  cancelled request.
- **Condition variable:** a thread waits until another says "changed"; the load
  counter's end notifies the waiting navigation threads instead of them polling.
- **`RefKind::Spelled`:** set on a reference whose token spells the symbol's name;
  references from macro bodies or implicit calls lack it.

## Key files walked
- `index/Background.cpp` - `waitForLoadedShards` (the wait, 100 ms steps for
  cancellation), the counter released after `loadProject` rebuilt the index;
  `includerOf` with the real path and the once-per-header wait (0018).
- `ClangdServer.cpp` - `runNavigationFromIndex`, `waitForNavigationIndex`; the
  destructor stops and waits for the navigation threads first.
- `XRefs.cpp` - `symbolsAtFromShard` (spelled only), `findReferencesToIndexedSymbols`
  (methods to the AST), `shardCommandMatches`, `locateIndexedSymbols` (no empty answer).
- `FuzzyMatch.cpp` - `workspaceSymbolMatch`, the one rule of Dex, MemIndex and
  `getWorkspaceSymbols`; `identifierOf` keeps an operator's `<`.
- `ClangdLSPServer.cpp`, `Protocol.cpp` - `middleMatch` below 3 an error, null accepted.
- `lisp/init-lsp.el` - `emacs-cpp-symbol-loose-scope-limit` (NEW), the option type of
  `emacs-cpp-symbol-middle-match`, the warning for a clangd offering one match kind;
  `lisp/init-go-to-anything.el` - `M-o`'s limit replaces the one the parameters bring.
- `packaging/clangd-index-nav/` - patches 0014 - 0019, PKGBUILD pkgrel 2.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** once the stored shards are loaded, the index's answer is as complete as
  the parse's cross-file part (both read the same index). **Would break if:** a project
  is never handed over by the compile database during the 5 s; the parse answers then,
  as before. **DESIGN bet:** D-212.
- **Assumed:** a thread per navigation request costs little (two or three per second
  at most). **Would break if:** a client floods requests; each thread ends within the
  wait. Not measured. **DESIGN bet:** D-212.
- **Assumed:** instance methods are a minority of `M-?` targets in the owner's code.
  **Would break if:** most lookups are on methods; they wait for the parse as before
  0001. **DESIGN bet:** D-212.
- **Assumed:** the stored compile command equals the one the database gives now for an
  unchanged configuration (both pass through the same mangler). **Would break if:**
  `.clangd` edits apply per file and differ in the context of the request; navigation
  from the index then never answers (safe, slower). UNVERIFIED on RMO. **DESIGN bet:**
  D-212.
- **Assumed:** a header waiting once is enough: its command is asked for again at the
  next edit, and its includer is known by then. **Would break if:** a header opened
  first keeps the guessed command for the session (D-214's case against).
- **Assumed:** no client sends a `middleMatch` of 1 or 2. The config sends 3 or more.

## How to verify
- ClangdTests on the Mac: 1432 / 1432 (the base 1425 plus seven); with the spelled
  filter or the once-per-header wait reverted, `AllSymbolsAtTheSameRangeAreTargets`
  and `IncluderOfKnownHeaderDoesNotWaitForTheDatabase` fail.
- Patches 0001 - 0019 on a fresh 23.1.5 tarball give the tested tree (`diff -r`).
- `EMACS_CPP_PATCHED_CLANGD=packaging/clangd-index-nav/src/build-tests/bin/clangd make
  test </dev/null`: 204 tests, 2 skipped.
- The Mac (owner, 2026-11-22, clangd installed in `~/opt/clangd-index-nav` at 10:12,
  carrying the patches' messages): `M-.` and `M-?` on a function right; `M-?` on a
  virtual method right, with a longer delay (`transport.h`: the parse answers, as D-212
  intends for methods); `C-c l s` with `geom::vert` right.
- Arch build and `make test`: H-40.

## Review fold-in (agents of this session, 2026-11-22)
Source: three reviewing agents of patches 0001 - 0013, then six agents on the
errored-file retry; no transcript kept.
- **Taken:** navigation 1 - 6 and 8 (D-212); header flags 1, 2 (D-214); workspace
  symbol 1 - 4, 6, 9, 10 (D-213).
- **Deferred:** navigation 4's alternative (methods through relations: impossible, the
  index cannot see what a method overrides); header flags 3 (O-93, T-155), 4 (T-156),
  5 (T-157); workspace symbol 5 (T-158).
- **Not taken:** navigation 5's digest work (0.2 ms), 7 (`#include` text scan fails
  safe), the limit counted before duplicates, UTF-16 columns (UNVERIFIED); header flags
  6 (hidden flags are deliberate, D-027), 7 (one reindex, already paid); workspace
  symbol 7, 8 (rare), the remote index (not built).
