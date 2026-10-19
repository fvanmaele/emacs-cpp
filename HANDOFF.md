# HANDOFF - emacs-cpp for code and design review

Written 2026-10-20 for reviewers (people or other models) who have not followed the
sessions. It summarises; the sources of truth are `DESIGN.md` (decisions `D-nnn`, open
questions `O-nn`), `TASKS.md`, `JOURNAL.md` with `docs/journal/`, `POSTMORTEM.md`, the
`RESEARCH_*.md` files and `spikes/*/RESULTS.md`. Cite ids, not this file.

## 1. What the project is
An Emacs 31 configuration that gives one owner a CLion-like C++ loop (navigate, refactor,
diagnostics, CMake presets, debugger, git, "go to anything") on an Arch Linux
workstation and a MacPorts macOS machine (D-050, D-053). The reference project is RMO
(`RMO-gross-pitaevskii`): C++20, CMake presets, every translation unit pulls in deal.II
9.8 (with PETSc, Trilinos, Kokkos, Boost). Non-goals: an Emacs distribution, Windows, a
CLion keymap (DESIGN 2). Python, R and LaTeX ride along and never drive design (D-045,
D-072, D-090).

The scale problem shaped almost everything: a deal.II translation unit takes 13.3 s
and 780 MB for clangd's first parse (S1 run 2), and a header 6.6 - 8.0 s. Most of the
divergence from upstream below exists to keep the editor interactive in front of that.

## 2. How the repository works (read before judging the code)
- Process (CLAUDE.md, `standard.mk`): tier 1 trivial, tier 2 feature with an agreed
  "done when", tier 3 risky with a PASS spike first. Every decision is a `D-nnn` row;
  every tier 2/3 change has a journal entry with an assumptions + risks ledger.
  `make check` checks the docs; `make test` runs ERT in a temporary HOME (D-104).
- Spikes (`spikes/`) are throwaway code that turns one risk into a measured verdict;
  spike code is never promoted, the shipped code is written fresh (S8 -> patches
  0001 - 0004, S15 -> patch 0013).
- Code was written largely by an LLM (Claude) in sessions with the owner, who rules on
  every decision and runs anything that touches real projects or the live
  `~/.emacs.d`. Commit messages carry `Reasoning:` (what was wrong, evidence, ruled
  out) and the tier. Treat the evidence lines as claims to check.
- Packages are git submodules pinned in `lib/` (D-006); nothing is downloaded at Emacs
  startup (D-014). `make packages` byte-compiles `lib/`; own Lisp in `lisp/` is loaded
  from source (not byte-compiled), which matters for hot loops (section 6).

## 3. Architecture (Emacs side)
- `early-init.el`, `init.el`, then `lisp/init-*.el` in a fixed order; each module
  loads alone (test `init-modules-load-alone`, D-098). One `use-package` form per
  package (DESIGN 4).
- Language server: eglot (vendored, D-108) with clangd; pyright, texlab for the riders.
  clangd is started only for a project with `CMakePresets.json`, pointed at the active
  preset's `binaryDir` with `--compile-commands-dir` (D-005, D-016). eglot is refused
  loudly on any preset or database error (D-018; a source missing from the database
  only warns, D-068).
- Completion: vertico, orderless, marginalia, consult, embark, corfu, cape (DESIGN 12).
  `M-o` (`lisp/init-go-to-anything.el`) is one consult prompt over buffers, recent
  files, bookmarks, project files, server symbols (per server, D-106), commands and
  projects (D-074 .. D-099).
- Build and debug: projectile with CMake presets; dape over DAP with `gdb -i dap` or
  `lldb-dap` (D-002, D-051); debug targets from CMake's file API (D-056).
- Platform defaults files `lisp/defaults-*.el` (D-055); a missing tool stops with the
  fix, never a silent fallback (principle 1).

## 4. Key design choices and why
- eglot, not lsp-mode: built in, small; xref / flymake / project integration. Considered:
  lsp-mode (bigger, more UI).
