"""S23 reproduce: does navigation from the index answer stale after a change?

Usage: python3 -I freshness.py CASE LABEL OUTDIR
  CASE  header_disk | header_unsaved | target_moved | header_first_define
  LABEL nav (patched clangd, --navigation-from-index); navdev: $S23_CLANGD with it
        noflag (patched clangd without the flag)
        upstream (/opt/local/bin/clangd-mp-23, MacPorts 23.1.5)

Per run: session 1 builds the background index from scratch and stops;
the case's change is applied; session 2 (stored shards) opens the files,
sends the case's queries once (the first answers race the AST), then polls
them for POLL seconds; session 3 restarts once more and asks once (did the
stored index get fixed?). Results: OUTDIR/CASE-LABEL.json and the clangd logs.
"""
import json
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lsp  # noqa: E402

BINARIES = {
    "nav": [os.path.expanduser("~/opt/clangd-index-nav/bin/clangd"),
            "--navigation-from-index"],
    "noflag": [os.path.expanduser("~/opt/clangd-index-nav/bin/clangd")],
    "upstream": ["/opt/local/bin/clangd-mp-23"],
    # A clangd under test (T-161, T-162): its path in S23_CLANGD.
    "navdev": [os.environ.get("S23_CLANGD", "S23_CLANGD-unset"),
               "--navigation-from-index"],
}
COMMON_FLAGS = ["--background-index", "--log=verbose", "--enable-config=false"]
POLL = 20.0
GAP = 0.3

HEAVY = "#pragma once\n" + "".join("#include <%s>\n" % h for h in [
    "algorithm", "chrono", "filesystem", "format", "functional", "future",
    "iostream", "map", "memory", "optional", "ranges", "regex", "set",
    "sstream", "string", "thread", "unordered_map", "variant", "vector"])


def cdb(entries):
    """entries: list of (file, extra flags)."""
    return lambda d: json.dumps([{
        "directory": d, "file": f,
        "arguments": ["/usr/bin/clang++", "-std=c++20"] + extra + ["-c", f]}
        for f, extra in entries], indent=1) + "\n"


# Each case: files before, files after (written to disk, or sent unsaved),
# queries (file, needle, occurrence, column offset inside needle, method),
# truth per query: list of (file, needle) whose line/column are looked up in
# the files after the change, and the stale answer the old index would give
# (same form, looked up in the files before).
CASES = {}

C1_BEFORE = {
    "heavy.h": HEAVY,
    "over.h": "#pragma once\n"
              "inline int f(int) { return 1; }\n"
              "inline int f(double) { return 2; }\n",
    "types.h": "#pragma once\n"
               "struct A { int run() { return 1; } };\n"
               "struct B { int run() { return 2; } };\n"
               "using Widget = A;\n",
    "macros.h": "#pragma once\n"
                "inline int handle_a() { return 1; }\n"
                "inline int handle_b() { return 2; }\n"
                "#define HANDLER handle_a\n",
    "main.cpp": '#include "heavy.h"\n#include "over.h"\n#include "types.h"\n'
                '#include "macros.h"\n\nint main() {\n  Widget w;\n'
                "  return f(1) + w.run() + HANDLER();\n}\n",
    "compile_commands.json": cdb([("main.cpp", [])]),
}
C1_AFTER = {
    "over.h": "#pragma once\n"
              "// f(int) was removed: f(1) now calls f(double).\n\n"
              "inline int f(double) { return 2; }\n",
    "types.h": "#pragma once\n"
               "struct A { int run() { return 1; } };\n"
               "struct B { int run() { return 2; } };\n"
               "using Widget = B;\n",
    "macros.h": "#pragma once\n"
                "inline int handle_a() { return 1; }\n"
                "inline int handle_b() { return 2; }\n\n\n"
                "#define HANDLER handle_b\n",
}
C1_QUERIES = [
    ("def f(1) overload", "main.cpp", "f(1)", 0, "definition",
     [("over.h", "f(double) {")], [("over.h", "f(int)")]),
    ("def w.run() typedef", "main.cpp", "run()", 0, "definition",
     [("types.h", "run() { return 2")], [("types.h", "run() { return 1")]),
    ("def HANDLER macro", "main.cpp", "HANDLER()", 0, "definition",
     [("macros.h", "HANDLER handle")], [("macros.h", "HANDLER handle")]),
    ("refs f(1) overload", "main.cpp", "f(1)", 0, "references",
     [("over.h", "f(double) {"), ("main.cpp", "f(1)")],
     [("over.h", "f(int)"), ("main.cpp", "f(1)")]),
]
CASES["header_disk"] = dict(before=C1_BEFORE, after=C1_AFTER, unsaved=False,
                            open_first=[], queries=C1_QUERIES)
