#!/bin/sh
# build-epdfinfo.sh - pdf-tools' server, epdfinfo, from the pinned lib/pdf-tools (D-199).
#   make epdfinfo
# Builds in lib/pdf-tools/server, where `pdf-info-epdfinfo-program' points; the build's
# files stay untracked there. The binary links the system's poppler, so a poppler library
# change means this rebuild; until then Emacs refuses to open a PDF and names this target.
# Stops on a missing tool or library, naming the platform's install command.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
DIR=$REPO/lib/pdf-tools/server
case $(uname -s) in
    Darwin) install="sudo port install poppler autoconf automake pkgconfig" ;;
    *) install="sudo pacman -S --needed base-devel libpng zlib poppler-glib" ;;
esac
fail() { echo "build-epdfinfo: $*" >&2; exit 1; }
for program in autoreconf automake pkg-config make cc; do
    command -v "$program" > /dev/null || fail "$program is not on PATH; install: $install"
done
pkg-config --exists poppler-glib libpng zlib ||
    fail "pkg-config finds no poppler-glib, libpng or zlib; install: $install"
[ -x "$DIR/autogen.sh" ] ||
    fail "no $DIR/autogen.sh; run: git submodule update --init lib/pdf-tools"
cd "$DIR"
./autogen.sh
./configure
make
[ -x epdfinfo ] || fail "make left no $DIR/epdfinfo"
echo "build-epdfinfo: built $DIR/epdfinfo"
