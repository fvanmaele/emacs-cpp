#!/bin/sh
# S8 clangd navigation from the index.  Owner runs:
#   sh spikes/s8-clangd-index-navigation/run.sh [project-dir] [patched-clangd]
# Copies the project to $S8_WORK (default /tmp/s8/work/rmo; three levels deep, see S1),
# configures the default preset, and for each clangd (system, patched + flag) runs two
# sessions: session 1 builds the index, session 2 times the first M-. after a restart.
# Never writes to the project.  Writes results.log next to this script, never over one.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
PATCHED=${2:-$HOME/source/repos/llvm-clangd/build/bin/clangd}
WORK=${S8_WORK:-/tmp/s8/work/rmo}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S8_LOG:-$HERE/results.log}
[ -x "$PATCHED" ] || { echo "s8: no patched clangd at $PATCHED" >&2; exit 1; }
"$PATCHED" --help-hidden | grep -q navigation-from-index \
    || { echo "s8: $PATCHED lacks --navigation-from-index" >&2; exit 1; }
[ -d "$SRC" ] || { echo "s8: no project at $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s8: $WORK exists; remove it first" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s8: $LOG exists; move it away first" >&2; exit 1; }
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s8: configure failed, see $WORK/configure.log" >&2; exit 1; }
{ echo "# S8 run $(date -Iseconds) on copy of $SRC"
  echo "system: $(clangd --version | head -n 1)"
  echo "patched: $("$PATCHED" --version | head -n 1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
BUILD=$(cd "$WORK" && sed -n 's/.*"binaryDir": *"\${sourceDir}\/\([^"]*\)\${presetName}".*/\1debug/p' CMakePresets.json | head -n 1)
for variant in "$(command -v clangd)|" "$PATCHED|--navigation-from-index"; do
    rm -rf "$WORK/${BUILD:-build/debug}/.cache"
    CLANGD=${variant%%|*} FLAGS=${variant#*|} S8_ROOT=$WORK S8_OUT=$LOG \
        emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
        -l "$HERE/navtime.el" > /dev/null 2>&1 || echo "s8: a session failed" >> "$LOG"
done
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
