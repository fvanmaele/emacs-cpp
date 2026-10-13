#!/bin/sh
# S11 run 5: project symbols among clangd's workspace symbols (O-37).  Owner runs:
#   sh spikes/s11-go-to-anything/scope.sh [project-dir] [file]
# The project is used in place with its configured preset and stored clangd index,
# as in a daily session; the script writes nothing into it or into ~/.emacs.d
# (it reads the preset state there).  Seeds: S11_SEEDS="name ..." (default: the
# project's C++ file base names).  Writes results-run5.log next to this script,
# never over one.
set -eu
PROJECT=${1:-$HOME/source/repos/RMO-gross-pitaevskii}
FILE=${2:-src/main.cc}
case $(uname) in
    Darwin) DEFAULT_CLANGD=$HOME/opt/clangd-index-nav/bin/clangd ;;  # D-052
    *) DEFAULT_CLANGD=/opt/clangd-index-nav/bin/clangd ;;
esac
CLANGD=${S11_CLANGD:-$DEFAULT_CLANGD}
EMACS_D=${S11_EMACS_D:-$HOME/.emacs.d}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
LOG=${S11_LOG:-$HERE/results-run5.log}
[ -x "$CLANGD" ] || { echo "s11: no clangd at $CLANGD" >&2; exit 1; }
[ -f "$PROJECT/CMakePresets.json" ] || { echo "s11: no CMakePresets.json in $PROJECT" >&2; exit 1; }
[ -f "$PROJECT/$FILE" ] || { echo "s11: no $FILE in $PROJECT" >&2; exit 1; }
[ -e "$LOG" ] && { echo "s11: $LOG exists; move it away first" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
if [ -f "$EMACS_D/emacs-cpp-presets.eld" ]; then
    cp "$EMACS_D/emacs-cpp-presets.eld" "$WORK/presets.eld"
fi
{ echo "# S11 run 5 $(date -Iseconds)"
  echo "project: $PROJECT ($FILE)"
  echo "clangd: $CLANGD, $("$CLANGD" --version | head -n 1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"; } > "$LOG"
S11_PROJECT=$PROJECT S11_FILE=$FILE S11_CLANGD=$CLANGD \
S11_EMACS_D=$EMACS_D S11_STATE=$WORK/presets.eld S11_OUT=$LOG \
    emacs -Q --batch -L "$REPO/scripts" -L "$REPO/lisp" -L "$REPO/test" \
    -l "$HERE/scope.el" > "$WORK/emacs.log" 2>&1 \
    || { echo "s11: the session failed; its last lines:" >> "$LOG"
         tail -n 20 "$WORK/emacs.log" >> "$LOG"; }
echo "load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$LOG"
echo "done; see $LOG"
