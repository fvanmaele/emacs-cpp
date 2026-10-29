#!/usr/bin/env python3
"""S20: a git repository with two branches apart by CHANGED files. Spike code.

    python3 -I gen_repo.py ROOT [DIRS] [FILES] [CHANGED]     (defaults 2000 20000 190)

Writes DIRS directories, two levels deep, and FILES small .h / .cc files over them,
commits them on branch `a`; branch `b` puts 19 lines in front of CHANGED files spread
over the tree (the shift of the 2026-10-29 report) and its first line names the
branch. Leaves `a` checked out. Refuses an existing ROOT."""
import os, subprocess, sys

root = sys.argv[1]
dirs = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
files = int(sys.argv[3]) if len(sys.argv) > 3 else 20000
changed = int(sys.argv[4]) if len(sys.argv) > 4 else 190
if os.path.exists(root):
    sys.exit(f"gen_repo: {root} exists")
os.makedirs(root)
leaves = []
for i in range(dirs):
    d = os.path.join(root, f"t{i // 50:03d}", f"l{i % 50:02d}")
    os.makedirs(d, exist_ok=True)
    leaves.append(d)
paths = []
for i in range(files):
    ext = ".h" if i % 3 == 0 else ".cc"
    p = os.path.join(leaves[i % len(leaves)], f"f{i:06d}{ext}")
    with open(p, "w") as f:
        f.write(f"// s20 a\nenum class E{i} {{ X }};\n")
    paths.append(p)
git = ["git", "-C", root, "-c", "user.name=s20", "-c", "user.email=s20@invalid"]
subprocess.run(["git", "init", "-q", "-b", "a", root], check=True)
subprocess.run(git + ["add", "-A"], check=True)
subprocess.run(git + ["commit", "-q", "-m", "s20 a"], check=True)
subprocess.run(git + ["checkout", "-q", "-b", "b"], check=True)
step = max(1, files // changed)
for i in range(0, step * changed, step):
    with open(paths[i]) as f:
        body = f.read().split("\n", 1)[1]
    with open(paths[i], "w") as f:
        f.write("// s20 b\n" + "".join(f"// shift {k}\n" for k in range(19)) + body)
subprocess.run(git + ["commit", "-q", "-a", "-m", "s20 b"], check=True)
subprocess.run(git + ["checkout", "-q", "a"], check=True)
print(f"gen_repo: {root}: {dirs} directories, {files} files, {changed} changed on b")
