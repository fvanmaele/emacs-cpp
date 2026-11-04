# 0125 - S19 criterion 6 on RMO-drafts: FAIL, S19 FAIL

- **Date:** 2026-11-04
- **Commits:** see `git log S19 -- spikes/s19-gap-trigrams` (branch `S19`)
- **Tier:** 3 (spike S19, T-132)
- **Decisions:** D-174 (owner: "RMO-drafts with RMO; O-83 (b)"); opens O-84
- **Host:** hp-elitedesk (i5-6500, 4 cores, 15 GB, Arch)
- **Done when:** criterion 6 as D-174 rules it judged; with 0124's criteria 1 - 5, S19
  has its verdict.

> Plain English for someone who does not read C++ fluently.

## What + why
0124 left S19's last criterion open: how fast `M-o` stays when every key asks clangd
for gap matches too. The owner ruled (D-174): on RMO-drafts, each key `M-o` sends,
in the request it really sends (up to 10000 symbols), with the gap field at most
twice the time of today's clangd and at most 30 ms.

RMO-drafts' `fmt` submodule is not checked out here, so the session ran a copy of
its files in the scratch directory with the installed fmt, configured with its own
preset. One clangd per run held RMO-drafts' background index and deal.II's library
index, as the config starts it. Three runs each of today's clangd, the patched one
without the field and the patched one with it, 26 keys each.

With the field, 16 of 26 keys take more than twice as long; `eto` goes from 15.9 to
411.9 ms, `ptr` from 27.8 to 386.4 ms. The patched clangd without the field is as
fast as today's, so the cost is the field. It is the reply, not the index lookup: a
broad three-letter key now returns up to 10000 symbols where it returned a few
hundred, and clangd spends its time scoring and serialising them. Today's clangd
itself exceeds 30 ms on 8 keys at this limit, so that half of the rule could not
hold on this project in any case. S19 fails; what follows is O-84 (recommended: stop,
no patch 0014).

## Concepts explained
- Per-key time: the time from sending the request until the reply's last byte has
  arrived, before the test client parses it, so the client's own JSON work is not
  counted; the median of six sends per key.
- A copy with the system library: CMake's `add_subdirectory(fmt)` needs the
  submodule's sources; `find_package(fmt CONFIG REQUIRED)` uses the installed fmt
  instead. Only the copy was changed.

## Key files walked
- `spikes/s19-gap-trigrams/keys.py`, `compare.py` (`keys`).
- `spikes/s19-gap-trigrams/keys/` - the nine runs, `criterion6.txt`,
  `control-nofield.txt`.
- `spikes/s19-gap-trigrams/RESULTS.md` - criterion 6's table and findings.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO-drafts' 17 translation units stand for RMO (D-174). **Would break
  if:** RMO's background index is much larger; the field's reply cost is driven by
  deal.II's index and broad keys, so a larger project index would raise it.
  **DESIGN bet:** D-174.
- **Assumed:** a reply's time on the client side stands for what `M-o` waits.
  **Would break if:** Emacs's JSON parse of 10000 symbols (not counted here) changes
  the ratio; it adds to both sides, more to the field's larger replies.
  **DESIGN bet:** D-174.
- **Assumed:** the copy with the system fmt indexes as the original would. **Would
  break if:** the submodule's fmt version differs in symbols the keys hit; fmt's
  headers are indexed either way. **DESIGN bet:** D-174.

## How to verify
`python3 -I spikes/s19-gap-trigrams/compare.py keys
spikes/s19-gap-trigrams/keys/keys-base-*.jsonl --
spikes/s19-gap-trigrams/keys/keys-gap-*.jsonl`; a new run with `keys.py` as in
RESULTS.md's criterion 6 section.
