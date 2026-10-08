#!/bin/sh
# S10 navigation into deal.II's own sources (O-12).  Owner runs:
#   sh spikes/s10-library-index/run.sh [project-dir] [source] [names]
# Builds, once, in $S10_DIR (default /tmp/s10/lib): a copy of deal.II's sources at the
# installed version (git archive of ~/source/repos/dealii at v<version>), its compile
# database (CMake, Debug, no examples or docs), the instantiation files, and an offline
# index (clangd-indexer of ~/source/repos/llvm-clangd, about 2.5 min, 10 GB peak).
# Then copies the project to $S10_WORK (default /tmp/s10/work/<name>), configures the
# debug preset, builds clangd's own index in one session, and measures four variants:
# the system clangd and the patched one (/opt/clangd-index-nav), each without and with
# the deal.II index (a private XDG_CONFIG_HOME whose clangd/config.yaml names it).
# Never writes to the project or to ~/.config/clangd.  Writes results.log next to this
# script, never over one.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
SOURCE=${2:-src/main_sparsity.cc}
NAMES=${3:-n_active_cells}
DIR=${S10_DIR:-/tmp/s10/lib}
WORK=${S10_WORK:-/tmp/s10/work/$(basename "$SRC")}
DEALII=${S10_DEALII:-$HOME/source/repos/dealii}
INDEXER=${S10_INDEXER:-$HOME/source/repos/llvm-clangd/build/bin/clangd-indexer}
PATCHED=${S10_PATCHED:-/opt/clangd-index-nav/bin/clangd}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S10_LOG:-$HERE/results.log}
VERSION=$(pacman -Q deal-ii | awk '{print $2}' | cut -d- -f1)
[ -e "$LOG" ] && { echo "s10: $LOG exists; move it away first" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s10: $WORK exists; remove it first" >&2; exit 1; }
[ -x "$INDEXER" ] || { echo "s10: no clangd-indexer at $INDEXER" >&2; exit 1; }
[ -x "$PATCHED" ] || { echo "s10: no patched clangd at $PATCHED" >&2; exit 1; }
[ -f "$SRC/$SOURCE" ] || { echo "s10: no $SOURCE in $SRC" >&2; exit 1; }
git -C "$DEALII" rev-parse -q --verify "v$VERSION" > /dev/null \
    || { echo "s10: no tag v$VERSION in $DEALII" >&2; exit 1; }
{ echo "# S10 run $(date -Iseconds) on copy of $SRC; $SOURCE; names: $NAMES"
  echo "deal-ii $VERSION; system $(clangd --version | head -n 1); patched $PATCHED"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
if [ ! -f "$DIR/dealii.dex" ]; then
    mkdir -p "$DIR/dealii-$VERSION"
    git -C "$DEALII" archive "v$VERSION" | tar -x -C "$DIR/dealii-$VERSION"
    cmake -S "$DIR/dealii-$VERSION" -B "$DIR/build" -G Ninja -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DDEAL_II_COMPONENT_EXAMPLES=OFF \
        -DDEAL_II_COMPONENT_DOCUMENTATION=OFF > "$DIR/configure.log" 2>&1 \
        || { echo "s10: deal.II configure failed, see $DIR/configure.log" >&2; exit 1; }
    ninja -C "$DIR/build" expand_all_instantiations > "$DIR/expand.log" 2>&1
    T0=$(date +%s)
    /usr/bin/time -v "$INDEXER" --executor=all-TUs --execute-concurrency="$(nproc)" \
        "$DIR/build/compile_commands.json" > "$DIR/dealii.dex.part" 2> "$DIR/indexer.log"
    mv "$DIR/dealii.dex.part" "$DIR/dealii.dex"
    echo "deal.II index: $(( $(date +%s) - T0 )) s, $(du -m "$DIR/dealii.dex" | cut -f1) MB, \
peak $(awk '/Maximum resident/ {print int($6/1024)}' "$DIR/indexer.log") MB" >> "$LOG"
else
    echo "deal.II index: reused $DIR/dealii.dex" >> "$LOG"
fi
mkdir -p "$DIR/xdg/clangd"
# MountPoint is required in a user config; "/" applies the index to every file.
printf 'Index:\n  External:\n    File: %s\n    MountPoint: /\n' "$DIR/dealii.dex" \
    > "$DIR/xdg/clangd/config.yaml"
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s10: configure failed, see $WORK/configure.log" >&2; exit 1; }
session() {  # clangd xdg mode label
    S10_ROOT=$WORK S10_SOURCE=$SOURCE S10_OUT=$LOG S10_CLANGD=$1 S10_XDG=$2 S10_MODE=$3 \
        S10_LABEL=$4 S10_NAMES=$NAMES \
        emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
        -l "$HERE/s10.el" > "$WORK/s10-$4.out" 2>&1 \
        || echo "s10: session $4 failed, see $WORK/s10-$4.out" >> "$LOG"
}
session clangd "" index index
session clangd "" measure system
session clangd "$DIR/xdg" measure system+dealii
session "$PATCHED" "" measure patched
session "$PATCHED" "$DIR/xdg" measure patched+dealii
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
