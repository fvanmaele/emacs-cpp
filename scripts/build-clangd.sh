#!/bin/sh
# build-clangd.sh - the patched clangd of packaging/clangd-index-nav, built against the
# installed LLVM (D-027).  Linux with pacman; macOS uses build-macos.sh there.
#   sh scripts/build-clangd.sh [makepkg flags]       or: make clangd MAKEPKG_FLAGS='-si'
# Writes pkgver from `llvm-config --version` into the PKGBUILD when it differs, refreshes
# the checksums with updpkgsums (pacman-contrib; it downloads the release tarball once),
# then runs makepkg in packaging/clangd-index-nav with the flags given: none builds the
# package only, -si installs the make-dependencies and the package.  The PKGBUILD keeps
# its exact depends on llvm-libs and clang: the binary links the system libLLVM and reads
# the system clangd's index shards, so every LLVM release means this rebuild, and a
# package built for another release will not install.  Stops on a missing tool, a
# version that is no release, or an llvm-libs that does not match llvm-config.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
DIR=$REPO/packaging/clangd-index-nav
fail() { echo "build-clangd: $*" >&2; exit 1; }
command -v llvm-config > /dev/null || fail "llvm-config is not on PATH; install llvm (makedepends)"
command -v updpkgsums > /dev/null || fail "updpkgsums is not on PATH; install pacman-contrib"
command -v makepkg > /dev/null || fail "makepkg is not on PATH"
installed=$(llvm-config --version)
# Three numbers and nothing else: a glob's `*' would let "24.0.0git" through.
expr "$installed" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' > /dev/null \
    || fail "llvm-config --version gave '$installed', not a release version"
libs=$(pacman -Q llvm-libs 2>/dev/null | awk '{ print $2 }' | sed 's/-[0-9]*$//') || libs=
[ -z "$libs" ] || [ "$libs" = "$installed" ] \
    || fail "llvm-config says $installed but llvm-libs is $libs; the package needs both at one version"
current=$(sed -n 's/^pkgver=//p' "$DIR/PKGBUILD")
if [ "$current" != "$installed" ]; then
    echo "build-clangd: pkgver $current -> $installed (the installed LLVM); refreshing the checksums"
    sed -i "s/^pkgver=.*/pkgver=$installed/" "$DIR/PKGBUILD"
    (cd "$DIR" && updpkgsums)
fi
cd "$DIR"
exec makepkg "$@"
