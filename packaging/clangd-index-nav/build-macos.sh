#!/bin/bash
# build-macos.sh - the patched clangd of this directory, built on macOS (D-052, T-023).
#
#   packaging/clangd-index-nav/build-macos.sh [--prefix DIR] [--tarball FILE]
#                                             [--workdir DIR]
#
# The PKGBUILD next to this file is Arch-only (makepkg, pacman's LLVM 23.1.1). This
# script builds the same release with the same patches, read from the PKGBUILD, but
# self-contained: clang and clang-tools-extra are compiled from the release sources,
# because MacPorts' llvm-23 is 23.1.3, not 23.1.1. Tools: cmake and ninja from MacPorts
# (D-053), the compiler from the Xcode Command Line Tools.
#
# --prefix DIR    install clangd and its builtin headers here
#                 (default ~/opt/clangd-index-nav)
# --tarball FILE  use this llvm-project tarball instead of downloading it
# --workdir DIR   sources and build tree (default src/ next to this file, git-ignored)
#
# Downloads the release tarball from github.com unless --tarball names one (D-052).
# Every file is checked against the PKGBUILD's sha256sums; a wrong checksum, a patch
# that does not apply or a missing tool stops the script with the reason. A rerun with
# the same sources keeps the build tree and resumes. About 30 - 60 min the first time.
# Afterwards set `emacs-cpp-clangd-program' to DIR/bin/clangd (the script prints how).
set -eu
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
prefix=$HOME/opt/clangd-index-nav
tarball=
workdir=$here/src

die() { printf 'build-macos: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

while [ $# -gt 0 ]; do
    case $1 in
        --prefix) [ $# -ge 2 ] || die "--prefix needs a directory"; prefix=$2; shift 2 ;;
        --tarball) [ $# -ge 2 ] || die "--tarball needs a file"; tarball=$2; shift 2 ;;
        --workdir) [ $# -ge 2 ] || die "--workdir needs a directory"; workdir=$2; shift 2 ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

[ "$(uname -s)" = Darwin ] || die "macOS only; on Arch Linux run makepkg -si here (D-027)"

need() {  # tool, how to get it
    command -v "$1" >/dev/null 2>&1 || die "$1 not found; $2"
}
need cmake "sudo port install cmake"
need ninja "sudo port install ninja"
need c++ "xcode-select --install"
need patch "xcode-select --install"
need shasum "it ships with macOS"
need tar "it ships with macOS"
[ -n "$tarball" ] || need curl "it ships with macOS"

# Version, tarball URL, patches and checksums: the PKGBUILD is the one source.
# shellcheck source=/dev/null
. "$here/PKGBUILD"
[ "${#source[@]}" -eq "${#sha256sums[@]}" ] \
    || die "PKGBUILD lists ${#source[@]} sources but ${#sha256sums[@]} checksums"
name=llvm-project-$pkgver.src
url=${source[0]}
case $url in
    */$name.tar.xz) ;;
    *) die "PKGBUILD's first source is not $name.tar.xz: $url" ;;
esac

check_sum() {  # file, expected sha256
    actual=$(shasum -a 256 "$1" | cut -d' ' -f1)
    [ "$actual" = "$2" ] || die "$1: sha256 is $actual, the PKGBUILD says $2"
}

step "Sources ($name, ${#source[@]} files)"
if [ -n "$tarball" ]; then
    [ -f "$tarball" ] || die "--tarball $tarball: no such file"
    archive=$tarball
else
    archive=$here/$name.tar.xz
    if [ ! -f "$archive" ]; then
        echo "downloading $url"
        curl -fL --retry 2 -o "$archive.part" "$url" || die "download failed: $url"
        mv "$archive.part" "$archive"
    fi
fi
check_sum "$archive" "${sha256sums[0]}"
patches=()
i=1
while [ "$i" -lt "${#source[@]}" ]; do
    patch_file=$here/${source[$i]}
    [ -f "$patch_file" ] || die "patch ${source[$i]} listed in the PKGBUILD is missing"
    check_sum "$patch_file" "${sha256sums[$i]}"
    patches+=("$patch_file")
    i=$((i + 1))
done
for patch_file in "$here"/[0-9][0-9][0-9][0-9]-*.patch; do
    case " ${source[*]} " in
        *" $(basename "$patch_file") "*) ;;
        *) die "$(basename "$patch_file") is not listed in the PKGBUILD" ;;
    esac
done
echo "checksums match the PKGBUILD"

# The extracted, patched tree is kept while the sources are unchanged, so a rerun
# resumes the build instead of compiling everything again.
tree=$workdir/$name
build=$workdir/build
stamp=$workdir/.prepared
step "Patched tree in $tree"
if [ -f "$stamp" ] && [ -d "$tree" ] && [ "$(cat "$stamp")" = "${sha256sums[*]}" ]; then
    echo "unchanged since the last run, kept"
else
    rm -rf "$tree" "$build" "$stamp"
    mkdir -p "$workdir"
    tar -xf "$archive" -C "$workdir"
    for patch_file in "${patches[@]}"; do
        echo "applying $(basename "$patch_file")"
        patch -d "$tree" -Np1 --quiet -i "$patch_file" \
            || die "$(basename "$patch_file") does not apply to $name"
    done
    printf '%s\n' "${sha256sums[*]}" > "$stamp"
fi

step "Configure ($build)"
cmake -S "$tree/llvm" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
    -DLLVM_TARGETS_TO_BUILD=host \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_DOCS=OFF \
    -DCLANGD_ENABLE_REMOTE=OFF \
    -DLLVM_APPEND_VC_REV=OFF  # else the version names the enclosing git repository

step "Build clangd and its builtin headers"
cmake --build "$build" --target clangd clang-resource-headers

step "Check the patched flags"
for flag in --navigation-from-index --header-flags-from-index; do
    "$build/bin/clangd" --help-hidden | grep -q -- "$flag" \
        || die "the built clangd lacks $flag; are the patches applied?"
done
echo "both flags present"

# clangd finds its builtin headers (stddef.h, ...) in ../lib/clang next to itself.
step "Install to $prefix"
mkdir -p "$prefix/bin" "$prefix/lib"
install -m 755 "$build/bin/clangd" "$prefix/bin/clangd"
rm -rf "$prefix/lib/clang"
cp -R "$build/lib/clang" "$prefix/lib/clang"
"$prefix/bin/clangd" --version | head -1

cat <<EOF

Done. In Emacs: M-x customize-variable RET emacs-cpp-clangd-program RET
set it to $prefix/bin/clangd and save it for future sessions. The tests use it with
  EMACS_CPP_PATCHED_CLANGD=$prefix/bin/clangd make test
EOF
