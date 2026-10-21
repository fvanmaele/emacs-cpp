# 0094 - T-119: eglot's file watches through the patched fswatch

- **Date:** 2026-10-21
- **Commits:** see `git log -1 --grep "T-119"`
- **Tier:** 2
- **Decisions:** D-127 (built), D-121 (superseded in part), D-109, D-055
- **Done when:** T-119's six items (TASKS.md, agreed by the owner 2026-10-21)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
Language servers ask the editor to watch files for them
(`workspace/didChangeWatchedFiles`). Emacs's own watches cost one kernel watch per
directory: on the Mac a kqueue descriptor, refused beyond 975, on Arch an inotify
watch, and eglot fails the whole registration past `eglot-max-file-watches`, after
which pyright exits. Until now `lisp/emacs-cpp-eglot-watch.el` patched around that on
the Mac only, keeping partial watches (D-121). D-127 replaces this on both machines
with one patched fswatch (D-109) per registration, watching the project root
recursively whatever its size; spike S18 measured the shape (`dedup` mode) on both
machines. This entry builds it, written fresh in `lisp/`, removes the old module and
its tests, and makes the patched fswatch a startup requirement.

## Concepts (Emacs Lisp) explained
- **`cl-defmethod ... :around` on an `(eql ...)` specializer.** eglot answers a
  server's registration through the generic function `eglot-register-capability`,
  dispatched on the method name. An `:around` method for exactly
  `workspace/didChangeWatchedFiles` runs instead of eglot's own, and since it never
  calls `cl-call-next-method`, eglot's file-notify code never runs for watches. Other
  capabilities are untouched.
- **A process filter.** `make-process :filter` hands Emacs each chunk fswatch writes.
  A chunk can end mid-record, so the filter keeps the unfinished tail (`pending`) for
  the next call. The filter is a closure: each process carries its own root, globs
  and overflow timer.
- **Globs to regexps.** LSP globs (`**/*.py`, `{c,h}`) become one anchored regexp
  each, matched against the path relative to the root; `string-match-p` with
  `case-fold-search` nil.

## Key files walked
- `lisp/emacs-cpp-eglot-fswatch.el` (NEW) - `emacs-cpp-eglot-fswatch--filter`: split
  NUL-separated records, warn once a minute on `Overflow`, merge records per path
  (`emacs-cpp-eglot-fswatch-merge`), turn them into changes
  (`emacs-cpp-eglot-fswatch-changes`) and send one notification per filter call.
- `lisp/init-lsp.el` - `emacs-cpp-fswatch-program-check` at eglot's `:init`, so a
  missing or stock fswatch stops startup with the build command; the backend is
  required in eglot's `:config`.
- `lisp/defaults-gnu-linux.el`, `lisp/defaults-darwin.el` -
  `emacs-cpp-default-fswatch-program` (`/opt/...` on Arch, `~/opt/...` on the Mac,
  the home taken from the user database so tests in a temporary HOME find it).
- `lisp/emacs-cpp-eglot-watch.el` - removed with its three tests; its duties (partial
  watches at the cap, shared directory watches, a stopped watch replaced) all
  belonged to the `file-notify` path, which no longer carries eglot's watches.
- `test/emacs-cpp-eglot-fswatch-test.el` (NEW) - globs, merging, the refusal, and the
  real fswatch on a temporary tree; `test/init-lsp-test.el` - pyright with 400
  directories over the backend.
- `spikes/s18-fswatch-backend/s18-run.el` - mode `shipped`, loading the config's file
  and counting by advice (spike code, as before).

## Deviations from the agreed done when
- Item 2 named `eglot--watch-globs` as the override point. The backend takes over the
  registration one level up (the `:around` methods), as DESIGN 7.1 "as built"
  records: one fswatch per registration needs the whole watcher list at once, which
  `eglot--watch-globs` sees only per base directory.
- `eglot-watch-files-outside-project-root` is no longer set: eglot's method that read
  it does not run; the backend skips watchers based outside the root itself (D-121).
- The old module refused any eglot but 1.24.31. The new one depends on fewer
  internals and checks, when it loads, that the three it uses exist.

## Results
- `make test`: 144 of 144 on Arch.
- Startup, 10 runs each, interleaved against the previous commit in a worktree:
  0.183 / 0.182 s there, 0.182 / 0.184 s here (item 6: within 10 ms).
- S18 run 5 on Arch, mode `shipped` (spikes/s18-fswatch-backend/RESULTS.md): the five
  criteria hold in three runs, 48 - 49 ms of Emacs's CPU per 1000 records against a
  limit of 50. The spike's `dedup` mode, rerun beside it, cost 50 - 52 ms where run 2
  measured 37 - 39 ms: today's machine is slower, cause UNVERIFIED, and the margin is
  thin. The Mac run is H-15.
- While testing: Emacs's lock file `.#m.py`, written beside a file being saved,
  matched `**/*.py` and was reported (eglot's own watches do the same); the test
  turns lock files off.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** a server registers watchers relative to its project root, or based
  inside it. **Would break if:** a server needs changes outside the root (pyright's
  site-packages): they are skipped, as under D-121. **DESIGN bet:** D-121, D-127.
- **Assumed:** a path's records arrive in one filter call often enough that merging
  per call gives the right type. **Would break if:** inotify's records for one write
  straddle two calls: then a created file may be reported as 1 and again as 2, which
  servers accept. **DESIGN bet:** D-127 (S18 `dedup`).
- **Assumed:** the string `queue-limit` in the binary marks the patched build.
  **Would break if:** upstream fswatch adds such an option; then the check passes a
  stock build that drops records under load. **DESIGN bet:** D-109.
- **Assumed:** Emacs's lock files (`.#name`) matching a server's glob are harmless,
  as with eglot's own watches. **Would break if:** a server reacts badly to them.
- **Assumed:** build directories inside the root cost the filter little.
  **Would break if:** a large build writes many files at once; S18 measured created
  files only.

## How to verify
- `make test </dev/null` - 144 tests pass on Arch.
- `sh scripts/measure-startup.sh 10` - median within 10 ms of the previous commit.
- `S18_RUNS=shipped:fake,shipped:pyright sh spikes/s18-fswatch-backend/run.sh 20000
  </dev/null` - the five criteria of S18's RUN.md. The Mac run is H-15.
