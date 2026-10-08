# S8 - clangd navigation from the index: results

Verdict: FAIL (run 1, 2026-10-08). Speed met (first `M-.` 1356 ms vs 9281 ms, same
target), but find-references returned 14 entries against the system clangd's 26: a bug
in the patch, found and fixed in clangd commit bd81165ed (below). Run 2 decides.

## Environment
Owner machine, 2026-10-08 03:56, load 0.07 at start. System clangd 23.1.1; patched
clangd 23.1.1 from `~/source/repos/llvm-clangd` (commits 8b73a0490, 2c0b7bf32).
Copy of RMO at `/tmp/s8/work/rmo`. Raw output: `results-run1.log`.

## Measurements (RMO, session 2 = fresh server, index on disk)
| clangd | first `M-.` | target | `M-?` |
|---|---|---|---|
| system | 9281 ms | variant | 26 entries |
| patched, `--navigation-from-index` | 1356 ms | variant | 14 entries |
Session 1 (empty index): both about 10 s, as expected.

## Findings
1. The fast path works on RMO: 6.8 times faster first `M-.`, same target.
2. Reference bug: at the cursor the shard records two symbols with the identical range
   (`std::visit`, two declarations; seen in a verbose debug log). The patch kept one;
   the AST path targets both. Fixed (bd81165ed): all symbols at the innermost range
   are targets, references are their union, deduplicated by location.
3. After the fix, on the same copy: the index answer has 16 distinct locations,
   containing all 15 distinct locations of the AST answer plus the call under the
   cursor, which the AST answer lacks. The AST answer lists 11 locations twice (it
   also queries both symbols and does not deduplicate).

## Decision
Pass criterion corrected (RUN.md): the patched `M-?` must contain every distinct
location of the system clangd's answer; equal counts are not expected, since the
system answer contains duplicates. Run 2 with the fixed build and the reference lists
in the log.
