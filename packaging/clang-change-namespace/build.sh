#!/bin/bash
# build.sh - clang-change-namespace with the fix of 0001, built against the installed
# LLVM 23 (D-097).
#
#   packaging/clang-change-namespace/build.sh [--prefix DIR] [--tarball FILE]
#                                             [--llvm-config FILE]
#
# LLVM 23's clang-change-namespace crashes when given two or more sources (a
# use-after-free, docs/upstream/clang-change-namespace-multiple-sources.md); the patch
# next to this file fixes it. The tool's three source files from LLVM 23.1.1 are
# compiled and linked against the LLVM and clang libraries already installed:
# MacPorts' llvm-23 / clang-23 on macOS (D-053), pacman's llvm and clang on Arch. The
# same script on both machines; a few seconds.
#
# --prefix DIR        install DIR/bin/clang-change-namespace
#                     (default ~/opt/clang-change-namespace)
# --tarball FILE      take the sources from the llvm-project-23.1.1.src.tar.xz release
#                     tarball (packaging/clangd-index-nav downloads the same one)
#                     instead of downloading the three files
# --llvm-config FILE  the installed LLVM's llvm-config (default: macOS
#                     /opt/local/libexec/llvm-23/bin/llvm-config, Arch: llvm-config)
#
# Downloads the three files from github.com's llvm-project at tag llvmorg-23.1.1
# unless --tarball names the tarball (D-097). Every file is checked against the
# sha256 sums below; a wrong sum, a patch that does not apply, a missing tool or an
# LLVM other than 23 stops the script with the reason. Afterwards the tool runs once
# on two generated sources (the crash's reproduction). In Emacs, `C-c l N' runs it
# (`emacs-cpp-refactor-change-namespace-program', default the installed file).
set -eu
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
version=23.1.1
major=${version%%.*}
prefix=$HOME/opt/clang-change-namespace
tarball=
case $(uname -s) in
    Darwin) llvm_config=/opt/local/libexec/llvm-$major/bin/llvm-config ;;
    *) llvm_config=llvm-config ;;
esac

