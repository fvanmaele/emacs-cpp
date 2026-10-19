#!/bin/bash
# S15 run: baseline and spike clangd on the same project, then compare.py.
#   bash spikes/s15-mid-word-rank/run.sh [PROJECT PRESET_DIR OPENED]
# Spike code, never promoted.  Defaults (macOS): ~/CLionProjects/step-1, its
# build/mac-debug, src/main.cc; on Arch the three arguments are required.  The
# build directory (compile database and clangd's index shards) is copied into
# $S15_BUILD/run afresh for each run (a clone where the file system has them), and
# clangd reads the database there, so the project itself is only read.  Baseline:
# the installed patched clangd (pkgrel 8; ~/opt on macOS, /opt on Arch); spike:
# $S15_BUILD/build/bin/clangd from build.sh.  Results: $S15_BUILD/baseline.jsonl,
# spike.jsonl, baseline2.jsonl (the baseline again, for the order of equally
# scored symbols) and compare.py's verdict on standard output.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=${S15_BUILD:-$HOME/.cache/emacs-cpp-s15}
die() { printf 's15 run: %s\n' "$*" >&2; exit 1; }
if [ "$(uname -s)" = Darwin ]; then
    project=${1:-$HOME/CLionProjects/step-1}
    preset=${2:-$project/build/mac-debug}
    opened=${3:-$project/src/main.cc}
    baseline=${S15_BASELINE:-$HOME/opt/clangd-index-nav/bin/clangd}
else
    [ $# -eq 3 ] || die "on Arch give PROJECT PRESET_DIR OPENED (got $#)"
    project=$1 preset=$2 opened=$3
    baseline=${S15_BASELINE:-/opt/clangd-index-nav/bin/clangd}
fi
spike=$work/build/bin/clangd
[ $# -le 3 ] || die "at most 3 arguments: PROJECT PRESET_DIR OPENED (got $#: $*)"
[ -d "$project" ] || die "no project directory $project"
[ -x "$baseline" ] || die "no baseline clangd at $baseline"
[ -x "$spike" ] || die "no spike clangd at $spike; run build.sh"
[ -f "$preset/compile_commands.json" ] || die "no compile_commands.json in $preset"
[ -f "$opened" ] || die "no file $opened"
run=$work/run
for which in baseline spike baseline2; do
    bin=$baseline
    [ "$which" = spike ] && bin=$spike
    echo "== $which: $bin"
    # A fresh copy for each run: a run that indexes writes shards the next would load.
    rm -rf "$run"
    mkdir -p "$run"
    if [ "$(uname -s)" = Darwin ]; then cp -c -R "$preset" "$run/db"
    else cp -a --reflink=auto "$preset" "$run/db"; fi
    python3 -I "$here/client.py" "$bin" "$run/db" "$opened" "$work/$which.jsonl"
done
python3 -I "$here/compare.py" "$work/baseline.jsonl" "$work/spike.jsonl" \
    "$work/baseline2.jsonl"
