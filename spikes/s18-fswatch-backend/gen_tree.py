#!/usr/bin/env python3
"""S18: an LLVM-sized tree (RESEARCH_platform_differences 3.12). Spike code.

    python3 -I gen_tree.py ROOT [DIRS] [FILES]     (defaults 15408 187395)

Writes DIRS directories, three levels deep, and FILES small .c / .h files spread over
them, then `git init` and one commit (eglot needs a project, and Emacs's own watches
list the directories through project.el's tracked files). Refuses an existing ROOT."""
import os, subprocess, sys

root = sys.argv[1]
dirs = int(sys.argv[2]) if len(sys.argv) > 2 else 15408
files = int(sys.argv[3]) if len(sys.argv) > 3 else 187395
if os.path.exists(root):
    sys.exit(f"gen_tree: {root} exists")
os.makedirs(root)
leaves = []
top = 24
mid = 25
n = 0
for a in range(top):
    for b in range(mid):
        for c in range(max(1, dirs // (top * mid))):
            if n >= dirs:
                break
            d = os.path.join(root, f"t{a:02d}", f"m{b:02d}", f"l{c:03d}")
            os.makedirs(d, exist_ok=True)
            leaves.append(d)
            n += 1
for i in range(files):
    d = leaves[i % len(leaves)]
    ext = ".c" if i % 3 else ".h"
    with open(os.path.join(d, f"f{i:06d}{ext}"), "w") as f:
        f.write("x\n")
subprocess.run(["git", "init", "-q", root], check=True)
git = ["git", "-C", root, "-c", "user.name=s18", "-c", "user.email=s18@invalid"]
subprocess.run(git + ["add", "-A"], check=True)
subprocess.run(git + ["commit", "-q", "-m", "s18 tree"], check=True)
print(f"gen_tree: {root}: {len(leaves)} leaf directories, {files} files")
