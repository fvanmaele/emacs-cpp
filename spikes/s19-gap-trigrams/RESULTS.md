# S19 results

Verdict: open; criteria 1 - 5 PASS, criterion 6 not run (O-83). In full (2026-11-04,
session, hp-elitedesk): criteria 1 (deal.II half), 2, 3, 4 and 5 PASS on this machine
with `s19.patch` as built in step 11a (gap trigrams cached per name); criterion 4
FAILED without the cache (2.64 times the baseline). Criterion 1's
`cml` half is struck (D-173). Criterion 6 (`M-o` on RMO) is not run: RMO is not on
this machine, and the request it should time is open (O-83). S19's verdict waits for
criterion 6.

## Setup
Host hp-elitedesk (Intel Core i5-6500, 4 cores, 15 GB, Arch), D-172. deal.II 9.8.0's
library index built here (`make library-index LIBRARY=dealii`, `indexes/dealii.dex`,
68 MB, 186162 symbols; section 20's had 128391). The patched tree: LLVM 23.1.4,
pkgrel 1, patches 0001 - 0013; `s19.patch` applied in place, `ninja clangd dexp`,
restored afterwards (step 12). Benchmarks medians of 21 at load 0.5 - 0.6.

## Criteria
| # | criterion | measured | limit | result |
|---|---|---|---|---|
| 1 | with the field, `eto` returns deal.II's `Vector`; gap matches below every tier 1 - 2 match, 12 queries | index: `dealii::Vector` in tier 3 at rank 458 of 10000; server: 11 deal.II `Vector`s in tier 3, the first at rank 1480 of 10000; no tier 1 - 2 match after a gap match in any list (index, scores never rise; server, by class) | - | PASS (deal.II half) |
| 1 | `cml` -> `class_multilevel_experiment` | struck (D-173: D-120 ranks it tier 4) | - | - |
| 2 | without the field, completion and `workspace/symbol` as pkgrel 1 | index: 36 of 36 lists identical (names, classes, scores); server: 36 of 36 requests equal to both baseline runs up to score ties, completion lists identical | - | PASS |
| 3 | deal.II's Dex grows at most 20 MB | 255.2 -> 270.7 MB (+15.5) | 20 MB | PASS |
| 4 | `Dex::build` at most 2.31 times the baseline (D-172) | 763.5 -> 1684.2 ms (2.21 times); without the name cache 2012.8 ms (2.64 times) | 1763.8 ms | PASS with the cache |
| 5 | each query at most 5 ms times f (D-172), f = 10.968 / 6.68 = 1.64 | with the field, limit 100: at most 7.98 ms (`eto`) | 8.21 ms | PASS (3 % margin) |
| 6 | `M-o` on RMO, keys within S11's 2 - 30 ms | not run | - | open (O-83) |

## Queries (medians, ms; `bench.cpp`, `baseline.txt`, `patched-cache.txt`)
Limit 100 with the field: `eto` 7.98, `get` 6.20, `ptr` 5.82, `tria` 3.8, `vector`
3.78, `vec` 3.3, `nac` 2.2, `rnm` 1.8, `cml` 1.2, `fev` 0.4, `dfh` 0.11, `qgau` 0.04;
sum 37.4 against 12.6 without the field (`middle-100`). At `M-o`'s limit 10000 (not
the criterion's request): `eto` 22.9, `ptr` 11.7, `get` 6.8, the rest at most 3.9;
sum 58.7 against 13.5. With the field the gap pass returns up to 9543 gap matches
(`eto`); `M-o` asks two indexes per key, so about twice that per key on a project
with a deal.II-sized background index.

## Findings
- The gap pass also admits tier 1 - 2 matches today's trigrams never offer
  (FuzzyMatcher skips segments, ordinary trigrams jump only to the next one): with
  the field 0 - 125 more per query at limit 10000 at the server (0 - 52 in deal.II's
  index alone; `rnm` -> `ExcIteratorRangeDoesNotMatchVectorSize`), none lost there;
  at limit 100 they can displace weaker ones (`ptr`, `vec`, `vector`: 3 - 5 swapped).
- `eto` at limit 100 (`C-c l s`) shows no gap match: tiers 1 - 2 fill the 100. The
  gap tier reaches the user only through `M-o`'s 10000.
- Without the per-name cache the generator's cubic work per letter-digit run was
  most of the extra build time; 60207 distinct names among 186162 symbols.
- Memory: the gap lists hold 11.56 M entries (`count_trigrams.py`), about 1.3 bytes
  each in the Dex's estimate.

## Measurement notes (each found and fixed in the session)
- Classification inside the timed callback inflated the query times (run 1 of the
  patched benchmark, kept out); `bench.cpp` now times only `fuzzyFind`.
- Two baseline client runs differ literally (score ties across the limit), so
  criterion 2 compares up to ties; LSP's exposed score is not the rank score, so
  criterion 1 at the server is checked by class (`classify.cpp`), certain bounds
  only (template arguments in reply names).
- The build tree's clangd finds compiler headers under `build/lib/clang`; replies
  are compared with the resource directory normalised.
- The restored tree's clangd answers as pkgrel 1 (36 of 36 requests) and offers no
  `gapMatch`; it is not byte-identical to `/opt`'s, which `makepkg` linked apart.

## Logs
`baseline.txt`, `patched.txt` (without the cache), `patched-cache.txt`;
`lists-base.tsv.gz`, `lists-gap.tsv.gz`; `client-base1.jsonl.gz`,
`client-base2.jsonl.gz`, `client-patched-nofield.jsonl.gz`,
`client-patched-gap.jsonl.gz`. `s19.patch` is the cached version.
