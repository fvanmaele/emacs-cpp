# 0112 - D-161: O-79 closed; with the on-access scan off the freeze is gone

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-161 (O-79 (l) with (p); (s) measured)
- **Done when:** the open test and S20's back-to-back pair rerun with G DATA's
  real-time protection off (O-79 (s)).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
0111 found that the quarter-second freeze left after D-156 (e) came from the Mac's
antivirus: G DATA checks a newly written file the first time anything opens it, and
during clangd's reparse that check waits for a CPU. The owner closed O-79 with (l):
T-128 ships with (e), plus (p), a filter that never runs inside itself. The owner
also turned the antivirus's real-time protection off, which let the session test the
reading directly.

With protection off, the first open of a just-written file costs what any open costs
(0.02 - 0.08 ms), idle or under full CPU load, in every place tried. The back-to-back
checkout that blocked Emacs 0.21 - 0.29 s now blocks it 0.075 - 0.116 s, and the 39
file reads in it take about 22 ms instead of 161 - 241 ms. The antivirus was the
residual.

Two things changed along with it. clangd itself runs faster (its own file opens were
checked too), so the reparse is shorter and clangd stayed busy talking for about 33 s
after the first checkout of the pair; the second checkout therefore landed later in
the reparse than before, though clangd still used 3 - 8 cores during it. And the
ordinary checkouts block slightly more (about 0.1 s), because clangd starts working
sooner and competes with the reverts.

## Concepts explained
- Back-to-back pair: two checkouts, the second as soon as clangd has been silent for
  5 s after the first; the case where clangd is still reparsing when files change.
- Real-time (on-access) protection: the antivirus inspects a file when it is opened
  and holds the open until it has decided; turning it off removes that wait.

## Key files walked
- `spikes/s20-fswatch-reverter/opentest.py` (rerun in three places).
- `spikes/s20-fswatch-reverter/mac-d161-rtp-off1.log`, `mac-d161-rtp-off2.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the protection stays off on this Mac. **Would break if:** it is turned
  on again; then a checkout during a reparse blocks 0.21 - 0.29 s again (0111), and
  O-79 (n), an exclusion for the source trees, is the owner's remedy. **DESIGN bet:**
  D-161.
- **Assumed:** the later landing in the reparse does not hide a freeze. **Would break
  if:** a second checkout early in a scan-free reparse blocks long; clangd ran 3 - 8
  cores during the measured ones, the condition that starved the scan before.
  **DESIGN bet:** D-161.

## How to verify
`python3 -I spikes/s20-fswatch-reverter/opentest.py <new directory>`; first opens
equal to second ones. `S20_STEP_WAITS=1 S20_CLANGD_FLAGS=patched S20_MODES=eglot
EMACS=/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs sh
spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`; back-to-back 2's "Emacs
blocked" in `spikes/s20-fswatch-reverter/eglot-share.log`.