die() { printf 'build: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

while [ $# -gt 0 ]; do
    case $1 in
        --prefix) [ $# -ge 2 ] || die "--prefix needs a directory"; prefix=$2; shift 2 ;;
        --tarball) [ $# -ge 2 ] || die "--tarball needs a file"; tarball=$2; shift 2 ;;
        --llvm-config) [ $# -ge 2 ] || die "--llvm-config needs a file"
                       llvm_config=$2; shift 2 ;;
        -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

# The tool's files in llvm-project, with their sha256 at llvmorg-23.1.1.
dir=clang-tools-extra/clang-change-namespace
files=("$dir/ChangeNamespace.cpp" "$dir/ChangeNamespace.h" "$dir/tool/ClangChangeNamespace.cpp")
sums=(2a0657f8e222bc8369453b002e8ca043b3960b3d8115e98dd6197627f468e2a4
      2cb4f6d0b4e4adea368e0a0d88665ee3d33f0fdc21f9ab542a4d6e78b522975e
      1a79467110b33371a3d45b8d011bbaba5e0dca91678f9cb99e37531e116df11c)
tarball_sum=ebe9be46fe8756d58c5b198ffad0fa2a766257add81a4dc52179bfacc7888ee6
patch_file=$here/0001-clang-change-namespace-Clear-the-moves-at-the-end-of.patch

need() {  # tool, how to get it
    command -v "$1" >/dev/null 2>&1 || die "$1 not found; $2"
}
if [ "$(uname -s)" = Darwin ]; then
    [ -x "$llvm_config" ] || die "$llvm_config not found; sudo port install clang-$major"
    need shasum "it ships with macOS"
    sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
    need "$llvm_config" "sudo pacman -S llvm clang"
    need sha256sum "it comes with coreutils"
    sha256() { sha256sum "$1" | cut -d' ' -f1; }
fi
need patch "Mac: xcode-select --install; Arch: sudo pacman -S patch"
if [ -n "$tarball" ]; then need tar "it ships with the system"; else need curl "it ships with the system"; fi

installed=$("$llvm_config" --version)
[ "${installed%%.*}" = "$major" ] \
    || die "$llvm_config is LLVM $installed; the sources are $version, for LLVM $major"
bindir=$("$llvm_config" --bindir)
libdir=$("$llvm_config" --libdir)
cxx=$bindir/clang++
[ -x "$cxx" ] || die "$cxx not found; it comes with clang $major"

check_sum() {  # file, expected sha256
    actual=$(sha256 "$1")
    [ "$actual" = "$2" ] || die "$1: sha256 is $actual, expected $2"
}

work=$(mktemp -d "${TMPDIR:-/tmp}/clang-change-namespace.XXXXXX")
trap 'rm -rf "$work"' EXIT

step "Sources (llvm-project $version, ${#files[@]} files)"
if [ -n "$tarball" ]; then
    [ -f "$tarball" ] || die "--tarball $tarball: no such file"
    check_sum "$tarball" "$tarball_sum"
    tar -xf "$tarball" -C "$work" "${files[@]/#/llvm-project-$version.src/}"
    mv "$work/llvm-project-$version.src/clang-tools-extra" "$work/"
else
    for file in "${files[@]}"; do
        url=https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-$version/$file
        mkdir -p "$work/$(dirname "$file")"
        curl -fsSL --retry 2 -o "$work/$file" "$url" || die "download failed: $url"
    done
fi
i=0
for file in "${files[@]}"; do
    check_sum "$work/$file" "${sums[$i]}"
    i=$((i + 1))
done
echo "checksums match"
patch -d "$work" -Np1 --quiet -i "$patch_file" \
    || die "$(basename "$patch_file") does not apply to $version's sources"
echo "applied $(basename "$patch_file")"

step "Compile against LLVM $installed ($libdir)"
read -r -a cxxflags <<< "$("$llvm_config" --cxxflags)"
read -r -a ldflags <<< "$("$llvm_config" --ldflags)"
read -r -a libs <<< "$("$llvm_config" --link-shared --libs)"
[ "$("$llvm_config" --has-rtti)" = YES ] || cxxflags+=(-fno-rtti)
# MacPorts' clang finds the SDK only when called by its -mp- name (a config file).
if [ "$(uname -s)" = Darwin ]; then
    sdk=$(xcrun --show-sdk-path) || die "no macOS SDK; xcode-select --install"
    cxxflags+=(-isysroot "$sdk")
    ldflags+=(-isysroot "$sdk")
fi
for source in ChangeNamespace.cpp tool/ClangChangeNamespace.cpp; do
    "$cxx" "${cxxflags[@]}" -O2 -I "$work/$dir" -c "$work/$dir/$source" \
        -o "$work/$(basename "$source" .cpp).o"
done
"$cxx" -o "$work/clang-change-namespace" "$work/ChangeNamespace.o" \
    "$work/ClangChangeNamespace.o" "${ldflags[@]}" -lclang-cpp "${libs[@]}" \
    -Wl,-rpath,"$libdir"

# The fix's check: two sources in one run crashed (exit 139) before it.
step "Run on two sources"
mkdir -p "$work/check"
printf 'namespace geom { struct Circle { double r; }; }\n' > "$work/check/shapes.h"
printf '#include "shapes.h"\nnamespace geom { double area(Circle c) { return c.r; } }\n' \
    > "$work/check/shapes.cc"
printf '#include "shapes.h"\nint main() { geom::Circle c{1.0}; return c.r > 0; }\n' \
    > "$work/check/main.cc"
"$work/clang-change-namespace" -old_namespace=geom -new_namespace=shapes \
    -file_pattern='.*' "$work/check/shapes.cc" "$work/check/main.cc" -- -std=c++17 \
    > "$work/check/out.txt" 2>&1 \
    || { cat "$work/check/out.txt" >&2; die "the built tool failed on two sources"; }
grep -q 'namespace shapes' "$work/check/out.txt" \
    || { cat "$work/check/out.txt" >&2; die "the built tool did not move the namespace"; }
echo "two sources: exit 0, namespace moved"

# Tools built on clang find the compiler's builtin headers (stddef.h, ...) in
# ../lib/clang next to the program; they are the installed clang's.
step "Install to $prefix"
mkdir -p "$prefix/bin" "$prefix/lib"
install -m 755 "$work/clang-change-namespace" "$prefix/bin/clang-change-namespace"
resource=$("$bindir/clang" -print-resource-dir)
rm -f "$prefix/lib/clang"
ln -s "$(dirname "$resource")" "$prefix/lib/clang"
echo "$prefix/bin/clang-change-namespace"
echo "$prefix/lib/clang -> $(dirname "$resource")"

cat <<EOF

Done. C-c l N runs it; if you chose another --prefix:
  M-x customize-variable RET emacs-cpp-refactor-change-namespace-program RET
and set it to $prefix/bin/clang-change-namespace.
EOF
