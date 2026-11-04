#!/bin/sh
# S20 probes (0120). Spike code, never promoted.
#   PROBE=trace|dedupe|none sh spikes/s20-fswatch-reverter/probe/run-probe.sh
# One batch run of mode shipped (MODE to change) with probe/$PROBE.el loaded before
# s20-run.el, the environment as run.sh's; prints the run's checkout lines and the
# probe's output. Needs run.sh's generated repository (one run of run.sh first).
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
p=$here/probe
probe=${PROBE:-trace}
out=$(mktemp "${TMPDIR:-/tmp}/s20-probe.XXXXXX"); tr=$(mktemp "${TMPDIR:-/tmp}/s20-trace.XXXXXX")
trap 'rm -f "$out" "$tr"' EXIT
if [ "$(uname -s)" = Darwin ]; then fsw=${S20_FSWATCH:-$HOME/opt/fswatch-no-loss/bin/fswatch}
else fsw=${S20_FSWATCH:-/opt/fswatch-no-loss/bin/fswatch}; fi
load=""
[ "$probe" = none ] || load="-l $p/$probe.el"
# shellcheck disable=SC2086
S20_ROOT=${TMPDIR:-/tmp}/s20-repo S20_MODE=${MODE:-shipped} S20_FSWATCH=$fsw \
  S20_OUT="$out" S20_DIFF_HL="$here/../../lib/diff-hl" TR_OUT="$tr" \
  "${EMACS:-emacs}" -Q --batch $load -l "$here/s20-run.el" </dev/null >/dev/null 2>&1
grep -E "^checkout|filter:|revert queue" "$out"
cat "$tr"
