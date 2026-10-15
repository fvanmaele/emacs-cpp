# S13 - clangd's background index through a symlinked path: results

Verdict: PASS: criteria 1 - 4 on Arch (2026-10-14), criterion 5, macOS under `/tmp`, on
the Mac (2026-10-15, run here on the generated project at the owner's request). The
criteria were proposed in RUN.md and have not been confirmed by the owner yet. Through a
symlinked directory the patched build gives 201 references in 26 files, as at the real
path; without the patch, 3 in 2. Restarts index nothing, and a header opened first still
takes its includer's command.

## Setup
- clangd: the patched tree of pkgrel 7 (23.1.1, patches 0001 - 0009), its clang and
  clang-tools-extra parts copied to `~/.cache/emacs-cpp-s13/tree` and built standalone
  against Arch's LLVM 23.1.1 (`build.sh`, the PKGBUILD's flags). First build 2171
  steps, about 25 minutes on 16 cores; with the patch applied afterwards, 3 steps.
  Baseline = that build without `0001-real-main-files.patch`.
- Project: S12's `gen_project.py`, 24 calling files (27 translation units with
  `combine.cpp`, `meter.cpp`, `tests/main.cpp`), CMake 4.4.4, `cmake --preset debug`.
  `real`: generated and configured at `real/p`. `link`: generated at `linked/p`,
  configured from `link/p` with `link -> linked`, so the database names `link/p/...`.
- Driver: `run.sh` -> `client.py`, clangd with `--background-index
  --navigation-from-index --header-flags-from-index --compile-commands-dir=<db>`,
  root and files sent by their real path (as eglot does), references to `combine` at
  its definition (`src/combine.cpp`) or declaration (`include/calc/api.h`) once the
  index has been idle 3 s. Each run starts its own clangd: run 1 on an empty index,
  run 2 a restart, run 3 a restart opening the header first.

## Measurements (Arch, 2026-10-14)
| Case | clangd | Run 1 refs (files), TUs indexed | Run 2 | Run 3 (header first) |
|---|---|---|---|---|
| real | baseline | 201 (26), 27 | 201 (26), 0 | 201 (26), 0, includer's flags |
| link | baseline | 3 (2), 27 | 3 (2), 0 | 2 (1), 0, includer's flags |
| real | patched | 201 (26), 27 | 201 (26), 0 | 201 (26), 0, includer's flags |
| link | patched | 201 (26), 27 | 201 (26), 0 | 201 (26), 0, includer's flags |

- Criterion 1: link, patched 201 (26) against baseline 3 (2). PASS.
- Criterion 2: real, 201 (26) both builds. PASS.
- Criterion 3: run 2, 0 translation units indexed in all four rows. PASS.
- Criterion 4: run 3, `Compile command for .../api.h from .../src/use_NN.cpp, which
  includes it (index)` in all four rows; patched, the includer is named by its real
  path (`linked/p/src/use_15.cpp`), baseline by the database's (`link/p/...`). PASS.
- The patch's log line in every patched link run: `27 of 27 main files named by their
  real path (2 directories)`; none in the real runs (nothing renamed, no line).
- Update from unpatched shards (baseline's link project, then the patched clangd
  twice): first start 201 (26) with 27 indexed, second 0 indexed. The baseline's
  shards stay on disk next to the new ones (`use_00.cpp.*.idx` twice), unused.
- Index time: every run 1 went idle 0.6 s after the client's open; the patch's lookup
  of 2 directories is not visible in it.

## Criterion 5: macOS under `/tmp` (2026-10-15)
- clangd: baseline the installed `~/opt/clangd-index-nav/bin/clangd` (23.1.3, patches
  0001 - 0009); patched the same tree plus `0001-real-main-files.patch`, built by
  `build-macos.sh` here (S13's `build.sh` is Arch-only; clone of the Mac tree, 3283
  steps). The patch applies to 23.1.3 unchanged.
- `S13_BUILD=/tmp/s13 bash spikes/s13-symlinked-paths/run.sh CLANGD LABEL`; CMake
  3.31.12 writes `/tmp/...` for both projects (`real` too: `/tmp` is a symlink to
  `/private/tmp`), eglot's spelling, the files' true names, is `/private/tmp/...`.

| Case | clangd | Run 1 refs (files), TUs indexed | Run 2 | Run 3 (header first) |
|---|---|---|---|---|
| real | baseline | 3 (2), 27 | 3 (2), 0 | 2 (1), 0, includer's flags |
| link | baseline | 3 (2), 27 | 3 (2), 0 | 2 (1), 0, includer's flags |
| real | patched | 201 (26), 27 | 201 (26), 0 | 201 (26), 0, includer's flags |
| link | patched | 201 (26), 27 | 201 (26), 0 | 201 (26), 0, includer's flags |

- Criteria 1 - 4 hold under `/tmp`: PASS. Every patched run logs `27 of 27 main
  files named by their real path (2 directories)`; the includer is named by its real
  path (`/private/tmp/...`), the baseline's by the database's (`/tmp/...`).
- Unlike Arch, the `real` case is affected on the Mac too: CMake 3.31 writes `/tmp`
  whatever the working directory (RESEARCH_platform_differences 2.2), so every
  project under `/tmp` loses its references with the stock or patched clangd 23.1.3
  without 0010.

## Decision
For the owner (O-50): the patch works on Arch and on the Mac as RESEARCH 2.8
proposed. Patch 0010 written fresh in the packaging (tier 3 passed: criterion 5
holds, 2026-10-15), with a clangd unit test in `BackgroundIndexTests.cpp` and the
config's references test asking for the definition's file too (2.5, Tests).

## Gotchas
- clangd answers `textDocument/references` only for an opened file: asking about
  `combine.cpp` while only `api.h` was open gave none. Run 3 asks at the header.
- Background index progress begins and ends more than once per start (shard loading,
  then indexing); the client waits for 3 s without progress. An earlier client that
  stopped at the first end saw 0.6 s and missed the indexing.
- "Indexed c++17 standard library" also starts with `Indexed`; the count takes lines
  with `Indexed /` only.

## Not covered
- A main file that is itself a symlink (only its directory is resolved, as the
  symbol collector does; RESEARCH 2.8, left open).
- Two database files sharing their last path components (`findEquivalent`).
- A large database: lookups are per directory (2 here); RMO and deal.II not run.
- macOS under `/tmp` with CMake 3.31 (criterion 5, the owner's).
