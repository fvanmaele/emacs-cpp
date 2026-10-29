#!/bin/sh
# S20 (T-128, D-147): one fswatch per project root reverting unedited buffers.
#   sh spikes/s20-fswatch-reverter/run.sh [REPO]     (default a repository under TMPDIR)
# Spike code, never promoted. Generates the repository once (2000 directories, 20000
# files, 190 changed between branches a and b; kept for reruns, removed by hand), then
# one batch Emacs per mode: fswatch-queued (judged); fswatch, fswatch-novc and poll
# (D-147's Mac setting) for contrast.
# Prints the blocks; the log is spikes/s20-fswatch-reverter/s20.log. Run on an idle
# machine.
set -eu
LC_ALL=C
export LC_ALL
here=$(cd "$(dirname "$0")" && pwd)
repo=${1:-${TMPDIR:-/tmp}/s20-repo}
log=$here/s20.log
EMACS=${EMACS:-emacs}
if [ "$(uname -s)" = Darwin ]; then fsw=${S20_FSWATCH:-$HOME/opt/fswatch-no-loss/bin/fswatch}
else fsw=${S20_FSWATCH:-/opt/fswatch-no-loss/bin/fswatch}; fi
[ -x "$fsw" ] || { echo "s20: no patched fswatch at $fsw (D-109)" >&2; exit 1; }
if [ ! -d "$repo" ]; then
    python3 -I "$here/gen_repo.py" "$repo"
fi
out=$(mktemp "${TMPDIR:-/tmp}/s20-out.XXXXXX")
trap 'rm -f "$out"' EXIT
{
    echo "S20 run $(date -u +%Y-%m-%dT%H:%M:%SZ), $(uname -s) $(uname -m), $("$EMACS" --version | head -1)"
    if [ -r /proc/loadavg ]; then echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
    else echo "load: $(sysctl -n vm.loadavg | tr -d '{}')"; fi
} | tee "$log"
for mode in ${S20_MODES:-fswatch-queued fswatch fswatch-novc poll}; do
    : > "$out"
    S20_ROOT=$repo S20_MODE=$mode S20_FSWATCH=$fsw S20_OUT=$out \
        "$EMACS" -Q --batch -l "$here/s20-run.el" </dev/null
    { echo; cat "$out"; } | tee -a "$log"
done
