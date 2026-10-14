#!/bin/bash
# S12 spike clangd: the patched clangd (pkgrel 7) plus the change-signature tweak.
#   bash spikes/s12-change-signature/build.sh
# Spike code, never promoted.  Copies the patched tree that makepkg (Arch) or
# build-macos.sh (macOS) left in packaging/clangd-index-nav/src into $S12_BUILD/clangd
# (default /tmp/s12/clangd; a reflink / clone copy where the file system has them),
# applies clangd/0001-tweak-input.patch, adds clangd/ChangeSignature.cpp and builds
# clangd there, flags as build-macos.sh.  A rerun keeps the tree and the build and
# only recompiles what changed (the tweak file is copied again each run).  Never
# writes to packaging/ or the installed clangd.  Result: $S12_BUILD/clangd/build/bin/clangd.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${S12_BUILD:-/tmp/s12}/clangd
src=${S12_PATCHED_TREE:-$repo/packaging/clangd-index-nav/src/llvm-project-23.1.1.src}
die() { printf 's12 build: %s\n' "$*" >&2; exit 1; }
[ -d "$src/clang-tools-extra/clangd" ] \
    || die "no patched tree at $src; run makepkg (Arch) or build-macos.sh (macOS) first"
grep -q header-flags-from-index "$src/clang-tools-extra/clangd/tool/ClangdMain.cpp" \
    || die "$src lacks the local patches"
tree=$work/tree
if [ ! -d "$tree" ]; then
    mkdir -p "$tree"
    for d in llvm clang clang-tools-extra cmake third-party libc; do
        cp -cR "$src/$d" "$tree/" 2>/dev/null || cp -R --reflink=auto "$src/$d" "$tree/"
    done
fi
clangd=$tree/clang-tools-extra/clangd
if ! grep -q 'std::string input;' "$clangd/Protocol.h"; then
    patch -d "$tree" -p1 --quiet -i "$here/clangd/0001-tweak-input.patch" \
        || die "0001-tweak-input.patch does not apply"
fi
cmp -s "$here/clangd/ChangeSignature.cpp" "$clangd/refactor/tweaks/ChangeSignature.cpp" \
    || cp "$here/clangd/ChangeSignature.cpp" "$clangd/refactor/tweaks/ChangeSignature.cpp"
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
