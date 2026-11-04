#!/bin/sh
# S19 (D-171 .. D-173): build bench.cpp against the clangd build tree's libraries.
#   sh spikes/s19-gap-trigrams/build.sh OUT [-DS19_GAP]
# Spike code, never promoted. Takes ninja's own compile and link commands for dexp
# (same flags and libraries) and swaps in bench.cpp and OUT, so the same source
# builds against pkgrel 1 and against the spike's patch. Needs `ninja dexp` built
# once in the tree (its object and link inputs).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
build=$here/../../packaging/clangd-index-nav/src/build
build=$(cd "$build" && pwd)
out=$1
shift
extra=${1:-}
obj=tools/extra/clangd/index/dex/dexp/CMakeFiles/dexp.dir/Dexp.cpp.o
cd "$build"
compile=$(ninja -t commands "$obj" | tail -1)
link=$(ninja -t commands bin/dexp | tail -1)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/s19-build.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
# The compile line names the source after -c (an absolute path through the tree's
# clang/tools/extra symlink) and the object by $obj.
compile=$(printf '%s' "$compile" | sed -e "s#-c [^ ]*/Dexp\.cpp#-c $here/bench.cpp#" \
    -e "s#-o $obj#-o $tmp/bench.o#" -e "s#-MF [^ ]*#-MF $tmp/bench.d#" \
    -e "s#-MT [^ ]*#-MT $tmp/bench.o#")
link=$(printf '%s' "$link" | sed -e "s#$obj#$tmp/bench.o#" -e "s#-o bin/dexp#-o $out#" \
    -e "s#-Wl,--dependency-file=[^ ]*##")
case $compile in
    *"-c $here/bench.cpp"*) ;;
    *) echo "build.sh: the compile line still names Dexp.cpp, not bench.cpp" >&2; exit 1 ;;
esac
case $link in
    *"$tmp/bench.o"*"-o $out"*|*"-o $out"*"$tmp/bench.o"*) ;;
    *) echo "build.sh: the link line was not rewritten" >&2; exit 1 ;;
esac
sh -c "$compile $extra"
sh -c "$link"
echo "build.sh: wrote $out"
