#!/bin/sh
# S22 on the Mac (H-32): fetch pdf-tools v1.3.0 and tablist, build epdfinfo against
# MacPorts' poppler, make the two test PDFs, run s22.el (run 1), then run it again with
# the PDF left open for criterion 5 (run 2; quit that Emacs with C-x C-c).
# Needs: `sudo port install poppler autoconf automake pkgconfig` (agreed 2026-11-08),
# pandoc and MacTeX. Logs: build-mac.log, mac-run1.log, mac-run2.log in this directory.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# S22_EMACS and S22_NO_HOLD=1 are for a dry run on another machine.
emacs=${S22_EMACS:-/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs}
src="$here/src"
cd "$here"

command -v "$emacs" >/dev/null || { echo "mac-run: no Emacs at $emacs" >&2; exit 1; }
for program in pandoc xelatex pkg-config autoreconf; do
    command -v "$program" >/dev/null || { echo "mac-run: $program not on PATH" >&2; exit 1; }
done

mkdir -p "$src"
[ -d "$src/pdf-tools" ] ||
    git clone -q --depth 1 --branch v1.3.0 https://github.com/vedang/pdf-tools "$src/pdf-tools"
[ -d "$src/tablist" ] ||
    git clone -q --depth 1 https://github.com/emacsorphanage/tablist "$src/tablist"

echo "mac-run: building epdfinfo (log: build-mac.log)"
status=0
(cd "$src/pdf-tools/server" && ./autogen.sh && ./configure && make) \
    > "$here/build-mac.log" 2>&1 </dev/null || status=$?
echo "mac-run: build exit $status"
tail -5 "$here/build-mac.log"
[ "$status" -eq 0 ] || exit "$status"

echo "mac-run: test PDFs"
cp "$here/../../docs/CHEATSHEET.md" "$src/cheat.md"
(cd "$src" &&
     pandoc cheat.md -o test-orig.pdf --pdf-engine=xelatex -V monofont=DejaVuSansMono.ttf \
            -V geometry:margin=3cm &&
     pandoc cheat.md -o test-new.pdf --pdf-engine=xelatex -V monofont=DejaVuSansMono.ttf \
            -V geometry:margin=1cm) </dev/null

load='(condition-case e (load (expand-file-name "s22.el"))
        (error (append-to-file (format "S22 load error: %S\n" e) nil
                               (expand-file-name (getenv "S22_LOG")))
               (kill-emacs 2)))'

echo "mac-run: run 1 (an Emacs window scrolls by itself for about 30 s; do not touch it)"
rm -f mac-run1.log
S22_CLAMP=1 S22_LOG=mac-run1.log "$emacs" -Q --eval "$load" </dev/null || true
cat mac-run1.log

[ -z "${S22_NO_HOLD:-}" ] || exit 0
echo "mac-run: run 2 (the window stays open: compare the text with DocView, then C-x C-c)"
rm -f mac-run2.log
S22_HOLD=1 S22_CLAMP=1 S22_LOG=mac-run2.log "$emacs" -Q --eval "$load" </dev/null || true
tail -2 mac-run2.log
