# S23 - index freshness: cost of a staleness check per navigation request

Verdict: FAIL against D-026's premise that an index answer equals the AST's: cases 1a
(header changed on disk) and 3 (header after a `-D` change) answer stale where stock
clangd answers right (`reproduce/RESULTS.md`). The cost of a check is recorded, not
judged (no budget was set before the runs; RUN.md). Fix 1 cannot be built the way it
was proposed (finding 1), and reading the closure per request costs seconds here.

## Question
The patched clangd answers `M-.` / `M-?` from the open file's background-index shard
when the open file's digest equals the shard's (patch 0001,
`clang-tools-extra/clangd/XRefs.cpp:2600` in the patched source tree:
`Node->getValue().Digest != digest(Content)`). Proposed fix 1: also require every file
in the open file's include closure to match its recorded digest. Proposed fix 2: check
the digest of the file the answer points into. What does each cost per request?

## Source facts (clangd 23.1.1 tree in `packaging/clangd-index-nav/src/llvm-project-23.1.1.src/clang-tools-extra/clangd`)
1. Hash: `digest()` is `llvm::xxh3_64bits` over the whole content, stored as 8 bytes
   (`SourceCode.cpp:565-573`). `digestFile` hashes the SourceManager buffer
   (`SourceCode.cpp:575-581`).
2. A TU's in-memory include graph holds the full transitive closure: the collector adds
   a node with a digest for every file entered (`index/IndexAction.cpp:56-84`,
   `FileChanged` on `EnterFile`) and an edge per `#include` (`index/IndexAction.cpp:
   88-107`). `IncludeGraphNode` = flags, URI, digest, `DirectIncludes`
   (`Headers.h:85-98`).
3. A stored shard does NOT hold the closure. When the TU's index is split into
   per-file shards, each shard keeps only its own node plus empty nodes for its direct
   includes: "Store only the direct includes of a file in a shard"
   (`index/FileIndex.cpp:173-179`), `getSubGraph` copies the file's node and
   `try_emplace`s each direct include with a default node, so their `Digest` stays
   `{0}` (`index/FileIndex.cpp:109-124`; default `Digest{{0}}` at `Headers.h:96`).
   The loader confirms: "A shard contains only edges for non main-file sources"
   (`index/BackgroundIndexLoader.cpp:75-78`), and walks the closure breadth-first by
   loading one shard per file (`index/BackgroundIndexLoader.cpp:90-107`).
4. The recorded digest of every indexed file is kept in memory, one per absolute path:
   `BackgroundIndex::ShardVersions` (`index/Background.h:206-209, 228`), filled when
   shards are loaded at startup (`index/Background.cpp:454-456`) and when a TU is
   indexed (`index/Background.cpp:274-282`). It is one digest per header, from the last
   TU that indexed it, not per TU.
5. No in-memory structure maps a TU to its closure: the loader's edges are discarded
   after loading; `Includers` maps header -> one TU (the reverse direction,
   `index/Background.h:230-231`).

## Method
Include closure per TU from the preprocessor (`-M`, system headers included),
deduplicated by real path, main file included: `measure-cost/closure.sh`. Flags: the
compile command of `~/source/repos/dealii/examples/step-1/compile_commands.json` (no
other example in that clone has a build directory), with two corrections: `-isysroot`
set to the SDK `xcrun --show-sdk-path` names (the recorded `MacOSX26.0.sdk` no longer
exists), and the magic_enum include directory added (step-1's command predates it;
`deal.II/base/patterns.h` needs it from step-6 on). The other examples use step-1's
command, which is what clangd would infer for them too (UNVERIFIED for the inference
rule; the examples share deal.II's CMake flags).

Cost per closure: `measure-cost/closurecost.c`, compiled `clang -O2` against
MacPorts' `/opt/local/include/xxhash.h` (`XXH_INLINE_ALL`, `XXH3_64bits`, the same
algorithm as `llvm::xxh3_64bits`; byte-identical output not checked, UNVERIFIED and
irrelevant for cost). One untimed warm-up pass, then N timed passes; median reported.
Modes:
- `hash`: open + fstat + read + XXH3 + close per file (fix 1 done naively).
- `open`: open + close only, no read (isolates the per-open cost).
- `stat`: `stat()` per file (mtime + size as the staleness proxy).
- `mem`: XXH3 over contents preloaded into memory (pure hashing cost).

Warm page cache only: every pass after the warm-up reads cached pages. A cold cache
needs `sudo purge`; not measured.

Environment: MacBook Pro, Apple M3 Pro, 18 GB, macOS (Darwin 27.2.0), 2026-11-22.
G DATA Antivirus's on-access scanner was running (`gdavserver` at 120 - 160 % CPU
during the runs). Another clangd (`--background-index`, not started by this spike)
indexed in parallel; load average 12 - 18 during run 2 (`measure-cost/load.log`).

