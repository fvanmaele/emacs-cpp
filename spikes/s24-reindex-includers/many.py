"""S24 driver (spike code). Usage:
  python3 -I many.py correct LABEL CLANGD OUTDIR
  python3 -I many.py cost LABEL CLANGD OUTDIR N
correct: three TUs include types.h; `using Widget = A` becomes `= B`; after a
restart every TU is asked for the definition at `w.run()` (s2: at once and
every 0.5 s for 20 s; s3: once after another restart). Truth: B::run.
cost: N TUs; restarts with nothing changed (3), after common.h changed, after
leaf_7.h changed; prints the prototype's "S24:" log line and the time until
the background index is idle.
"""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "s23-index-freshness", "reproduce"))
import lsp  # noqa: E402

FLAGS = ["--navigation-from-index", "--background-index", "--log=verbose",
         "--enable-config=false"]


def write(d, files):
    for name, text in files.items():
        with open(os.path.join(d, name), "w") as f:
            f.write(text)


def cdb(d, tus):
    json.dump([{"directory": d, "file": os.path.join(d, t),
                "arguments": ["c++", "-std=c++17", "-c", os.path.join(d, t),
                              "-o", t + ".o"]} for t in tus],
              open(os.path.join(d, "compile_commands.json"), "w"))


def session(clangd, d, log, open_files):
    c = lsp.Client([clangd] + FLAGS, d, os.path.join(d, log))
    c.initialize(d)
    for f in open_files:
        c.did_open(os.path.join(d, f))
    return c


def s24_line(path):
    lines = [l.strip() for l in open(path) if "S24:" in l]
    return lines[-1] if lines else "(no S24 line)"


def correct(label, clangd, outdir):
    d = os.path.realpath(os.path.join(outdir, "correct-" + label))
    os.makedirs(d, exist_ok=False)
    types = ("#pragma once\nstruct A { int run() { return 1; } };\n"
             "struct B { int run() { return 2; } };\nusing Widget = %s;\n")
    tus = ["a.cpp", "b.cpp", "c.cpp"]
    files = {"types.h": types % "A"}
    for t in tus:
        files[t] = ('#include "types.h"\nint %s() { Widget w; return w.run(); }\n'
                    % t[0])
    write(d, files)
    cdb(d, tus)
    c = session(clangd, d, "s1.log", ["a.cpp"])
    c.wait_index_end(120)
    time.sleep(1)
    c.stop()
    write(d, {"types.h": types % "B"})
    truth, stale = 2, 1  # 0-based lines of B::run, A::run in types.h

    def ask(c, t):
        text = open(os.path.join(d, t)).read().splitlines()[1]
        r = c.request("textDocument/definition", {
            "textDocument": {"uri": lsp.uri(os.path.join(d, t))},
            "position": {"line": 1, "character": text.index("run")}}, timeout=60)
        res = r.get("result") or []
        lines = sorted({x["range"]["start"]["line"] for x in res})
        return ("correct" if lines == [truth] else
                "stale" if lines == [stale] else "other %s" % lines)

    out = []
    c = session(clangd, d, "s2.log", tus)
    t0 = time.time()
    seen = {t: [] for t in tus}
    while time.time() - t0 < 20:
        for t in tus:
            v = ask(c, t)
            if not seen[t] or seen[t][-1][1] != v:
                seen[t].append((round(time.time() - t0, 2), v))
        time.sleep(0.5)
    c.stop()
    for t in tus:
        out.append("%s s2 %s: %s" % (label, t, seen[t]))
    out.append("%s s2 %s" % (label, s24_line(os.path.join(d, "s2.log"))))
    c = session(clangd, d, "s3.log", tus)
    for t in tus:
        out.append("%s s3 %s: %s" % (label, t, ask(c, t)))
    c.stop()
    print("\n".join(out))


def cost(label, clangd, outdir, n):
    d = os.path.realpath(os.path.join(outdir, "cost-%s-%d" % (label, n)))
    os.makedirs(d, exist_ok=False)
    files = {"common.h": "#pragma once\n#include <vector>\n#include <string>\n"
                         "#include <map>\ninline int common() { return 1; }\n",
             "mid.h": '#pragma once\n#include "common.h"\n'
                      "inline int mid() { return 2; }\n"}
    tus = []
    for i in range(n):
        files["leaf_%d.h" % i] = ('#pragma once\n#include "common.h"\n'
                                  "inline int leaf_%d() { return %d; }\n" % (i, i))
        inc = '#include "mid.h"\n' if i % 2 == 0 else ""
        files["tu_%d.cpp" % i] = ('#include "leaf_%d.h"\n%sint tu_%d() { '
                                  "return leaf_%d() + common(); }\n" % (i, inc, i, i))
        tus.append("tu_%d.cpp" % i)
    write(d, files)
    cdb(d, tus)
    t0 = time.time()
    c = session(clangd, d, "s1.log", ["tu_0.cpp"])
    ok = c.wait_index_end(3600)
    time.sleep(2)
    c.stop()
    print("%s N=%d first index %s in %.1f s" % (label, n, "done" if ok else "TIMEOUT",
                                                time.time() - t0))

    def restart(name):
        t0 = time.time()
        c = session(clangd, d, name + ".log", ["tu_0.cpp"])
        ok = c.wait_index_end(3600)
        idle = time.time() - t0
        time.sleep(2)
        c.stop()
        print("%s N=%d %s: idle after %.1f s (%s); %s" % (
            label, n, name, idle, "end" if ok else "TIMEOUT",
            s24_line(os.path.join(d, name + ".log"))))

    for k in range(3):
        restart("unchanged-%d" % k)
    with open(os.path.join(d, "common.h"), "a") as f:
        f.write("inline int common2() { return 3; }\n")
    restart("common-changed")
    with open(os.path.join(d, "leaf_7.h"), "a") as f:
        f.write("inline int leaf_7b() { return 4; }\n")
    restart("leaf7-changed")


if __name__ == "__main__":
    mode, label, clangd, outdir = sys.argv[1:5]
    if mode == "correct":
        correct(label, clangd, outdir)
    else:
        cost(label, clangd, outdir, int(sys.argv[5]))
