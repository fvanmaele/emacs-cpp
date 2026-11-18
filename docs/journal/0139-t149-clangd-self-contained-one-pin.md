# 0139 - T-149: the patched clangd self-contained on Arch, one LLVM pin

- **Date:** 2026-11-18
- **Commits:** see `git log --grep T-149`
- **Tier:** 2
- **Decisions:** D-207 (supersedes D-123, D-100; amends D-027, D-052, D-150)
- **Done when:** T-149's row (agreed 2026-11-18, owner: "Tier 2, agreed").

> Plain English for someone who does not read shell or makepkg files fluently.

## What + why
The owner asked whether the patched clangd needed a rebuild. On the Mac the installed
binary matched the current patches but was LLVM 23.1.3, while MacPorts' `llvm-23` had
moved to 23.1.5: `build-macos.sh` carried its own release number and nobody was told
to move it. On Arch the opposite held: the package linked pacman's `libLLVM` and
depended on `llvm-libs` and `clang` at one exact version, so every LLVM upgrade from
pacman meant a rebuild before the upgrade could install (D-027, D-123).

D-207 removes both couplings. The Arch package is now built the way the Mac's binary
always was: LLVM and clang are compiled from the release's sources and linked into
`clangd`, and the builtin headers (`stddef.h` and the like) are the release's own.
Both machines build the same release, 23.1.5, and that release is written in one
place, the PKGBUILD.

## Concepts (shell, makepkg) explained
- **PKGBUILD.** A bash file that `makepkg` reads: variables (`pkgver`, `source`,
  `sha256sums`, `depends`) and functions (`prepare`, `build`, `check`, `package`).
  `build-macos.sh` reads the same file with `.` (bash's "source"), which only sets the
  variables; it never calls the functions. That is how one file pins both builds.
- **Static against shared linking.** Before, `-DLLVM_LINK_LLVM_DYLIB=ON` made clangd
  load `/usr/lib/libLLVM.so` at start, which must be the exact release it was compiled
  against. Now the LLVM code is inside the binary; `check()` runs `ldd` (the list of
  shared libraries a binary loads) and fails if `libLLVM` or `libclang` is in it.
- **Resource directory.** clang looks for its builtin headers in `../lib/clang` next
  to its own binary. The old package put a link to pacman's `/usr/lib/clang` there;
  the new one copies the headers built with the release (`clang-resource-headers`).
- **`case "$(uname -s)"` in the Makefile.** `uname -s` prints `Linux` or `Darwin`;
  `make clangd` picks `makepkg` or `build-macos.sh` from it and fails on anything
  else.

## Key files walked
- `packaging/clangd-index-nav/PKGBUILD` - `pkgver=23.1.5` and the first `sha256sums`
  entry are the pin; `build()` configures `llvm/` with clang and clang-tools-extra
  enabled; `depends` lost `llvm-libs` and `clang`.
- `packaging/clangd-index-nav/build-macos.sh` - `version=$pkgver`,
  `tarball_sha256=${sha256sums[0]}`; its own two lines are gone.
- `Makefile` - `clangd` dispatches on the system; `scripts/build-clangd.sh` deleted.
- `test/build-clangd-test.el` - three tests reading the two files: no LLVM among the
  dependencies, `pkgver` a release, the script without a release or checksum of its
  own. They replace the two tests of the deleted script's refusals.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the PKGBUILD's new `build()` works on Arch; it was not run (no Arch
  machine in this session). **Would break if:** a flag differs on Linux (libxml2 and
  libedit are turned off so `depends` is complete; a library LLVM still finds and
  links would be missing from `depends`). **DESIGN bet:** D-207; H-38 runs it.
- **Assumed:** pacman refuses to upgrade over the old package's `lib/clang` link, so
  H-38 removes the package first. **Would break if:** nothing; the removal is safe
  either way, the assumption only explains the step. UNVERIFIED.
- **Assumed:** someone moves the pin. **Would break if:** nobody does: pacman no
  longer forces it, and the Mac already showed two releases of drift under a pin.
  **DESIGN bet:** D-207's case against, accepted by the owner.
- **Assumed:** clangd's index shard format is the same across 23.1.x, so a system
  clangd run on the same project does not force a re-index. **Would break if:** a
  point release changes the format; the cost is a re-index. UNVERIFIED.

## How to verify
- Mac (the session, 2026-11-18): `make clangd`, then `~/opt/clangd-index-nav/bin/clangd
  --version` prints `clangd version 23.1.5`; `make test`. Results: built in about
  15 min; `clangd version 23.1.5`; `otool -L` names no `libLLVM` or `libclang`;
  `EMACS_CPP_PATCHED_CLANGD=$HOME/opt/clangd-index-nav/bin/clangd make test`: 189
  tests, 187 as expected, 2 skipped (gdb), `init-cpp-patched-clangd-navigates` passed.
- Arch: H-38 in `TODO_human.md`.
- Before any edit: the 13 patches applied to 23.1.5's `clang-tools-extra/clangd`, and
  `diff -rq` against the patched 23.1.3 tree showed no difference.
