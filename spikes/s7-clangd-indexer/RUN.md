# S7 - sharded pre-index (LLVM PR 175209)

## Risk
clangd builds its background index inside the editor session: on the first start of a
build directory, and again for every other preset, because each build directory holds
its own index (`<build>/.cache/clangd/index`). At deal.II scale (D-010) that costs
minutes to hours of CPU and several GB while editing. The unmerged LLVM PR 175209 lets
`clangd-indexer` write the same shards offline. Question: does the system clangd
23.1.1 load them without re-indexing, are the results the same, and how long does the
offline run take on RMO? It does not address the per-file parse (DESIGN 11).

## Step 1: build the package (owner)
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
