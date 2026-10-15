"""S14: workspace/symbol replies of one clangd for three sets of queries.

Spike code, never promoted.
  python3 -I client.py CLANGD DBDIR OPENED OUT [WAIT_S]
Starts CLANGD with the shipped config's flags plus --compile-commands-dir=DBDIR, opens
OPENED (a source file of the project, by its real path, as eglot does), waits until
the background index is idle (every progress begun has ended, none for 5 s; at most
WAIT_S, default 300) and a probe query answers the same twice in a row, then sends each query twice, with limit 100 (as C-c l s) and
10000 (as M-o's `s'), and writes one JSON line per request to OUT:
  {"set", "query", "limit", "ms", "names": [container::name in reply order],
   "bare": [the names alone, same order], "scores": [clangd's score field]}
"""
import json
import os
import subprocess
import sys
import threading
import time

clangd, dbdir, opened, out = sys.argv[1:5]
wait = float(sys.argv[5]) if len(sys.argv) > 5 else 300

# Fuzzy queries as typed today (regressions), mid-word ones (O-57 (c)), qualified
# ones with an abbreviated scope (O-57 (b)).
QUERIES = {
    "fuzzy": ["typ", "ope", "vec", "tri", "dof", "sol", "ass", "fin", "mat", "cel",
              "quad", "poi", "gri", "out", "bou", "fe_", "sparse", "count", "vector",
              "triang"],
    "middle": ["ector", "ngulat", "olution", "ssembl", "ndari", "atrix", "uadrat",
               "egree"],
    "scoped": ["geom::vert", "gi::vert", "tria::n_act", "dof::n_dofs", "vt::interp",
               "spm::vmult", "dealii::vt::interp"],
}

proc = subprocess.Popen(
    [clangd, "--background-index", "--navigation-from-index", "--header-flags-from-index",
     "--compile-commands-dir=" + dbdir, "--log=error"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
replies, progress = {}, {"begin": 0, "end": 0, "last": time.time()}
lock = threading.Lock()


def send(message):
    body = json.dumps(message).encode()
    proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    proc.stdin.flush()


def read_loop():
    stream = proc.stdout
    while True:
        header = b""
        while not header.endswith(b"\r\n\r\n"):
            byte = stream.read(1)
            if not byte:
                return
            header += byte
        length = int([h for h in header.decode().split("\r\n")
                      if h.lower().startswith("content-length")][0].split(":")[1])
        message = json.loads(stream.read(length))
        if "method" in message:
            if message["method"] == "$/progress":
                kind = message["params"]["value"].get("kind")
                with lock:
                    if kind in ("begin", "end"):
                        progress[kind] += 1
                    progress["last"] = time.time()
            if "id" in message:  # a request from the server: accept it
                send({"jsonrpc": "2.0", "id": message["id"], "result": None})
        elif "id" in message:
            with lock:
                replies[message["id"]] = message


threading.Thread(target=read_loop, daemon=True).start()
next_id = [0]


def request(method, params, timeout=60):
    next_id[0] += 1
    rid = next_id[0]
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
    deadline = time.time() + timeout
    while time.time() < deadline:
        with lock:
            if rid in replies:
                return replies.pop(rid)
        time.sleep(0.001)
    raise SystemExit("s14 client: no reply to %s within %d s" % (method, timeout))


opened = os.path.realpath(opened)
root = os.path.dirname(os.path.realpath(dbdir))
request("initialize", {"processId": os.getpid(), "rootUri": "file://" + root,
                       "capabilities": {"window": {"workDoneProgress": True}}})
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
with open(opened) as f:
    send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
        "uri": "file://" + opened, "languageId": "cpp", "version": 1, "text": f.read()}}})
start = time.time()
while time.time() - start < wait:
    with lock:
        idle = (progress["begin"] == progress["end"]
                and time.time() - progress["last"] > 5)
    if idle and time.time() - start > 10:
        break
    time.sleep(0.2)
# The index swaps in what it rebuilt some time after the last progress ends (dry
# run 3: replies still changed), so wait until a probe gives the same reply twice in
# a row, 2 s apart (at most 120 s).
previous, settled = None, False
probe_deadline = time.time() + 120
while time.time() < probe_deadline:
    names = [(r.get("containerName") or "") + "::" + r["name"] for r in
             request("workspace/symbol", {"query": "vec", "limit": 10000}).get("result") or []]
    if names == previous:
        settled = True
        break
    previous = names
    time.sleep(2)
with open(out, "w") as sink:
    for name, queries in QUERIES.items():
        for query in queries:
            for limit in (100, 10000):
                t0 = time.time()
                reply = request("workspace/symbol", {"query": query, "limit": limit})
                ms = (time.time() - t0) * 1000
                result = reply.get("result") or []
                names = [(s.get("containerName") or "") + "::" + s["name"] for s in result]
                sink.write(json.dumps({"set": name, "query": query, "limit": limit,
                                       "ms": round(ms, 2), "names": names,
                                       "bare": [s["name"] for s in result],
                                       "scores": [s.get("score") for s in result]}) + "\n")
print("s14 client: index idle and %s after %.0f s; %d requests written to %s"
      % ("settled" if settled else "NOT settled", time.time() - start,
         2 * sum(map(len, QUERIES.values())), out))
proc.kill()