CASES["header_unsaved"] = dict(before=C1_BEFORE, after=C1_AFTER, unsaved=True,
                               open_first=["over.h", "types.h", "macros.h"],
                               queries=C1_QUERIES)

C2_BEFORE = {
    "heavy.h": HEAVY,
    "g.h": "#pragma once\nint g();\n",
    "g.cpp": '#include "g.h"\nint g() { return 7; }\n',
    "other.cpp": '#include "g.h"\nint other1() { return g(); }\n',
    "main.cpp": '#include "heavy.h"\n#include "g.h"\n\n'
                "int main() { return g(); }\n",
    "compile_commands.json": cdb([("main.cpp", []), ("g.cpp", []),
                                  ("other.cpp", [])]),
}
C2_AFTER = {
    "g.cpp": '#include "g.h"\n// five lines\n//\n//\n//\n//\n'
             "int g() { return 7; }\n",
    "other.cpp": '#include "g.h"\nint other1() { return g(); }\n'
                 "int other2() { return g() + g(); }\n",
}
C2_QUERIES = [
    ("def g() moved in g.cpp", "main.cpp", "g()", 0, "definition",
     [("g.cpp", "g() {")], [("g.cpp", "g() {")]),
    ("refs g() new calls in other.cpp", "main.cpp", "g()", 0, "references",
     [("main.cpp", "g()"), ("g.h", "g()"), ("g.cpp", "g() {"),
      ("other.cpp", "g(); }"), ("other.cpp", "g() +"), ("other.cpp", "g(); }\n", 2)],
     [("main.cpp", "g()"), ("g.h", "g()"), ("g.cpp", "g() {"),
      ("other.cpp", "g(); }")]),
]
CASES["target_moved"] = dict(before=C2_BEFORE, after=C2_AFTER, unsaved=False,
                             open_first=[], queries=C2_QUERIES)

C3_HEADER = ("#pragma once\n#include \"heavy.h\"\n#ifdef USE_A\n"
             "inline int f(int) { return 1; }\n#endif\n"
             "inline int f(double) { return 2; }\n"
             "inline int user() { return f(1); }\n")
C3_BEFORE = {
    "heavy.h": HEAVY,
    "over3.h": C3_HEADER,
    "main.cpp": '#include "over3.h"\n\nint main() { return f(1) + user(); }\n',
    "compile_commands.json": cdb([("main.cpp", ["-DUSE_A"])]),
}
C3_AFTER = {"compile_commands.json": cdb([("main.cpp", [])])}
C3_QUERIES = [
    ("def f(1) in header opened first", "over3.h", "f(1)", 0, "definition",
     [("over3.h", "f(double)")], [("over3.h", "f(int)")]),
    ("refs f(1) in header opened first", "over3.h", "f(1)", 0, "references",
     [("over3.h", "f(double)"), ("over3.h", "f(1)"), ("main.cpp", "f(1)")],
     [("over3.h", "f(int)"), ("over3.h", "f(1)"), ("main.cpp", "f(1)")]),
    ("control: def f(1) in main.cpp", "main.cpp", "f(1)", 0, "definition",
     [("over3.h", "f(double)")], [("over3.h", "f(int)")]),
]
CASES["header_first_define"] = dict(before=C3_BEFORE, after=C3_AFTER,
                                    unsaved=False, open_first=["over3.h"],
                                    queries=C3_QUERIES)

