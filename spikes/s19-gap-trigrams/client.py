"""S19 (T-132, D-171 .. D-173): workspace/symbol and completion replies of one clangd.

Spike code, never promoted.
  python3 -I client.py CLANGD INDEX DEALII_DB OUT [--gap]
Makes a one-file project in a temporary directory (main.cc including
<deal.II/lac/vector.h>, compiled with the command DEALII_DB, the index build's
compile_commands.json, gives deal.II's lac/vector.cc), starts CLANGD with the shipped
config's flags and --index-file=INDEX (D-130), opens main.cc, waits until the
background index is idle (every progress begun has ended, none for 5 s), the static
index has loaded (it loads in the background on the first workspace/symbol, D-130)
and a probe query answers the same three times 3 s apart (at most 600 s), then for
each of the 12
queries of RESEARCH_go_to_anything 20:
  workspace/symbol with limit 100 (C-c l s) and 10000 (M-o, D-083), middleMatch 3
  and looseScope as the config sends them (D-113), and gapMatch 3 with --gap;
  textDocument/completion after `dealii::QUERY` in main.cc.
Writes one JSON line per request (the second of two sends):
  {"kind": "symbol"|"completion", "query", "limit", "ms": [first, second],
   "items": [...] in reply order}
A symbol item is its file:line:column and qualified name ("scores" beside them,
clangd's score per item), a completion item its label and detail.
"""
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time

clangd, index, dealii_db, out = sys.argv[1:5]
gap = "--gap" in sys.argv[5:]
QUERIES = ["eto", "ptr", "get", "tria", "nac", "rnm", "cml", "vec", "vector", "dfh",
           "fev", "qgau"]
HEADER = "#include <deal.II/lac/vector.h>\n"

project = tempfile.mkdtemp(prefix="s19-client.")
main = os.path.join(project, "main.cc")


def source(tail):
    return HEADER + "void s19() { " + tail + " }\n"


with open(main, "w") as f:
    f.write(source(""))
with open(dealii_db) as f:
    entry = next(e for e in json.load(f) if e["file"].endswith("/lac/vector.cc"))
arguments = entry.get("arguments") or shlex.split(entry["command"])
arguments = [main if a == entry["file"] else a for a in arguments]
if "-o" in arguments:
    arguments[arguments.index("-o") + 1] = os.path.join(project, "main.o")
with open(os.path.join(project, "compile_commands.json"), "w") as f:
    json.dump([{"directory": project, "file": main, "arguments": arguments}], f)

proc = subprocess.Popen(
    [clangd, "--background-index", "--navigation-from-index", "--header-flags-from-index",
     "--compile-commands-dir=" + project, "--index-file=" + os.path.abspath(index),
     "--log=" + os.environ.get("S19_LOG", "error")],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    stderr=open(os.environ["S19_STDERR"], "w") if os.environ.get("S19_STDERR") else subprocess.DEVNULL)
lock = threading.Lock()
replies, progress = {}, {"begin": 0, "end": 0, "last": time.time()}


def send(message):
    body = json.dumps(message).encode()
    with lock:
        proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        proc.stdin.flush()


def reader():
    while True:
        headers = {}
        while True:
            line = proc.stdout.readline()
            if not line:
                return
            line = line.decode().strip()
            if not line:
                break
            key, value = line.split(": ", 1)
            headers[key] = value
        message = json.loads(proc.stdout.read(int(headers["Content-Length"])))
        if "method" in message and "id" in message:
            send({"jsonrpc": "2.0", "id": message["id"], "result": None})
        elif message.get("method") == "$/progress":
            kind = message["params"]["value"]["kind"]
            if kind in ("begin", "end"):
                progress[kind] += 1
            progress["last"] = time.time()
        elif "id" in message:
            replies[message["id"]] = (message, time.time())


threading.Thread(target=reader, daemon=True).start()
next_id = [0]


def request(method, params):
    next_id[0] += 1
    rid = next_id[0]
    start = time.time()
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
    while rid not in replies:
        if proc.poll() is not None:
            sys.exit("s19 client: clangd exited (%s)" % proc.returncode)
        time.sleep(0.001)
    message, end = replies.pop(rid)
    if "error" in message:
        sys.exit("s19 client: %s failed: %s" % (method, message["error"]))
    return message["result"], (end - start) * 1000


def symbols(query, limit):
    params = {"query": query, "limit": limit, "middleMatch": 3, "looseScope": True}
    if gap:
        params["gapMatch"] = 3
    return request("workspace/symbol", params)


version = [1]


def complete(query):
    version[0] += 1
    text = source("dealii::" + query)
    send({"jsonrpc": "2.0", "method": "textDocument/didChange", "params": {
        "textDocument": {"uri": "file://" + main, "version": version[0]},
        "contentChanges": [{"text": text}]}})
    line = text.count("\n", 0, text.index("dealii::"))
    column = len(text.split("\n")[line].split(query)[0]) + len(query)
    return request("textDocument/completion", {
        "textDocument": {"uri": "file://" + main},
        "position": {"line": line, "character": column}})


try:
    init, _ = request("initialize", {"rootUri": "file://" + project, "capabilities": {
        "window": {"workDoneProgress": True}}})
    offered = init["capabilities"].get("workspaceSymbolMatchesProvider", {})
    if gap and not offered.get("gapMatch"):
        sys.exit("s19 client: %s does not offer gapMatch (the spike's patch)" % clangd)
    send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
    send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
        "uri": "file://" + main, "languageId": "cpp", "version": 1,
        "text": source("")}}})
    start = time.time()
    while time.time() - start < 600:
        time.sleep(1)
        if (progress["begin"] and progress["begin"] == progress["end"]
                and time.time() - progress["last"] > 5):
            break
    probe, same = None, 0
    while time.time() - start < 600:
        reply, _ = symbols("vector", 10000)
        same = same + 1 if reply == probe and reply else 0
        if same == 2:
            break
        probe = reply
        time.sleep(3)
    print("s19 client: idle after %.0f s" % (time.time() - start), file=sys.stderr)

    with open(out, "w") as f:
        for query in QUERIES:
            for limit in (100, 10000):
                _, ms1 = symbols(query, limit)
                reply, ms2 = symbols(query, limit)
                f.write(json.dumps({
                    "kind": "symbol", "query": query, "limit": limit,
                    "ms": [round(ms1, 2), round(ms2, 2)],
                    "items": ["%s:%d:%d %s%s" % (
                        s["location"]["uri"], s["location"]["range"]["start"]["line"],
                        s["location"]["range"]["start"]["character"],
                        (s.get("containerName") or "") + "::", s["name"])
                        for s in reply],
                    "scores": [s.get("score") for s in reply]}) + "\n")
        for query in QUERIES:
            _, ms1 = complete(query)
            reply, ms2 = complete(query)
            items = reply["items"] if isinstance(reply, dict) else reply
            f.write(json.dumps({
                "kind": "completion", "query": query, "limit": None,
                "ms": [round(ms1, 2), round(ms2, 2)],
                "items": ["%s | %s" % (c["label"].strip(), c.get("detail", ""))
                          for c in items]}) + "\n")
finally:
    proc.kill()
    proc.wait()
    shutil.rmtree(project, ignore_errors=True)