## Measurements (run 2, `measure-cost/results.log`)
| TU | closure files | MB | hash median ms | open median ms | stat median ms | mem median ms |
|---|---|---|---|---|---|---|
| synthetic | 2670 | 25.4 | 3426 | 3584 | 3.0 | 0.7 |
| step-1 | 2629 | 25.2 | 6448 | 18628 | 15.4 | 4.4 |
| step-6 | 2896 | 29.9 | 15103 | 11239 | 9.0 | 2.7 |
| step-22 | 3902 | 40.6 | 12401 | 12458 | 3.5 | 1.3 |
| step-40 | 3047 | 33.4 | 9629 | 10338 | 2.6 | 1.2 |
| step-69 | 3182 | 33.6 | 9497 | 8302 | 2.7 | 1.1 |

hyperfine, step-40, one pass per process: hash 14.3 s +- 2.1 s, stat 0.012 s.

Run 3 (`measure-cost/results-run3-split.log`, session, load average 3 - 3.5, the other
clangd idle, `gdavserver` at 81 % CPU): step-40 open 9098 ms / hash 8699 ms; its deal.II
part (2089 files, `/Applications/deal.II.app`) open 5051 ms, its SDK part (957 files,
`/Library/Developer/CommandLineTools`) open 2493 ms. About 2.4 - 3 ms per open in both
trees at low load: the load of run 2 is not the cause; the on-access scanner is the
likely one (UNVERIFIED until a run with the scan off, which only the owner can do).

Run 1 (`measure-cost/results-run1.log`, 31 hash / 201 stat passes, lower load before
the other clangd started): synthetic hash 4757 ms, stat 2.4 ms; step-1 hash 3759 ms,
stat 3.6 ms. step-6 failed there on the missing magic_enum directory.

## Findings
1. Fix 1 as proposed does not exist in the data: the open file's shard records no
   digest for its includes and lists only direct includes (source fact 3). The recorded
   digests are available in memory (`ShardVersions`, fact 4), but the closure itself is
   not; it has to be rebuilt per request by walking DirectIncludes through one shard
   load per header (2600 - 3900 loads for these TUs; shard load cost not measured,
   UNVERIFIED), or recorded once when shards are loaded / a TU is indexed (a new
   in-memory TU -> closure map; memory not measured).
2. Hashing is not the cost. XXH3 over 25 - 41 MB takes 0.7 - 4.4 ms. The cost is the
   file system: open() alone takes 3.6 - 18.6 s per closure here, about 1.3 - 7 ms
   per open, the same as open + read + hash. With G DATA's on-access scanner every
   open is scanned; whether the scanner or the load dominates is UNVERIFIED (the
   scanner cannot be turned off without the owner). Either way fix 1 done by re-reading
   the closure costs seconds per request, against an index path of 2 - 606 ms (journal
   0014, synthetic project) and 1358 ms (S8 run 2, RMO), and an AST path of 6.6 s
   (synthetic, S8 dry run) / 9.3 s (RMO, S8 run 2). It would make the index path
   slower than the AST path it replaces.
3. stat() of the whole closure costs 2.6 - 15.4 ms (no open, so the scanner is not
   involved). A stat-based check needs a recorded mtime + size per file; clangd records
   only digests (`IncludeGraphNode`, `Headers.h:85-98`), so the shard format or an
   in-memory table would have to carry them (new state; UNVERIFIED that mtime is
   reliable across checkouts that restore identical content, which would cause false
   "stale" answers, never false "fresh" ones unless mtime and size are both restored).
4. Fix 2 (one file, the answer's target): one open + read + hash, about 1.3 - 7 ms
   here, or one stat (microseconds). It is cheap, but it only notices a change to the
   target file, not to a header that shifts the open file's meaning (a macro, an
   overload added elsewhere).
5. Closures are large: 2629 files (step-1, 25 MB) to 3902 (step-22, 41 MB). The
   synthetic S8 / S10-style TU (2670 files) is representative of deal.II examples.

## Commands
```
cd spikes/s23-index-freshness/measure-cost
sh run.sh > results.log 2>&1 </dev/null      # run 2
sh loadlog.sh </dev/null                     # in parallel: load averages
```
`run.sh` compiles `closurecost`, writes `lists/<tu>.txt` with `closure.sh`, then per TU:
`./closurecost hash lists/<tu>.txt 11`, `open ... 11`, `stat ... 201`, `mem ... 51`,
and a `hyperfine --warmup 1 --runs 5 -N` cross-check on step-40.
