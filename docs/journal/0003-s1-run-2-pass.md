# 0003 - S1 run 2: PASS; headers opened first remain wrong

- **Date:** 2026-10-07
- **Commits:** see `git log -- spikes/s1-compile-db` (this entry is committed with them)
- **Tier:** 3 (spike S1)
- **Decisions:** D-011, D-012 (applied in RMO), D-016 (new)
- **Done when:** RESULTS.md carries a PASS or FAIL verdict (T-001); RMO writes `-std`
  into its database (T-009)
- **Tag:** none

> Plain English. Still no Emacs Lisp here: this entry closes the question of how clangd
> learns the compiler commands, and names the one case that is still wrong.

## What + why
After run 1 the owner changed the reference project (RMO commit 9dc35b7): CMake now
writes `-std=c++20` (D-011), and the project carries the presets file (D-012). Run 2
repeated the measurement on a fresh copy. Source files now parse with no false errors,
and the owner's live check in Emacs confirmed that go-to-definition, find-usages and
jumping into deal.II all work. The three ways of pointing clangd at the database were
equal again, so the owner chose the one that leaves project trees untouched: Emacs
passes the directory to clangd when it starts it (D-016).

## Concepts explained
- **Warm and cold headers:** a header has no entry in the database. When a source file
  that includes the header is already open, clangd remembers that relation and reuses
  the source file's flags for the header ("warm", live check 5: clean). When the header
  is the first file opened, clangd guesses from the most similar-looking path, which in
  RMO is a file of the bundled fmt library ("cold", live check 6: errors).
- **First-parse cost:** clangd builds a "preamble", a cache of everything the file
  includes, on first open. For a deal.II file that is now about 13.4 s and 778 MB;
  later edits reuse it.

## Key files walked
- `spikes/s1-compile-db/RESULTS.md` - verdict, both runs' numbers, the live check.
- `spikes/s1-compile-db/results-run2.log` - raw run 2 output.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** passing `--compile-commands-dir` behaves in a long-running clangd as in
  `clangd --check` (variant D was checked only by the script; the live check used the
  root symlink). **Would break if:** T-004's live use shows "file not found" with D.
  **DESIGN bet:** D-016.
- **Assumed:** a first open of 13.4 s per deal.II translation unit is acceptable once
  per session and file. **Would break if:** the owner finds daily use too slow.
  **DESIGN bet:** D-010.
- **Assumed:** cold headers can be fixed without changing clangd. **Would break if:**
  spike S4 finds no working mechanism. **DESIGN bet:** none yet (O-5).

## How to verify
Read `spikes/s1-compile-db/RESULTS.md` (Run 2 section). In RMO:
`cmake --preset debug && grep -c -- -std= build/debug/compile_commands.json` is 12.

## Open questions
O-5 (cold headers) goes to spike S4, gating T-011.