# Case 3's control (T-161): the flags unchanged, the index must still answer
# from the header (truth: f(int), selected by -DUSE_A).
CASES["header_first_same"] = dict(
    before=C3_BEFORE, after={}, unsaved=False, open_first=["over3.h"],
    queries=[(name, f, needle, occ, kind, stale, truth)
             for (name, f, needle, occ, kind, truth, stale) in C3_QUERIES])

# Case 1 without a restart: main.cpp open and parsed, then the headers are
# changed on disk, opened and saved in the editor (didOpen + didSave).
CASES["header_live"] = dict(before=C1_BEFORE, after=C1_AFTER, unsaved=False,
                            live=True, open_first=[], queries=C1_QUERIES)

# Case 1, asked from the headers with main.cpp never opened: are main.cpp's
# references to the new targets in the stored index?
CASES["header_disk_from_header"] = dict(
    before=C1_BEFORE, after=C1_AFTER, unsaved=False,
    open_first=["over.h", "types.h"], queries=[
        ("refs f(double) from over.h", "over.h", "f(double) {", 0, "references",
         [("over.h", "f(double) {"), ("main.cpp", "f(1)")],
         [("over.h", "f(double) {")]),
        ("refs B::run from types.h", "types.h", "run() { return 2", 0,
         "references",
         [("types.h", "run() { return 2"), ("main.cpp", "run()")],
         [("types.h", "run() { return 2")]),
    ])

# Case 2 with slow reindexing: g.cpp and other.cpp include heavy.h, so the
# stale g.cpp shard may outlive main.cpp's AST build.
C2S_BEFORE = dict(C2_BEFORE)
C2S_BEFORE["g.cpp"] = '#include "heavy.h"\n' + C2_BEFORE["g.cpp"]
C2S_BEFORE["other.cpp"] = '#include "heavy.h"\n' + C2_BEFORE["other.cpp"]
C2S_AFTER = {k: '#include "heavy.h"\n' + v for k, v in C2_AFTER.items()}
CASES["target_moved_slow"] = dict(before=C2S_BEFORE, after=C2S_AFTER,
                                  unsaved=False, open_first=[],
                                  queries=C2_QUERIES)


def text_of(files, d, name):
    v = files[name]
    return v(d) if callable(v) else v


def find(text, needle, occurrence=1):
    i = -1
    for _ in range(occurrence):
        i = text.index(needle, i + 1)
    line = text.count("\n", 0, i)
    col = i - (text.rfind("\n", 0, i) + 1)
    return line, col


def locations(spec, files, d):
    out = []
    for item in spec:
        name, needle = item[0], item[1]
        occ = item[2] if len(item) > 2 else 1
        line, col = find(text_of(files, d, name), needle, occ)
        out.append((name, line, col))
    return sorted(out)


def summarize(result, d):
    """LSP Location list -> sorted (relative file, line, col)."""
    if not result:
        return []
    if isinstance(result, dict):
        result = [result]
    out = []
    for loc in result:
        path = loc["uri"][len("file://"):]
        rel = os.path.relpath(os.path.realpath(path), os.path.realpath(d))
        out.append((rel, loc["range"]["start"]["line"],
                    loc["range"]["start"]["character"]))
    return sorted(out)


def write_files(d, files):
    for name in files:
        with open(os.path.join(d, name), "w") as f:
            f.write(text_of(files, d, name))


def start(label, d, log):
    c = lsp.Client(BINARIES[label] + COMMON_FLAGS, d, log)
    c.initialize(d)
    return c


