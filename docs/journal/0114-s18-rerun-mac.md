# 0114 - D-164: S18 rerun on the Mac with a correct CPU clock

- **Date:** 2026-11-04
- **Commits:** see `git log -- spikes/s18-fswatch-backend` (this entry's commit)
- **Tier:** 3 (spike S18)
- **Decisions:** D-164 (O-80 (b))
- **Done when:** S18's `shipped` mode rerun on the Mac with Emacs's CPU from
  `current-cpu-time`, O-80 ruled on the measured number.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
S18 checked that eglot's file watches through the patched fswatch cost Emacs little
CPU: at most 50 ms per 1000 change records. On the Mac it reported 2 ms, but that
number came from `process-attributes`, which on Apple silicon reports CPU time 41.7
times too small (0111, O-80). The owner asked for the run again with Emacs's own
clock (`current-cpu-time`).

Five runs measured 61 - 64 ms per 1000 records, over the limit. Everything else
holds: every created file reached the server, pyright stayed up, readiness in 0.06 s,
no process left behind. Seen per created file, though, the Mac is the cheaper
machine: Linux's inotify writes three records for each new file, macOS's FSEvents
one, so Arch spends 2.9 - 3.2 s of CPU on the 20000-file burst and the Mac 1.2 - 1.3
s. The work comes in 46 filter calls of about 27 ms, so Emacs does not freeze.

The first three runs found the generated tree emptied: macOS removes files under
TMPDIR that nobody used for 3 days. Rerun on a regenerated tree, the numbers did not
change (63 - 64 ms against 61 - 62 ms).

## Concepts explained
- Records against files: fswatch writes one record per event; inotify reports a new
  file as created, modified and closed (three records), FSEvents once. A limit "per
  1000 records" therefore asks less of the Mac per change than of Arch.
- `current-cpu-time`: Emacs's own CPU clock (`clock()`), correct on both machines.

## Key files walked
- `spikes/s18-fswatch-backend/s18-run.el` - `s18-run--cpu` (fixed in cee20d1).
- `spikes/s18-fswatch-backend/mac-run8-shipped1.log` .. `mac-run8-shipped5.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the cost per record is the same with G DATA's real-time protection
  on. **Would break if:** the scanner slows Emacs's handling of these records; the
  filter opens no files, so it should not (UNVERIFIED). **DESIGN bet:** O-80.
- **Assumed:** 27 ms per filter call is not felt. **Would break if:** a larger burst
  or a slower machine makes single calls long; S18 measured no freeze. **DESIGN bet:**
  O-80 (a).

## How to verify
`S18_RUNS=shipped:fake sh spikes/s18-fswatch-backend/run.sh 20000 </dev/null`; the
"Emacs CPU after the block" line in `spikes/s18-fswatch-backend/s18.log`.
