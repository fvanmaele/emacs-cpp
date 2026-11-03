#!/bin/sh
# S20, eglot's share (D-153): the fswatch-shown reverter with eglot and the patched
# clangd on a clone of RMO-drafts, against the same run with no server.
#   sh spikes/s20-fswatch-reverter/eglot-share.sh [CLONE]   (default under TMPDIR)
# Spike code, never promoted. Makes the clone once (kept for reruns, removed by hand)
# from ~/source/repos/RMO-drafts without touching that tree: fmt from its checkout, no
# network; preset mac-debug configured; branch s20-base at its HEAD and s20-shift
# with 19 lines in front of every tracked file under src/ and include/. Then one
# batch Emacs per mode: eglot (judged), no-eglot (contrast). The log is
# spikes/s20-fswatch-reverter/eglot-share.log. The Mac only (deal.II.app).
set -eu
LC_ALL=C
export LC_ALL
here=$(cd "$(dirname "$0")" && pwd)
src=${S20_RMO:-$HOME/source/repos/RMO-drafts}
clone=${1:-${TMPDIR:-/tmp}/s20-rmo}
log=$here/eglot-share.log
EMACS=${EMACS:-emacs}
fsw=${S20_FSWATCH:-$HOME/opt/fswatch-no-loss/bin/fswatch}
clangd=${S20_CLANGD:-$HOME/opt/clangd-index-nav/bin/clangd}
[ "$(uname -s)" = Darwin ] || { echo "s20: eglot-share runs on the Mac (preset mac-debug)" >&2; exit 1; }
[ -x "$fsw" ] || { echo "s20: no patched fswatch at $fsw (D-109)" >&2; exit 1; }
[ -x "$clangd" ] || { echo "s20: no patched clangd at $clangd (D-026)" >&2; exit 1; }
if [ ! -d "$clone" ]; then
    git clone -q "$src" "$clone"
    git -C "$clone" config submodule.fmt.url "$src/fmt"
    git -C "$clone" -c protocol.file.allow=always submodule update -q --init
    ln -s CMakePresets.darwin.json "$clone/CMakePresets.json"
    (cd "$clone" && cmake --preset mac-debug >/dev/null)
    git -C "$clone" checkout -q -b s20-base
    git -C "$clone" checkout -q -b s20-shift
    git -C "$clone" ls-files src include | while read -r f; do
        {
            i=0
            while [ "$i" -lt 19 ]; do echo "// s20 shift $i"; i=$((i + 1)); done
            cat "$clone/$f"
        } > "$clone/$f.s20"
        mv "$clone/$f.s20" "$clone/$f"
    done
    git -C "$clone" -c user.name=s20 -c user.email=s20@invalid commit -q -a -m "s20 shift"
fi
# macOS deletes TMPDIR files unused for 3 days and keeps the directories.
git -C "$clone" rev-parse -q --verify s20-shift >/dev/null || {
    echo "s20: $clone is not the spike's clone (emptied?); remove it and rerun" >&2
    exit 1
}
git -C "$clone" checkout -q s20-base
diff_hl=$(cd "$here/../../lib/diff-hl" && pwd)
out=$(mktemp "${TMPDIR:-/tmp}/s20-out.XXXXXX")
trap 'rm -f "$out"' EXIT
{
    echo "S20 eglot-share $(date -u +%Y-%m-%dT%H:%M:%SZ), $(uname -s) $(uname -m), $("$EMACS" --version | head -1)"
    echo "source: $src at $(git -C "$src" rev-parse --short HEAD); clangd: $("$clangd" --version | head -1)"
    echo "load: $(sysctl -n vm.loadavg | tr -d '{}')"
} | tee "$log"
status=0
for mode in ${S20_MODES:-eglot no-eglot}; do
    : > "$out"
    S20_ROOT=$clone S20_MODE=$mode S20_FSWATCH=$fsw S20_CLANGD=$clangd S20_OUT=$out \
        S20_DIFF_HL=$diff_hl "$EMACS" -Q --batch -l "$here/eglot-share.el" </dev/null ||
        status=$?
    { echo; cat "$out"; } | tee -a "$log"
    [ "$status" -eq 0 ] || { echo "s20: $mode failed ($status)" | tee -a "$log"; exit "$status"; }
done
