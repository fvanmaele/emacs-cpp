# S10 results

Verdict: FAIL (run 2, the session's, Arch, 2026-10-21): criteria 2 and 3 hold, 1 does
not. With the patched clangd and the deal.II index, `M-?` on `n_active_cells` finds 19
uses against 2, and clangd grows by 218 MB (limit 300); the first `M-.` lands on the
declaration (`tria.h:3376`) and only the one 10 s later on the definition
(`tria.cc:15874`): the deal.II index is not loaded when the first request comes, about
5 s after the file opens. Run 1 (owner, 2026-10-20) failed for the config, below; run 2
confirms the config fix by two routes.

## Run 2 (session, Arch, 2026-10-21)
Runner changes (`run.sh`): a probe source `src/s10_probe.cc` written into the copy only
(a `Triangulation<2>`, `hyper_cube`, `refine_global`, `n_active_cells`); the deal.II
config with a second YAML fragment `Index: {Background: Build}`; the run-1 config again
as `patched+dealii-root`; the index given by clangd's `--index-file` flag, no config,
as `patched+dealii-flag`; RMO's presets copied as `CMakePresets.json` when the
checkout has only `CMakePresets-gnu-linux.json` (RMO 0188cc2; the owner has since
added the symlink). Load 0.45 at the start, 1.46 after. Log: `arch-run2.log`.

| variant | first `M-.` `n_active_cells` | after 10 s | `M-?` | `M-?` `refine_global` | RSS |
|---|---|---|---|---|---|
| system | `tria.h:3376` (5539 ms) | same | 1 | 5 | 6994 MB |
| system + deal.II | `tria.h:3376` (4782 ms) | `tria.cc:15874` | 19 | 14 | 1205 MB |
| patched | `tria.h:3376` (5018 ms) | same | 2 | 5 | 990 MB |
| patched + deal.II, two fragments | `tria.h:3376` (5075 ms) | `tria.cc:15874` | 19 | 14 | 1208 MB |
| patched + deal.II, run-1 config | `tria.h:3376` (4980 ms) | `tria.cc:15874` | 18 | 10 | 881 MB |
| patched + deal.II, `--index-file` | `tria.h:3376` (5273 ms) | `tria.cc:15874` | 19 | 14 | 1210 MB |

`refine_global`, asked 25 s after the open, lands in `tria.cc:13792` at once in every
variant with the index.

## Reading (run 2)
- The config fix works: with the second fragment and with `--index-file`, `M-?` on
  `refine_global` finds RMO's uses as well as deal.II's (14); the run-1 config loses
  RMO's own (10), as run 1 saw (7 -> 2 for `n_dofs`). `--index-file` gives clangd an
  external index with no mount point and leaves the background policy alone
  (`ClangdMain.cpp:735-740`; the `Skip` of `ConfigCompile.cpp:419-422` is only in the
  config path). The run-1 config's lower RSS (881 MB) is the project index it skips.
- Criterion 1: every variant needs about 5 s for the first `M-.`, the system clangd
  without an index too, so that is the probe's parse (deal.II headers); the deal.II
  index (38 MB) is loaded in the background and arrives between 5 and 15 s after the
  open (not timed closer, UNVERIFIED). The dry run's first `M-.` reached `tria.cc`
  because its index was already loaded by the time of the request; here it is not.
  The patched clangd's index-first wait (up to 5 s, dry run) does not cover a static
  index still loading.
- The system clangd without an index again holds about 7 GB (8053 MB in run 1); the
  patched one under 1 GB. Not explained (UNVERIFIED cause), twice now.

## Run 1 (owner, Arch, 2026-10-20)

### Environment
Owner's Arch workstation; deal-ii 9.8.0; system clangd 23.1.3, patched
`/opt/clangd-index-nav/bin/clangd`; RMO (`RMO-gross-pitaevskii`, commit 0188cc2) copied
to `/tmp/s10/work`; the deal.II index reused from `/tmp/s10/lib/dealii.dex` (built in
an earlier attempt). Load 3.99 at the start, so not idle. Log:
`owner-arch-run1.log`.

### What ran
H-6 named `src/main_sparsity.cc` and `n_active_cells`; RMO no longer has that file (its
sources are `main.cc`, `main_bench.cc`, `main_coarse.cc`, `main_matrix.cc`), so the
runner refused, and the owner ran `src/main_matrix.cc` with `n_dofs`. In
`main_matrix.cc`, `n_dofs` is RMO's own member (`include/rmo/gpe/gpe.h:434`, which
calls deal.II's `DoFHandler::n_dofs` inside), so every variant lands on `gpe.h:434`, as
it should. Nothing in the run asks for a definition inside deal.II.

### Measurements (owner's run 1)
| variant | first `M-.` `n_dofs` | after 10 s | `M-?` | RSS |
|---|---|---|---|---|
| system | `gpe.h:434` (7774 ms) | same | 2 | 8053 MB |
| system + deal.II | `gpe.h:434` (6572 ms) | same | 2 | 1048 MB |
| patched | `gpe.h:434` (905 ms) | same | 7 | 2391 MB |
| patched + deal.II | `gpe.h:434` (6622 ms) | same | 2 | 1002 MB |

### Finding: `MountPoint: /` turns off RMO's background index
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

### Run 2 as proposed then
- A probe source written into the copy only (`/tmp/s10/work/.../src/s10_probe.cc`, a
  `Triangulation<2>` and a call of `n_active_cells`), so that the name is deal.II's;
  clangd interpolates its flags from the database's neighbours (UNVERIFIED for this
  file until the run prints them).
- The config's second fragment as above.
- The pass criteria unchanged. The session runs it on Arch itself (about 3 minutes,
  the deal.II index reused).
