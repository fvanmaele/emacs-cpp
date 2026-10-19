# 0081 - T-108: clangd patch 0013, mid-word matches ranked by shape

- **Date:** 2026-10-19
- **Commits:** see `git log --grep T-108` (the patch, the PKGBUILD and this entry)
- **Tier:** 2
- **Decisions:** D-119 (O-67 (a)), S15 PASS
- **Done when:** patch 0013 in `packaging/clangd-index-nav`: matches contiguous from
  a word start keep their order; scattered fuzzy and mid-word matches follow by the
  share of the name they cover (doubled at a word end), in Dex, MemIndex and
  `getWorkspaceSymbols`; a second-tier score -1 / (1 + score), replacing 0012's -1
  times quality and minus 1e6; behind `middleMatch`, no new field or Emacs option.
  Unit tests: the tiers and coverage scores; on a toy index `ector` puts `Vector`
  before an `E` + `Ctor` constructor and keeps quality order among mid-word
  matches; a limit keeps the best; code completion unchanged; the other ClangdTests
  pass. pkgrel 9: `makepkg -si` (Arch), `build-macos.sh` (Mac); `make test` on both;
  terminal check on RMO: `C-c l s ector` shows `dealii::Vector` first.

> Plain English for someone who does not read C++ fluently.

## What + why
S15 showed on RMO that ranking symbol matches by their shape puts `dealii::Vector`
first for `ector`, where clangd listed Kokkos constructors matched as `E` + `Ctor`,
without moving any good match of an ordinary query. This entry is that rule written
fresh as clangd patch 0013, with clangd's own unit tests, in package pkgrel 9. The
Emacs side is unchanged: `M-o` and `C-c l s` already send `middleMatch`.

## Concepts (C++) explained
- **One helper, three callers.** `tieredMatch` (FuzzyMatch.cpp) takes the symbol's
  name, the query and the fuzzy score (or none) and returns a score and a tier.
  Dex (the background index), MemIndex (the small in-memory one) and
  `getWorkspaceSymbols` (the final ranking) all call it, but only when the request
  carries `middleMatch` and the query is that long; code completion never sets it.
- **`std::optional`.** "A float or nothing": no fuzzy score, or no match at all. The
  helper returns `std::nullopt` when the name neither fuzzy-matches nor contains the
  query, and the callers skip the symbol.
- **`calculateRoles`.** clangd's own word splitter marks each character as the head
  of a word segment, inside one, or a separator; the helper uses it to tell "from a
  word start" and "ends a word" (`Vector` in `AlignedVectorCopy` ends where `Copy`
  starts).
- **`find_insensitive`.** `llvm::StringRef`'s case-insensitive search, used in a loop
  so that every occurrence is tried (`ectorector` has two).
- **`secondTierScore`.** -1 / (1 + score): a second-tier score lands in [-1, 0),
  below every first-tier one (0 or more), and a larger score stays larger. 0012
  subtracted 1e6 instead, and a `float` that large only has steps of 0.0625.
- **Unit tests as the proof.** Four of the six new tests (Dex, MemIndex, workspace
  symbols) were run against 0012's ranking code with the helper present: all four
  fail there, and pass with 0013. 0012's own tests pass with both.

## Key files walked
- `packaging/clangd-index-nav/0013-...-rank-mid-word-matches-by-sha.patch` -
  `FuzzyMatch.h` / `.cpp` (`tieredMatch`, `secondTierScore`; 0012's
  `containsInIdentifier` is gone, and `FuzzyMatcher`'s comment is back above its
  class), `index/dex/Dex.cpp`, `index/MemIndex.cpp`, `FindSymbols.cpp`, and the tests
  in `unittests/FuzzyMatchTests.cpp`, `DexTests.cpp`, `IndexTests.cpp`,
  `FindSymbolsTests.cpp`.
- `packaging/clangd-index-nav/PKGBUILD` - pkgrel 9, 0013 in the sources.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** covering more of the name is the better mid-word match. **Would break
  if:** the owner wants long names first; the coverage rule is one function.
  **DESIGN bet:** D-119.
- **Assumed:** the patch applies to the Mac's 23.1.3 tree as 0001 - 0012 do.
  **Would break if:** the files differ there; `build-macos.sh` stops on a patch that
  does not apply.
- **Risk:** the tests ran on Arch only (ClangdTests in the spike's build directory,
  configured with tests); the Mac build has no test run.

## How to verify
- Arch: `cd packaging/clangd-index-nav && makepkg -si` (pkgrel 9); then `make test`;
  in Emacs on RMO, `C-c l s ector`: a `dealii::Vector` first.
- Mac: `packaging/clangd-index-nav/build-macos.sh`; `make test`.
