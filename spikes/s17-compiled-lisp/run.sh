#!/bin/sh
# S17 (D-125): does byte-compiling lisp/ change startup, and do the modules then run
# as native code?  Spike code, never promoted.  Run on an idle machine, after
# `make packages`:
#   sh spikes/s17-compiled-lisp/run.sh [RUNS] [ROUNDS]     (defaults 10, 2)
# Copies init.el, early-init.el, lib/, lisp/ and scripts/measure-startup.sh into two
# trees under a temporary directory: `interp` as shipped, `byte` with lisp/*.elc
# (compile.el, temporary HOME).  Each round measures both trees with Emacs's JIT
# native compiler on and off (measure-startup.sh's ELISP argument), then probes which
# form `emacs-cpp-match-tier' and `emacs-cpp-presets-resolve' have after startup.
# Never touches ~/.emacs.d; the repository is only read.
set -eu
LC_ALL=C
export LC_ALL
RUNS=${1:-10}
ROUNDS=${2:-2}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
EMACS=${EMACS:-emacs}
[ -f "$repo/lib/load-path.el" ] || { echo "s17: run make packages first" >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/s17.XXXXXX")
trap 'rm -rf "$work"' EXIT
for t in interp byte; do
    mkdir -p "$work/$t/scripts"
    cp -R "$repo/init.el" "$repo/early-init.el" "$repo/lib" "$repo/lisp" "$work/$t/"
    cp "$repo/scripts/measure-startup.sh" "$work/$t/scripts/"
    rm -f "$work/$t"/lisp/*.elc
done
mkdir "$work/home"
HOME=$work/home "$EMACS" -Q --batch -l "$here/compile.el" "$work/byte" \
    > "$work/compile.log" 2>&1 || { cat "$work/compile.log"; exit 1; }
echo "s17: compiler warnings: $(grep -c 'Warning' "$work/compile.log" || true)"
tail -1 "$work/compile.log"
jit_off='(setq native-comp-jit-compilation nil)'
probe() {  # tree, jit elisp: one start, then the functions' forms
    out=$work/probe.$$
    sh "$work/$1/scripts/measure-startup.sh" 1 "$2
(add-hook 'kill-emacs-hook
  (lambda () (write-region
    (mapconcat (lambda (s) (let ((f (symbol-function s)))
      (format \"%s=%s\" s (cond ((null f) 'unbound) ((autoloadp f) 'autoload)
                              ((native-comp-function-p f) 'native)
                              ((byte-code-function-p f) 'byte) (t 'interpreted)))))
      '(emacs-cpp-match-tier emacs-cpp-presets-resolve consult-buffer) \" \")
    nil \"$out\")))" > /dev/null
    cat "$out"; echo; rm -f "$out"
}
echo "S17 run $(date -u +%Y-%m-%dT%H:%M:%SZ), $(uname -s) $(uname -m), $("$EMACS" --version | head -1)"
round=1
while [ "$round" -le "$ROUNDS" ]; do
    for t in interp byte; do
        for jit in on off; do
            if [ "$jit" = on ]; then extra=; else extra=$jit_off; fi
            printf 'round %s  %-6s jit %-3s  ' "$round" "$t" "$jit"
            sh "$work/$t/scripts/measure-startup.sh" "$RUNS" "$extra" \
                | awk '/^load:/ { load = $0 } /^median/ { print $0 "  (" load ")" }'
        done
    done
    round=$((round + 1))
done
for t in interp byte; do
    printf 'probe  %-6s jit on   ' "$t"; probe "$t" ""
    printf 'probe  %-6s jit off  ' "$t"; probe "$t" "$jit_off"
done
