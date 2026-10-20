#!/usr/bin/env python3
"""S18: create N files fast inside an existing tree. Spike code.

    python3 -I burst.py ROOT N TAG

Files `burst-TAG-NNNNNN.py`, spread over the tree's first 200 leaf directories."""
import os, sys, time

root, n, tag = sys.argv[1], int(sys.argv[2]), sys.argv[3]
leaves = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = sorted(d for d in dirnames if d != ".git")
    if not dirnames:
        leaves.append(dirpath)
    if len(leaves) >= 200:
        break
t0 = time.time()
for i in range(n):
    with open(os.path.join(leaves[i % len(leaves)], f"burst-{tag}-{i:06d}.py"), "w") as f:
        f.write("x = 1\n")
print(f"burst: {n} files in {time.time() - t0:.2f} s", file=sys.stderr)
