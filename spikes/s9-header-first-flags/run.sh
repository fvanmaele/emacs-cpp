#!/bin/sh
# S9 compile command of a header opened first (O-21).  Owner runs:
#   sh spikes/s9-header-first-flags/run.sh [project-dir] [header] [source] [runs]
# Copies the project to $S9_WORK (default /tmp/s9/work/<name>; three levels deep, see
# S1), configures the debug preset, builds clangd's index once (index session), then
# RUNS times each (default 5, alternating): a fresh session that opens HEADER first,
# and one that opens SOURCE first and HEADER once SOURCE's parse has started.  Uses the
# patched clangd ($S9_CLANGD, default /opt/clangd-index-nav/bin/clangd).  Never writes
# to the project.  Writes results.log next to this script, never over one.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
HEADER=${2:-include/rmo/gpe/iteration.h}
SOURCE=${3:-src/main.cc}
RUNS=${4:-5}
CLANGD=${S9_CLANGD:-/opt/clangd-index-nav/bin/clangd}
WORK=${S9_WORK:-/tmp/s9/work/$(basename "$SRC")}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S9_LOG:-$HERE/results.log}
[ -x "$CLANGD" ] || { echo "s9: no clangd at $CLANGD" >&2; exit 1; }
"$CLANGD" --help-hidden | grep -q header-flags-from-index \
    || { echo "s9: $CLANGD lacks --header-flags-from-index (pkgrel 3)" >&2; exit 1; }
[ -d "$SRC" ] || { echo "s9: no project at $SRC" >&2; exit 1; }
[ -f "$SRC/$HEADER" ] || { echo "s9: no $HEADER in $SRC" >&2; exit 1; }
[ -f "$SRC/$SOURCE" ] || { echo "s9: no $SOURCE in $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s9: $WORK exists; remove it first" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s9: $LOG exists; move it away first" >&2; exit 1; }
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s9: configure failed, see $WORK/configure.log" >&2; exit 1; }
{ echo "# S9 run $(date -Iseconds) on copy of $SRC; header $HEADER, source $SOURCE"
  echo "clangd: $CLANGD ($("$CLANGD" --version | head -n 1))"
  echo "includers of the header in the database's sources:"
  grep -rl "$(basename "$(dirname "$HEADER")")/$(basename "$HEADER")" "$WORK" \
       --include='*.cc' --include='*.cpp' 2>/dev/null | sed "s|$WORK/|  |" | head -5
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
session() {  # mode run
    S9_ROOT=$WORK S9_OUT=$LOG S9_CLANGD=$CLANGD S9_HEADER=$HEADER S9_SOURCE=$SOURCE \
        S9_MODE=$1 S9_RUN=$2 \
        emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
        -l "$HERE/headerfirst.el" > "$WORK/s9-$1-$2.out" 2>&1 \
        || echo "s9: session $1 $2 failed, see $WORK/s9-$1-$2.out" >> "$LOG"
}
session index 0
i=1
while [ "$i" -le "$RUNS" ]; do
    session header-first "$i"
    session source-first "$i"
    i=$((i + 1))
done
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
