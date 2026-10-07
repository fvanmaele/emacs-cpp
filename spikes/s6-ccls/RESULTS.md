# S6 - ccls: results

Verdict: PASS (2026-10-08). On RMO, a fresh ccls with its cache on disk answers `M-.`
correctly 1.17 s after starting (clangd: 10.5 s per file); a header opened first has
0 errors (O-5); memory 0.71 - 0.86 GB; the timer error is understood (below). Adoption
is the owner's call, because ccls lacks clang-tidy and clangd's refactorings.

## Environment
Owner machine, 2026-10-08 00:52, load 0.6 at start. ccls 0.20250815.1 and clangd
23.1.1, both on clang 23.1.1. Copy of RMO at `/tmp/s6/work/rmo`, `debug` preset, empty
indexes at the start. Raw output: `results-run1.log` (first attempt failed on the
symbol search, see Gotchas).

## Measurements (RMO)
`M-.` on `std::visit` in main.cc. clangd with an empty index; ccls r1 with an empty
cache; ccls r2 a new process with the cache on disk.
| | clangd | ccls r1 | ccls r2 |
|---|---|---|---|
| first `M-.` | 10498 ms | 96484 ms, 9 refusals | 1168 ms after start |
| `M-.` once ready | - | 5 ms | 3 ms (r3) |
| references | 0 (index building) | 13 | 13 |
| errors in main.cc | 0 | 0 | - |
| memory | 7676 MB (indexing) | peak 3914, then 860 MB | peak 709 MB |
| until idle | - | 109 s | 6.3 s (cache load) |
| cache on disk | - | 437 MB | 437 MB |
ccls r3 (fresh, header `include/rmo/fe/assemble.h` opened first): 0 errors; then `M-.`
in main.cc 3 ms. clangd's daily memory with a persisted index is 1.1 GB (S5 run 2).

## Capabilities (declared by each server, same project, 2026-10-08)
Both: definition, declaration, implementation, type definition, references, rename,
formatting, hover, signature help, completion, document and workspace symbols, call
hierarchy, semantic tokens, highlights, folding. clangd only: refactoring code actions
(`refactor`, `info`: extract variable / function, define outline, ...), type
hierarchy, inlay hints. ccls only: code lens. Measured on the toy project with
`.clang-tidy`: clangd reports the clang-tidy finding, ccls reports no diagnostics
(no clang-tidy integration).

## Findings
1. ccls answers from its on-disk index, so after the first indexing of a build
   directory every file answers `M-.` within about a second of starting, instead of
   each file waiting for its own parse.
2. The first indexing of a build directory takes about 110 s (3.9 GB peak); meanwhile
   `M-.` is refused ("not indexed"). Each preset's build directory gets its own cache.
3. For about 1 s after each start ccls answers `M-.` with nothing ("no definitions").
4. Headers opened first get correct flags (O-5 solved by ccls).
5. Timer error, understood: ccls sends `workspace/semanticTokens/refresh` with a `uri`
   parameter the LSP specification does not define; eglot's handler for it takes no
   parameters and is a no-op anyway (its body is commented out). Effect: one ignored
   request per session, nothing else. Fixable by a tolerant method in the config, or
   upstream in ccls.

## Decision
Owner: ccls instead of clangd, stay with clangd, or a hybrid (O-8, DESIGN 11).

## Gotchas
- First attempt stopped on RMO: the script looked only for `dealii::` names and RMO's
  main.cc has `using namespace dealii`; fixed to `dealii::` or `std::` (as S5).
