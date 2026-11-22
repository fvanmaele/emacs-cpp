# Research: retrying sources whose index shard has errors (O-93)

Findings only; verdicts go to DESIGN (O-93). 2026-11-22, the session with six study
agents in two rounds (use-case simulations, then a review of the gated design), each
reading the patched clangd 23.1.5 tree; claims marked UNVERIFIED were not checked in
code or by experiment. Paths below are under `clang-tools-extra/clangd` unless named.

## 1. The problem
Patch 0009 (D-060) reindexes at every startup each source whose stored shard has
`HadErrors`, because a header that did not exist at indexing time is not in the include
graph: creating it makes nothing stale. A retry that still errors on unchanged content
is neither written nor merged (`index/Background.cpp` 304 - 307). For sources that never
compile (GCC-only flags, work in progress) every startup pays a full parse each: about
10 s of CPU per deal.II file (estimate from journal 0042's first `M-.` of 7.4 - 12.6 s
and O-8's 10.5 s); 150 such files about 1500 CPU-s, about 2 min on 11 cores, in the
window where O-79's editor stalls happened.

## 2. Verified facts
- `IndexFile` is already the lowest queue priority and index threads already run at low
  thread priority (`index/Background.h` 271 - 275, 143): a "lower priority" retry needs a
  new level and only reorders work (SCHED_IDLE on Linux, UTILITY on macOS).
- Background indexing runs only when the compile database announces files;
  `ClangdServer::onFileEvent` does nothing (`ClangdServer.cpp` 1126 - 1129); each queue
  key runs once per process (`index/BackgroundQueue.cpp` 83, `SeenKeys`).
- A flagged header is retried only through its `DependentTU`, the first source that
  reached it when loading (`index/BackgroundIndexLoader.cpp` 50 - 59); if that source
  never compiles the header stays flagged though clean includers exist.
- Upstream bug (same in the 23.1.5 tarball, `index/Background.cpp` 341): the condition
  skips exactly the clean-after-errors case its comment means to update; the clean shard
  reaches the disk, the in-memory index keeps the errored symbols until restart.
- Stock clangd ignores an unknown RIFF chunk: `readRIFF` maps chunks by name and looks up
  only `meta`, `stri`, `srcs`, `symb`, `refs`, `rela`, `cmdl` (`index/Serialization.cpp`
  469 - 471); no patch touches the file. Stock clangd drops the chunk when it rewrites.
- A fatal "file not found" does not stop include lookups: no `hasFatalErrorOccurred` in
  `clang/lib/Lex`; `InclusionDirective` with no file and `FileNotFound` are reached for
  every include (`clang/lib/Lex/PPDirectives.cpp` 2272, 2628); clang 23 `-H` shows a later
  existing include entered after the fatal error. Hidden until a missing header exists:
  only its own includes and `#ifdef` branches on its macros.
- Non-existent `-I` directories are dropped from HeaderSearch
  (`clang/lib/Lex/InitHeaderSearch.cpp` 147 - 168, `ignoring nonexistent directory`):
  candidates must come from `HeaderSearchOptions`, not the surviving list.
- `__has_include` of a missing header records nothing through `InclusionDirective`; it
  has its own callback (`PPCallbacks::HasInclude`).
- `-include` / `-imacros` resolve from the command's directory, not the main file's.
- An unreadable header is "not found" though it exists; `#include_next` searches only the
  directories after the current one: a recorded candidate may already exist.
- The stored `Cmd` is the mangled command; comparing it at load time needs the source's
  own context (`ContextProvider(TU)`), or `.clangd` edits make every command differ.
- clang's `MissingFileCollector` (`clang/lib/Frontend/PrecompiledPreamble.cpp` 86 - 135)
  already records candidate paths of not-found includes for preambles.
- MockFS rebuilds its file system at each `view()`, so a header appearing between two
  index sessions is testable as in `ReindexesShardsIndexedWithErrors`.

## 3. Policies studied
| Policy | Ends right after a generated header | CPU per restart, 150 never-compiling | Notes |
|---|---|---|---|
| P0 stock (no startup retry) | no, until the source is edited | 0 | the bug D-060 fixed |
| P1 0009 today | after 1 restart | about 1500 CPU-s | shared-header trap |
| P2 keep result, lowest priority, write if bytes differ | after 1 restart | same, later | a worse errored result can replace a better one |
| P3 directory mtimes | partly: a header in an existing subdirectory is missed | about 0 | copies reset mtimes; `stat` of 2000 - 5000 directories 3 - 10 ms warm (measured 1.3 - 2.2 us per `stat`) |
| P4 count or backoff | if within the cap | bounded | a cap can be spent before the build |
| P5 on demand (open, events) | on use | 0 | needs `onFileEvent`, `SeenKeys` bypass |
| Gated (command + missing headers) | after 1 restart | 0 for never-compiling | design in section 4 |

Other IDEs: Qt Creator with clangd behaves as P0; CLion's parsers keep a file's symbols
whatever its errors and document no retry (UNVERIFIED). No clangd issue asks for this;
closest: clangd/clangd#97, #1711; a maintainer floated a rebuild trigger in
llvm/llvm-project#140651 (draft).

## 4. The gated design and the review's amendments
Design: record, when indexing, every candidate path of each include not found; store it
in a new `miss` chunk of the source's main shard; at startup retry a flagged source only
if its command changed, a recorded candidate now exists, or it has no `miss` chunk
(once); retry a flagged header through an includer with a clean shard; fix line 341.

Amendments found by the review (all three agents unless named):
1. A retry that still errors must rewrite the main shard (fresh `Cmd`, fresh `miss`, the
   chunk written even when empty), or each gate fires at every startup forever; rewrite
   every flagged file this way, so new include edges reach the loader. This replaces the
   byte comparison, which the storage API cannot do (it returns parsed shards only).
2. Candidates from `HeaderSearchOptions` entries made absolute against the command's
   directory; drop candidates that exist at record time; at startup count only regular
   readable files; add `HasInclude`; the predefines buffer resolves from the command's
   directory; frameworks expanded (`Foo.framework/Headers`), header maps unresolvable.
3. Gate (a) under `ContextProvider(TU)`.
4. Extra gates proposed: a changed clangd version (stored in the chunk), and a changed
   digest of any file in the source's include graph (UNVERIFIED that `srcs` covers every
   node).
5. Line 341: move the version check before `storeShard` too (a broken run finishing
   after a clean one leaves disk and memory disagreeing; harmless, one extra retry).
6. Routing only to includers still in the compile database; with no clean includer the
   header follows its sources' gates. The reverse walk needs the loaded shards' own
   nodes only (each has its full `DirectIncludes`).
7. Tell the user: one `log()` line per load ("N flagged: R retried (reasons), S kept")
   and an Emacs message, per "fail loudly"; an `M-x` command through
   `workspace/executeCommand` to force a retry (P5-like, cheap).
8. Measure the startup `stat` cost with thousands of flagged sources (about 100k - 300k
   `stat` calls, UNVERIFIED) before shipping.
Size estimate: about 160 lines of code and 200 of tests without amendments 4, 7.

A cheaper alternative from the review: 0009 with a backoff counter (restarts 1, 2, 4, 8)
plus the manual command, about a tenth of the code; against: a generated header may wait
several restarts.
