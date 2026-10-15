#!/bin/bash
# S14 run: baseline and spike clangd on the same project, then compare.py.
#   bash spikes/s14-symbol-matches/run.sh [PROJECT] [PRESET_DIR] [OPENED]
# Spike code, never promoted.  Defaults: ~/CLionProjects/step-1, its build/mac-debug,
# src/main.cc.  The build directory (compile database and clangd's index shards) is
# cloned into $S14_BUILD/run (APFS clonefile, no copy), afresh for each run, and
# clangd reads the database there, so its index is loaded and written there: the
# project itself is only read.  Baseline: the installed ~/opt/clangd-index-nav/bin/clangd (23.1.3,
# patches 0001 - 0009); spike: $S14_BUILD/build/bin/clangd from build.sh.  Results:
# $S14_BUILD/baseline.jsonl, spike.jsonl, baseline2.jsonl (the baseline again, for the
# order of equally scored symbols) and compare.py's verdict on standard output.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=${S14_BUILD:-$HOME/.cache/emacs-cpp-s14}
project=${1:-$HOME/CLionProjects/step-1}
preset=${2:-$project/build/mac-debug}
opened=${3:-$project/src/main.cc}
baseline=${S14_BASELINE:-$HOME/opt/clangd-index-nav/bin/clangd}
spike=$work/build/bin/clangd
die() { printf 's14 run: %s\n' "$*" >&2; exit 1; }
[ -x "$baseline" ] || die "no baseline clangd at $baseline"
[ -x "$spike" ] || die "no spike clangd at $spike; run build.sh"
[ -f "$preset/compile_commands.json" ] || die "no compile_commands.json in $preset"
[ -f "$opened" ] || die "no file $opened"
run=$work/run
# Builtin headers for the spike binary, found relative to it, as in ~/opt.
[ -e "$work/build/lib/clang" ] || die "spike build lacks lib/clang; rerun build.sh"
for which in baseline spike baseline2; do
    bin=$baseline
    [ "$which" = spike ] && bin=$spike
    echo "== $which: $bin"
    # A fresh clone for each run: a run that indexes writes shards, which the next
    # would load (dry run 2: the baseline then agreed with itself in 17 of 40).
    rm -rf "$run"
    mkdir -p "$run"
    cp -c -R "$preset" "$run/db"
    python3 -I "$here/client.py" "$bin" "$run/db" "$opened" "$work/$which.jsonl"
done
python3 -I "$here/compare.py" "$work/baseline.jsonl" "$work/spike.jsonl" \
    "$work/baseline2.jsonl"
