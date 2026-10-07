#!/bin/sh
# S5 preamble warm-up.  Owner runs: sh spikes/s5-preamble-warmup/run.sh [project-dir]
# Copies the project to $S5_WORK (default /tmp/s5/work/rmo; three levels deep, see S1),
# configures the active preset's default, and measures with the shipped config in a
# batch Emacs.  Never writes to the project.  Writes results.log next to this script.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
WORK=${S5_WORK:-/tmp/s5/work/rmo}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S5_LOG:-$HERE/results.log}
[ -e "$LOG" ] && { echo "s5: $LOG exists; move it away first" >&2; exit 1; }
[ -d "$SRC" ] || { echo "s5: no project at $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s5: $WORK exists; remove it first" >&2; exit 1; }
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s5: configure failed, see $WORK/configure.log" >&2; exit 1; }
{ echo "# S5 run $(date -Iseconds) on copy of $SRC"
  echo "clangd: $(clangd --version | head -n 1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)  free: $(free -g | awk '/Mem:/ {print $7}') GB available"; } > "$LOG"
S5_ROOT=$WORK S5_OUT=$LOG emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
    -l "$HERE/warmup.el"
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
