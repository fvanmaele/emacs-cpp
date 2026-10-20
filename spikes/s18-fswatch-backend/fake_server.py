#!/usr/bin/env python3
"""S18: a language server that only registers file watches and logs the changes it
is told about. Spike code.

    python3 -I fake_server.py LOG

After `initialized` it asks for `workspace/didChangeWatchedFiles` with pyright's kind
of globs. LOG gets one line per change, "TYPE URI", plus "registered ok|error ..."."""
import json, sys

log = open(sys.argv[1], "a", buffering=1)
inp, out = sys.stdin.buffer, sys.stdout.buffer


def send(msg):
    body = json.dumps(msg).encode()
    out.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    out.flush()


def read():
    length = None
    while True:
        line = inp.readline()
        if not line:
            return None
        line = line.strip()
        if not line:
            break
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":")[1])
    return json.loads(inp.read(length))


while True:
    msg = read()
    if msg is None:
        break
    method = msg.get("method")
    if method == "initialize":
        send({"jsonrpc": "2.0", "id": msg["id"],
              "result": {"capabilities": {"textDocumentSync": 1}}})
    elif method == "initialized":
        send({"jsonrpc": "2.0", "id": "s18-register", "method": "client/registerCapability",
              "params": {"registrations": [{
                  "id": "s18-watch", "method": "workspace/didChangeWatchedFiles",
                  "registerOptions": {"watchers": [
                      {"globPattern": "**/*.{py,pyi}"},
                      {"globPattern": "**/*.{c,h}"},
                      {"globPattern": "**/pyrightconfig.json"}]}}]}})
    elif msg.get("id") == "s18-register" and "method" not in msg:
        if "error" in msg:
            log.write(f"registered error {json.dumps(msg['error'])}\n")
        else:
            log.write("registered ok\n")
    elif method == "workspace/didChangeWatchedFiles":
        for ch in msg["params"]["changes"]:
            log.write(f"{ch['type']} {ch['uri']}\n")
    elif method == "shutdown":
        send({"jsonrpc": "2.0", "id": msg["id"], "result": None})
    elif method == "exit":
        break
    elif "id" in msg and method:
        send({"jsonrpc": "2.0", "id": msg["id"], "result": None})