def ask(c, d, q, after_texts, case):
    name, fname, needle, off, method = q[:5]
    line, col = find(after_texts[fname], needle)
    params = {"textDocument": {"uri": lsp.uri(os.path.join(d, fname))},
              "position": {"line": line, "character": col + off}}
    if method == "references":
        params["context"] = {"includeDeclaration": True}
    t_send = time.time() - c.t0
    rid = c.request_async("textDocument/" + method, params)
    reply = c.wait_reply(rid, timeout=60)
    t_reply = time.time() - c.t0
    time.sleep(0.05)  # keeps the log's lines of one request together
    return rid, t_send, t_reply, reply.get("result"), reply.get("error")


LOG_TIME = re.compile(r"^[IVED]\[(\d\d):(\d\d):(\d\d)\.(\d\d\d)\] (.*)$")


def parse_log(path, t0):
    """Log lines as (seconds since the client started clangd, text)."""
    lt = time.localtime(t0)
    base = lt.tm_hour * 3600 + lt.tm_min * 60 + lt.tm_sec + (t0 % 1)
    out = []
    with open(path, errors="replace") as f:
        for line in f:
            m = LOG_TIME.match(line.rstrip("\n"))
            if not m:
                continue
            s = int(m[1]) * 3600 + int(m[2]) * 60 + int(m[3]) + int(m[4]) / 1000
            out.append((round(s - base, 3), m[5]))
    return out


def path_of(log, rid, method):
    """Which path answered request rid: the lines from its receipt to the next
    request's receipt name the index answer or the reasons it needed the AST."""
    start_i = None
    for i, (_, text) in enumerate(log):
        if text == "<-- textDocument/%s(%d)" % (method, rid):
            start_i = i
            break
    if start_i is None:
        return "unknown", []
    notes = []
    answered = "AST"
    for _, text in log[start_i + 1:]:
        if text.startswith("<-- textDocument/"):
            break
        if "answered from the index shard" in text:
            answered = "index"
            notes.append(text)
        elif "need the AST" in text or "needs the AST" in text:
            notes.append(text)
    return answered, notes


def session_queries(c, d, case, after_texts, before, after, rounds_until):
    """Ask every query; repeat until rounds_until (seconds since start)."""
    records = []
    while True:
        for q in case["queries"]:
            rid, ts, tr, res, err = ask(c, d, q, after_texts, case)
            records.append(dict(query=q[0], method=q[4], rid=rid, t_send=ts,
                                t_reply=tr, error=err,
                                answer=summarize(res, d)))
        if time.time() - c.t0 >= rounds_until:
            return records
        time.sleep(GAP)


def judge(records, log, case, d, before, after):
    truth = {q[0]: locations(q[5], after, d) for q in case["queries"]}
    stale = {q[0]: locations(q[6], before, d) for q in case["queries"]}
    for r in records:
        r["path"], r["notes"] = path_of(log, r["rid"], r["method"])
        got = [tuple(x) for x in r["answer"]]
        want = [tuple(x) for x in truth[r["query"]]]
        if r["method"] == "definition":
            r["verdict"] = "correct" if got == want else (
                "stale" if got == [tuple(x) for x in stale[r["query"]]]
                else "other")
        else:
            r["verdict"] = "correct" if set(got) == set(want) else (
                "stale" if set(got) == set(tuple(x) for x in stale[r["query"]])
                else "other")
    return truth, stale


