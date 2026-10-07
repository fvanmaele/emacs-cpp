#!/bin/sh
# S1 compile-db discovery. Owner runs: sh spikes/s1-compile-db/run.sh [project-dir]
# Works on a copy under $S1_WORK (default /tmp/s1/work/rmo); never writes to the project.
# The copy must sit at least three levels deep: the project's find_package(deal.II HINTS
# ../ ../../) would otherwise reach / and pick /lib/cmake/deal.II via Arch's /lib symlink,
# making deal.II compute its root as / (configure fails, macros not found).
# Writes results.log next to this script. Spike code: never promoted into the config.
set -eu
SRC=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
WORK=${S1_WORK:-/tmp/s1/work/rmo}
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=$HERE/results.log
QD=--query-driver=/usr/bin/c++,/usr/bin/g++

[ -d "$SRC" ] || { echo "s1: no project at $SRC" >&2; exit 1; }
[ -e "$WORK" ] && { echo "s1: $WORK exists; remove it first" >&2; exit 1; }

mkdir -p "$(dirname "$WORK")"
rsync -a --exclude build-release --exclude build "$SRC"/ "$WORK"/
cp "$HERE/CMakePresets.json" "$WORK/"
cd "$WORK"
HEADER=$(find include -name '*.h' | sort | head -n 1)
: > "$LOG"
say() { printf '%s\n' "$*" | tee -a "$LOG"; }

say "# S1 run $(date -Iseconds) on copy of $SRC"
say "clangd: $(clangd --version | head -n 1)"
cmake --preset debug > configure.log 2>&1 \
    || { say "configure FAILED, see $WORK/configure.log"; exit 1; }
say "configure debug: ok; entries: $(grep -c '"file"' build/debug/compile_commands.json)"

# check VARIANT FILE ARGS...: one clangd --check, summarised; full output kept in WORK.
check() {
    variant=$1; file=$2; shift 2
    out="$WORK/check-$variant-$(basename "$file").log"
    python3 -I -c '
import resource, subprocess, sys, time
t = time.monotonic()
with open(sys.argv[1], "w") as f:
    subprocess.run(sys.argv[2:], stdout=f, stderr=subprocess.STDOUT)
r = resource.getrusage(resource.RUSAGE_CHILDREN)
print("elapsed %.1f s, max RSS %d MB" % (time.monotonic() - t, r.ru_maxrss // 1024))
' "$out" clangd --check="$file" "$@" > "$out.time"
    say "## $variant $file ($*)"
    say "  $(cat "$out.time")"
    say "  db: $(grep -Eo 'Loaded compilation database from .*|Failed to find compilation database' "$out" | head -n 1)"
    say "  not found: $(grep -c 'file not found' "$out" || true)"
    say "  $(grep -Eo 'All checks completed, [0-9]+ errors' "$out" || echo 'no completion line')"
}

for f in src/main.cc "$HEADER"; do
    check A-none "$f" "$QD"
    printf 'CompileFlags:\n  CompilationDatabase: build/debug\n' > .clangd
    check B-dotclangd "$f" "$QD"
    rm .clangd
    ln -s build/debug/compile_commands.json compile_commands.json
    check C-symlink "$f" "$QD"
    rm compile_commands.json
    check D-argument "$f" "$QD" --compile-commands-dir=build/debug
    check E-argument-no-query-driver "$f" --compile-commands-dir=build/debug
done
say "done; full clangd logs in $WORK/check-*.log"
