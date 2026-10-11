# 0051 - S11 run 3: PASS, the shipped go-to-anything command on RMO

- **Date:** 2026-10-11
- **Commits:** see `git log -- spikes/s11-go-to-anything`
- **Tier:** 3 (spike S11)
- **Decisions:** D-074 .. D-078 (built in 0050, confirmed here)
- **Done when:** RUN.md run 2's criteria for the shipped command on RMO (T-049's
  done-when): opening <= 150 ms, each key's results <= 100 ms, symbols <= 200 ms
- **Tag:** none

> Plain English summary of the spike result.

## What + why
T-049 built `emacs-cpp-go-to-anything` fresh from the spike's findings (spike code is
never shipped). Its done-when asked for the spike's timing to be repeated against the
shipped command on RMO. The owner ran it on a busy machine (load 5 - 6): the prompt
opened in 54 - 74 ms, every key showed its results in 2 - 30 ms, clangd's symbols
appeared 122 - 150 ms after the third key, and Emacs did not collect garbage while
typing. The prompt never showed consult's `#`. Details:
`spikes/s11-go-to-anything/RESULTS.md`, run 3.

## Concepts explained
- **Same harness, real command:** `S11_SHIPPED=1` keeps run 2's logging but binds
  `M-o` to the shipped command, so the numbers measure what the owner uses.
- **Why opening got faster than in run 2:** the shipped command lists the files once,
  before the prompt opens; run 2's copy listed them inside consult's source.

## Key files walked
- `spikes/s11-go-to-anything/prompt.el` - the `S11_SHIPPED` branch: binds the shipped
  command, logs file listing time through an advice on `projectile-project-files`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a busy machine makes the numbers worse, not better. **Would break
  if:** never; the criteria held under load.
- **Risk:** the arrival of symbols for inputs beyond three characters is not visible
  in the log (the shipped command does not log replies).

## How to verify
`spikes/s11-go-to-anything/results-run3.log`; RUN.md run 3's command.

## Open questions
None. The owner's hand check on RMO and the deal.II tree completes T-049.
