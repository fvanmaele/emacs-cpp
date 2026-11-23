#!/bin/sh
# Usage: closure.sh SOURCE OUTLIST
# Writes the include closure of SOURCE (the main file included), one absolute
# path per line, sorted and unique, using step-1's compile command from
# ~/source/repos/dealii/examples/step-1/compile_commands.json with "-c FILE -o
# OUT" replaced by "-M" and -isysroot set to the SDK xcrun names (step-1's
# MacOSX26.0.sdk no longer exists on this machine), plus the magic_enum include
# directory step-1's stale command lacks (deal.II/base/patterns.h needs it) (preprocessor only; -M lists system headers too).
set -eu
src=$1
out=$2
db=$HOME/source/repos/dealii/examples/step-1/compile_commands.json
cmd=$(/usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))[0]["command"])' "$db")
# Drop the compiler, "-o X" and "-c FILE"; keep every other flag.
flags=$(printf '%s\n' "$cmd" | /usr/bin/python3 -I -c '
import shlex, sys
a = shlex.split(sys.stdin.read())[1:]
r = []
i = 0
while i < len(a):
    if a[i] in ("-o", "-c"):
        i += 2
        continue
    if a[i] == "-isysroot":
        r += ["-isysroot", sys.argv[1]]; i += 2
        continue
    r.append(a[i]); i += 1
r += ["-isystem", "/Applications/deal.II.app/Contents/Resources/spack/opt/magic-enum-0.9.7-bfmh/include/magic_enum"]
print(" ".join(shlex.quote(x) for x in r))' "$(xcrun --show-sdk-path)")
mpicxx=/Applications/deal.II.app/Contents/Resources/Libraries/bin/mpicxx
dep=$(mktemp)
eval "$mpicxx $flags -M -MF \"$dep\" \"$src\"" </dev/null
/usr/bin/python3 -I -c '
import os, sys
t = open(sys.argv[1]).read().replace("\\\n", " ")
parts = t.split(":", 1)[1].split()
print("\n".join(sorted(set(os.path.realpath(p) for p in parts))))' "$dep" > "$out"
rm -f "$dep"
wc -l < "$out"
