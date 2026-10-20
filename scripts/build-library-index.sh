#!/bin/sh
# build-library-index.sh - a library's offline index for clangd (D-130, D-133, T-118).
#   sh scripts/build-library-index.sh LIBRARY      or: make library-index LIBRARY=dealii
# Writes into indexes/ of this repository (ignored by git):
#   LIBRARY-VERSION/        the library's sources at the installed version (kept: the
#                           index points into them, `M-.' opens them)
#   LIBRARY-VERSION-build/  its CMake build directory (compile database and the
#                           generated instantiation files the sources include)
#   LIBRARY.dex             the index, by clangd-indexer of the patched clangd (D-133)
#   LIBRARY.stamp           (:library :version :sources :probe :built), read by
#                           lisp/emacs-cpp-library-index.el before clangd starts (D-131)
# deal.II: about 2.5 minutes on 16 cores and 10 GB of memory at the peak (S10).
# Environment: INDEXER (default: clangd-indexer next to the patched clangd),
# DEALII_SOURCES (a git checkout with the release tags, default
# ~/source/repos/dealii), DEALII_INCLUDE (where the installed headers lie; default
# /usr/include on Linux, required on macOS).
set -eu
fail() { echo "build-library-index: $*" >&2; exit 1; }
LIBRARY=${1:-}
[ -n "$LIBRARY" ] || fail "name a library: make library-index LIBRARY=dealii"
repo=$(cd "$(dirname "$0")/.." && pwd)
out=$repo/indexes
case "$(uname -s)" in
    Darwin) indexer_default=$HOME/opt/clangd-index-nav/bin/clangd-indexer; include_default= ;;
    *) indexer_default=/opt/clangd-index-nav/bin/clangd-indexer; include_default=/usr/include ;;
esac
INDEXER=${INDEXER:-$indexer_default}
[ -x "$INDEXER" ] || fail "no clangd-indexer at $INDEXER; install clangd-index-nav pkgrel 10 \
or later (make clangd MAKEPKG_FLAGS=-si; on macOS build-macos.sh), D-133"
case "$LIBRARY" in
    dealii)
        sources=${DEALII_SOURCES:-$HOME/source/repos/dealii}
        include=${DEALII_INCLUDE:-$include_default}
        [ -n "$include" ] || fail "set DEALII_INCLUDE to the directory holding deal.II/base/config.h"
        config=$include/deal.II/base/config.h
        [ -f "$config" ] || fail "no $config; is deal.II installed?"
        version=$(sed -n 's/^#define DEAL_II_PACKAGE_VERSION "\([^"]*\)".*/\1/p' "$config")
        [ -n "$version" ] || fail "no DEAL_II_PACKAGE_VERSION in $config"
        tag=v$version
        probe=n_active_cells
        ;;
    *) fail "unknown library $LIBRARY (known: dealii)" ;;
esac
[ -d "$sources/.git" ] || fail "no git checkout at $sources (clone the library's repository there)"
git -C "$sources" rev-parse -q --verify "$tag" > /dev/null \
    || fail "no tag $tag in $sources (git -C $sources fetch --tags)"
dest=$out/$LIBRARY-$version
build=$dest-build
mkdir -p "$out"
echo "build-library-index: $LIBRARY $version from $sources ($tag) into $dest"
rm -rf "$dest" "$build"
mkdir -p "$dest"
git -C "$sources" archive "$tag" | tar -x -C "$dest"
cmake -S "$dest" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DDEAL_II_COMPONENT_EXAMPLES=OFF \
    -DDEAL_II_COMPONENT_DOCUMENTATION=OFF > "$build.configure.log" 2>&1 \
    || fail "configure failed, see $build.configure.log"
ninja -C "$build" expand_all_instantiations > "$build.expand.log" 2>&1 \
    || fail "expand_all_instantiations failed, see $build.expand.log"
jobs=$(getconf _NPROCESSORS_ONLN)
"$INDEXER" --executor=all-TUs --execute-concurrency="$jobs" \
    "$build/compile_commands.json" > "$out/$LIBRARY.dex.part" 2> "$build.indexer.log" \
    || fail "clangd-indexer failed, see $build.indexer.log"
[ "$(head -c 4 "$out/$LIBRARY.dex.part")" = RIFF ] \
    || fail "clangd-indexer wrote no RIFF index, see $build.indexer.log"
mv "$out/$LIBRARY.dex.part" "$out/$LIBRARY.dex"
printf '(:library %s :version "%s" :sources "%s/" :probe "%s" :built "%s")\n' \
    "$LIBRARY" "$version" "$dest" "$probe" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$out/$LIBRARY.stamp"
echo "build-library-index: wrote $out/$LIBRARY.dex ($(du -m "$out/$LIBRARY.dex" | cut -f1) MB) \
and $out/$LIBRARY.stamp"
