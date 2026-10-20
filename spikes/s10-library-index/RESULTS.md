# S10 results

Verdict: FAIL (owner's run 1, 2026-10-20), by the letter of the criteria and for a
cause other than the one they test: with the deal.II index the patched clangd found
fewer uses (2 against 7), because the runner's config switches off the project's own
index (below). The name measured was RMO's own, so the run says nothing yet about
reaching deal.II's sources; run 2 is proposed.

## Environment
Owner's Arch workstation; deal-ii 9.8.0; system clangd 23.1.3, patched
`/opt/clangd-index-nav/bin/clangd`; RMO (`RMO-gross-pitaevskii`, commit 0188cc2) copied
to `/tmp/s10/work`; the deal.II index reused from `/tmp/s10/lib/dealii.dex` (built in
an earlier attempt). Load 3.99 at the start, so not idle. Log:
`owner-arch-run1.log`.

## What ran
H-6 named `src/main_sparsity.cc` and `n_active_cells`; RMO no longer has that file (its
sources are `main.cc`, `main_bench.cc`, `main_coarse.cc`, `main_matrix.cc`), so the
runner refused, and the owner ran `src/main_matrix.cc` with `n_dofs`. In
`main_matrix.cc`, `n_dofs` is RMO's own member (`include/rmo/gpe/gpe.h:434`, which
calls deal.II's `DoFHandler::n_dofs` inside), so every variant lands on `gpe.h:434`, as
it should. Nothing in the run asks for a definition inside deal.II.

## Measurements (owner's run 1)
| variant | first `M-.` `n_dofs` | after 10 s | `M-?` | RSS |
|---|---|---|---|---|
| system | `gpe.h:434` (7774 ms) | same | 2 | 8053 MB |
| system + deal.II | `gpe.h:434` (6572 ms) | same | 2 | 1048 MB |
| patched | `gpe.h:434` (905 ms) | same | 7 | 2391 MB |
| patched + deal.II | `gpe.h:434` (6622 ms) | same | 2 | 1002 MB |

## Finding: `MountPoint: /` turns off RMO's background index
With the deal.II index the patched clangd finds 2 uses instead of 7 and its first `M-.`
takes 6.6 s instead of 0.9 s; the system clangd's log shows background indexing ending
at once ("Enqueueing 11 commands", then `"kind":"end"`). Cause, read in clangd's source
(`~/source/repos/llvm-clangd/clang-tools-extra/clangd/ConfigCompile.cpp:419-422`): an
external index sets `Index.Background = Skip` for every file under its mount point, and
the runner's mount point is `/`. So with the config as written, every file of the
project loses its own background index, which the patched clangd's index-first
navigation (D-026) relies on. The dry run did not see it: its 12-line program had no
index of its own worth losing.

A later fragment overrides it (the comment there: the setting "will overwrite statements
in any previous fragments", not later ones), so a second YAML document in the same
config file, `Index: {Background: Build}`, should keep both indexes. UNVERIFIED until
run 2. A narrower mount point does not help: clangd uses an external index only for
files under its mount point, and the files asking are RMO's.

The 8053 MB of the system clangd without the deal.II index is not explained; one
sample, not repeated (UNVERIFIED cause).

## Run 2 (proposed)
- A probe source written into the copy only (`/tmp/s10/work/.../src/s10_probe.cc`, a
  `Triangulation<2>` and a call of `n_active_cells`), so that the name is deal.II's;
  clangd interpolates its flags from the database's neighbours (UNVERIFIED for this
  file until the run prints them).
- The config's second fragment as above.
- The pass criteria unchanged. The session runs it on Arch itself (about 3 minutes,
  the deal.II index reused).
