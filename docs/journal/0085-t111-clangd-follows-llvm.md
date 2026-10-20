# 0085 - T-111: the Arch clangd package follows the installed LLVM

- **Date:** 2026-10-20
- **Commits:** see `git log -1 --grep "T-111"`
- **Tier:** 2
- **Decisions:** D-123 (amends D-027)
- **Done when:** as D-123: `make clangd MAKEPKG_FLAGS=-si` on Arch builds, passes
  `check()` and installs at pacman's LLVM (owner's run); the refusals are tested
- **Tag:** none

> Plain English for someone who does not read POSIX sh or makepkg fluently.

## What + why
The PKGBUILD named LLVM 23.1.1 by hand and demanded exactly that `llvm-libs`, so
once Arch moved to 23.1.3 the package could neither build nor install: the first
symptom of "rebuild after an LLVM upgrade" was "cannot be installed". The exact
dependency is right (D-027: the binary links the system `libLLVM`), so only who
writes the version changes: `make clangd` reads the installed LLVM's version, writes
it into the PKGBUILD with fresh checksums, and runs makepkg. The change is the
outside review's `review/llvm-unpin.patch` (author kept), taken through `git am`;
this session added a stricter version check, tests and the docs.

## Concepts (POSIX sh, makepkg) explained
- `case $v in [0-9]*.[0-9]*.[0-9]*)` is a glob: `*` matches anything, so
  "24.0.0git" passed and GNU `sed -i` would have written it as `pkgver`. `expr "$v"
  : 'RE'` matches a basic regular expression anchored at the start; with `$` at the
  end it accepts three numbers and nothing else.
- `makepkg` cannot ask pacman for a version from inside a PKGBUILD; a wrapper that
  edits `pkgver` and then runs `updpkgsums` (from `pacman-contrib`) is the usual way.

## Key files walked
- `scripts/build-clangd.sh` (NEW, from the review) - checks tools, versions, writes
  `pkgver`, refreshes sums, `exec makepkg "$@"`.
- `Makefile` - target `clangd`, `MAKEPKG_FLAGS`.
- `test/build-clangd-test.el` (NEW) - runs the script with stub `llvm-config`,
  `pacman`, `updpkgsums` and `makepkg` first on PATH.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** pacman's `llvm`, `llvm-libs` and `clang` move together. **Would break
  if:** a partial upgrade leaves them apart; the script refuses `llvm-libs` against
  `llvm-config`, not `clang`, and makepkg's exact `depends` catch the rest.
  **DESIGN bet:** D-123.
- **Assumed:** the 13 patches keep applying across LLVM point releases (the review:
  23.1.3, no offset). **Would break if:** a release touches the patched files; then
  makepkg's `prepare()` stops with patch's message, loudly.
- **Risk:** the build rewrites a tracked file (the PKGBUILD); the change is committed
  after a good build, as any version bump.

## How to verify
`make test` (the two `build-clangd-*` tests). Owner, on Arch: `make clangd
MAKEPKG_FLAGS=-si`, then `/opt/clangd-index-nav/bin/clangd --version` names
pacman's LLVM and `--help-hidden` lists `--navigation-from-index`.
