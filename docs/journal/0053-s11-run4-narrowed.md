# 0053 - S11 run 4: narrowed `M-o` as calm as `C-c l s`, also with deal.II's files

- **Date:** 2026-10-11
- **Commits:** see `git log -- spikes/s11-go-to-anything`
- **Tier:** 3 (spike S11)
- **Decisions:** D-079 confirmed
- **Done when:** T-054: `results-run4.log` handed back and RESULTS.md has run 4
  (recorded, not judged)
- **Tag:** none

> Plain English summary of the spike result.

## What + why
The owner had found `M-o` narrowed to symbols less calm than `C-c l s` in deal.II-sized
trees; D-079 patched consult so a hidden source leaves the candidate list. Run 4
typed ten words at one key per 100 ms, in both commands, with RMO's files and with
deal.II's 34602 files, RMO's clangd answering. Narrowed `M-o` now redraws in a median
1.4 ms per key in both trees (`C-c l s`: about 3 ms), with no garbage collection, and
shows the final symbols 107 - 186 ms after the last key, where `C-c l s` takes about
410 ms because it waits for a pause. The price is about twice as many clangd requests.
Details: `spikes/s11-go-to-anything/RESULTS.md`, run 4.

## Concepts explained
- **Throttle against debounce:** `M-o` asks clangd at most every 0.05 s while typing;
  `C-c l s` asks once typing has paused for 0.2 s. Both stay responsive per key now;
  they differ in how soon the list follows the typing.

## Key files walked
- `spikes/s11-go-to-anything/prompt.sh` - `S11_NARROW=1`: `<` `s` and the word in
  `M-o`, then the word in `C-c l s`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO's clangd stands for symbol searches while working in deal.II's
  files. **Would break if:** deal.II as its own clangd project (not measured): a larger
  index may reply more slowly, and `M-o`'s request per key could queue.
  **DESIGN bet:** D-077, D-079.

## How to verify
`spikes/s11-go-to-anything/results-run4.log`; RUN.md run 4's command.

## Open questions
None.
