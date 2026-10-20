#!/bin/sh
# S17 run 4 (O-74): lisp/'s hot paths interpreted, as bytecode and as native code.
# Spike code, never promoted.  After `make packages`, on an idle machine:
#   sh spikes/s17-compiled-lisp/bench.sh [DEALII-CHECKOUT] [RMO-CHECKOUT]
# Builds one copy of init.el, lib/ and lisp/ in a temporary directory: lisp/*.elc by
# compile.el (init.el's settings), then lisp/*.eln by `native-compile' with the same
# settings into the temporary HOME's cache.  Runs bench.el once per state, each in a
# fresh Emacs.  Writes bench.log next to this script (appends).  The repository is
# only read.
set -eu
LC_ALL=C
export LC_ALL
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
DEALII=${1:-$HOME/source/repos/dealii}
RMO=${2:-$HOME/source/repos/RMO-gross-pitaevskii}
EMACS=${EMACS:-emacs}
log=$here/bench.log
[ -f "$repo/lib/load-path.el" ] || { echo "s17: run make packages first" >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/s17b.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/tree" "$work/home"
cp -R "$repo/init.el" "$repo/early-init.el" "$repo/lib" "$repo/lisp" "$work/tree/"
rm -f "$work/tree"/lisp/*.elc
{ echo "S17 run 4 (bench) $(date -u +%Y-%m-%dT%H:%M:%SZ), $(uname -s) $(uname -m), $("$EMACS" --version | head -1)"
  echo "load: $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || sysctl -n vm.loadavg)"; } | tee -a "$log"
# Interpreted first, before any .elc exists.
HOME=$work/home "$EMACS" -Q --batch -l "$here/bench.el" interp "$work/tree" "$DEALII" "$RMO" "$log" > /dev/null
HOME=$work/home "$EMACS" -Q --batch -l "$here/compile.el" "$work/tree" > "$work/compile.log" 2>&1 \
    || { cat "$work/compile.log"; exit 1; }
HOME=$work/home "$EMACS" -Q --batch -l "$here/bench.el" byte "$work/tree" "$DEALII" "$RMO" "$log" > /dev/null
# Native: the same settings as the bytecode, set in the compiling Emacs itself.
HOME=$work/home "$EMACS" -Q --batch --eval "(progn
  (setq emacs-cpp-root \"$work/tree/\")
  (load \"$work/tree/lib/load-path.el\" nil t)
  (load \"$work/tree/lib/autoloads.el\" nil t)
  (add-to-list 'load-path \"$work/tree/lisp\")
  (require 'use-package)
  (setq use-package-always-defer t use-package-expand-minimally t)
  (require (if (eq system-type 'darwin) 'defaults-darwin 'defaults-gnu-linux))
  (dolist (f (directory-files \"$work/tree/lisp\" t \"\\\\\`[^.].*\\\\.el\\\\'\"))
    (native-compile f)))" > "$work/native.log" 2>&1 || { tail -20 "$work/native.log"; exit 1; }
HOME=$work/home "$EMACS" -Q --batch -l "$here/bench.el" native "$work/tree" "$DEALII" "$RMO" "$log" > /dev/null
echo "done; see $log"
