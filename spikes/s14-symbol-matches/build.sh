#!/bin/bash
# S14 spike clangd (macOS): the patched clangd of build-macos.sh (23.1.3, patches
# 0001 - 0009) plus 0001-middle-and-loose-scope-matches.patch.
#   bash spikes/s14-symbol-matches/build.sh
# Spike code, never promoted.  Clones (APFS clonefile, no copy) the patched tree
# build-macos.sh left in packaging/clangd-index-nav/src into $S14_BUILD/tree (default
# ~/.cache/emacs-cpp-s14), applies the spike patch once, configures as build-macos.sh
# does and builds clangd and its builtin headers.  Never writes to packaging/ or to
# the installed clangd, which serves as the baseline.  Result:
# $S14_BUILD/build/bin/clangd.  The first build takes about as long as build-macos.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${S14_BUILD:-$HOME/.cache/emacs-cpp-s14}
src=${S14_PATCHED_TREE:-$repo/packaging/clangd-index-nav/src/llvm-project-23.1.3.src}
die() { printf 's14 build: %s\n' "$*" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || die "macOS only (the tree of build-macos.sh)"
[ -d "$src/clang-tools-extra/clangd" ] || die "no patched tree at $src; run build-macos.sh first"
grep -q header-flags-from-index "$src/clang-tools-extra/clangd/tool/ClangdMain.cpp" \
    || die "$src lacks the local patches"
tree=$work/tree
mkdir -p "$work"
[ -d "$tree/llvm" ] || cp -c -R "$src" "$tree"
if ! grep -q 'S14 spike' "$tree/clang-tools-extra/clangd/FindSymbols.cpp"; then
    patch -d "$tree" -p1 --quiet -i "$here/0001-middle-and-loose-scope-matches.patch" \
        || die "0001-middle-and-loose-scope-matches.patch does not apply"
fi
cmake -S "$tree/llvm" -B "$work/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
    -DLLVM_TARGETS_TO_BUILD=host \
    -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF \
    -DCLANGD_ENABLE_REMOTE=OFF -DLLVM_APPEND_VC_REV=OFF > "$work/configure.log" \
    || die "configure failed, see $work/configure.log"
cmake --build "$work/build" --target clangd clang-resource-headers
echo "built $work/build/bin/clangd"
