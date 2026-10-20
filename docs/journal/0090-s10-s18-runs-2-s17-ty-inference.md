# 0090 - S10 and S18 run 2, S17's result, ty's diagnostics explained

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "S10 and S18 run 2"`; S17 in cfd84c8, S16's
  criteria in 60dbeb2
- **Tier:** 3 (spike runs; spike code only)
- **Decisions:** D-130 (O-12 (b)); bears on D-127, D-124, D-125, O-72
- **Done when:** both runs' verdicts in their RESULTS.md, the ty differences placed
  rule by rule, O-12 ruled
- **Tag:** none

> Plain English record of two spikes rerun on the Arch machine by the session itself.

## What + why
The owner asked for S18's and S10's second runs, a fix for S10's `MountPoint: /`, and
why ty and pyright report differently on one file; S17's result and S16's criteria
came in on the way (their own commits).
- **S18 run 2: PASS on Arch** in a new mode, `dedup`. Run 1's guess (one notification
  per record) was wrong: 60 filter calls carry 60004 records. The cost was
  `eglot-path-to-uri` (95 us per path, 77 of them in `file-truename`, needless for
  fswatch's true names) and inotify's three records per written file. URIs built
  from the root's and a call's records merged per path: 37 - 39 ms per 1000 records
  (limit 50). The Mac reruns `dedup` (H-13).
- **S10 run 2: FAIL on criterion 1 only.** With a probe file of deal.II calls, `M-?`
  2 -> 19, +218 MB; the first `M-.` gives the declaration because the deal.II index
  is still loading about 5 s after the open. The `MountPoint` fix works both ways:
  a second config fragment and clangd's `--index-file` (no mount point, background
  index left on). The owner ruled `--index-file` (D-130) and asked for research into
  a clangd patch that waits for the library index (T-117).
- **RMO's presets** moved to `CMakePresets-gnu-linux.json` at 23:13 (RMO 0188cc2);
  the config and `cmake --preset` read only `CMakePresets.json`, so the runner copied
  it; the owner then added a symlink in RMO.
- **ty against pyright** (RESEARCH_python_ty 4a): the first "15 against 48" was the
  research client lacking `tagSupport`; with eglot's capabilities both give the same
  39 unused-name hints, and errors 15 against 7: 5 shared, 2 from ty rules off by
  default, 8 from pyright's inference of unannotated code (ty infers no return type
  of an unannotated function and types unannotated parameters `Unknown`), 2 ty alone.

## Key files walked
- `spikes/s18-fswatch-backend/s18-backend.el`: `s18--merge` (records per path),
  `s18--root-uri`, `s18-prefix-uri`, `s18-batch`; `s18-run.el` the modes.
- `spikes/s10-library-index/run.sh`: the probe, the two configs, the flag variant.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** fswatch's paths are true names, so the root's URI plus the relative
  path equals `eglot-path-to-uri`'s answer. **Would break if:** a symlink inside the
  watched tree; fswatch then reports the link's path (UNVERIFIED) and the URI differs
  from the one eglot sends for an open buffer. **DESIGN bet:** D-127.
- **Assumed:** S10's 5 s first `M-.` is the probe's parse, the index's load later.
  **Would break if:** the index loads within the 5 s and the patched clangd's
  index-first path ignores it; T-117 reads the loading path. **DESIGN bet:** D-130.
- **Assumed:** S18's three Arch runs of `dedup` at load 1.1 - 1.4 hold idle.
  **Would break if:** an idle rerun differs by more than the 5 ms seen.

## How to verify
`S18_RUNS=dedup:fake sh spikes/s18-fswatch-backend/run.sh 20000 </dev/null` and `sh
spikes/s10-library-index/run.sh </dev/null` on Arch; `make docs-check`.
