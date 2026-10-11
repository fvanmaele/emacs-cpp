# 0049 - S11 run 2: PASS, the whole go-to-anything prompt on RMO

- **Date:** 2026-10-11
- **Commits:** see `git log -- spikes/s11-go-to-anything`
- **Tier:** 3 (spike S11)
- **Decisions:** D-077 confirmed
- **Done when:** RUN.md run 2 criteria (RMO: opening <= 150 ms, each key's results
  <= 100 ms, symbols <= 200 ms after the key)
- **Tag:** none

> Plain English summary of the spike result.

## What + why
Run 1 timed the parts of the prompt in a batch Emacs, where garbage collection never
ran. A terminal Emacs then showed collections were most of a key's time, and D-077
adopted four settings against that. The owner asked for the real thing before code:
the prompt as T-049 will build it, on RMO with the patched clangd, listing the
project's files each time it opens. Run 2 typed ten words into it in a terminal Emacs
and logged every screen update. On RMO it opens in about 90 ms, each key shows its
results in 6 - 24 ms, and clangd's symbols appear 120 - 150 ms after the key, most of
that the deliberate 0.05 s waits. Details: `spikes/s11-go-to-anything/RESULTS.md`.

## Concepts explained
- **Garbage collection threshold:** Emacs collects unused memory after a set amount
  of new allocation (800 KB by default). Filtering tens of thousands of names
  allocates megabytes per key, so with the default it collects several times per key.
  Raising the threshold to 64 MB only while the prompt is open avoids that; one
  collection follows when it closes.
- **`while-no-input`:** consult computes candidates so that any pending input aborts
  the work, and starts again 0.2 s later. That keeps typing responsive, but an
  interruption during a long first computation repeats it: here the deal.II file
  list was built twice in 6 of 10 openings.
- **Throttle and refresh:** consult waits after typing before asking clangd
  (throttle) and before redrawing with new results (refresh); D-077 shortens both to
  0.05 s for this prompt, since clangd answers in under 20 ms.

## Key files walked
- `spikes/s11-go-to-anything/prompt.el` - the prompt as D-074 .. D-077 rule it;
  `symbol-request` asks clangd only for non-empty input; `limited-compiler`
  highlights the first 100 hits.
- `spikes/s11-go-to-anything/prompt.sh` - runs it in tmux, two passes.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** keys sent by tmux every 300 ms stand for typing. **Would break if:**
  faster typing interrupts more computations (each restart waits 0.2 s).
  **DESIGN bet:** D-077.
- **Assumed:** RMO stands for the owner's projects. **Would break if:** a
  deal.II-sized project: openings up to 178 ms, first letters up to 139 ms with a
  collection (accepted by D-075).
- **Risk:** the repeated file listing (finding 3) if T-049 lists inside consult's
  static source; listing before the prompt avoids it.

## How to verify
`spikes/s11-go-to-anything/results-run2.log`; rerun with RUN.md run 2's command
(move the log away first).

## Open questions
None; T-049's done-when is next.
