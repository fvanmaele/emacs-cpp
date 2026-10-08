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
