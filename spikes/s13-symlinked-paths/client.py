"""S13: a minimal LSP client asking clangd for references to calc::combine.

Spike code, never promoted.
  python3 -I client.py CLANGD PROJECT DBDIR LOG FILE [WAIT_S]
Starts CLANGD with the shipped config's flags plus --compile-commands-dir=DBDIR and
--log=verbose (stderr to LOG), sends PROJECT's real path as the root and opens FILE
(relative to PROJECT) under its real path, as eglot does.  Waits for the background
index to finish (every progress begun has ended, none for 3 s; at most WAIT_S, default
120), then asks for references to combine at line 5, column 5 of FILE (its definition
in src/combine.cpp, its declaration in include/calc/api.h; clangd answers only for an
opened file) and prints one line:
  references N files M index_end_s T indexed K
K counts the "Indexed /..." lines in LOG: translation units indexed in this run.
"""
import json
import os
import subprocess
import sys
import threading
import time

clangd, project, dbdir, logpath, opened = sys.argv[1:6]
wait = float(sys.argv[6]) if len(sys.argv) > 6 else 120
project = os.path.realpath(project)
proc = subprocess.Popen(
    [clangd, "--background-index", "--navigation-from-index", "--header-flags-from-index",
     "--compile-commands-dir=" + dbdir, "--log=verbose"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(logpath, "w"))
replies = {}
progress = {"begin": 0, "end": 0, "last": 0.0}


def send(message):
    body = json.dumps(message).encode()
    proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    proc.stdin.flush()


def read_loop():
    stream = proc.stdout
    while True:
        headers = {}
        while True:
            line = stream.readline()
            if not line:
                return
            line = line.decode().strip()
            if not line:
                break
            key, value = line.split(":", 1)
            headers[key.lower()] = value.strip()
        message = json.loads(stream.read(int(headers["content-length"])))
        method = message.get("method")
        if "id" in message and method is None:
            replies[message["id"]] = message
        elif method == "window/workDoneProgress/create":
            send({"jsonrpc": "2.0", "id": message["id"], "result": None})
        elif method == "$/progress":
            params = message["params"]
            kind = params["value"].get("kind")
            if params["token"] == "backgroundIndexProgress" and kind in progress:
                progress[kind] += 1
                progress["last"] = time.time()


def request(number, method, params):
    send({"jsonrpc": "2.0", "id": number, "method": method, "params": params})
    start = time.time()
    while number not in replies:
        if time.time() - start > 30:
            sys.exit("s13 client: no reply to " + method)
        time.sleep(0.05)
    return replies[number]


threading.Thread(target=read_loop, daemon=True).start()
request(1, "initialize", {"processId": os.getpid(), "rootUri": "file://" + project,
                          "capabilities": {"window": {"workDoneProgress": True}}})
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
path = os.path.join(project, opened)
send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
    "uri": "file://" + path, "languageId": "cpp", "version": 1,
    "text": open(path).read()}}})
start = time.time()
while not (progress["end"] and progress["end"] == progress["begin"]
           and time.time() - progress["last"] > 3):
    if time.time() - start > wait:
        sys.exit("s13 client: background index not finished after %g s" % wait)
    time.sleep(0.1)
index_end = progress["last"] - start
reply = request(2, "textDocument/references", {
    "textDocument": {"uri": "file://" + path}, "position": {"line": 4, "character": 4},
    "context": {"includeDeclaration": True}})
locations = reply.get("result") or []
files = {loc["uri"] for loc in locations}
request(3, "shutdown", None)
send({"jsonrpc": "2.0", "method": "exit"})
proc.wait(10)
indexed = sum(1 for line in open(logpath) if "] Indexed /" in line)
print("references %d files %d index_end_s %.1f indexed %d"
      % (len(locations), len(files), index_end, indexed))
