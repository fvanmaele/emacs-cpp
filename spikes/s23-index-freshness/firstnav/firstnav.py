"""S23 firstnav: the first go-to-definition after a restart, nothing changed.

Usage: python3 -I firstnav.py LABEL CLANGD WORKDIR [NEEDLE]
NEEDLE: the name asked for (default local_fn, declared in the project's
local.h: deal.II's headers lie outside the project, so the background index
stores no shard for them and only a library index (D-130) answers there); an existing WORKDIR/LABEL with
its index is reused (session 2 only).
Builds WORKDIR/LABEL (S23's synthetic deal.II TU as main.cpp, step-1's flags as
in measure-cost/closure.sh), session 1 indexes it, session 2 (stored shards)
asks textDocument/definition on NEEDLE at once and prints the reply time and
which path answered (from the verbose log). T-162 done when: under 1 s.
"""
import json
import os
import shlex
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "reproduce"))
import lsp  # noqa: E402

label, clangd, workdir = sys.argv[1], sys.argv[2], sys.argv[3]
needle = sys.argv[4] if len(sys.argv) > 4 else "local_fn"
d = os.path.realpath(os.path.join(workdir, label))
reuse = os.path.exists(os.path.join(d, "s1.log"))
os.makedirs(d, exist_ok=True)
src = ('#include "local.h"\n'
       + open(os.path.join(HERE, "..", "measure-cost", "synthetic.cc")).read()
       + "int use_local() { return local_fn(1); }\n")
main = os.path.join(d, "main.cpp")
if not reuse:
    open(main, "w").write(src)
    open(os.path.join(d, "local.h"), "w").write(
        "#pragma once\ninline int local_fn(int x) { return x + 1; }\n")

db = os.path.expanduser("~/source/repos/dealii/examples/step-1/compile_commands.json")
args = shlex.split(json.load(open(db))[0]["command"])
sdk = subprocess.run(["xcrun", "--show-sdk-path"], capture_output=True, text=True,
                     check=True).stdout.strip()
flags, i = [], 1
while i < len(args):
    if args[i] in ("-o", "-c"):
        i += 2
        continue
    if args[i] == "-isysroot":
        flags += ["-isysroot", sdk]
        i += 2
        continue
    flags.append(args[i])
    i += 1
flags += ["-isystem", "/Applications/deal.II.app/Contents/Resources/spack/opt/"
          "magic-enum-0.9.7-bfmh/include/magic_enum"]
cmd = [args[0]] + flags + ["-o", "main.o", "-c", main]
if not reuse:
    json.dump([{"directory": d, "file": main, "arguments": cmd}],
              open(os.path.join(d, "compile_commands.json"), "w"))

argv = [clangd, "--navigation-from-index", "--background-index", "--log=verbose",
        "--enable-config=false"]
line = next(i for i, t in enumerate(src.splitlines()) if needle in t)
col = src.splitlines()[line].index(needle)

if not reuse:
    c = lsp.Client(argv, d, os.path.join(d, "s1.log"))
    c.initialize(d)
    c.did_open(main)
    ok = c.wait_index_end(900)
    c.stop()
    print("%s session 1: index %s" % (label, "done" if ok else "TIMEOUT"))

log = os.path.join(d, "s2.log")
c = lsp.Client(argv, d, log)
c.initialize(d)
t0 = time.time()
c.did_open(main)
r = c.request("textDocument/definition", {
    "textDocument": {"uri": lsp.uri(main)},
    "position": {"line": line, "character": col}}, timeout=120)
ms = (time.time() - t0) * 1000
c.stop()
res = r.get("result") or []
target = os.path.basename(res[0]["uri"]) if res else None
path = "AST"
for text in open(log):
    if "answered from the index shard" in text:
        path = "index"
    if "needs the AST" in text or "need the AST" in text:
        print("  " + text.strip()[:160])
print("%s session 2: first definition of %s %.0f ms, %s, target %s"
      % (label, needle, ms, path, target))
