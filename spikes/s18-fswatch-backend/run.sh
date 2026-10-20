#!/bin/sh
# S18 (D-127): the fswatch backend against Emacs's own watches on an LLVM-sized tree.
#   sh spikes/s18-fswatch-backend/run.sh [N] [TREE]     (defaults 20000, a tree under TMPDIR)
# Spike code, never promoted. Generates the tree once (15408 directories, 187395 files,
# RESEARCH_platform_differences 3.12; kept for reruns, removed by hand), then one
# interactive `emacs -nw -Q` per run in a private tmux server with a throwaway HOME:
# baseline, eglot and regexp against the fake server, then regexp against pyright.
# Prints the blocks; the log is spikes/s18-fswatch-backend/s18.log. Run on an idle machine.
set -eu
LC_ALL=C
export LC_ALL
here=$(cd "$(dirname "$0")" && pwd)
N=${1:-20000}
tree=${2:-${TMPDIR:-/tmp}/s18-tree}
log=$here/s18.log
EMACS=${EMACS:-emacs}
command -v tmux > /dev/null || { echo "s18: tmux is not on PATH" >&2; exit 1; }
# The runs get a throwaway HOME, so the patched fswatch is named here, absolute.
if [ "$(uname -s)" = Darwin ]; then fsw=${S18_FSWATCH:-$HOME/opt/fswatch-no-loss/bin/fswatch}
else fsw=${S18_FSWATCH:-/opt/fswatch-no-loss/bin/fswatch}; fi
[ -x "$fsw" ] || { echo "s18: no patched fswatch at $fsw (D-109)" >&2; exit 1; }
if [ ! -d "$tree" ]; then
    python3 -I "$here/gen_tree.py" "$tree"
fi
home=$(mktemp -d "${TMPDIR:-/tmp}/s18-home.XXXXXX")
sock=s18-$$
trap 'tmux -L "$sock" kill-server 2>/dev/null || true; rm -rf "$home"' EXIT
out=$home/out
{
    echo "S18 run $(date -u +%Y-%m-%dT%H:%M:%SZ), $(uname -s) $(uname -m), $("$EMACS" --version | head -1)"
    echo "tree: $(find "$tree" -type d -not -path '*/.git*' | wc -l | tr -d ' ') directories, $(find "$tree" -type f -not -path '*/.git/*' | wc -l | tr -d ' ') files"
    if [ -r /proc/loadavg ]; then echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
    else echo "load: $(sysctl -n vm.loadavg | tr -d '{}')"; fi
} | tee "$log"
# S18_RUNS: which runs, MODE:SERVER, comma-separated (default all four).
runs=${S18_RUNS:-baseline:fake,eglot:fake,regexp:fake,regexp:pyright}
for run in $(echo "$runs" | tr ',' ' '); do
    set -- "${run%%:*}" "${run#*:}"
    rm -f "$out"
    tmux -L "$sock" new-session -d -s s18 -x 120 -y 40 \
        "env HOME=$home S18_FSWATCH=$fsw S18_ROOT=$tree S18_MODE=$1 S18_SERVER=$2 S18_N=$N S18_OUT=$out $EMACS -nw -Q -l $here/s18-run.el"
    while tmux -L "$sock" has-session -t s18 2>/dev/null; do sleep 1; done
    { echo; cat "$out" 2>/dev/null || echo "s18: run $1 $2 wrote nothing"; } | tee -a "$log"
done
