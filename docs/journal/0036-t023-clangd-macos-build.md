# 0036 - T-023: the patched clangd built on macOS

- **Date:** 2026-10-09
- **Commits:** see `git log -- packaging/clangd-index-nav/build-macos.sh`
- **Tier:** 2
- **Decisions:** D-052 (built here), D-053, D-014, D-027
- **Done when:** run by the owner on the Mac, it installs a clangd that lists
  `--navigation-from-index` and `--header-flags-from-index`; a wrong checksum, a patch
  that does not apply or a missing tool stops it with the reason;
  `init-cpp-patched-clangd-navigates` passes on the Mac with that clangd; the steps in
  CHEATSHEET are replaced by a pointer to the script (agreed 2026-10-09).
- **Tag:** none

> Plain English for an owner who reads shell scripts only in part.

## What + why
On Arch the patched clangd is a pacman package built from the PKGBUILD against the
system LLVM 23.1.1 (D-027). On macOS neither makepkg nor that LLVM exists; MacPorts
ships LLVM 23.1.3. The owner ruled for a script (D-052) following the manual steps
that CHEATSHEET listed. `build-macos.sh` builds the same release with the same patches,
self-contained (clang compiled from the release sources), and installs clangd and its
builtin headers to `~/opt/clangd-index-nav`.

A test run on the Mac, into scratch directories and with the owner's already
downloaded tarball (so no download), took 14 minutes and installed a clangd 23.1.1
with both patched flags. `init-cpp-patched-clangd-navigates` passes with it.

## Concepts explained
- **The PKGBUILD as the one source.** A PKGBUILD is a bash file that sets variables:
  `pkgver`, `source` (the tarball URL and the patch files) and `sha256sums` (one per
  source, same order). The script reads it with `.` (bash's "run this file here"), so
  a new patch or version is changed in one place and both platforms follow. Its
  functions (`build`, `package`) are defined but never called.
- **Checksums before anything else.** `shasum -a 256` of the tarball and of every
  patch must equal the PKGBUILD's value; a patch file in the directory that the
  PKGBUILD does not list also stops the script. Only then is anything extracted.
- **Resuming.** The extracted, patched tree is kept with a stamp holding the
  checksums. A rerun with the same sources keeps it, and ninja only builds what is
  missing; changed sources start from a fresh tree.
- **`LLVM_APPEND_VC_REV=OFF`.** LLVM puts the git revision of the source tree into
  `clangd --version`. Built inside this repository, it picked up this repository's
  revision ("clangd version 23.1.1 (git@github.com:fvanmaele/emacs-cpp a1f47e9...)" in
  the owner's manual build); now it says only "clangd version 23.1.1".
- **Builtin headers.** clangd looks for `stddef.h` and friends in `../lib/clang/23`
  next to its binary, so the install copies that directory along.

## Key files walked
- `packaging/clangd-index-nav/build-macos.sh` - options, tool checks, PKGBUILD,
  checksums, extraction and patches, configure, build, flag check, install.
- `test/init-cpp-test.el` - the patched clangd's default path is `~/opt/...` on macOS.
- `docs/CHEATSHEET.md` - item 6 now points to the script.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the PKGBUILD stays plain assignments readable by bash 3.2 (macOS's
  bash). **Would break if:** it uses bash 4 syntax; the script then fails on reading.
  **DESIGN bet:** D-052.
- **Assumed:** MacPorts' libedit, zlib and zstd stay installed: the built clangd links
  them from `/opt/local/lib`. **Would break if:** they are uninstalled or change
  their library version; clangd then does not start, and the config refuses eglot
  (D-026). Rerun the script.
- **Risk:** 3.3 GB of build tree stay in `packaging/clangd-index-nav/src/` (git-ignored)
  so that a rerun resumes. Delete it to reclaim the space.
- **Risk:** the download from github.com happens only when the owner runs the script
  without `--tarball` (D-052); not exercised in the test run.

## How to verify
Owner, on the Mac:
```
packaging/clangd-index-nav/build-macos.sh --tarball packaging/llvm-project-23.1.1.src.tar.xz
EMACS_CPP_PATCHED_CLANGD=$HOME/opt/clangd-index-nav/bin/clangd make test
```
(or without `--tarball`, which downloads it). Then set `emacs-cpp-clangd-program`.
