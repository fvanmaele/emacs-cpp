#!/bin/sh
# S23 reproduce: session s3 again, N times, on a work directory run.sh left.
# Usage: sh rerun.sh CASE LABEL N
here=$(cd "$(dirname "$0")" && pwd)
i=1
while [ "$i" -le "$3" ]; do
  python3 -I "$here/freshness.py" "$1" "$2" "$here" rerun "$i" </dev/null
  i=$((i + 1))
done
