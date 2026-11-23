#!/bin/sh
# Three first-M-. timings after a restart (firstnav.py), for H-42 on Arch.
# Usage: sh run3.sh CLANGD COMPILE_COMMANDS_JSON
# Session 1 indexes once (work/arch); the second and third runs reuse its index.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
[ -x "$1" ] || { echo "run3: no clangd at $1" >&2; exit 1; }
[ -f "$2" ] || { echo "run3: no compile_commands.json at $2" >&2; exit 1; }
[ -e "$here/work/arch" ] && { echo "run3: $here/work/arch exists; remove it first" >&2; exit 1; }
for i in 1 2 3; do
    S23_CDB=$2 python3 -I "$here/firstnav.py" arch "$1" "$here/work" </dev/null
done
