# S19 plan (T-132, D-171, D-172)

Session on hp-elitedesk, 2026-11-04. Spike code stays under `spikes/s19-gap-trigrams/`
and is never promoted; a PASS leads to clangd patch 0014 written fresh (D-069). Names
marked NEW do not exist yet; everything else was checked to exist on 2026-11-04.

- [x] 1. Branch `S19` from `main` after the D-172 commit (~2 min)
  No tag: tags need the owner.
- [x] 2. Clone deal.II at v9.8.0, shallow, into `~/source/repos/dealii` (~10 min)
  Network (D-172): https://github.com/dealii/dealii; deal.II 9.8.0 is installed
  (`pacman -Q deal-ii`), so `scripts/build-library-index.sh` takes tag v9.8.0.
- [x] 3. `make library-index LIBRARY=dealii`, memory watched (~25 min)
  Uses `/opt/clangd-index-nav/bin/clangd-indexer` (installed, pkgrel 1); writes
  `indexes/dealii.dex` and `indexes/dealii.stamp` (ignored by git).
- [x] 4. Baseline benchmark against the unpatched libraries (~60 min)
  `bench.cpp`, `build.sh` (NEW): medians of 21 for `Dex::build`,
  `estimateMemoryUsage` and the 12 queries; f for criterion 5. Built before any
  patch, so the baseline binary stays as it is.
- [x] 5. Clients and baseline lists for criterion 2 (~45 min)
  `client.py` (NEW, from `spikes/s15-mid-word-rank`'s client): `workspace/symbol`
  with and without the request field, and a code completion probe; `compare.py`
  (NEW).
- [x] 6. Patch, part 1: gap trigrams and their token kind (~40 min)
  `index/dex/Trigram.cpp`, `index/dex/Token.h`.
- [x] 7. Patch, part 2: the gap kind's posting lists and query path (~40 min)
  `index/dex/Dex.cpp`: built with the ordinary lists, intersected in their place
  when the field is set.
- [x] 8. Patch, part 3: tier 3 and the request field (~45 min)
  `tieredMatch` in `FuzzyMatch.cpp` (patch 0012's code); the field in
  `index/Index.h` / `Index.cpp`, `Protocol.h` / `.cpp`, `FindSymbols.cpp`, as
  `middleMatch`.
- [x] 9. Build the patched clangd (~60 min)
  The patch applied in place to `packaging/clangd-index-nav/src/llvm-project-23.1.4.src`,
  `ninja clangd` in `src/build`, saved as `s19.patch` (NEW). Mostly wait (4 cores).
- [x] 10. Patched benchmark: criteria 3, 4, 5 (~15 min)
  The baseline reruns with the fixed bench (classification outside the timing)
  after step 12 restores the tree.
- [x] 11. Patched clients: criteria 1 (deal.II half) and 2 (~30 min)
  `eto` -> deal.II's `Vector`, gap matches below tiers 1 - 2 for the 12 queries; the
  lists without the field unchanged.
- [x] 11a. Build time: gap trigrams cached per distinct name, rebuild, rerun (~30 min)
  Added 2026-11-04 after step 10: `Dex::build` 2012.8 ms against criterion 4's
  1797 ms; 60207 distinct names among 186162 symbols. Both numbers reported.
- [x] 12. Restore the tree and rebuild (~40 min)
  `patch -R`, `ninja clangd`, the binary compared with pkgrel 1's. Mostly wait.
- [x] 13. Results, journal, the RMO half as an H-n, commit (~30 min)
  RESULTS.md, journal 0124, RUN.md's commands. `cml` struck (D-173); criterion 6's
  H-n waits for O-83 (which request it times), not written.

Session work about 7.5 h, about 2 h of it waiting on builds.

Criterion 6 (D-174, added 2026-11-04 after the owner's "RMO-drafts with RMO; O-83 (b)"):
- [x] 14. D-174 recorded, O-83 resolved (~5 min)
- [x] 15. RMO-drafts copied to scratch, fmt from the system, configured (~10 min)
  The copy in the session's scratch directory; `cmake --preset linux-debug` in it,
  `compile_commands.json` checked.
- [x] 16. `client.py`'s key mode and `compare.py keys` (NEW) (~30 min)
  Each prefix of three or more letters of S11's words and the 12 queries, the
  shipped `M-o` request, two sends, the second timed.
- [x] 17. `s19.patch` applied in place, `ninja clangd dexp` (~10 min)
- [x] 18. Key runs: pkgrel 1, patched without and with the field, three each (~20 min)
- [x] 19. Tree restored and rebuilt, checked against pkgrel 1 (~10 min)
- [x] 20. RESULTS, journal, verdict, commit (~20 min)

## Checkpoint
done 21 of 21; S19 FAIL (0125); steps 14 - 20 approved 2026-11-04