def main():
    case_name, label, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    case = CASES[case_name]
    d = os.path.realpath(os.path.join(outdir, "work", case_name + "-" + label))
    if len(sys.argv) > 6:
        # rerun on another label's work directory (same files, other binary)
        d = os.path.realpath(os.path.join(outdir, "work", sys.argv[6]))
    # "rerun TAG": only another session s3 on the existing work directory.
    rerun = sys.argv[5] if len(sys.argv) > 5 and sys.argv[4] == "rerun" else None
    if not rerun:
        if os.path.exists(d):
            shutil.rmtree(d)
        os.makedirs(d)
    before = dict(case["before"])
    after = dict(before)
    after.update(case["after"])
    if not rerun:
        write_files(d, before)
    after_texts = {k: text_of(after, d, k) for k in after}
    before_texts = {k: text_of(before, d, k) for k in before}
    logs = os.path.join(outdir, "logs")
    os.makedirs(logs, exist_ok=True)
    prefix = os.path.join(logs, case_name + "-" + label)
    if rerun:
        prefix += "-rerun" + rerun
        indexed = None
    else:
        # Session 1: index from scratch.
        c = start(label, d, prefix + "-s1.log")
        c.did_open(os.path.join(d, "main.cpp"))
        indexed = c.wait_index_end(180)
        time.sleep(1.0)
        c.stop()
    shards = sorted(os.listdir(os.path.join(d, ".cache", "clangd", "index")))

    # The change.
    if not rerun and not case["unsaved"] and not case.get("live"):
        write_files(d, case["after"])

    result = dict(case=case_name, label=label, binary=BINARIES[label],
                  session1_index_ended=indexed, shards=shards, sessions={})
    sessions = (("s3", 0.0),) if rerun else (("s2", POLL), ("s3", 0.0))
    for sname, poll in sessions:
        log_path = "%s-%s.log" % (prefix, sname)
        c = start(label, d, log_path)
        for name in case["open_first"]:
            text = after_texts[name] if case["unsaved"] else None
            c.did_open(os.path.join(d, name), text)
        opened = set(case["open_first"])
        for q in case["queries"]:
            if q[1] not in opened:
                c.did_open(os.path.join(d, q[1]))
                opened.add(q[1])
        if sname == "s2" and case.get("live"):
            # Parsed with the old headers first; the answers before the
            # change are not judged.
            session_queries(c, d, case, before_texts, before_texts,
                            after_texts, 0.0)
            time.sleep(max(0.0, 6.0 - (time.time() - c.t0)))
            write_files(d, case["after"])
            result["t_change"] = time.time() - c.t0
            for name in case["after"]:
                c.did_open(os.path.join(d, name))
                c.notify("textDocument/didSave", {"textDocument": {
                    "uri": lsp.uri(os.path.join(d, name))}})
            poll = result["t_change"] + POLL
        records = session_queries(c, d, case, after_texts, before_texts,
                                  after_texts, poll)
        c.wait_index_end(5 if sname == "s3" else 30)
        time.sleep(0.5)
        c.stop()
        log = parse_log(log_path, c.t0)
        truth, stale = judge(records, log, case, d, before_texts, after_texts)
        events = [(t, x) for t, x in log
                  if x.startswith("Indexed ") or x.startswith("Built preamble")
                  or x.startswith("Enqueueing") or "Reindexing" in x
                  or x.startswith("Indexing ")]
        result["sessions"][sname] = dict(records=records, events=events)
        result["truth"] = {k: v for k, v in truth.items()}
        result["stale_answer"] = {k: v for k, v in stale.items()}
    with open(prefix + ".json", "w") as f:
        json.dump(result, f, indent=1)
    print_summary(result)


def print_summary(r):
    print("== %s / %s" % (r["case"], r["label"]))
    for sname, s in r["sessions"].items():
        print(" session %s" % sname)
        for t, x in s["events"]:
            print("   %7.3f %s" % (t, x[:150]))
        seen = {}
        for rec in s["records"]:
            key = (rec["query"], rec["verdict"], rec["path"])
            if key in seen:
                seen[key][1] = rec["t_reply"]
                seen[key][2] += 1
                continue
            seen[key] = [rec["t_reply"], rec["t_reply"], 1, rec]
        for (qname, verdict, path), (t1, t2, n, rec) in seen.items():
            print("   %-36s %-7s %-5s x%-3d %6.3f..%6.3f s %s" % (
                qname, verdict, path, n, t1, t2, rec["answer"]))
            for note in rec["notes"][:2]:
                print("        " + note[:160])


if __name__ == "__main__":
    main()
