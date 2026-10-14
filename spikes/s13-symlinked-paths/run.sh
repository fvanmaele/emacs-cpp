#!/bin/bash
# S13 runs: references to calc::combine with a project reached through a symlink.
#   bash spikes/s13-symlinked-paths/run.sh CLANGD [LABEL]
# Spike code, never promoted.  Generates S12's project (24 calling files) twice under
# $S13_BUILD/projects/LABEL (default ~/.cache/emacs-cpp-s13): real/p configured at
# its real path, and linked/p configured through the symlink link -> linked (so the
# compile database spells link/p).  For each: run 1 opens src/combine.cpp on an
# empty index; run 2 restarts and opens it again (shards loaded, nothing should be
# indexed); run 3 restarts and opens include/calc/api.h first (its flags should come
# from an includer, patches 0005 - 0008).  Logs next to the projects.
# Under /tmp on macOS: S13_BUILD=/tmp/s13 (CMake 3.31 writes /tmp, eglot /private/tmp).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
clangd=$1
label=${2:-$(basename "$(dirname "$(dirname "$clangd")")")}
base=${S13_BUILD:-$HOME/.cache/emacs-cpp-s13}/projects/$label
rm -rf "$base"
mkdir -p "$base/linked"
ln -s linked "$base/link"
python3 -I "$repo/spikes/s12-change-signature/gen_project.py" "$base/real/p" 24
python3 -I "$repo/spikes/s12-change-signature/gen_project.py" "$base/linked/p" 24
(cd "$base/real/p" && cmake --preset debug > /dev/null)
(cd "$base/link/p" && cmake --preset debug > /dev/null)
echo "clangd $clangd ($label); cmake $(cmake --version | head -1)"
for case in real link; do
    db=$base/$case/p/build/debug
    printf '%s database: %s\n' "$case" "$(grep -m1 '"file"' "$db/compile_commands.json")"
    for run in 1 2 3; do
        opened=src/combine.cpp
        [ "$run" = 3 ] && opened=include/calc/api.h
        log=$base/$case-run$run.log
        result=$(python3 -I "$here/client.py" "$clangd" "$base/$case/p" "$db" "$log" \
                         "$opened") || result="client failed"
        printf '%s run %s (%s): %s\n' "$case" "$run" "$opened" "$result"
        if [ "$run" = 3 ]; then
            printf '  header flags: %s\n' \
                "$(grep -m1 -o 'Compile command for .*api.h.*' "$log" || echo none)"
        fi
        grep -m1 -o 'Background-index: [0-9]* of .*' "$log" | sed 's/^/  /' || true
    done
done
