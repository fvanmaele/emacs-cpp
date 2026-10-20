# 0089 - The owner's Arch runs (S10, S16, S18, bench) and ty researched

- **Date:** 2026-10-20
- **Commits:** see `git log -1 --grep "S10, S16, S18 Arch runs"`
- **Tier:** 1 (spike results and research; no code)
- **Decisions:** none new; O-72 opened; bears on D-124, D-127, O-12, D-045
- **Done when:** each run's verdict in its RESULTS.md, the done `H-n` removed, ty's
  findings in a RESEARCH doc with the ruling asked as an O-n
- **Tag:** none

> Plain English record of results coming back from the owner's machine.

## What + why
The owner ran H-1, H-2, H-3, H-6 and H-12 on Arch and asked for research into
replacing pyright with ty. Results, in each spike's `RESULTS.md`:
- **S16** (D-124): PASS compiled, FAIL interpreted. The function gives the regexps'
  tier for all 277632 pairs in every state and is 2.3 - 3.7 times faster compiled, 41 -
  48 ms on the largest prompt against D-120's 89; interpreted it is about twice as
  slow. The criteria in RUN.md are still marked proposed, so the owner confirms them;
  D-124 then waits on S17 (D-125) as before.
- **S18** (D-127): FAIL on Arch on criterion 3 alone: 194 ms of Emacs CPU per 1000
  records against at most 50 (the Mac: 6). Every created file arrives, no overflow,
  nothing left running. Both matchers cost the same, so the matcher is not it; the
  suspect (UNVERIFIED) is one notification per record on inotify. Run 2 counts
  filter calls and batches sends by a timer; the session can run it on this machine.
- **S10** (O-12): FAIL by the letter, for the config, not the question. H-6 named
  `src/main_sparsity.cc`, which RMO no longer has; the owner ran `main_matrix.cc`
  with `n_dofs`, RMO's own member, so no request
  went into deal.II. The run found a real defect: the runner's `MountPoint: /` makes
  clangd skip the background index of every file under it (read in
  `ConfigCompile.cpp:419-422`), `M-?` 7 -> 2 for the patched clangd. Run 2: a
  deal.II name in a probe file of the copy, and a second config fragment that turns
  the background index back on (UNVERIFIED that it does).
- **Bench** (review 0084, 5b item 6), Arch, commit a35b8cd, load 0.96: startup median
  0.182 s (0.180 - 0.198, 1 collection each, budget 0.5 s holds); `make test` 135 of
  135, 37.5 s wall. The review's machine: 0.097 s, 20.2 s.
- **H-1**: `clangd-index-nav 23.1.3-9` installed (`pacman -Q`, read here); T-111 and
  T-108 wait only on the owner calling them done.
- **ty**: `RESEARCH_python_ty.md`. ty 0.0.90 answers every request the config uses,
  six times faster to the first diagnostics on a 139-file project, fills
  `workspace/symbol` where pyright had nothing yet, and stays up when its watch
  registration is refused (pyright stops answering, the reason for D-121's watch
  advice). No MacPorts port found. O-72 asks pyright or ty, recommends ty on Arch and
  pyright on the Mac until a port exists.

## Key files walked
- `spikes/s10-library-index/RESULTS.md`, `spikes/s16-match-function/RESULTS.md`,
  `spikes/s18-fswatch-backend/RESULTS.md`: verdicts, tables, run 2 proposals; the
  owner's logs kept as `owner-arch-run1.log` next to each.
- `RESEARCH_python_ty.md`: findings; DESIGN O-72 the options.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** S18's Arch cost is the per-record send, not the tree or the machine.
  **Would break if:** run 2 with batched sends still costs over 50 ms per 1000
  records; then D-127 needs another reader (or fewer records) on Linux.
  **DESIGN bet:** D-127.
- **Assumed:** a later clangd config fragment restores the background index under an
  external index's mount point. **Would break if:** clangd applies the external
  index's `Skip` after all fragments; then O-12 needs the index in the project's own
  `.clangd` or a clangd patch. **DESIGN bet:** O-12.
- **Assumed:** ty's speed on a stdlib copy carries over to the owner's projects.
  **Would break if:** a real project with heavy dependencies (numpy, matplotlib)
  is slow or wrong under ty; the hand check of O-72 is for that.

## How to verify
`make docs-check`. The logs are the owner's; the ty numbers rerun with any LSP client
against `ty server` and `pyright-langserver --stdio`, as RESEARCH_python_ty states.

## Standard feedback (optional; the standard pulls it with `make feedback`)
- Hurt: rule on grounded plans: an `H-n` step named a file that a later commit in
  another repository (RMO) removed; the check runs when the item is written, not when
  the owner runs it.
