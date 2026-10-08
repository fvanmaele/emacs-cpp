#!/bin/sh
# measure-startup.sh - startup time of this configuration (DESIGN 11, T-008).
#   sh scripts/measure-startup.sh [runs] [elisp]
# Starts `emacs -nw` in a detached tmux session with a throwaway HOME whose .emacs.d
# holds only the two symlinks (D-003), RUNS times (default 10). Each run prints the
# seconds from `before-init-time' to the end of `after-init-hook' (an --eval runs right
# after that hook), the garbage collections done and their seconds. ELISP, if given, is
# evaluated in early-init.el before the repository's (a variant to compare). A first,
# unmeasured start waits until native compilation of all loaded files has finished, as
# in a used ~/.emacs.d. Never touches ~/.emacs.d. Run on an idle machine.
set -eu
RUNS=${1:-10}
EXTRA=${2:-}
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
# A private tmux server (-L): a running one would hand the session its own
# environment, so HOME would be the real one and ~/.emacs.d would be used.
TMUX_SOCKET=measure-$$
trap 'tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.emacs.d"
ln -s "$REPO/init.el" "$WORK/.emacs.d/init.el"
if [ -n "$EXTRA" ]; then
    printf '%s\n(load "%s/early-init.el" nil t)\n' "$EXTRA" "$REPO" \
        > "$WORK/.emacs.d/early-init.el"
else
    ln -s "$REPO/early-init.el" "$WORK/.emacs.d/early-init.el"
fi
OUT=$WORK/times
start() {  # elisp to evaluate after after-init-hook
    printf '%s\n' "$1" > "$WORK/eval.el"
    tmux -L "$TMUX_SOCKET" new-session -d -s measure -x 120 -y 40 \
        "env HOME=$WORK emacs -nw -l $WORK/eval.el"
    while tmux -L "$TMUX_SOCKET" has-session -t measure 2>/dev/null; do sleep 0.2; done
}
# Warm-up: stay until the native compiler's queue is empty.
start '(progn (require (quote comp-run))
  (while (or comp-files-queue (> (comp--async-runnings) 0)) (sleep-for 1))
  (kill-emacs))'
i=0
while [ "$i" -lt "$RUNS" ]; do
    start "(progn (write-region (format \"%.3f %d %.3f\\n\"
      (float-time (time-subtract (current-time) before-init-time)) gcs-done gc-elapsed)
      nil \"$OUT\" t) (kill-emacs))"
    i=$((i + 1))
done
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "seconds gcs gc-seconds"
cat "$OUT"
sort -n "$OUT" | awk '{ t[NR] = $1 } END { printf "median %.3f s, min %.3f, max %.3f\n",
    (NR % 2 ? t[(NR + 1) / 2] : (t[NR / 2] + t[NR / 2 + 1]) / 2), t[1], t[NR] }'
