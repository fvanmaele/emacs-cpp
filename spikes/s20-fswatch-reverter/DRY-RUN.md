# S20 dry run on the Mac (2026-10-29)

Not a verdict: the criteria were proposed after this run and wait for the owner; the
machine was not idle (load 3 - 4, the owner's Emacs and clangd running). Log:
`dry-run-mac-run1.log` (Darwin arm64, Emacs 31.1, fswatch-no-loss pkgrel 3).

| mode | buffers current after `git` | Emacs blocked at most | VC states current |
|---|---|---|---|
| fswatch-queued | 0.24 s, 0.12 s | 0.15 s, 0.06 s (VC queue: 0.80 s, 0.15 s) | 9.50 s, 9.49 s |
| fswatch | 6.84 s, 6.55 s | 4.11 s, 4.06 s | with the revert |
| fswatch-novc | 0.11 s, 0.13 s | 0.06 s, 0.04 s | not refreshed |
| poll (D-147, Mac) | 11.32 s, 9.99 s | 6.40 s, 6.46 s | with the revert |

Every mode reverted all 189 unedited buffers, none of the unchanged files' buffers,
and kept the edited buffer's edit. Idle fswatch: 6 descriptors, 6.1 MB RSS; ready
0.02 - 0.57 s; no Overflow; gone after `delete-process`.

Against the proposed criteria, `fswatch-queued` meets 1, 2, 4, 5 and fails 3 once:
one VC refresh step blocked 0.80 s (one `git` process; cause not traced, the machine
was busy). An earlier run of the same mode blocked at most 0.20 s.

Findings:
- `auto-revert-handler` refreshes VC per reverted buffer, one `git` process each,
  about 31 ms on this Mac: 189 buffers block Emacs about 6 s. That is D-147's shipped
  behaviour (the `poll` row), a defect in T-127 recorded as O-78, not fixed here.
- Without VC the reverter's whole work for a checkout is 77 - 96 ms of filter time in
  2 - 3 calls.
