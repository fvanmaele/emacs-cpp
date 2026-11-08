#!/bin/sh
# measure-pdf.sh - pdf-tools on a long PDF in the shipped profile (T-142, D-199): times
# recorded, no budget. A window opens for about a minute; do not touch it.
#   sh scripts/measure-pdf.sh [LOG]      default LOG: measure-pdf.log in the current directory
# The PDF is docs/CHEATSHEET.md through the export's pandoc options, joined to about 1000
# pages by poppler's pdfunite. Stops when pandoc, xelatex, pdfunite or the server is missing.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
LOG=${1:-$PWD/measure-pdf.log}
case $LOG in /*) ;; *) LOG=$PWD/$LOG ;; esac
EMACS=${EMACS:-emacs}
fail() { echo "measure-pdf: $*" >&2; exit 1; }
for program in pandoc xelatex pdfunite "$EMACS"; do
    command -v "$program" > /dev/null || fail "$program is not on PATH"
done
[ -x "$REPO/lib/pdf-tools/server/epdfinfo" ] || fail "no server; run: make epdfinfo"

work=$(mktemp -d "${TMPDIR:-/tmp}/emacs-cpp-measure.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM
cp "$REPO/docs/CHEATSHEET.md" "$work/cheat.md"
(cd "$work" && pandoc cheat.md -o one.pdf --pdf-engine=xelatex \
    -V monofont=DejaVuSansMono.ttf -V geometry:margin=3cm) </dev/null
copies=""
i=0
while [ "$i" -lt 167 ]; do
    copies="$copies $work/one.pdf"
    i=$((i + 1))
done
# shellcheck disable=SC2086  # the words are this script's own paths, without spaces
pdfunite $copies "$work/long.pdf"
mkdir "$work/home"
rm -f "$LOG"
code=0
HOME="$work/home" MEASURE_PDF="$work/long.pdf" MEASURE_LOG="$LOG" \
    "$EMACS" --chdir="$REPO" -Q -L scripts -L lisp -L test -l measure-pdf </dev/null || code=$?
[ -f "$LOG" ] || fail "no log: Emacs did not start graphically (exit $code)"
cat "$LOG"
exit "$code"
