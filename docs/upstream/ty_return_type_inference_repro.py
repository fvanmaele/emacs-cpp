#!/usr/bin/env python3
"""Time ty's first find-references with and without return type inference.

usage: ty_return_type_inference_repro.py ROOT FILE LINE COL [never|always]

Starts `ty server` in ROOT (a git repository), sends the inline configuration
{"analysis": {"return-type-inference": MODE}} through workspace/configuration
(section "ty", key "configuration"), opens FILE and asks
textDocument/references at LINE:COL (0-based) with includeDeclaration true.
Prints the time to the reply, the number of references and the server's RSS.
Standard library only; Linux (/proc) for the RSS.
"""
import json, os, subprocess, sys, threading, time

root, path, line, col = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
mode = sys.argv[5] if len(sys.argv) > 5 else "always"
settings = {"configuration": {"analysis": {"return-type-inference": mode}}}
server = subprocess.Popen(["ty", "server"], cwd=root, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
replies, ready = {}, threading.Condition()


def send(message):
    body = json.dumps(message).encode()
    server.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    server.stdin.flush()


def read_messages():
    while True:
        header = b""
        while not header.endswith(b"\r\n\r\n"):
            byte = server.stdout.read(1)
            if not byte:
                return
            header += byte
        length = int([h for h in header.split(b"\r\n")
                      if h.lower().startswith(b"content-length")][0].split(b":")[1])
        message = json.loads(server.stdout.read(length))
        if "method" in message and "id" in message:
            items = message["params"].get("items", [])
            result = ([settings if i.get("section") == "ty" else None for i in items]
                      if message["method"] == "workspace/configuration" else None)
            send({"jsonrpc": "2.0", "id": message["id"], "result": result})
        elif "id" in message:
            with ready:
                replies[message["id"]] = message
                ready.notify_all()


def request(ident, method, params):
    send({"jsonrpc": "2.0", "id": ident, "method": method, "params": params})
    with ready:
        while ident not in replies:
            ready.wait(600)
    return replies.pop(ident).get("result")


threading.Thread(target=read_messages, daemon=True).start()
root_uri = "file://" + os.path.abspath(root)
uri = "file://" + os.path.abspath(os.path.join(root, path))
request(1, "initialize", {"processId": os.getpid(), "rootUri": root_uri,
                          "capabilities": {"workspace": {"configuration": True}}})
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
with open(os.path.join(root, path), encoding="utf-8") as source:
    send({"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {"textDocument": {
        "uri": uri, "languageId": "python", "version": 1, "text": source.read()}}})
start = time.time()
found = request(2, "textDocument/references", {
    "textDocument": {"uri": uri}, "position": {"line": line, "character": col},
    "context": {"includeDeclaration": True}}) or []
elapsed = time.time() - start
with open("/proc/%d/status" % server.pid) as status:
    rss = int([s for s in status if s.startswith("VmRSS")][0].split()[1]) // 1024
print("return-type-inference=%s: %d references in %d files, %.2f s, server RSS %d MB"
      % (mode, len(found), len({r["uri"] for r in found}), elapsed, rss))
request(3, "shutdown", None)
send({"jsonrpc": "2.0", "method": "exit"})
