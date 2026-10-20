# RESEARCH - indexing library sources (O-12, Bear)

Question (owner, 2026-10-08): can Bear make compile databases for the dependent
libraries, so that clangd indexes their sources? Findings only; verdicts go to DESIGN.
Measured on the owner machine with the synthetic deal.II project (`src/model.cc` calls
`v.l2_norm()` and `tria.n_active_cells()`), deal-ii 9.8.0-2, clangd 23.1.1.

## 1. What navigation into deal.II gives today
- `M-.` on a deal.II function the project calls lands on its declaration in the
  installed header: `l2_norm` -> `vector.h:560`, `n_active_cells` -> `tria.h:3376`.
  `M-?` lists the declaration and the project's own call (2 references each).
- The definitions are elsewhere: `l2_norm` in `vector.templates.h:477` (installed,
  but included only by the library's `vector.cc`, which no project file includes);
  `n_active_cells` in `source/grid/tria.cc:15874` (not installed at all). The Arch
  deal-ii and boost packages carry headers and binaries, no library sources.

## 2. A compile database for deal.II needs no Bear and no build
- Bear records the compiler calls of a build that runs; it is for build systems that
  cannot write a database (make, autotools, b2). deal.II builds with CMake, which
  writes `compile_commands.json` at configure time.
- Sources at the installed version: `git -C ~/source/repos/dealii archive v9.8.0`
  (the checkout is on master; the tag exists locally; the checkout is not touched).
- Configure (`cmake -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, examples and docs
  off): 38 s, 353 database entries.
- The library sources include generated instantiation lists (`#include
  "lac/vector.inst"`); `ninja expand_all_instantiations` makes all 219 in 1.2 s.
  Nothing else is compiled.

## 3. Indexing it offline
`clangd-indexer --executor=all-TUs --execute-concurrency=16 build/compile_commands.json`
(stock indexer from the local clangd tree, `~/source/repos/llvm-clangd/build/bin`):

| scope | TUs | wall | CPU | peak memory | index |
|---|---|---|---|---|---|
| `lac/vector.cc`, `grid/tria.cc` | 2 | 21 s | 28 s | - | 23 MB |
| `source/lac` | 39 | 19 s | 191 s | 4.7 GB | 13 MB |
| all of deal.II | 353 | 142 s | 2078 s | 10.1 GB | 40 MB |

One TU failed (`vtkDataObject.h` not found; VTK is optional and not installed). The
index is a single `.dex` file; the sharded format would need LLVM PR 175209 (S7).

## 4. Using it in clangd
- `clangd --index-file=<dex>` (experimental, "will be removed eventually") or the
  config `Index: External: File:`. Either becomes an external index, created on the
  first query made under a file's config and loaded in the background: the first
  query after start does not see it yet (log: "Associating ... with monolithic
  index" at the first `M-.`).
- Once loaded (system clangd, second query 10 s later):

| request | without | with the deal.II index |
|---|---|---|
| `M-.` `l2_norm` | `vector.h:560` (declaration) | `vector.templates.h:477` (definition) |
| `M-.` `n_active_cells` | `tria.h:3376` (declaration) | `tria.cc:15874` (definition) |
| `M-?` `l2_norm` | 2 | 9 (also in `fe_series.h`, `chunk_sparse_matrix...`) |
| `M-?` `n_active_cells` | 2 | 19 (also in `grid_generator.cc`, `tria.cc`) |

- Memory: clangd resident 884 MB without, 1000 MB with the index (+116 MB).
- Locations point into the source copy the index was built from (its `include/` and
  `source/`), so that copy has to be kept, at the installed version.
- The patched clangd (`--navigation-from-index`) never loaded the index: its
  index-first answers run without a file's config context, and the external index
  exists only under that context. Requests answered the normal way (AST) do load it.
  A fix would run those lookups under the file's context (a further local patch).

## 5. Where Bear would still be needed
For libraries that do not build with CMake and whose sources should be indexed: the
compiled Boost libraries (b2; e.g. `options_description.cpp`, where lldb-dap stepped
in S2). Their sources are not installed either (Boost 1.92.0 would have to be
downloaded at that version), and most of Boost is header-only, whose headers the
project's background index already covers.

## 6. Not measured
RMO itself (its first `M-.` into deal.II definitions, its memory with the index); a
rebuild after a deal-ii package update (the index and the source copy must follow
the installed version, like D-027's pin); completion or workspace-symbol search over
the library (O-9's other benefit).

## 7. When the index answers the first request (T-117, 2026-10-21)
Owner request 2026-10-21: research a clangd patch that makes the first `M-.` wait for the
library index, and its downsides. S10 run 2 (D-130's `--index-file`) gave the
declaration for the first `M-.` and the definition 10 s later. Read in clangd 23.1.3's
source and measured on Arch with an LSP client of this research (scratchpad, not kept)
against the patched clangd (pkgrel 9) and the S10 copy of RMO (`/tmp/s10/work`):

- **The load is lazy.** `--index-file` becomes an external index spec
  (`ClangdMain.cpp:735-740`). `ProjectAwareIndex::getIndex` (`index/ProjectAware.cpp`,
  near its end) creates the index for a spec on the first query that needs it, and
  `loadExternalIndex` (`ClangdMain.cpp:659-675`) loads it on a task into a `SwapIndex`
  that holds an empty `MemIndex` until then. Nothing queries the index before the first
  request, so the first request starts the load and is answered from the empty
  placeholder.
- **The load is short.** `Associating ... monolithic index` to `Loaded Dex` (148 MB
  estimated): 1.1 - 1.3 s in each of the six runs logged.
- **AST path** (a file without a background-index shard: the probe, or any clangd
  without `--navigation-from-index`): the first `M-.` answers after the preamble, 4.8 s
  here, and only then asks the index. One `workspace/symbol` request at connect starts
  the load at once; then the first `M-.` gives `tria.cc:15874` (2 of 2 runs; without it
  `tria.h:3376`, 2 of 2).
- **Index path of patch 0002** (a source with a shard, `--navigation-from-index`, the
  config's flags; `src/main_bench.cc` of the copy with one added call of
  `n_active_cells`): the shard answers after 0.95 s with the declaration from the
  background index, before the library index has loaded (about 1.25 s after the
  request), with or without the request at connect (4 of 4 runs); 0.5 s later the
  definition. 0002's poll (`pollIndex`, 50 ms steps, up to 5 s) stops at the first
  answer, and an answer without a definition counts.

### Shapes of a fix
- (a) No patch: the config sends one `workspace/symbol` when clangd connects. Fixes
  the AST path; the index path still answers wrong for about 1.2 s after connect, a
  window a person reaches only by `M-.` within a second of opening the project's
  first file. Against: relies on the lazy load, an implementation detail (a clangd
  that loads at startup makes the request a no-op, not a fault).
- (b) Patch, eager load: with `--index-file`, ask the flags spec's index once at
  startup so it loads while the preamble builds (a few lines in `ClangdMain.cpp` or
  `ProjectAwareIndex`). Same window as (a), without a request from Emacs; one patch
  more to carry across LLVM updates (D-123). The 148 MB are spent at start, which
  D-130 does only for projects that name a library.
- (c) Patch, wait: 0002's poll treats an answer that has no definition as "not yet"
  while an external index is still loading, until it has loaded or the 5 s pass.
  Needs a loaded signal the placeholder does not have (`SwapIndex` has no state; a
  flag set by `loadExternalIndex`'s task on success and on failure, else a missing or
  broken index file holds every first request for 5 s). Closes the window. Against:
  the most code in the most-changed part of the patch set (0001 - 0004, upstream's
  `XRefs.cpp`, `ClangdServer.cpp`), so the most rebase work per LLVM release; a
  symbol that the library index does not define either (inline, a template defined
  in a header) waits only for the load, not the 5 s; while waiting the request holds
  a worker thread (0002 polls on `WorkScheduler->run`, as today, up to 5 s).
- Combined: (b) + (c), or (a) + (c): the wait is then 0.3 s at most in practice.

Not measured: a request at connect on the Mac; `M-?` (references) on the index path,
which 0002 polls the same way (UNVERIFIED that it answers early alike).
