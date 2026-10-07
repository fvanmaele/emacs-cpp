# S7 - sharded pre-index (LLVM PR 175209)

## Risk
clangd builds its background index inside the editor session: on the first start of a
build directory, and again for every other preset, because each build directory holds
its own index (`<build>/.cache/clangd/index`). At deal.II scale (D-010) that costs
minutes to hours of CPU and several GB while editing. The unmerged LLVM PR 175209 lets
`clangd-indexer` write the same shards offline. Question: does the system clangd
23.1.1 load them without re-indexing, are the results the same, and how long does the
offline run take on RMO? It does not address the per-file parse (DESIGN 11).

## Variant A first: released static index (no build)
Owner input 2026-10-08 (Reddit, "Making clangd fast for big projects"): clangd's own
GitHub releases ship `clangd-indexer`. Release 23.1.0 (2026-09-02) has
`clangd_indexing_tools-linux-23.1.0.zip` (160 MB). It writes one static index file
(`clangd-indexer --executor=all-TUs build/debug > rmo.dex`), which clangd loads with
`--index-file=rmo.dex` (or `.clangd` `Index: File:`), usually with the background index
off (`Index: Background: Skip`). Not live-updated: rerun after changes; clangd's
dynamic index still covers open files. Merged, prebuilt, no PKGBUILD needed. Format
compatibility of a 23.1.0 `.dex` with the system clangd 23.1.1 is part of the test.
The measurement script covers variant A first and variant B (the PR) only if wanted.

## Variant B: build the PR package (owner, optional)
```
cd ~/source/repos/emacs-cpp/spikes/s7-clangd-indexer
makepkg -si
```
Installs the `llvm` 23.1.1 build dependency, builds only `clangd-indexer` with the PR
applied (sources and the pinned PR diff verified by checksum; `prepare()` was run
successfully on 2026-10-08), and installs
`/opt/clangd-indexer-pr175209/bin/clangd-indexer`. Expect tens of minutes on 16 cores.
Remove later with `sudo pacman -Rns clangd-indexer-pr175209`.

## Step 2: measure (owner, script follows)
The measurement script is written and dry-run on a synthetic project once the binary
exists; it will compare, on a copy of RMO: clangd's own background indexing (time,
memory) against the offline sharded run, whether clangd then re-indexes, and
references / workspace symbols from both indexes.

## Known caveats from the PR review
Reference counts are written non-zero (clangd's loader expects zero; Arch's clangd is
built without assertions), and files that failed to parse are not marked. The
comparison in step 2 checks results against clangd's own index.
