# 0093 - S18 PASS on the Mac in `dedup`: the fswatch backend gated through

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "S18 PASS on both machines"`
- **Tier:** 3 (spike result; no code)
- **Decisions:** D-127 (gated through), D-133 (kept in the package, owner)
- **Done when:** S18's verdict on both machines in RESULTS.md; T-119 proposed
- **Tag:** none

> Plain English record of a spike result from the owner's Mac.

## What + why
S18 asks whether one patched fswatch per server and root, read by config Lisp over
Emacs's own eglot, delivers every change of a 20000-file burst to the language server
at a cost Emacs can carry. Arch passed in run 2 with mode `dedup` (0090). The owner ran
`dedup` on the Mac (H-13): 20000 of 20000 changes, 2 ms of Emacs's CPU per 1000
records, pyright alive, nothing left running. So S18 passes on both machines and D-127
may be built; T-119 proposes its done when. The owner also kept `clangd-indexer` in
the patched package (D-133) and installed pkgrel 10; the deal.II index was rebuilt
with it (38 MB).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the Mac run at load 4 stands for an idle Mac. **Would break if:** an
  idle run costs more, which is unlikely; FSEvents batches records.
  **DESIGN bet:** D-127.
- **Assumed:** a tree grown by earlier bursts (247398 files) measures as the generated
  one. **Would break if:** the backend's cost depends on the tree size; it reads only
  records, so it should not.

## How to verify
`spikes/s18-fswatch-backend/owner-mac-run4-dedup.log`; `make docs-check`.
