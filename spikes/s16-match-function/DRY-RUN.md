# S16 dry run - Mac, 2026-10-20

Not a verdict: budgets bind on Arch (D-057); the owner's Arch run gives `RESULTS.md`.
Criteria 1 and 2 do not depend on the machine.

## Environment
The owner's Mac (Apple silicon, 11 cores), MacPorts Emacs 31.1 with native
compilation, load 4.6 - 5.1 (not idle: G DATA scanning, D-057's note). Corpus: the
deal.II checkout at v9.6.2, `git ls-files`, 33768 names. Commit: the tree after
4683f20. Log: `dry-run-mac.log`.

## Measurements
1. Spec: 15 rows and the sort example, 0 failures in each state.
2. Agreement: 270144 pairs (8 inputs x 33768 names), 0 disagree in each state; the
   regexps' tiers 1 / 2 / 3: 4332 / 2708 / 263104.
3. Sort time, best of 5, ms (rx the regexps, fn the function; int interpreted, nat
   native). On the set orderless's filter lets through (what a prompt sorts):

| input | filtered | rx int | fn int | rx byte | fn byte | rx nat | fn nat |
|---|---|---|---|---|---|---|---|
| vec | 3881 | 20.1 | 33.5 | 17.1 | 6.0 | 16.5 | 5.0 |
| tria | 11950 | 110.3 | 204.2 | 104.5 | 32.9 | 102.1 | 25.4 |
| fe | 8789 | 62.3 | 105.0 | 52.7 | 17.3 | 51.5 | 14.1 |
| vt | 5489 | 42.8 | 77.3 | 37.1 | 12.3 | 36.7 | 9.4 |
| dofh | 5911 | 55.6 | 105.9 | 48.2 | 16.6 | 47.8 | 14.5 |
| fe q | 633 | 5.8 | 7.7 | 5.2 | 1.3 | 4.9 | 1.1 |
| grid in | 2837 | 27.0 | 37.3 | 25.0 | 6.7 | 22.6 | 5.2 |
| sparsematrix | 472 | 3.5 | 6.3 | 3.1 | 1.1 | 3.0 | 0.9 |

   On all 33768 names (review 0084's method):

| input | rx int | fn int | rx byte | fn byte | rx nat | fn nat |
|---|---|---|---|---|---|---|
| vec | 244 | 420 | 198 | 61 | 189 | 45 |
| tria | 302 | 505 | 247 | 76 | 244 | 62 |
| fe | 251 | 427 | 209 | 64 | 200 | 51 |
| vt | 252 | 446 | 203 | 62 | 198 | 48 |
| dofh | 277 | 507 | 223 | 74 | 214 | 61 |
| fe q | 467 | 466 | 394 | 66 | 389 | 51 |
| grid in | 356 | 456 | 286 | 66 | 278 | 51 |
| sparsematrix | 275 | 527 | 236 | 84 | 219 | 64 |

## Reading
- The function is the regexps' rule, exactly, on a real tree: criteria 1 and 2 hold.
- Interpreted (as `lisp/` ships today) it is 1.3 - 1.9 times slower on the filtered
  sets: criterion 3 fails in that state. Compiled, it takes about a third of the
  regexps' time (byte) or a quarter (native); the regexps gain little from
  compiling (their matching runs in C already).
- So D-124 hangs on D-125: the function only with compiled `lisp/` (S17).
- The regexps' interpreted 110 ms for `tria` (11950 names) here sits above D-120's
  89 ms for 35000 on Arch: a slower or busier machine, not a new finding; Arch
  decides.

## Gotchas
- `native-compile` refuses a function already byte-compiled in the session: each
  state runs in its own Emacs (`run.sh`).
- `downcase` can change a string's length for a few letters; the function then
  signals (none in this corpus). The app code must decide that case (e.g. fall back
  to case-sensitive indices) before it ships.
