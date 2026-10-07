# RESEARCH - clangd: answering navigation from the index ("ahead-of-time")

Question (owner, 2026-10-08): what would have to change in clangd so that `M-.` and
find-references do not wait for each file's parse, the way ccls answers from its
on-disk index (S6)? Findings only; verdicts go to DESIGN.

Source read: clangd 23.1.1 (`clang-tools-extra/clangd` of the llvm-project 23.1.1
release tarball, unpacked for spike S7). The local checkout `~/source/repos/clangd` is
github.com/clangd/clangd, the release-packaging repository (scripts, workflows,
`releases.md`); it contains no clangd source.

## 1. Where the wait comes from
- `ClangdServer::locateSymbolAt` (go to definition), `findReferences`,
  `findImplementations`, document highlights, symbol info, rename and others all call
  `WorkScheduler->runWithAST(...)`. `TUScheduler::runWithAST` delivers the parsed file
  (preamble plus main file) and waits for it; on first open of a deal.II source that is
  the 7 - 13 s measured in S1 / S5.
- `clangd::locateSymbolAt(ParsedAST &AST, Position, Index)` (XRefs.cpp) uses the AST to
  find the symbol under the cursor and the index only to find where it is defined.
- Precedent for not waiting: `ClangdServer::codeComplete` uses `runWithPreamble` with
  `TUScheduler::Stale` / `StaleOrAbsent`, and `--completion-parse=always|auto|never`
  (`auto` = parse if ready) lets completion run from the index alone. Workspace symbol
  search (`getWorkspaceSymbols`) runs with no file at all, from the index only.
- `locateSymbolTextually` (XRefs.cpp) is an index-based textual fallback, but it is
  only reached inside the `runWithAST` path.

## 2. What the index already stores
- The background index (`index/Background.cpp`) writes one shard per file
  (`BackgroundIndexStorage::storeShard` / `loadShard`); `FileShardedIndex::getShard`
  puts into a file's shard the symbols, references and relations located in that file
  (`IndexFileIn`: `Symbols`, `Refs`, `Relations`, `Sources`).
- Each `Ref` has a `Location` (file URI, start / end line and column), a `Kind`
  (declaration, definition, reference, spelled) and a `Container`.
- The background indexer collects references to main-file-only symbols
  (`CollectMainFileRefs = true`), and its indexing action indexes function locals
  (`IndexFunctionLocals = true`).
- `Sources` is the include graph; each `IncludeGraphNode` carries the file's content
  `Digest`, which clangd already uses to decide whether a shard is stale.
- Missing: a lookup by position. `SymbolIndex` answers `refs(RefsRequest{IDs})` (where
  is symbol X referenced), `lookup`, `fuzzyFind`, `relations`, `containedRefs`; nothing
  answers "which symbol is at line L, column C of file F". The in-memory index keeps
  references keyed by symbol, not by file and position.

## 3. Changes that would be needed (sketch)
1. Position lookup from a shard. Load the current file's shard
   (`BackgroundIndexStorage::loadShard`; the storage is internal to `BackgroundIndex`
   today and would need an accessor), keep its refs sorted by position, and find the
   ref whose range covers the cursor -> `SymbolID`. A new function next to
   `locateSymbolAt` in XRefs.cpp, e.g. `locateSymbolFromIndex(File, Pos, Shard, Index)`,
   then reuses the existing index lookup of definition / declaration; references go
   through the existing `Index->refs`.
2. Validity check. Use the shard only when the editor's current contents hash to the
   shard's `Digest` for that file (and the compile command matches the shard's
   `Cmd`); otherwise positions may be off, and the request takes the normal AST path.
   Because the shard was produced by a full semantic parse of exactly that content and
   command, its answer equals the AST's for every position it covers.
3. Scheduling. In `ClangdServer::locateSymbolAt` / `findReferences` (and highlights),
   answer from the shard when the AST is not ready yet and the digest matches; else
   `runWithAST` as now. `TUScheduler` has no "is the AST ready" query today; one would
   be added, or the fast path is tried first unconditionally.
4. Fallback for positions the index does not record: the `auto` keyword (deduced
   type), `#include` lines, implicit references (conversions, implicit constructors),
   dependent names in templates, some macro uses. These keep waiting for the AST.
5. A switch, following `--completion-parse`: e.g. `--navigation-parse=always|auto`
   (`auto` = use the index while the file is not parsed yet), plus unit tests in
   `XRefsTests` / `BackgroundIndexTests` and a TUScheduler test with a delayed
   preamble.
Size estimate: a few hundred lines plus tests. Not checked: whether upstream would
accept it, or whether an equivalent proposal exists in clangd's tracker.

## 4. Without changing clangd
- Name-based quick jump: while the definition request is pending, query
  `workspace/symbol` (index only, instant) for the identifier at point and offer the
  matches. Imprecise for overloads and equal names in different scopes; it is what
  `locateSymbolTextually` does inside clangd, but earlier.
- Note on memory: keeping a by-position table for every file in memory roughly doubles
  the reference storage; loading only the current file's shard on demand avoids that.
