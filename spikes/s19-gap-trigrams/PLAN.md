# S19 plan (T-132, D-171, D-172)

Session on hp-elitedesk, 2026-11-04. Spike code stays under `spikes/s19-gap-trigrams/`
and is never promoted; a PASS leads to clangd patch 0014 written fresh (D-069). Names
marked NEW do not exist yet; everything else was checked to exist on 2026-11-04.

- [ ] 1. Branch `S19` from `main` after the D-172 commit (~2 min)
  No tag: tags need the owner.
- [ ] 2. Clone deal.II at v9.8.0, shallow, into `~/source/repos/dealii` (~10 min)
  Network (D-172): https://github.com/dealii/dealii; deal.II 9.8.0 is installed
  (`pacman -Q deal-ii`), so `scripts/build-library-index.sh` takes tag v9.8.0.
- [ ] 3. `make library-index LIBRARY=dealii`, memory watched (~25 min)
  Uses `/opt/clangd-index-nav/bin/clangd-indexer` (installed, pkgrel 1); writes
  `indexes/dealii.dex` and `indexes/dealii.stamp` (ignored by git).
- [ ] 4. Baseline benchmark against the unpatched libraries (~60 min)
  `bench.cpp`, `build.sh` (NEW): medians of 21 for `Dex::build`,
  `estimateMemoryUsage` and the 12 queries; f for criterion 5. Built before any
  patch, so the baseline binary stays as it is.
- [ ] 5. Clients and baseline lists for criterion 2 (~45 min)
  `client.py` (NEW, from `spikes/s15-mid-word-rank`'s client): `workspace/symbol`
  with and without the request field, and a code completion probe; `compare.py`
  (NEW).
- [ ] 6. Patch, part 1: gap trigrams and their token kind (~40 min)
  `index/dex/Trigram.cpp`, `index/dex/Token.h`.
- [ ] 7. Patch, part 2: the gap kind's posting lists and query path (~40 min)
  `index/dex/Dex.cpp`: built with the ordinary lists, intersected in their place
  when the field is set.
- [ ] 8. Patch, part 3: tier 3 and the request field (~45 min)
  `tieredMatch` in `FuzzyMatch.cpp` (patch 0012's code); the field in
  `index/Index.h` / `Index.cpp`, `Protocol.h` / `.cpp`, `FindSymbols.cpp`, as
  `middleMatch`.
- [ ] 9. Build the patched clangd (~60 min)
  The patch applied in place to `packaging/clangd-index-nav/src/llvm-project-23.1.4.src`,
  `ninja clangd` in `src/build`, saved as `s19.patch` (NEW). Mostly wait (4 cores).
- [ ] 10. Patched benchmark: criteria 3, 4, 5 (~15 min)
- [ ] 11. Patched clients: criteria 1 (deal.II half) and 2 (~30 min)
  `eto` -> deal.II's `Vector`, gap matches below tiers 1 - 2 for the 12 queries; the
  lists without the field unchanged.
- [ ] 12. Restore the tree and rebuild (~40 min)
  `patch -R`, `ninja clangd`, the binary compared with pkgrel 1's. Mostly wait.
- [ ] 13. Results, journal, the RMO half as an H-n, commit (~30 min)
  RESULTS.md, a journal entry, an H-n for criterion 1's `cml` half and criterion 6
  where RMO is, RUN.md's commands.

Session work about 7.5 h, about 2 h of it waiting on builds.

## Checkpoint
done 0 of 13, now: approval
