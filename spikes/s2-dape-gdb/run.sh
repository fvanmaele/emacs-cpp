#!/bin/sh
# S2 dape + gdb DAP on a preset-built binary.  Owner runs:
#   sh spikes/s2-dape-gdb/run.sh [project-dir] [target]
# Copies the project to $S2_WORK (default /tmp/s2/work/rmo; three levels deep, see S1),
# configures and builds the debug preset's TARGET (default main), then runs a plain
# gdb baseline and s2.el for four adapter variants: gdb as dape configures it, gdb with
# deal.II's pretty-printers, the same with shared-library symbols loaded on demand, and
# lldb-dap.  Never writes to the project.  Writes results.log next to this script,
# never over one.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
TARGET=${2:-main}
WORK=${S2_WORK:-/tmp/s2/work/rmo}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S2_LOG:-$HERE/results.log}
DEALII=$HOME/source/repos/dealii
PRINTERS_SRC=${S2_DEALII_PRINTERS:-$DEALII/contrib/utilities/dotgdbinit.py}
SOURCE=${S2_SOURCE:-src/$TARGET.cc}
BREAK=${S2_BREAK:-ProgramOptions opts}
WATCH=${S2_WATCH:-argc}
[ -d "$SRC" ] || { echo "s2: no project at $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s2: $WORK exists; remove it first" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s2: $LOG exists; move it away first" >&2; exit 1; }
command -v gdb > /dev/null || { echo "s2: gdb not found" >&2; exit 1; }
mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
( cd "$WORK" && cmake --preset debug > configure.log 2>&1 ) \
    || { echo "s2: configure failed, see $WORK/configure.log" >&2; exit 1; }
BUILD=$(cd "$WORK" \
    && sed -n 's/.*"binaryDir": *"\${sourceDir}\/\([^"]*\)\${presetName}".*/\1debug/p' \
           CMakePresets.json | head -n 1)
BUILD=$WORK/${BUILD:-build/debug}
( cmake --build "$BUILD" --target "$TARGET" > "$WORK/build.log" 2>&1 ) \
    || { echo "s2: build failed, see $WORK/build.log" >&2; exit 1; }
PROGRAM=$BUILD/$TARGET
[ -x "$PROGRAM" ] || { echo "s2: no program at $PROGRAM" >&2; exit 1; }
LINE=$(grep -n -m 1 -- "$BREAK" "$WORK/$SOURCE" | cut -d: -f1)
[ -n "$LINE" ] || { echo "s2: '$BREAK' not found in $SOURCE" >&2; exit 1; }
{ echo "# S2 run $(date -Iseconds) on copy of $SRC, target $TARGET"
  echo "gdb: $(gdb --version | head -n 1)"
  echo "lldb-dap: $(lldb-dap --version 2>/dev/null | head -n 1 || echo missing)"
  echo "dape: $(git -C "$REPO/lib/dape" describe --tags)"
  echo "flags: $(grep -o -- ' -g[^ ]*\| -O[0-9sg]' "$BUILD/compile_commands.json" \
                  | sort | uniq -c | tr -s ' \n' ' ')"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
# Baseline: gdb alone from start to the breakpoint, no DAP, no Emacs.
T0=$(date +%s%N)
( cd "$WORK" && gdb -batch -nx -iex 'set debuginfod enabled off' \
      -ex "break $SOURCE:$LINE" -ex run -ex bt "$PROGRAM" \
      > "$WORK/gdb-baseline.log" 2>&1 ) || true
T1=$(date +%s%N)
STOPS=$(grep -c '^#0' "$WORK/gdb-baseline.log" || true)
echo "gdb alone to $SOURCE:$LINE: $(( (T1 - T0) / 1000000 )) ms ($STOPS stop)" >> "$LOG"
# deal.II's printers are a gdb command script named .py: copy it under a .gdb name.
PRINTERS=$WORK/dealii-printers.gdb
if [ -f "$PRINTERS_SRC" ]; then cp "$PRINTERS_SRC" "$PRINTERS"; else PRINTERS=; fi
N=0
run() {  # adapter, extra arguments separated by |
    N=$((N + 1))
    echo "" >> "$LOG"
    S2_ROOT=$WORK S2_PROGRAM=$PROGRAM S2_SOURCE=$SOURCE S2_BREAK=$BREAK S2_WATCH=$WATCH \
        S2_ADAPTER=$1 S2_ARGS=$2 S2_OUT=$LOG \
        emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
        -l "$HERE/s2.el" > "$WORK/s2-$N-$1.out" 2>&1 \
        || echo "s2: a session failed" >> "$LOG"
}
run gdb "-iex|set debuginfod enabled off"
if [ -n "$PRINTERS" ]; then
    run gdb "-iex|set debuginfod enabled off|-iex|source $PRINTERS"
    run gdb "-iex|set debuginfod enabled off|-iex|source $PRINTERS\
|-iex|set auto-solib-add off"
else
    echo "s2: no deal.II printers at $PRINTERS_SRC; printer variants skipped" >> "$LOG"
fi
if command -v lldb-dap > /dev/null; then run lldb-dap ""; fi
echo "" >> "$LOG"
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
