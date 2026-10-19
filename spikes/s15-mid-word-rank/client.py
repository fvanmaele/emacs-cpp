"""S15: workspace/symbol replies of one clangd for mid-word and fuzzy queries.

Spike code, never promoted.
  python3 -I client.py CLANGD DBDIR OPENED OUT [WAIT_S]
Starts CLANGD with the shipped config's flags plus --compile-commands-dir=DBDIR,
opens OPENED (a source of the project, by its real path, as eglot does), waits until
the background index is idle (every progress begun has ended, none for 5 s; at most
WAIT_S, default 600) and a probe query answers the same twice in a row, then sends
each query twice with limit 100 (as C-c l s) and 100000 (every match), with
middleMatch 3 and looseScope as the config sends them (D-113), and writes one JSON
line per query and limit (the second reply; both times):
  {"set", "query", "limit", "ms": [first, second], "symbols": [{"id", "name",
   "container", "kind", "score"}] in reply order}
"id" is the symbol's file and start position, so two runs can be compared.
"""
import json
import subprocess
import sys
import threading
import time

clangd, dbdir, opened, out = sys.argv[1:5]
wait = float(sys.argv[5]) if len(sys.argv) > 5 else 600

QUERIES = {
    "middle": ["ector", "ngulat", "olution", "ssembl", "ndari", "atrix", "uadrat",
               "egree", "ernel", "xecution", "olicy", "ensor"],
    "fuzzy": ["typ", "ope", "vec", "tri", "dof", "sol", "ass", "fin", "mat", "cel",
              "quad", "poi", "gri", "out", "bou", "fe_", "sparse", "count", "vector",
              "triang"],
}

proc = subprocess.Popen(
    [clangd, "--background-index", "--navigation-from-index", "--header-flags-from-index",
     "--compile-commands-dir=" + dbdir, "--log=error"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
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
        time.sleep(0.001)
    message, end = replies.pop(rid)
    if "error" in message:
        sys.exit("s15 client: %s failed: %s" % (method, message["error"]))
    return message["result"], (end - start) * 1000


def symbols(query, limit):
    return request("workspace/symbol", {"query": query, "limit": limit,
                                        "middleMatch": 3, "looseScope": True})


init, _ = request("initialize", {"rootUri": "file://" + dbdir, "capabilities": {
    "window": {"workDoneProgress": True}}})
if not init["capabilities"].get("workspaceSymbolMatchesProvider", {}).get("middleMatch"):
    sys.exit("s15 client: %s does not offer middleMatch (patch 0012)" % clangd)
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
with open(opened) as f:
    text = f.read()
send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
    "uri": "file://" + opened, "languageId": "cpp", "version": 1, "text": text}}})

start = time.time()
while time.time() - start < wait:
    time.sleep(1)
    if (progress["begin"] and progress["begin"] == progress["end"]
            and time.time() - progress["last"] > 5):
        break
probe = None
while time.time() - start < wait:
    reply, _ = symbols("ector", 100000)
    if reply == probe:
        break
    probe = reply
    time.sleep(2)
print("s15 client: index idle after %.0f s" % (time.time() - start), file=sys.stderr)

with open(out, "w") as f:
    for name, queries in QUERIES.items():
        for query in queries:
            for limit in (100, 100000):
                first, ms1 = symbols(query, limit)
                reply, ms2 = symbols(query, limit)
                f.write(json.dumps({
                    "set": name, "query": query, "limit": limit,
                    "ms": [round(ms1, 2), round(ms2, 2)],
                    "symbols": [{
                        "id": "%s:%d:%d" % (s["location"]["uri"],
                                            s["location"]["range"]["start"]["line"],
                                            s["location"]["range"]["start"]["character"]),
                        "name": s["name"], "container": s.get("containerName", ""),
                        "kind": s["kind"], "score": s.get("score")} for s in reply]}) + "\n")
proc.kill()
