#!/bin/bash
# build-macos.sh - the patched fswatch of this directory, built on macOS (D-109, T-098).
#
#   packaging/fswatch-no-loss/build-macos.sh [--prefix DIR] [--tarball FILE]
#                                            [--workdir DIR]
#
# The PKGBUILD next to this file is Arch-only (makepkg). This script builds the same
# release with the same patches, both read from the PKGBUILD, with the compiler from
# the Xcode Command Line Tools (configure and make; no MacPorts tools needed), then
# runs check.sh on the result before installing it.
#
# --prefix DIR    install bin/fswatch here (default ~/opt/fswatch-no-loss)
# --tarball FILE  use this fswatch release tarball instead of downloading it
# --workdir DIR   sources and build tree (default src/ next to this file, git-ignored)
#
# Downloads the release tarball from github.com unless --tarball names one (D-109).
# Every source is checked against the PKGBUILD's sha256; a wrong checksum, a patch
# that does not apply, a failed check or a missing tool stops the script with the
# reason. libfswatch is linked in (--disable-shared), so the binary never loads
# MacPorts' libfswatch. MacPorts' own fswatch stays where it is.
set -eu
export LC_ALL=C

here=$(cd "$(dirname "$0")" && pwd)
prefix=$HOME/opt/fswatch-no-loss
tarball=
workdir=$here/src

die() { printf 'build-macos: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

while [ $# -gt 0 ]; do
    case $1 in
        --prefix) [ $# -ge 2 ] || die "--prefix needs a directory"; prefix=$2; shift 2 ;;
        --tarball) [ $# -ge 2 ] || die "--tarball needs a file"; tarball=$2; shift 2 ;;
        --workdir) [ $# -ge 2 ] || die "--workdir needs a directory"; workdir=$2; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
done

[ "$(uname -s)" = Darwin ] || die "macOS only; on Arch Linux run makepkg -si here (D-109)"

need() {  # tool, how to get it
    command -v "$1" >/dev/null 2>&1 || die "$1 not found; $2"
}
need c++ "xcode-select --install"
need make "xcode-select --install"
need patch "xcode-select --install"
need python3 "xcode-select --install (check.sh needs it)"
need shasum "it ships with macOS"
need tar "it ships with macOS"
[ -n "$tarball" ] || need curl "it ships with macOS"

# Sources and checksums: the PKGBUILD is the one source.
# shellcheck source=/dev/null
. "$here/PKGBUILD"
[ "${#source[@]}" -eq "${#sha256sums[@]}" ] \
    || die "PKGBUILD lists ${#source[@]} sources but ${#sha256sums[@]} checksums"
name=fswatch-$pkgver
case ${source[0]} in
    */$name.tar.gz) ;;
    *) die "PKGBUILD's first source is not $name.tar.gz: ${source[0]}" ;;
esac
url=${source[0]}

check_sum() {  # file, expected sha256
    actual=$(shasum -a 256 "$1" | cut -d' ' -f1)
    [ "$actual" = "$2" ] || die "$1: sha256 is $actual, the PKGBUILD says $2"
}

step "Sources ($name, ${#source[@]} files)"
if [ -n "$tarball" ]; then
    [ -f "$tarball" ] || die "--tarball $tarball: no such file"
    archive=$tarball
else
    archive=$here/$name.tar.gz
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
    file=$here/${source[$i]}
    [ -f "$file" ] || die "${source[$i]} listed in the PKGBUILD is missing"
    check_sum "$file" "${sha256sums[$i]}"
    case $file in *.patch) patches+=("$file") ;; esac
    i=$((i + 1))
done
for file in "$here"/[0-9][0-9][0-9][0-9]-*.patch; do
    case " ${source[*]} " in
        *" $(basename "$file") "*) ;;
        *) die "$(basename "$file") is not listed in the PKGBUILD" ;;
    esac
done
echo "checksums match"

tree=$workdir/$name
step "Patched tree in $tree"
rm -rf "$tree"
mkdir -p "$workdir"
tar -xzf "$archive" -C "$workdir"
for file in "${patches[@]}"; do
    echo "applying $(basename "$file")"
    patch -d "$tree" -Np1 --quiet -i "$file" || die "$(basename "$file") does not apply to $name"
done

step "Configure and build"
(cd "$tree" && ./configure --prefix="$prefix" --disable-shared >configure.log 2>&1) \
    || die "configure failed; see $tree/configure.log"
make -C "$tree" -j"$(sysctl -n hw.ncpu)" >"$tree/make.log" 2>&1 \
    || die "make failed; see $tree/make.log"
binary=$tree/fswatch/src/fswatch
file "$binary" | grep -q 'Mach-O' || die "$binary is not a Mach-O executable"
if otool -L "$binary" | grep -q libfswatch; then
    die "$binary links a shared libfswatch; expected it linked in"
fi

step "Check"
sh "$here/check.sh" "$binary" || die "check.sh failed; nothing installed"

step "Install to $prefix"
mkdir -p "$prefix/bin"
install -m 755 "$binary" "$prefix/bin/fswatch"
"$prefix/bin/fswatch" --version | head -1

cat <<EOF

Done: $prefix/bin/fswatch, the config's emacs-cpp-default-fswatch-program (D-127).
EOF
