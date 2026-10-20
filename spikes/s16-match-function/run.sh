#!/bin/sh
# S16 (D-124): the spec, the agreement and the timings in each compilation state.
#   sh spikes/s16-match-function/run.sh CORPUS-DIR [LOG]     (default LOG: s16.log)
# Spike code, never promoted.  Run on an idle machine; the load is logged.
set -eu
corpus=${1:?usage: run.sh CORPUS-DIR [LOG]}
here=$(cd "$(dirname "$0")" && pwd)
log=${2:-$here/s16.log}
EMACS=${EMACS:-emacs}
{
    echo "S16 run $(date -u +%Y-%m-%dT%H:%M:%SZ); load: $(uptime | sed 's/.*load average[s]*: //')"
    for state in interp byte native; do
        "$EMACS" -Q --batch -l "$here/s16.el" "$corpus" "$state" 2>&1 \
            | grep -v '^Loading\|^Compiling\|already compiled\|^$'
    done
} | tee "$log"
