#!/bin/sh
# S20 probe (0120): in a terminal Emacs, do self-arming 50 ms timer steps (0.01 s
# apart) leave gaps in which process output and typed keys are handled? Spike code,
# never promoted. Linux script(1) only.  TS_START (default 0.4 s) aligns the steps
# with keys.sh's typing.
#   sh spikes/s20-fswatch-reverter/probe/tstep.sh
set -eu
p=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp "${TMPDIR:-/tmp}/s20-tstep.XXXXXX")
trap 'rm -f "$out"' EXIT
sh "$p/keys.sh" | TS_START=${TS_START:-0.4} TS_OUT=$out TERM=xterm-256color \
  script -q -e -c "\"${EMACS:-emacs}\" -Q -nw -l \"$p/tstep.el\"" /dev/null >/dev/null
cat "$out"
