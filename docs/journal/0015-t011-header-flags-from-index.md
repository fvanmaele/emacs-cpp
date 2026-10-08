# 0015 - T-011: header flags from the index (patch 0005)

- **Date:** 2026-10-08
- **Commits:** llvm-clangd `b704ffd66`; here: `git log -- packaging/clangd-index-nav`
- **Tier:** 2 (owner ruling: replaces spike S4)
- **Decisions:** D-028 (resolves O-5 for indexed headers)
- **Done when:** after a restart with the index on disk, a header without a database
  entry gets the flags of a source file that includes it, per the stored index; on the
  fmt toy and on RMO, `option.h` reached by `M-.` on its `#include` line and
  `include/rmo/fe/assemble.h` opened first show no flymake errors; the config refuses
  loudly a clangd lacking the flag; ClangdTests and `make test` pass; pkgrel 3 carries
  the patch; first sessions unchanged (agreed 2026-10-08)
- **Tag:** none

> Plain English for someone who does not read C++ or Emacs Lisp fluently.

## What + why
A header (`.h`) has no line of its own in `compile_commands.json`, so clangd must
decide which compiler flags to parse it with. It borrows the flags of an open source
file that includes it, but only after that file has been parsed; otherwise it guesses
from file names, and in RMO the guess is the vendored `fmt` library, which knows no
deal.II include paths. Patch 0004 made `M-.` on `#include <rmo/option.h>` instant, so
the header now opened before `main.cc` was parsed and showed many errors (owner
report). The same happened before for headers opened first (O-5).
The stored index already records, for each header, a source file whose indexing
reached it. Patch 0005 asks the index for that file and uses its flags; the config
passes the new flag `--header-flags-from-index` next to `--navigation-from-index`.

## Concepts explained
- **Compile command "inferred from":** clangd's log line `ASTWorker building file X
  with command inferred from Y` names the file whose flags X got; `Y` = a source file
  that includes X is right, an unrelated file is the guess.
- **Includer from the index:** at startup clangd walks each source file's include
  graph when it loads the stored shards; every header it reaches remembers that source
  file. If the header is opened while this load runs, clangd waits for it (at most
  5 s) instead of guessing.
- **Config check:** the Emacs side asks the binary's `--help-hidden` for every patched
  flag; an older package (pkgrel 2) is refused with the missing flag named.

## Key files walked
- clangd `index/Background.{h,cpp}` - `includerOf`, `recordIncluders`, the load
  counter around `loadProject`.
- clangd `ClangdServer.cpp` - `IncluderFromIndexCDB`, the database the scheduler uses.
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-presets--patched-flags`,
  `emacs-cpp-presets--missing-flags`.
- `packaging/clangd-index-nav/PKGBUILD` (pkgrel 3, `check()` greps both flags).

## Measured
Fmt toy (deal.II project plus a vendored `fmt` library, like RMO), second session:

| `option.h` | pkgrel 2 | pkgrel 3 |
|---|---|---|
| reached by `M-.` on its `#include` line | 2 errors (fmt/src/format.cc) | 0 (src/main.cc) |
| opened first, nothing else open | 2 errors (fmt/src/format.cc) | 0 (src/main.cc) |

(In parentheses: the file the flags were "inferred from".)

Deal.II toy navigation unchanged (1 - 607 ms). ClangdTests 1413 / 1413 (new:
`BackgroundIndexTest.IncluderOfHeaders`: direct and transitive includers, unknown
headers, and waiting for the asynchronous load). `make test` 24 / 24 with the pkgrel
3 binary; with pkgrel 2 installed the patched-server test fails with "lacks
--header-flags-from-index", as intended. pkgrel 3 built incrementally from the pkgrel
2 tree with patch 0005 applied as `prepare()` does.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** any source file that includes a header has suitable flags for it.
  **Would break if:** a header is included by targets with different flags (e.g.
  different defines); clangd's own includer cache has the same limit.
  **DESIGN bet:** D-028.
- **Assumed:** waiting up to 5 s for the stored shards is better than a wrong guess.
  **Would break if:** loading takes longer on a much larger project; then the guess
  returns (logged), as before.
- **Risk:** headers no source file includes, and first sessions before indexing,
  still get the guess.

## Owner verification (2026-10-08)
With pkgrel 3 on RMO: `option.h` reached by the `#include` jump and
`include/rmo/fe/assemble.h` opened first show no flymake errors. T-011 done.

## How to verify
Owner: install pkgrel 3, restart Emacs, open RMO `src/main.cc`, `M-.` on
`#include <rmo/option.h>`: no flymake errors in `option.h`. Restart, open
`include/rmo/fe/assemble.h` first: no errors. Optional log: `CLANGD_FLAGS=--log=verbose`
and `occur` for `Compile command for`.

## Open questions
O-13 stays open (second-file name lookup not yet logged).
