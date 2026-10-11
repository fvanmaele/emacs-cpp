#!/bin/sh
# S11 run 2: the go-to-anything prompt (D-077) timed in a terminal Emacs.  Owner runs:
#   sh spikes/s11-go-to-anything/prompt.sh [project-dir] [large-tree] [file]
# Two passes, each a fresh `emacs -nw' in a detached tmux session: the prompt lists
# the project's own files, then the large tree's files (a deal.II-sized stand-in).
# Each pass opens the prompt once per word, types it one key per 300 ms, closes it.
# The project is used in place (its preset and clangd index, as in a daily
# session); nothing is written into it or into ~/.emacs.d.  Writes results-run2.log
# next to this script, never over one.  Run 3: S11_SHIPPED=1 times the shipped
# `emacs-cpp-go-to-anything' (T-049) instead, RMO pass only (the shipped command
# lists the open file's project), into results-run3.log.
set -eu
PROJECT=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
TREE=${2:-$HOME/source/repos/dealii}
FILE=${3:-src/main.cc}
CLANGD=${S11_CLANGD:-/opt/clangd-index-nav/bin/clangd}
EMACS_D=${S11_EMACS_D:-$HOME/.emacs.d}
WORDS=${S11_WORDS:-main vec Tri assemble Sol main vec Tri assemble Sol}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
if [ -n "${S11_SHIPPED:-}" ]; then RUN=3; ROOTS=$PROJECT; else RUN=2; ROOTS="$PROJECT $TREE"; fi
LOG=${S11_LOG:-$HERE/results-run$RUN.log}
command -v tmux > /dev/null || { echo "s11: tmux is not installed" >&2; exit 1; }
[ -x "$CLANGD" ] || { echo "s11: no clangd at $CLANGD" >&2; exit 1; }
[ -f "$PROJECT/CMakePresets.json" ] || { echo "s11: no CMakePresets.json in $PROJECT" >&2; exit 1; }
[ -f "$PROJECT/$FILE" ] || { echo "s11: no $FILE in $PROJECT" >&2; exit 1; }
[ -d "$TREE" ] || { echo "s11: no tree at $TREE" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s11: $LOG exists; move it away first" >&2; exit 1; }
tmux has-session -t s11 2> /dev/null && { echo "s11: tmux session s11 exists" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'tmux kill-session -t s11 2> /dev/null || true; rm -rf "$WORK"' EXIT
if [ -f "$EMACS_D/emacs-cpp-presets.eld" ]; then
    cp "$EMACS_D/emacs-cpp-presets.eld" "$WORK/presets.eld"
fi
{ echo "# S11 run $RUN $(date -Iseconds)"
  echo "project: $PROJECT ($FILE), tree: $TREE"
  echo "clangd: $CLANGD, $("$CLANGD" --version | head -n 1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
for root in $ROOTS; do
    tmux new-session -d -s s11 -x 160 -y 48 \
        "cd '$REPO' && S11_PROJECT='$PROJECT' S11_FILE='$FILE' S11_FILES_ROOT='$root' \
S11_CLANGD='$CLANGD' S11_STATE='$WORK/presets.eld' S11_EMACS_D='$EMACS_D' \
S11_OUT='$LOG' S11_SETTLE='${S11_SETTLE:-20}' S11_SHIPPED='${S11_SHIPPED:-}' \
emacs -nw -Q -L scripts -L lisp -L test -l '$HERE/prompt.el'"
    i=0
    until [ "$(grep -c '^# ready' "$LOG")" -gt "$( [ "$root" = "$PROJECT" ] && echo 0 || echo 1)" ]; do
        sleep 0.5; i=$((i + 1))
        [ $i -lt 240 ] || { echo "s11: Emacs did not get ready; see $LOG" >&2; exit 1; }
    done
    for word in $WORDS; do
        tmux send-keys -t s11 M-o; sleep 1
        for c in $(echo "$word" | sed 's/./& /g'); do tmux send-keys -t s11 "$c"; sleep 0.3; done
        sleep 1.5; tmux send-keys -t s11 C-g; sleep 0.5
    done
    tmux kill-session -t s11
done
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
