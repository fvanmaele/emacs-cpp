# S16 results

Verdict: PASS in the byte and native states, FAIL interpreted (owner's run 1,
2026-10-20), against the criteria of RUN.md, which are still marked proposed: the owner
confirms them before this verdict stands. D-124 also waits on S17: criterion 3 is
judged in the state `lisp/` ships in, and only D-125 (S17) makes that compiled.

## Environment
Owner's Arch workstation, GNU Emacs 31.1 (native compilation); deal.II source checkout,
34704 names; load 1.48 (one minute; the 5 and 15 minute averages 10.95 and 12.14 from
an earlier job). Log: `owner-arch-run1.log`.

## Measurements (owner's run 1)
| Criterion | interp | byte | native |
|---|---|---|---|
| 1. spec: 15 rows and the sort example | 0 failures | 0 failures | 0 failures |
| 2. agreement, 277632 pairs | 0 disagree | 0 disagree | 0 disagree |
| 3. function no slower on every filtered set | no (1.4 - 2.1 times slower) | yes (2.3 - 3.3 times faster) | yes (2.6 - 3.7 times faster) |
| 3. largest filtered set (`tria`, 12344 names), function | 308.6 ms | 47.5 ms | 41.0 ms |

The 89 ms limit of D-120 holds compiled (47.5 and 41.0 ms) and fails interpreted
(308.6 ms; the regexps take 153.4 ms there). Over all names the function takes 97 -
119 ms byte and 79 - 102 ms native against the regexps' 254 - 516 ms. The Mac dry run
(`DRY-RUN.md`) gave the same shape.
