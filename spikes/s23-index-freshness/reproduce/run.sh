#!/bin/sh
# S23 reproduce: every case with every clangd. Output in this directory:
# logs/CASE-LABEL-s{1,2,3}.log, logs/CASE-LABEL.json, $OUT (default summary.txt).
set -e
here=$(cd "$(dirname "$0")" && pwd)
cases=${CASES:-"header_disk header_unsaved header_live header_disk_from_header target_moved target_moved_slow header_first_define"}
labels=${LABELS:-"nav noflag upstream"}
out=${OUT:-summary.txt}; : > "$here/$out"
for c in $cases; do
  for l in $labels; do
    python3 -I "$here/freshness.py" "$c" "$l" "$here" </dev/null >> "$here/$out" 2>&1
  done
done
echo done >> "$here/$out"
