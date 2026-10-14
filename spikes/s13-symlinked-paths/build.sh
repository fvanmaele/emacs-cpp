#!/bin/bash
# S13 spike clangd: the patched clangd (pkgrel 7) plus 0001-real-main-files.patch.
#   bash spikes/s13-symlinked-paths/build.sh [--baseline]
# Spike code, never promoted.  Copies the clang and clang-tools-extra parts of the
# patched tree makepkg left in packaging/clangd-index-nav/src into $S13_BUILD/tree
# (default ~/.cache/emacs-cpp-s13; reflink copy where the file system has it) and
# builds clangd there standalone against the system LLVM, as the PKGBUILD does.
# --baseline builds without the spike patch (for the before numbers); a later run
# without it applies the patch and recompiles only Background.cpp.  Never writes to
# packaging/ or the installed clangd.  Result: $S13_BUILD/build/bin/clangd.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${S13_BUILD:-$HOME/.cache/emacs-cpp-s13}
src=${S13_PATCHED_TREE:-$repo/packaging/clangd-index-nav/src/llvm-project-23.1.1.src}
die() { printf 's13 build: %s\n' "$*" >&2; exit 1; }
[ -d "$src/clang-tools-extra/clangd" ] || die "no patched tree at $src; run makepkg first"
grep -q header-flags-from-index "$src/clang-tools-extra/clangd/tool/ClangdMain.cpp" \
    || die "$src lacks the local patches"
tree=$work/tree
if [ ! -d "$tree/clang" ]; then
    mkdir -p "$tree/llvm/utils"
    for d in clang clang-tools-extra cmake third-party llvm/cmake llvm/utils/lit; do
        cp -R --reflink=auto "$src/$d" "$tree/$d"
    done
fi
bg=$tree/clang-tools-extra/clangd/index/Background.cpp
if [ "${1:-}" != --baseline ] && ! grep -q 'S13' "$bg"; then
    patch -d "$tree" -p1 --quiet -i "$here/0001-real-main-files.patch" \
        || die "0001-real-main-files.patch does not apply"
fi
cmake -S "$tree/clang" -B "$work/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DCLANG_INCLUDE_TESTS=OFF -DCLANG_INCLUDE_DOCS=OFF -DLLVM_INCLUDE_TESTS=OFF \
    -DCLANGD_ENABLE_REMOTE=OFF -DCMAKE_SKIP_RPATH=ON > "$work/configure.log" \
    || die "configure failed, see $work/configure.log"
cmake --build "$work/build" --target clangd
# Builtin headers (stddef.h, ...) are found relative to the binary, as in the package.
[ -e "$work/build/lib/clang" ] || ln -s /usr/lib/clang "$work/build/lib/clang"
echo "built $work/build/bin/clangd"