- clangd, patched, not ccls: clangd is maintained; patching it cost less than ccls's bugs
  (POSTMORTEM ccls). Considered: ccls hybrid D-023/D-024, superseded by D-026.
- CMake presets as the only build profile: the owner's projects use them; one source for
  build dir and database (D-005). Considered: `.clangd`, a root symlink (S1).
- Fail loudly: a half-loaded config looks fine until needed (principle 1, D-018).
  Considered: warnings, fallbacks.
- Patches as files on pinned submodules: reviewable, reproducible on a fresh clone (D-069,
  D-116). Considered: forks, Lisp workarounds.
- One match rule in every prompt: LSP 3.18's "letters in order, case ignored", ranked in
  tiers (D-120). Considered: three matchers (before 2026-10-20).
- RET and TAB indent by Emacs rules: clangd's on-type formatting rewrites whole statements
  (D-061 -> D-065). Considered: server-side indentation.
- No module switches: one config, both machines (D-098). Considered: Doom-style layers.

## 5. Divergence from upstream: clangd
The patched clangd lives in `packaging/clangd-index-nav/`: `PKGBUILD` (Arch, LLVM 23.1.1
tarball + patches, built against pacman's LLVM, installed to `/opt/clangd-index-nav`,
`llvm-libs` and `clang` pinned to the exact version, D-027) and `build-macos.sh` (macOS,
LLVM 23.1.3 self-contained, `~/opt/clangd-index-nav`, D-052, D-100). The config uses it
only when `emacs-cpp-clangd-program` names it, and refuses a binary that lacks the
patched flags (D-026). Every behaviour change is behind a hidden flag or a request
field, so the patched binary behaves as upstream unless asked. None of these patches
has been proposed upstream yet; they are written as upstreamable commits
(`git format-patch`, unit tests in ClangdTests).

### 5.1 Navigation answered from the index (patches 0001 - 0004, D-025, D-026, S8)
- When: 2026-10-08, after S5 (warm-up) failed and the ccls hybrid aborted.
- Problem: `go to definition` and `find references` call `TUScheduler::runWithAST` and
  wait for the file's parse: 7 - 13 s on a deal.II source after opening or a restart,
  although the background index already stores, per file, every reference with its
  position, built from a full parse (`RESEARCH_clangd_index_navigation.md` 1, 2).
- Change: hidden flag `--navigation-from-index`. If the open file's content matches the
  shard's digest and the shard had no errors, the symbol under the cursor is found
  among the shard's references and the request is answered from the index (0001). The
  index answer races the AST path; whichever is first answers (0002: shards load
  asynchronously at startup, so a synchronous lookup found nothing and waited anyway).
  All symbols at one range (0003: `std::visit` referred to two declarations, one lost
  references), `#include` lines (0004). Edited files, keywords, locals and macros keep
  the AST path.
- Effect: first `M-.` after a restart on RMO 9282 ms -> 1358 ms with the same target;
  `M-?` held every distinct location of the AST answer (S8 run 2). Below jsonrpc's 10 s
  request timeout, which the stock clangd could exceed.
