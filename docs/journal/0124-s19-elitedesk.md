# 0124 - S19 on hp-elitedesk: criteria 1 - 5 pass, criterion 6 open

- **Date:** 2026-11-04
- **Commits:** see `git log S19 -- spikes/s19-gap-trigrams` (branch `S19`)
- **Tier:** 3 (spike S19, T-132)
- **Decisions:** D-171, D-172 (machine, ratios), D-173 (tier 3 is D-120's); opens O-83
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** S19's criteria 1 - 6 of `spikes/s19-gap-trigrams/RUN.md` (as D-172
  and D-173 amend them) judged; 1 - 5 here, 6 waits for O-83.

> Plain English for someone who does not read C++ fluently.

## What + why
clangd finds a symbol for `workspace/symbol` only if the symbol holds every
three-letter run of the query, as letters that follow each other or jump to the next
word part. So `eto` never finds `Vector`. S19 tried D-171's fix in a spike patch: a
second kind of trigram, every three letters in order inside one run of letters and
digits (the owner's rule D-120, ruled for S19 as D-173), looked up only when the
request asks for gap matches, and a third ranking tier below the two clangd already
has.

On this machine, against deal.II's library index (186162 symbols), the patch keeps
every list without the field exactly as it was (criterion 2), puts gap matches only
below the others (criterion 1), adds 15.5 MB (criterion 3, limit 20), and keeps
queries with the field at limit 100 under 8 ms (criterion 5, limit 8.2). Building the
index took 2.64 times as long at first, over criterion 4's 2.31; caching the gap
trigrams per name (60207 names among 186162 symbols) brought it to 2.21 times.
`eto` finds `dealii::Vector`, but only at `M-o`'s limit of 10000 (first at rank 1480
at the server): at 100 the first two tiers fill the list.

Criterion 6, `M-o`'s keys on RMO, is not run. RMO is not here, and the number it was
written against (S11's 2 - 30 ms) came from a cheaper request than the one `M-o`
sends, while the field costs up to 23 ms per index per key at `M-o`'s limit. Which
request and which limit count is O-83.

## Concepts (C++ and clangd) explained
- Posting lists: for every trigram, the list of symbols that hold it, sorted by
  quality; a query intersects the lists of its trigrams. The patch adds lists for
  the gap kind and, with the field, intersects "ordinary or gap" per trigram.
- Two passes: Dex keeps only the best `limit x 100` candidates before it matches.
  With the field the patch runs today's pass unchanged, then a second pass under its
  own cap, and merges them, so a broad gap query cannot push a weak tier 1 - 2
  candidate out.
- Tiers as score ranges: tier 1 scores are positive, tier 2 in [-1, 0), tier 3 in
  [-2, -1), so sorting by score keeps the tiers apart.

## Key files walked
- `spikes/s19-gap-trigrams/s19.patch` - Trigram.cpp/.h, Token.h, Dex.cpp, MemIndex.cpp,
  FuzzyMatch.cpp/.h, Index.h/.cpp, Protocol.h/.cpp, ClangdLSPServer.cpp,
  FindSymbols.cpp/.h.
- `spikes/s19-gap-trigrams/bench.cpp`, `build.sh`, `classify.cpp`, `client.py`,
  `compare.py`, `count_trigrams.py`.
- `spikes/s19-gap-trigrams/RESULTS.md` - the numbers.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** recomputed scores (match times quality, boosts 1) are Dex's. **Would
  break if:** a boost differs; `compare.py lists` found no rising score in any list,
  which a wrong recomputation would likely show. **DESIGN bet:** D-173.
- **Assumed:** this index stands for the Xeon's (128391 symbols there). **Would break
  if:** ratios differ with index size; criteria 4 and 5 are ratios of this machine's
  own baseline (D-172). **DESIGN bet:** D-172.
- **Assumed:** limit 100 is the request criterion 5 means (section 20 measured there).
  **Would break if:** the owner judges `M-o`'s 10000, where `eto` takes 22.9 ms per
  index; O-83. **DESIGN bet:** D-171.
- **Assumed:** the per-name cache is part of the patch S19 judges. **Would break if:**
  the owner counts the first build (2.64 times, criterion 4 failed); both reported.
  **DESIGN bet:** D-171.

## How to verify
`spikes/s19-gap-trigrams/RUN.md`'s commands on a machine with the patched tree and
`indexes/dealii.dex`; `compare.py lists`, `same`, `tiers` on the outputs.
