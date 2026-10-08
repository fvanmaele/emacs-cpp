# S10 - navigation into deal.II's own sources

## Risk
O-12 (owner: adopt, spike first, 2026-10-08): `M-.` on a deal.II function lands on its
declaration in the installed header, `M-?` misses uses inside the library, because no
index knows deal.II's sources (the package installs headers only). An offline index
of deal.II 9.8.0's sources (RESEARCH_library_sources_index.md) fixes that for the
stock clangd. Questions: does it work on RMO, with the patched clangd too (the
research saw its index-first path miss the index), at what memory, and is a further
clangd patch needed?

## Prerequisites
deal-ii installed; `~/source/repos/dealii` with the tag of the installed version
(`v9.8.0`); `clangd-indexer` built in `~/source/repos/llvm-clangd/build`; the patched
clangd (pkgrel 5) in `/opt/clangd-index-nav`; cmake, ninja, rsync, the shipped config
built. About 1 GB free in `/tmp` and 10 GB of free memory for the indexer. Best on an
idle machine.

## Commands (owner runs)
```
cd ~/source/repos/emacs-cpp
sh spikes/s10-library-index/run.sh ~/source/repos/RMO-gross-pitaevskii \
   src/main_sparsity.cc n_active_cells
```
About 6 minutes: the deal.II index (once, about 2.5 min; kept in `/tmp/s10/lib` for
reruns), RMO's own index (one session), then four measured sessions.

## What it measures
For the system clangd and the patched one, each without and with the deal.II index:
the first `M-.` on each name and its target, the same 10 s later, the `M-?` count, and
clangd's resident memory. The deal.II index reaches clangd through a private
`XDG_CONFIG_HOME` whose `clangd/config.yaml` names it (`Index: External: File`, with
`MountPoint: /`, which a user config requires); `~/.config/clangd` is not touched.

## Pass criteria
PASS if, with the patched clangd and the deal.II index, the first `M-.` on
`n_active_cells` lands in deal.II's `tria.cc`, `M-?` finds more uses than without the
index, and clangd's memory grows by less than 300 MB. FAIL otherwise; if only the
patched variant misses the index, a clangd patch is needed (was planned as 0009).

## Dry run (synthetic deal.II project, 2026-10-08)
`l2_norm` and `n_active_cells` from a 12-line program on the installed deal.II 9.8.0.
deal.II index: 353 sources, 140 s, 38 MB, peak 9.9 GB.

| variant | first `M-.` `l2_norm` | after 10 s | `M-?` | RSS |
|---|---|---|---|---|
| system | `vector.h:560` | `vector.h:560` | 2 | 945 MB |
| system + deal.II | `vector.h:560` | `vector.templates.h:477` | 8 | 977 MB |
| patched | `vector.h:560` | `vector.h:560` | 2 | 947 MB |
| patched + deal.II | `vector.templates.h:477` (1.3 s) | same | 8 | 974 - 1008 MB |

`n_active_cells`: `tria.h:3376` without the index, `tria.cc:15874` with it (also the
first `M-.` of the system clangd), `M-?` 2 -> 18. The patched clangd uses the index on
the first request (its index-first path waits up to 5 s for indexes to answer); the
system clangd misses it on the first request while it loads. The research's "patched
clangd never loaded the index" came from a config without `MountPoint`, which clangd
rejects in a user config (logged as a config error); no patch 0009 is needed.

## Hand back
`spikes/s10-library-index/results.log`; delete `/tmp/s10` afterwards (or keep
`/tmp/s10/lib` until the decision on where the index lives).
