"""S19 criterion 6 (D-174): the time of each key M-o sends a symbol request for.

Spike code, never promoted.
  python3 -I keys.py CLANGD INDEX PROJECT FILE OUT [--gap]
Starts CLANGD as the shipped config does (--background-index,
--navigation-from-index, --header-flags-from-index, --index-file=INDEX, D-130) on
PROJECT's compile database (PROJECT/build/linux-debug), opens PROJECT/FILE, waits
until the background index is idle (every progress begun has ended, none for 10 s)
and the static index has loaded (a probe query answering the same three times 3 s
apart; at most S19_WAIT seconds, default 1800), then sends each key: every prefix of
three or more letters (M-o asks symbols from the third key) of S11's words (main,
vec, Tri, assemble, Sol) and of the 12 queries of RESEARCH_go_to_anything 20, as
the shipped M-o sends it (limit 10000, middleMatch 3, looseScope; gapMatch 3 with
--gap), three times; the last two are timed.
Writes one JSON line per key: {"key", "ms": [second, third], "items": count}; a
reply's time ends when its last byte is read, before the client parses it.
"""
import json
import os
import subprocess
import sys
import threading
import time

clangd, index, project, opened, out = sys.argv[1:6]
gap = "--gap" in sys.argv[6:]
wait = float(os.environ.get("S19_WAIT", "1800"))
WORDS = ["main", "vec", "Tri", "assemble", "Sol",
         "eto", "ptr", "get", "tria", "nac", "rnm", "cml", "vec", "vector", "dfh",
         "fev", "qgau"]
KEYS = list(dict.fromkeys(w[:n] for w in WORDS for n in range(3, len(w) + 1)))

path = os.path.join(project, opened)
proc = subprocess.Popen(
    [clangd, "--background-index", "--navigation-from-index", "--header-flags-from-index",
     "--compile-commands-dir=" + os.path.join(project, "build", "linux-debug"),
     "--index-file=" + os.path.abspath(index), "--log=error"],
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
        body = proc.stdout.read(int(headers["Content-Length"]))
        arrived = time.time()  # before parsing: the client's JSON is not clangd's time
        message = json.loads(body)
        if "method" in message and "id" in message:
            send({"jsonrpc": "2.0", "id": message["id"], "result": None})
        elif message.get("method") == "$/progress":
            kind = message["params"]["value"]["kind"]
            if kind in ("begin", "end"):
                progress[kind] += 1
            progress["last"] = time.time()
        elif "id" in message:
            replies[message["id"]] = (message, arrived)


threading.Thread(target=reader, daemon=True).start()
next_id = [0]


def request(method, params):
    next_id[0] += 1
    rid = next_id[0]
    start = time.time()
    send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
    while rid not in replies:
        if proc.poll() is not None:
            sys.exit("s19 keys: clangd exited (%s)" % proc.returncode)
        time.sleep(0.0005)
    message, end = replies.pop(rid)
    if "error" in message:
        sys.exit("s19 keys: %s failed: %s" % (method, message["error"]))
    return message["result"], (end - start) * 1000


def symbols(query):
    params = {"query": query, "limit": 10000, "middleMatch": 3, "looseScope": True}
    if gap:
        params["gapMatch"] = 3
    return request("workspace/symbol", params)


try:
    init, _ = request("initialize", {"rootUri": "file://" + project, "capabilities": {
        "window": {"workDoneProgress": True}}})
    offered = init["capabilities"].get("workspaceSymbolMatchesProvider", {})
    if gap and not offered.get("gapMatch"):
        sys.exit("s19 keys: %s does not offer gapMatch (the spike's patch)" % clangd)
    send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
    with open(path) as f:
        text = f.read()
    send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
        "uri": "file://" + path, "languageId": "cpp", "version": 1, "text": text}}})
    start = time.time()
    while time.time() - start < wait:
        time.sleep(1)
        if (progress["begin"] and progress["begin"] == progress["end"]
                and time.time() - progress["last"] > 10):
            break
    probe, same = None, 0
    while time.time() - start < wait:
        reply, _ = symbols("vector")
        same = same + 1 if reply == probe and reply else 0
        if same == 2:
            break
        probe = reply
        time.sleep(3)
    else:
        sys.exit("s19 keys: not idle after %.0f s" % wait)
    print("s19 keys: idle after %.0f s, %d keys" % (time.time() - start, len(KEYS)),
          file=sys.stderr)
    with open(out, "w") as f:
        for key in KEYS:
            symbols(key)
            _, ms2 = symbols(key)
            reply, ms3 = symbols(key)
            f.write(json.dumps({"key": key, "ms": [round(ms2, 2), round(ms3, 2)],
                                "items": len(reply)}) + "\n")
finally:
    proc.kill()
    proc.wait()
