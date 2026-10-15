#!/bin/bash
# S13 spike clangd on macOS (criterion 5): the patched clangd of build-macos.sh
# (23.1.3, patches 0001 - 0009) plus 0001-real-main-files.patch.
#   bash spikes/s13-symlinked-paths/build-macos.sh
# Spike code, never promoted.  build.sh builds against Arch's system LLVM; this one
# clones (APFS clonefile, no copy) the tree build-macos.sh left in
# packaging/clangd-index-nav/src into $S13_MAC_BUILD/tree (default
# ~/.cache/emacs-cpp-s13-mac), applies the spike patch once, configures as
# build-macos.sh does and builds clangd and its builtin headers.  Never writes to
# packaging/ or to the installed clangd, the baseline.  Result:
# $S13_MAC_BUILD/build/bin/clangd.  About as long as build-macos.sh the first time.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${S13_MAC_BUILD:-$HOME/.cache/emacs-cpp-s13-mac}
src=${S13_PATCHED_TREE:-$repo/packaging/clangd-index-nav/src/llvm-project-23.1.3.src}
die() { printf 's13 build-macos: %s\n' "$*" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || die "macOS only; on Arch use build.sh"
[ -d "$src/clang-tools-extra/clangd" ] || die "no patched tree at $src; run build-macos.sh first"
grep -q header-flags-from-index "$src/clang-tools-extra/clangd/tool/ClangdMain.cpp" \
    || die "$src lacks the local patches"
tree=$work/tree
mkdir -p "$work"
[ -d "$tree/llvm" ] || cp -c -R "$src" "$tree"
if ! grep -q 'realMainFiles' "$tree/clang-tools-extra/clangd/index/Background.cpp"; then
    patch -d "$tree" -p1 --quiet -i "$here/0001-real-main-files.patch" \
        || die "0001-real-main-files.patch does not apply"
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
