# S23 reproduce - stale answers from navigation from the index

Mac (arm64, macOS, 11 cores), 2026-11-22. Three servers:
- `nav`: `~/opt/clangd-index-nav/bin/clangd --navigation-from-index` (23.1.5, patches
  0001 - 0019),
- `noflag`: the same binary without the flag,
- `upstream`: `/opt/local/bin/clangd-mp-23` (MacPorts 23.1.5, no patches).

All with `--background-index --log=verbose --enable-config=false`.

## How
`freshness.py` (python3 -I) writes a hand-made project with a `compile_commands.json`
under `work/CASE-LABEL/` and drives clangd over stdin/stdout (`lsp.py`):
- s1 builds the index from scratch, waits for `backgroundIndexProgress` to end,
  then stops;
- the change is applied;
- s2 (stored shards) opens the files and sends the queries right away (the first
  answers race the AST), then repeats them every 0.3 s for 20 s;
- s3 restarts once more and asks once: did the stored index get fixed?

Path attribution: the log lines between `<-- textDocument/X(id)` and the next request
(`answered from the index shard`, or `needs the AST: <reason>`); an answer with neither
line is the AST's. Ground truth: positions looked up in the changed files. The first
answers raced main.cpp's preamble (1.5 - 2 s, 19 standard headers in `heavy.h`).
`run.sh` runs every case with every server; `rerun.sh` repeats s3; `raw_replies.py`
prints raw replies. Summaries: `summary-batch1.txt` and `summary-batch2.txt`. Logs and
per-run JSON: `logs/`.

LSP positions are 0-based (`line 1` = the second line of the file).

Caveat: another agent's job ran on the machine during batch 2, so its preamble times
(6 - 16 s) are slower than batch 1's (about 1.7 s). The verdicts do not depend on timing,
but the window lengths do.

## Case 1 - an included header changed, main file unchanged

Project: `main.cpp` includes `over.h` (`f(int)`, `f(double)`), `types.h` (`A::run`,
`B::run`, `using Widget = A`), `macros.h` (`#define HANDLER handle_a`). Change:
`f(int)` removed (so `f(1)` calls `f(double)`), `using Widget = B`, the macro moved two
lines down and now names `handle_b`. Queries in main.cpp: definition at `f(1)`,
`w.run()` and `HANDLER()`, references at `f(1)`.

