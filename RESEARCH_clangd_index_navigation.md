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

## 4. Local implementation (2026-10-08)
Tree `~/source/repos/llvm-clangd` (23.1.1 sources under git, standalone build against
the system LLVM, D-025). Commit 8b73a0490: `BackgroundIndex::loadShard`,
`symbolAtFromShard` / `locateSymbolFromShard` / `findReferencesFromShard` in XRefs,
`ClangdServer::Options::NavigationFromIndex`, hidden flag `--navigation-from-index`,
tests comparing shard and AST answers. Commit 2c0b7bf32: the first version fell back
to the AST at startup because the background index loads its stored shards
asynchronously (verbose log: references answered from the shard, definitions not);
now a task polls the index (50 ms steps, up to 5 s) while the AST path runs, and
whichever answers first delivers the result once (`FirstAnswer` in ClangdServer.cpp);
`locateIndexedSymbol` / `findReferencesToIndexedSymbol` say "not yet" while the index
lacks the symbol. Findings while testing: function-local symbols are not indexed, so
their uses have no shard reference and take the AST path. Result: ClangdTests
1409 / 1409; synthetic deal.II project, second session, first `M-.` 6623 -> 606 ms.
Commit 8df32dbe5 (owner report: `M-.` on `#include <rmo/option.h>` still slow): the
shard's include graph lists the headers that the indexed content included directly
(`IncludeGraphNode::DirectIncludes`, kept per file by `FileShardedIndex`); the one whose
path ends with the spelled name is the answer, as `locateFileReferent` gives it from
the AST. Synthetic project: 6226 -> 1 ms. The same commit logs (verbose) why a request
falls back to the AST.

## 4a. Header compile commands (owner report 2026-10-08)
- `TUScheduler.cpp`, `ASTWorker::update`: a file without a reliable command (the
  database's interpolated guess carries a `Heuristic`) borrows the command of a proxy
  from `HeaderIncluderCache`; that cache is filled only when an open file's preamble
  is built (`HeaderIncluders.update`). The command is chosen at each update, so a
  header opened before its includer is parsed keeps the guess until it changes.
- In RMO the guess is `fmt/src/format.cc` (include paths without deal.II). Fast
  `#include` jumps (patch 0004) made this frequent; reproduced on a toy with a vendored
  fmt library: 2 errors ("Kokkos_Macros.hpp" not found), 0 after `revert-buffer` once
  `main.cc` was parsed.
- The background index knows includers: `BackgroundIndexLoader::load` walks each TU's
  include graph and sets `LoadedShard::DependentTU` for every shard it reaches
  (transitively), and `BackgroundIndex::update` sees each TU's graph when indexing.
  Patch 0005 records header -> TU from both and lets a compilation database wrapper
  in front of the TUScheduler transfer that TU's command
  (`tooling::transferCompileCommand`). Toy: 0 errors by jump and opened first.

## 5. Without changing clangd
- Name-based quick jump: while the definition request is pending, query
  `workspace/symbol` (index only, instant) for the identifier at point and offer the
  matches. Imprecise for overloads and equal names in different scopes; it is what
  `locateSymbolTextually` does inside clangd, but earlier.
- Note on memory: keeping a by-position table for every file in memory roughly doubles
  the reference storage; loading only the current file's shard on demand avoids that.

## 6. Prior work on the same problem (owner question 2026-10-08)
- clangd upstream: the RFC "A C++ pseudo parser for tooling" (Sam McCall, cfe-dev,
  November 2021) targeted the same gap: long warm-up before features work, and no
  symbol results until indexing completes ("people very often value latency over
  correctness when editing C++ code"). It became clang-pseudo, was moved to
  clang-tools-extra, and was removed in September 2024 as incomplete and unmaintained
  (discourse "Removing pseudo parser"); it is not in the 23.1.1 tree.
- clangd today: the background index, a static index (`clangd-indexer`, `--index-file`
  / `Index: External`) and a remote index (for very large projects) all serve
  cross-file queries; none answers a position before the file is parsed. Code
  completion is the exception (`--completion-parse=auto`, index-only when no preamble).
- ccls (and cquery before it): stores, per file, which symbol each token refers to,
  and answers navigation from that on-disk index (S6).
- Microsoft C/C++ extension for VS Code: a "Tag Parser" builds a symbol database
  (`.BROWSE.VC.DB`) and gives quick, "fuzzy" Go to Definition results, also as the
  fallback when the compiler-based engine cannot resolve or is not ready.
- Qt Creator: see section 7.
- Not searched further: CLion internals, web code browsers built on pre-computed
  indexes (Kythe, Sourcegraph scip-clang, Woboq), Emacs ctags-based fallbacks (citre,
  dumb-jump).
- `clangd-indexer` from the local tree (`build/bin/clangd-indexer`, built 2026-10-08) is
  the stock 23.1.1 indexer: the three local commits change only how clangd answers,
  not how it indexes; it writes a monolithic `.dex` (no `--index-type=sharded`, that is
  PR 175209, spike S7).


## 7. Qt Creator (owner question 2026-10-08)
Source read: `~/source/repos/qt-creator`, commit 3ab64c8e2811 (2026-10-07). Read only,
nothing run or measured.
- Two code models. Qt Creator runs clangd (plugin `clangcodemodel`) next to its own
  "built-in" model (plugin `cppeditor` on the hand-written parser in
  `src/libs/3rdparty/cplusplus`). The built-in indexer (`cppindexingsupport.cpp`,
  `index()`) preprocesses and parses every project file and the headers it includes,
  using the include paths and language features of the CMake project part. It keeps
  the result in memory as a `CPlusPlus::Snapshot`. Nothing is written to disk, so it
  runs again in every session. It stays on while clangd is in use: setting
  `EnableIndexing`, default on, or `QTC_NO_CODE_INDEXER=1` to turn it off.
- Routing (`ClangModelManagerSupport` in `clangmodelmanagersupport.cpp`):
  - `followSymbol`, `findUsages`, `globalRename` and `switchDeclDef` go to clangd only
    when `ClangdClient::isFullyIndexed()` is true. Until then they go to the built-in
    model (`CppModelManager::Backend::Builtin`).
  - `isFullyIndexed` becomes true when clangd ends its `backgroundIndexProgress` work
    done progress (`clangdclient.cpp`, `Client::workDone`). Until then the answer comes
    from the built-in model, which looks up names by scope (`LookupContext`) without
    clang's semantic analysis; it does not wait for clangd's AST.
  - When clangd answers a go to definition without a target, and the mode is not
    `Exact`, Qt Creator asks the built-in model again.
- After indexing, Qt Creator waits like any other client. `ClangdFollowSymbol` sends
  `textDocument/definition` and, at the same time, clangd's `textDocument/ast` for the
  cursor (to detect virtual calls and offer overrides). In clangd both run with the
  parsed file (`runWithAST`). The first M-. after opening a file therefore waits for
  the parse, as in S1 / S5. In a second session, the stored shards load and the
  progress ends early. From then on Qt Creator has the same wait that S8 removed, but
  this was not measured.
- clangd command line (`clientInterface`): `--background-index`,
  `--background-index-priority`, `--limit-references=0`, `--rename-file-limit=0`,
  `--clang-tidy=0` (clang-tidy runs separately), `--use-dirty-headers`, and
  `--compile-commands-dir` set to a directory Qt Creator writes from the project.
  None of these flags avoids the wait for the parse.
- Summary: Qt Creator hides the cold-index period with a second, approximate parser
  that runs all the time. It does not answer from clangd's index before the parse, and
  it has no counterpart to `--navigation-from-index`.
