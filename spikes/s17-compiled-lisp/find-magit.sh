#!/bin/sh
# S17 run 2 (D-125, T-113): which form loads magit at startup when lisp/ runs as
# native code?  Spike code, never promoted.  Run after `make packages`:
#   sh spikes/s17-compiled-lisp/find-magit.sh
# Builds the `byte' tree as run.sh does, then one measured start (measure-startup.sh,
# after its warm-up) with the JIT on and one with it off, each recording: the backtrace
# at the moment magit.el finishes loading (after-load-functions, so no advice on
# `require' is needed), the features loaded, and the files still queued for native
# compilation at exit.  Prints one block per start.  The repository is only read.
set -eu
LC_ALL=C
export LC_ALL
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
EMACS=${EMACS:-emacs}
[ -f "$repo/lib/load-path.el" ] || { echo "s17: run make packages first" >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/s17.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/byte/scripts" "$work/home"
cp -R "$repo/init.el" "$repo/early-init.el" "$repo/lib" "$repo/lisp" "$work/byte/"
cp "$repo/scripts/measure-startup.sh" "$work/byte/scripts/"
rm -f "$work/byte"/lisp/*.elc
# S17_PRELUDE=1: as run.sh's run 3, init.el's use-package settings at compile time.
if [ "${S17_PRELUDE:-}" = 1 ]; then
    for f in "$work/byte"/lisp/*.el; do
        awk 'done != 1 && /^;;; Code:/ { print; print "(eval-when-compile (setq use-package-always-defer t use-package-expand-minimally t))"; done = 1; next } { print }' \
            "$f" > "$f.new" && mv "$f.new" "$f"
    done
fi
HOME=$work/home "$EMACS" -Q --batch -l "$here/compile.el" "$work/byte" \
    > "$work/compile.log" 2>&1 || { cat "$work/compile.log"; exit 1; }
tail -1 "$work/compile.log"
start() {  # label, extra elisp for early-init.el
    out=$work/out.$1
    # measure-startup.sh starts twice (warm-up, then the measured start): each start
    # writes a marker first.
    sh "$work/byte/scripts/measure-startup.sh" 1 "$2
(write-region \"-- start (the first is the warm-up)\\n\" nil \"$out\" t)
(add-hook 'after-load-functions
  (lambda (file)
    (when (string-match-p \"/magit\\\\.el\" file)
      (write-region (concat \"magit loaded from \" file \"\\n\"
                            (with-output-to-string (backtrace)) \"\\n\")
                    nil \"$out\" t))))
(add-hook 'kill-emacs-hook
  (lambda ()
    (write-region
     (format \"features %d, magit %s, comp queue %d\\n\"
             (length features) (if (featurep 'magit) \"loaded\" \"not loaded\")
             (if (boundp 'comp-files-queue) (length comp-files-queue) 0))
     nil \"$out\" t)))" > /dev/null
    echo "== $1"
    cat "$out" 2>/dev/null || echo "(nothing recorded)"
}
start "byte jit on" ""
start "byte jit off" "(setq native-comp-jit-compilation nil)"
