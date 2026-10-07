#!/bin/sh
# S6 ccls vs clangd.  Owner runs: sh spikes/s6-ccls/run.sh [project-dir]
# Copies the project to $S6_WORK (default /tmp/s6/work/rmo; three levels deep, see S1),
# configures the default preset, and measures with the shipped config in a batch Emacs.
# Never writes to the project.  Writes results.log next to this script, never over one.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
WORK=${S6_WORK:-/tmp/s6/work/rmo}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S6_LOG:-$HERE/results.log}
command -v ccls >/dev/null || { echo "s6: ccls not installed (sudo pacman -S ccls)" >&2; exit 1; }
[ -d "$SRC" ] || { echo "s6: no project at $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s6: $WORK exists; remove it first" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s6: $LOG exists; move it away first" >&2; exit 1; }
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s6: configure failed, see $WORK/configure.log" >&2; exit 1; }
{ echo "# S6 run $(date -Iseconds) on copy of $SRC"
  echo "clangd: $(clangd --version | head -n 1)"
  echo "ccls: $(ccls --version 2>&1 | head -n 1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)  free: $(free -g | awk '/Mem:/ {print $7}') GB available"; } > "$LOG"
S6_ROOT=$WORK S6_OUT=$LOG emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
    -l "$HERE/compare.el"
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
