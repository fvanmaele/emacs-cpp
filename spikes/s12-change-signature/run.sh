#!/bin/sh
# S12 change signature, against the pass criteria in RUN.md.
#   sh spikes/s12-change-signature/run.sh [files]
# Generates the project (gen_project.py, FILES calling files, default 24) in
# $S12_WORK/project (default ~/.cache/emacs-cpp-s12; not under /tmp on macOS, see
# RESULTS.md: a symlink in the path loses the index's cross-file references), commits it to a fresh git
# repository there, builds it and keeps the test output as the baseline.  Then for
# each of 9 operations (add / reorder / remove on calc::combine, Meter::adjust,
# calc::weigh) on a fresh copy: configure the debug preset, one batch Emacs session
# with the shipped config (changesig.el) running "Change signature" through
# `eglot-code-actions', then build, run the tests and compare with the baseline.
# Uses $S12_CLANGD (default build.sh's /tmp/s12/clangd/build/bin/clangd).  Writes results.log
# next to this script, never over one; each copy's diff in $S12_WORK/runs/OP.diff.
set -eu
FILES=${1:-24}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
WORK=${S12_WORK:-$HOME/.cache/emacs-cpp-s12}
mkdir -p "$WORK"
CLANGD=${S12_CLANGD:-${S12_BUILD:-/tmp/s12}/clangd/build/bin/clangd}
LOG=${S12_LOG:-$HERE/results.log}
case $LOG in /*) ;; *) LOG=$PWD/$LOG ;; esac  # the Emacs sessions run elsewhere
die() { echo "s12: $*" >&2; exit 1; }
[ -x "$CLANGD" ] || die "no clangd at $CLANGD; run build.sh first"
[ -e "$LOG" ] && die "$LOG exists; move it away first"
[ -e "$WORK/project" ] && die "$WORK/project exists; remove it first"
[ -e "$WORK/runs" ] && die "$WORK/runs exists; remove it first"
python3 -I "$HERE/gen_project.py" "$WORK/project" "$FILES"
( cd "$WORK/project" && git init -q && git add -A && git -c user.name=s12 \
      -c user.email=s12@localhost commit -qm generated \
  && cmake --preset debug > configure.log 2>&1 && cmake --build build/debug > build.log 2>&1 \
  && ./build/debug/calc_tests > "$WORK/baseline.out" ) \
    || die "the generated project does not build, see $WORK/project/*.log"
{ echo "# S12 run $(date '+%Y-%m-%dT%H:%M:%S') on $(uname -sm), generated project, $FILES calling files"
  echo "clangd: $CLANGD ($("$CLANGD" --version | head -n 1))"
  echo "calls in the project: combine $(grep -o 'combine(' "$WORK"/project/src/use_*.cpp | wc -l | tr -d ' ')," \
       "adjust $(grep -o 'adjust(' "$WORK"/project/src/use_*.cpp | wc -l | tr -d ' ')," \
       "weigh $(grep -o 'weigh' "$WORK"/project/src/use_*.cpp | wc -l | tr -d ' ') (text matches, overloads and templates included)"
} > "$LOG"
mkdir -p "$WORK/runs"
run() {  # op file search name input
    dir=$WORK/runs/$1
    rsync -a --exclude build "$WORK/project/" "$dir/"
    ( cd "$dir" && cmake --preset debug > configure.log 2>&1 ) || die "$1: configure failed"
    S12_ROOT=$dir S12_OUT=$LOG S12_CLANGD=$CLANGD S12_OP=$1 S12_FILE=$2 S12_SEARCH=$3 \
        S12_NAME=$4 S12_INPUT=$5 \
        emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
        -l "$HERE/changesig.el" > "$WORK/runs/$1.emacs.out" 2>&1 \
        || { echo "$1: FAIL emacs session failed, see $WORK/runs/$1.emacs.out" >> "$LOG"; return; }
    ( cd "$dir" && git diff > "$WORK/runs/$1.diff" )
    [ -s "$WORK/runs/$1.diff" ] || { echo "$1: FAIL nothing edited" >> "$LOG"; return; }
    echo "$1: diff $(cd "$dir" && git diff --shortstat)" >> "$LOG"
    if ( cd "$dir" && cmake --build build/debug > build.log 2>&1 ); then
        if ( cd "$dir" && ./build/debug/calc_tests > tests.out 2>&1 ) \
           && cmp -s "$dir/tests.out" "$WORK/baseline.out"; then
            echo "$1: builds, tests pass (output equals the baseline)" >> "$LOG"
        else
            echo "$1: builds, TESTS FAIL (see $dir/tests.out)" >> "$LOG"
        fi
    else
        echo "$1: BUILD FAILS: $(grep -c 'error:' "$dir/build.log") errors, first:" >> "$LOG"
        grep 'error:' "$dir/build.log" | head -3 | sed "s|$dir/|  |" >> "$LOG"
    fi
}
run combine-add src/combine.cpp 'int combine(int base' combine '(base, scale, int extra = 7, offset, tag)'
run combine-reorder src/combine.cpp 'int combine(int base' combine '(scale, base, offset, tag)'
run combine-remove src/combine.cpp 'int combine(int base' combine '(base, scale, offset)'
run adjust-add src/meter.cpp 'int Meter::adjust(' adjust '(delta, times, clamp, reserved, int extra = 7)'
run adjust-reorder src/meter.cpp 'int Meter::adjust(' adjust '(times, delta, clamp, reserved)'
run adjust-remove src/meter.cpp 'int Meter::adjust(' adjust '(delta, times, clamp)'
run weigh-add include/calc/api.h 'T weigh(' weigh '(value, factor, int extra = 7, shift, unused)'
run weigh-reorder include/calc/api.h 'T weigh(' weigh '(value, shift, factor, unused)'
run weigh-remove include/calc/api.h 'T weigh(' weigh '(value, factor, shift)'
echo "done; see $LOG"
