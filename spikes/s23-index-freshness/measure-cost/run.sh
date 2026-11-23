#!/bin/sh
# S23: include-closure size and staleness-check cost per TU (warm page cache).
# Run from this directory: sh run.sh > results.log 2>&1 </dev/null
set -eu
here=$(cd "$(dirname "$0")" && pwd)
ex=$HOME/source/repos/dealii/examples
cd "$here"
clang -O2 -I/opt/local/include -o closurecost closurecost.c
mkdir -p lists
date
uname -a
sysctl -n machdep.cpu.brand_string
for tu in synthetic step-1 step-6 step-22 step-40 step-69; do
  if [ "$tu" = synthetic ]; then src=$here/synthetic.cc; else src=$ex/$tu/$tu.cc; fi
  echo "== $tu ($src)"
  ./closure.sh "$src" "lists/$tu.txt"
  ./closurecost hash "lists/$tu.txt" 11
  ./closurecost open "lists/$tu.txt" 11
  ./closurecost stat "lists/$tu.txt" 201
  ./closurecost mem "lists/$tu.txt" 51
done
echo "== hyperfine cross-check, step-40, whole process (includes list parse, warm-up)"
hyperfine --warmup 1 --runs 5 -N \
  "./closurecost hash lists/step-40.txt 1" \
  "./closurecost stat lists/step-40.txt 1" </dev/null