### 1a header changed on disk, then restart (`header_disk`)
- Reproduced: yes.
- Wrong answers (nav, s2, path: index, `Definitions in main.cpp answered from the index
  shard`):
  - `f(1)` at 0.228 s:
    `[{"range":{"start":{"line":1,"character":11},"end":{"line":1,"character":12}},"uri":".../over.h"}]`
    (the removed `f(int)`'s old line; truth: line 3, character 11, `f(double)`).
  - `w.run()` at 0.283 s: `types.h` line 1, character 15 (`A::run`; truth: line 2,
    character 15, `B::run`).
- s3, after main.cpp was reindexed in s2 (`Indexed main.cpp` at 2.918 s): `w.run()` is
  answered stale from the index again at 1.771 s:
  `[{"range":{"start":{"line":1,"character":15},"end":{"line":1,"character":18}},"uri":".../types.h"}]`.
  `f(1)` is no longer stale there: the index refuses (`the index does not locate every
  symbol there`) because `f(int)` is gone from over.h's rewritten shard, and the AST
  answers.
- Why it stays: reindexing a TU rewrites only the shards whose digest changed
  (`BackgroundIndex::update`, `FilesToUpdate`, `index/Background.cpp` 283 - 330). main.cpp's
  digest did not change, so its shard keeps the old references (`main.cpp.*.idx` mtime
  15:28:08 from s1, the headers' 15:28:13). Navigation from the index takes the
  symbol at the cursor from that shard, and its digest check passes.
- Stale window: from the first request until the AST wins the race (s2: about 1.75 s,
  the preamble); in every later session the index answers `A::run` again whenever it
  wins the race. No bound: until main.cpp's own content changes. For a symbol that was
  removed (`f(int)`), the window ends when the header's shard is rewritten (reindex,
  2.9 s after the restart here).
- `HANDLER`: never stale from the index (`does not locate every symbol`, AST answers).
- Stock: `noflag` and `upstream` answer every definition correctly (AST). Regression.
- Inherited part: references at `f(1)` from the AST in all three servers list
  `over.h` line 2 (the old position of `f(double)`, from the index) until the reindex
  (about 2.9 s).

### 1a' asked from the headers, main.cpp never opened (`header_disk_from_header`)
References of `f(double)` (over.h) and of `B::run` (types.h), main.cpp not open: all
three servers, s2 and s3, return only the header's own location
(`over.h` 3:11, `types.h` 2:15) and miss main.cpp's call (`main.cpp` 7:9 / 7:20). The
same unrewritten main.cpp shard. Inherited (upstream bug), not a regression; nav's
index path did not answer here (`the file changed since it was indexed` in s2; AST in s3).

### 1b unsaved header edits, disk unchanged (`header_unsaved`)
Headers opened with the changed text (didOpen), then main.cpp. All three servers answer
stale in s2 (20 s) and s3: `f(1)` -> `over.h` 1:11, `w.run()` -> `types.h` 1:15,
`HANDLER` -> `macros.h` 3:8. Path in nav: AST (the index path refused `f(1)` and
`HANDLER`: `does not locate every symbol`). clangd builds main.cpp from the files on
disk, not from other open buffers. Reproduced: yes, inherited, not a regression. Stale
window: until the headers are saved (not measured).

### 1c headers saved during a session, no restart (`header_live`)
main.cpp opened and parsed; at 6.0 s (nav) the headers are written, opened (didOpen) and
saved (didSave).
- nav: `f(1)` stale from the index at 6.021 s; `w.run()` stale from the index at 6.125 s
  and again at 19.333 s, after main.cpp's preamble was rebuilt (19.111 s) and the AST
  would have answered correctly:
  `{"id":107,...,"result":[{"range":{"start":{"line":1,"character":15},...},"uri":".../types.h"}]}`.
  From 19.279 s on the AST won every race and answered correctly.
- All three servers answer stale from the AST until main.cpp's preamble is rebuilt
  (nav 6.0 -> 19.1 s, noflag 6.5 -> 16.9 s, upstream 14.3 -> 27.6 s; slow because of
  the machine's load). Inherited.
- The background index does not reindex on save (`ClangdServer::onFileEvent` is a
  no-op; didSave only reparses open files): main.cpp's shard stays stale for the whole
  session. s3 (restart): nav answers `f(1)` and `w.run()` stale from the index at
  1.745 s / 1.825 s; reindex of main.cpp started 13.5 s, ended 25.3 s.
- Regression: the index path answers stale after the AST is current, whenever it wins
  the race (seen once here, 19.333 s), with no bound within the session.

## Case 2 - definition moved in another .cpp (`target_moved`, `target_moved_slow`)

main.cpp calls `g()` (declared in g.h, defined in g.cpp); other.cpp calls it once.
Change on disk: five comment lines above `g`'s definition; two more calls in other.cpp.
Queries in main.cpp: definition and references at `g()`.

### Light TUs (`target_moved`)
- Reproduced: yes. nav, path index: definition `g.cpp` 1:4
  (`{"start":{"line":1,"character":4}...}`, truth 6:4) and references missing other.cpp's
  new calls (2:22, 2:28), 0.315 - 1.149 s; correct from the index at 1.565 s, after g.cpp
  and other.cpp were reindexed (1.427 s).
- Stale window: 1.4 s (until the reindex of g.cpp; the queue order is shuffled, so on a
  large project this can be minutes - UNVERIFIED on a large project).
- Stock: `noflag` / `upstream` correct, because their AST answered (1.7 - 1.9 s) after
  the reindex.

### Heavy TUs (`target_moved_slow`, g.cpp and other.cpp include heavy.h)
- nav, s2: index answers stale from 0.715 to 11.586 s (definition `g.cpp` 2:4, truth
  7:4; references without other.cpp 3:22, 3:28); then the AST answers, also stale, until
  the reindex ends (16.8 s); references correct after that.
- noflag / upstream, s2: AST answers stale too until the reindex (noflag 7.9 - 14.6 s,
  upstream 7.6 - 12.6 s): the AST takes `g`'s definition from the index. Inherited.
- s3 (after the reindex): nav's definition stays stale from the index, 5 of 5 sessions
  (`{"start":{"line":2,"character":4}...,"uri":".../g.cpp"}`); references correct.
  upstream on its own work directory: correct, 5 of 5. But upstream on nav's work
  directory (`rerun.sh` with the directory argument): stale too, 2 of 2, from the AST;
  nav on upstream's directory: correct (AST answered). So the persistent stale definition
  is a property of the stored index, not of the patch. Likely cause (UNVERIFIED in code):
  g.h's shard, not rewritten because g.h's digest did not change, still carries `g`'s
  old definition location, and which shard's definition wins the merge depends on the
  files' paths.
- Verdict: reproduced; inherited (upstream also stale, both during the reindex and
  persistently with this index). nav makes the window start earlier (0.7 s instead of
  the AST's 7.6 s) but does not lengthen it.

## Case 3 - header opened directly, `-D` changed (`header_first_define`)

over3.h: `#ifdef USE_A inline int f(int) ... #endif inline int f(double) ...
inline int user() { return f(1); }`. The database's only entry, main.cpp, had `-DUSE_A`;
the change removes it. over3.h opened first; definition and references at `f(1)` in
`user()`; control: definition at `f(1)` in main.cpp.
- Reproduced: yes. nav, path index (`Definitions in over3.h answered from the index
  shard`), s2 at 0.224 s and s3 at 0.396 s:
  `[{"range":{"start":{"line":3,"character":11},"end":{"line":3,"character":12}},"uri":".../over3.h"}]`
  (inside the now inactive `#ifdef USE_A`; truth: line 5, character 11, `f(double)`).
  References from the index: `over3.h` 3:11 instead of 5:11.
- Control: main.cpp refused by 0017 (`the shard was indexed with another compile
  command`), AST correct. Headers have no stored command (`shardCommandMatches` returns
  true when `Shard.Cmd` is empty), so the header case passes the check.
- Stale window: unbounded. No reindex happens at restart (the staleness check compares
  digests only, `shardIsStale`, Background.cpp 80; s2 and s3 logs show no `Indexing`).
  It ends only when some file of main.cpp's include graph changes, or the database
  changes while clangd runs (UNVERIFIED: `CDB.watch` -> `enqueue` was not exercised).
- Stock: `noflag` and `upstream` answer correctly (AST) in s2 and s3. Regression.

## Summary

| case | reproduced | nav path | stale window | stock |
|---|---|---|---|---|
| 1a header on disk, restart | yes | index | first: until the AST wins (1.75 s); typedef: unbounded (main shard never rewritten) | correct: regression |
| 1a' refs asked from the header | yes | AST | unbounded | same: inherited |
| 1b unsaved header | yes | AST | until saved | same: inherited |
| 1c header saved, no restart | yes | index and AST | AST: until preamble rebuild (10 - 13 s); index: whole session when it wins | AST part inherited, index part regression |
| 2 target moved, light | yes | index | 1.4 s (until reindex) | correct (later AST): regression in timing only |
| 2 target moved, heavy | yes | index then AST | 0.7 s - reindex (16.8 s); definition persistently stale with this index | also stale: inherited |
| 3 header first, -D changed | yes | index | unbounded (no reindex) | correct: regression |

Not observed / not tested: macros answered stale from the index (never; the index path
refused `HANDLER` every time); a changed `-D` while clangd runs (UNVERIFIED); window on a
large project (UNVERIFIED).
