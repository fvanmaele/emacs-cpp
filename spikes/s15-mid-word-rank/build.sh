#!/bin/bash
# S15 spike clangd: the patched clangd of packaging/clangd-index-nav (patches 0001 -
# 0012) plus 0001-rank-mid-word-by-shape.patch.
#   bash spikes/s15-mid-word-rank/build.sh
# Spike code, never promoted.  Copies the patched tree that makepkg (Arch, 23.1.1) or
# build-macos.sh (macOS, 23.1.3) left in packaging/clangd-index-nav/src into
# $S15_BUILD/tree (default ~/.cache/emacs-cpp-s15), applies the spike patch once and
# builds clangd as the PKGBUILD (Arch: against the system LLVM library) or
# build-macos.sh (macOS: LLVM in-tree) does.  Never writes to packaging/ or to the
# installed clangd, which serves as the baseline.  Result: $S15_BUILD/build/bin/clangd.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${S15_BUILD:-$HOME/.cache/emacs-cpp-s15}
die() { printf 's15 build: %s\n' "$*" >&2; exit 1; }
case $(uname -s) in
    Darwin) version=23.1.3 ;;
    Linux) version=23.1.1 ;;
    *) die "Arch or macOS only" ;;
esac
src=${S15_PATCHED_TREE:-$repo/packaging/clangd-index-nav/src/llvm-project-$version.src}
[ -d "$src/clang-tools-extra/clangd" ] \
    || die "no patched tree at $src; run makepkg (Arch) or build-macos.sh (macOS) first"
grep -q workspaceSymbolMatchesProvider "$src/clang-tools-extra/clangd/ClangdLSPServer.cpp" \
    || die "$src lacks patches 0011 / 0012"
tree=$work/tree
mkdir -p "$tree"
for dir in clang clang-tools-extra cmake llvm third-party; do
    [ -d "$tree/$dir" ] && continue
    if [ "$(uname -s)" = Darwin ]; then cp -c -R "$src/$dir" "$tree/"
    else cp -a --reflink=auto "$src/$dir" "$tree/"; fi
done
if ! grep -q 'S15 spike' "$tree/clang-tools-extra/clangd/FuzzyMatch.h"; then
    patch -d "$tree" -p1 --quiet -i "$here/0001-rank-mid-word-by-shape.patch" \
        || die "0001-rank-mid-word-by-shape.patch does not apply"
fi
if [ "$(uname -s)" = Darwin ]; then
    cmake -S "$tree/llvm" -B "$work/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
        -DLLVM_TARGETS_TO_BUILD=host \
        -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
        -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF \
        -DCLANGD_ENABLE_REMOTE=OFF -DLLVM_APPEND_VC_REV=OFF > "$work/configure.log" \
        || die "configure failed, see $work/configure.log"
    cmake --build "$work/build" --target clangd clang-resource-headers
else
    cmake -S "$tree/clang" -B "$work/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_LINK_LLVM_DYLIB=ON \
        -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF -DCLANGD_ENABLE_REMOTE=OFF > "$work/configure.log" \
        || die "configure failed, see $work/configure.log"
    cmake --build "$work/build" --target clangd
fi
echo "built $work/build/bin/clangd"
