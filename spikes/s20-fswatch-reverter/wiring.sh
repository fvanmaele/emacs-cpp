#!/bin/sh
# S20 criterion 7 (D-153): does `window-buffer-change-functions' run after the ways a
# buffer gets shown?  Batch Emacs runs no window change functions, so this runs a
# terminal Emacs under script(1) and prints wiring.el's lines.
#   sh spikes/s20-fswatch-reverter/wiring.sh
# Spike code, never promoted.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
EMACS=${EMACS:-emacs}
out=$(mktemp "${TMPDIR:-/tmp}/s20-wiring.XXXXXX")
trap 'rm -f "$out"' EXIT
export S20_OUT="$out"
status=0
if [ "$(uname -s)" = Darwin ]; then
    TERM=xterm-256color script -q /dev/null "$EMACS" -Q -nw -l "$here/wiring.el" \
        </dev/null >/dev/null || status=$?
else
    TERM=xterm-256color script -q -e -c "\"$EMACS\" -Q -nw -l \"$here/wiring.el\"" \
        /dev/null </dev/null >/dev/null || status=$?
fi
cat "$out"
exit "$status"