- Similar elsewhere: ccls answers from its on-disk index (S6: `M-.` 1.2 s after start);
  CLion and Visual Studio's C++ tooling keep their own symbol databases that serve
  navigation before a full semantic parse; clangd itself already serves completion
  (`--completion-parse=auto`) and `workspace/symbol` without an AST. An offline index
  (`clangd-indexer`, LLVM PR 175209's sharded variant, spike S7) addresses index build
  time, not the per-file wait; S7 is prepared, not run.

### 5.2 Headers get an includer's flags (patches 0005 - 0008, S9)
Decisions D-028, D-046, D-047, D-059.
- Problem: a header has no compile command; clangd borrows one from an open includer
  once its preamble is built, else guesses from file names. With index navigation an
  `#include` jump opens the header before any includer is parsed, and a header opened
  first never has one: on RMO the guess came from vendored fmt's sources and showed
  "file not found" errors (O-5, O-21).
- Change: hidden flag `--header-flags-from-index`; `BackgroundIndex::includerOf`
  returns a translation unit that includes the header, from the stored include graph
  (0005), waiting up to 5 s while shards load. 0006 fixed a race (the wait counter rose
  only after the first lookup returned, so a header opened first did not wait: 10 of 10
  sessions guessed on RMO), 0007 ends the wait once includers are recorded (1.5 s ->
  0.9 s), 0008 answers a known includer at once.
- Effect: header opened first after a restart: 10 of 10 sessions correct on RMO,
  0.85 - 0.90 s to the decision (S9 run 4).
- Similar elsewhere: clangd's own `HeaderIncluderCache` (open includers only) and
  compile-database interpolation; CLion resolves header context from its project model.

### 5.3 Shards indexed with errors are re-indexed (patch 0009, D-060)
- Problem: a shard written while the code did not compile keeps `HadErrors` after the
  code is fixed if no file of its include graph changed; index navigation refuses such
  shards, so those files waited for the parse after every restart (7.4 - 12.6 s).
- Change: at startup flagged shards are re-indexed like stale ones. After one session,
  5 ms - 2.7 s.

### 5.4 Paths through symbolic links (patch 0010, D-114, S13)
- Problem: when the database spells a file through a symlink (on macOS every project
  under `/tmp`), the shard update dropped every symbol of the main file: 3 references
  instead of 201 (S13). Upstream issue clangd/clangd#503 (open since 2020) is related.
- Change: files a database change brings are named by their directory's real path.

### 5.5 CLion-style symbol matches (patches 0011 - 0013, D-113, D-119, S14, S15)
- 0011 `looseScope`: an abbreviated qualifier (`geom::vert` ->
  `GeometryInfo::vertices_per_cell`). 0012 `middleMatch`: names containing the query
  mid-word (`ector` -> `TangentVector`). Both are `workspace/symbol` request fields
  next to clangd's existing `limit`, announced as the capability
  `workspaceSymbolMatchesProvider`; a client that does not send them gets upstream
  behaviour, and code completion never sets them (D-113 chose request fields over
  startup flags so each prompt decides per request).
- 0013 (2026-10-19): with 0012 a fuzzy match scattered over word starts ranked before
  every mid-word match, so `ector` listed Kokkos's `EBOBaseImpl<T, true,
  CtorNotOnDevice>` constructor (E + Ctor; clangd names a partial specialization's
  constructor with its template arguments) before any `Vector`. 0013 ranks in two
  tiers: matches unbroken from a word start keep their order; scattered and mid-word
  matches follow by the share of the name they cover. It applies in Dex and MemIndex
  too, because the index cuts at the limit before `getWorkspaceSymbols` ranks. It also
  fixed two defects of 0012: Dex scored a mid-word match as -1 times quality (the
  better symbol ranked lower and a limit kept the worst), and `Score -= 1e6f` left
  float steps of 0.0625, so mid-word matches tied. S15 on RMO: 7 of 7 criteria, no
  first-tier match moved, same matches, replies as fast (4.7 / 7.7 ms medians).
- This departs from CLion, which lists mid-word matches last, on the owner's request.
- Not done (O-68, later stage): letters in order with a gap inside a word (`eto` ->
  `Vector`). Dex pre-filters by the query's trigrams, and the matcher wants the first
  letter at a word start; LSP 3.18 recommends the looser rule (section 7).

### 5.6 How the clangd divergence relates to interactivity
- Every patch either removes a wait the user sees (0001 - 0009) or makes a prompt's
  first screen useful (0011 - 0013). The config sends the symbol fields only to a
  server that announces them (`emacs-cpp-lsp-symbol-params`).
- Costs: a pinned LLVM per platform (an LLVM upgrade means a rebuild; pacman sees the
  pin), two builds to keep (Arch 23.1.1, macOS 23.1.3), and ClangdTests run on one
  machine per change. 0013 has not yet been built on the Mac.

## 6. Other divergences from upstream
All as patch files, applied by `make packages` after resetting the touched files to
the pinned commit (D-069, D-116):
- eglot, vendored from GNU ELPA's mirror at c79f727 (D-108) for three patches: 0001
  keeps partial file watches when `eglot-max-file-watches` is reached or a watch is
  refused (stock eglot answered failure, pyright exited, and eglot reconnected in a
  loop; RESEARCH_platform_differences 3.8, 3.14); 0002 shares one watch per directory
  among a server's registrations (macOS kqueue needs a descriptor per directory);
  0003 makes eglot's finders work with Emacs 31's xref 1.7.0 (the vendored eglot calls
  `xref-find-by-kind`, which only Emacs master has; `C-c l i` failed with
  `void-function`, D-117).
- consult 0001: hidden sources leave asynchronous candidate lists (D-079).
  consult-eglot 0001: keep each server's `workspace/symbol` order (clangd's `score`
  omits the name match) and pass extra request fields (D-105, D-113).
- projectile 0001 (search the project's file list), treemacs 0001 (timer), auctex 0001
  (generated manuals), yasnippet-snippets 0001 (load on demand).
- fswatch fork (`packaging/fswatch-no-loss`, D-109): a writer thread so a slow reader
  no longer makes FSEvents drop events, a queue limit with an `Overflow` record, the
  present state of a path, numbers in the C locale. For a future eglot fswatch backend
  (DESIGN 7.1); not used by the config yet. Similar: Watchman, VS Code's file watcher;
  LSP leaves watching to the client (`workspace/didChangeWatchedFiles`).
- clang-change-namespace 0001: LLVM 23's tool crashed on two or more sources (D-094,
  D-097).
- Upstream report drafts are in `docs/upstream/` (eglot watches, consult, projectile,
  treemacs, c-ts-mode indentation, texlab, clang-change-namespace, ccls); sending them
  is the owner's (T-032, T-036, T-070 ...).

## 7. Standards and comparable tools
- LSP: 3.17's `workspace/symbol` only says "a query string to filter symbols by";
  3.18 adds that the query "should be interpreted in a relaxed way ... match
  case-insensitive and ... check that the characters of query appear in their order
  ... Servers shouldn't use prefix, substring, or similar strict matching". No
  standard defines ranking. D-120 adopts 3.18's rule for every prompt but path
  completion and ranks in the same three tiers as clangd with 0013 (unbroken from a
  word start; unbroken inside a word or initials; letters with gaps).
- Matchers with their own definitions: clangd `FuzzyMatcher` (first letter at a word
  start, segment-aware), IntelliJ/CLion `MinusculeMatcher` (humps; mid-word only with
  `*`), fzf and Emacs `flex` / `orderless-flex` (any subsequence),
  `orderless-initialism`.
- Indexing models: clangd background index (per-file shards, include graph, digests),
  ccls (on-disk cache), offline indexes (`clangd-indexer`, Kythe, LSIF / SCIP) for
  large or remote code.
- File watching: inotify (per-user watch limit, D-115), kqueue (a descriptor per
  directory), FSEvents (one stream per tree; drops under load).

## 8. Performance and interactivity: budgets and techniques
- Budgets (DESIGN 11, binding on Arch, D-057): startup <= 0.5 s (0.151 s with a 64 MB
  GC threshold during startup, D-038); `M-o` opening <= 150 ms and each key's results
  <= 100 ms (S11 run 2 on RMO: 89 - 96 ms, 6 - 24 ms).
- `M-o` techniques: GC threshold 64 MB while open; highlight only the first 100 hits
  (D-077); consult's throttle 0.5 s / debounce 0.2 s for symbols (D-087); preview after a
  pause (D-088); project symbols fetched with `limit` 10000 and filtered by URI prefix
  (D-082, D-083, D-085), because clangd's 100 are crowded out by library symbols.
- Tier sort (D-120, 2026-10-20): a first version walked characters in Lisp, 0.5 ms per
  candidate (5 s for 35000 file names); regexps compiled once per input bring it to
  1 - 7 ms for 2767 names and at most 89 ms for 35000 (Arch). The owner's S11 rerun is
  pending.
- clangd: index-first navigation and header flags (section 5); a source missing from
  the database warns instead of silently using guessed flags (D-068).

## 9. Setbacks and how they shaped the code base
- Startup measured the wrong endpoint, then with a leaked environment (2026-10-07).
  Changed: measurements name endpoint and environment; `scripts/measure-startup.sh`.
- S5: warming up clangd by opening files cost 3.0 GB vs 1.1 GB. Changed: owner ruled out
  memory-for-latency (D-021); led to S6, S8.
- ccls hybrid aborted in 1 of 5 runs (indexer race on eglot's connect). Changed: patched
  clangd instead (D-026); spikes repeat sessions and watch for crashes.
- Header flags raced the project handover (O-21). Changed: patches 0006, 0007; timing
  paths tested over 10 sessions; tests that force the bad order.
- RET via clangd's on-type formatting rewrote statements (D-061). Changed: Emacs indents
  (D-065); partial server edits avoided.
- eglot refused quietly on broken presets. Changed: one loud refusal path, tested with
  seven broken projects (D-018 extended).
- Project symbols matched by URI spelling (3 spellings, case). Changed: one prefix rule
  for every server (D-085).
- Tests wrote into the owner's `~/.emacs.d`. Changed: `make test` in a temporary HOME,
  checked by the runner (D-104).
- LaTeX formatting parity claimed without a check. Changed: claims checked before README
  (D-101, D-103).
- S12 change signature FAIL: calls in templates the index cannot settle. Changed: feature
  not shipped; O-43 with the owner.
- Vendored eglot needed Emacs master's xref (found from native-compiler warnings).
  Changed: eglot patch 0003; tests run the finders, not only the key bindings.
- A grown consult-eglot patch broke `make packages` on the other machine. Changed: files
  reset to the pin before applying (D-116); uninitialised submodules named.
- fswatch fork hung on exit under glibc (condition variable destroyed while waited on).
  Changed: never-destroyed sync objects; per-platform checks (macOS libc differs).
- 0012's mid-word ranking: inverted quality order and float ties. Changed: patch 0013;
  ranking tests that fail on the old code.
- `eto` found nothing; three matchers in the config. Changed: D-120: one rule (LSP 3.18)
  and tiers; pre-filter left for later (O-68).

## 10. Open items and risks for reviewers
- Owner runs left: S11 rerun with D-120 (T-109), pkgrel 9 on the Mac and `make test`
  there (T-108), fswatch pkgrel 2 on the Mac, T-104's hand check, S10 (O-12).
- Open questions: O-12 (deal.II sources index), O-38, O-39, O-47, O-56, O-57, O-68.
- Internal APIs used: `vertico--metadata`, `consult--tofu-get`, `consult--multi`,
  `orderless--highlight`; pinned submodules make breakage visible in tests.
- Two LLVM releases per platform; patches checked on one platform per change.
- A flaky debugger test (`init-debug-lldb-preset-builds-stops-and-steps`, 0067).
- `lisp/` is interpreted: per-candidate Lisp loops in prompts are expensive.

## 11. Where to start reviewing
1. `DESIGN.md` 1 - 5 and the decisions ledger; `POSTMORTEM.md`.
2. `packaging/clangd-index-nav/*.patch` with `RESEARCH_clangd_index_navigation.md` and
   `spikes/s8-*`, `s9-*`, `s13-*`, `s14-*`, `s15-*` RESULTS.
3. `lisp/init-lsp.el`, `lisp/emacs-cpp-presets.el` (server command, refusals),
   `lisp/init-completion.el` and `lisp/init-go-to-anything.el` (matching, `M-o`).
4. `scripts/build-packages.el` and `patches/` (how upstream code is changed).
5. Verify: `make packages`, `make test`, `make check`; the patched clangd's tests are
   `ClangdTests` in a build with `-DCLANG_INCLUDE_TESTS=ON` (journal 0081).
