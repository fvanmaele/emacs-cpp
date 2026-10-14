#!/usr/bin/env python3
"""texlab: no textDocument/rangeFormatting, and FormattingOptions ignored for LaTeX.

Usage: python3 texlab_range_formatting_repro.py [TEXLAB]

Starts TEXLAB (default: texlab on PATH) over stdio in a fresh temporary directory
holding one LaTeX file, then:
  1. prints the formatting capabilities from the initialize result;
  2. sends textDocument/rangeFormatting for the itemize list (lines 3 - 6);
  3. sends textDocument/formatting with insertSpaces true, tabSize 2;
  4. runs `latexindent --lines 3-6` on the same file, for comparison.
Needs only Python 3 and latexindent. Part of emacs-cpp (O-51, O-53, D-101, D-103).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

SOURCE = (
    "\\documentclass{article}\n"
    "\\begin{document}\n"
    "\\begin{itemize}\n"
    "\\item one\n"
    "\\item two\n"
    "\\end{itemize}\n"
    "\\begin{enumerate}\n"
    "\\item three\n"
    "\\end{enumerate}\n"
    "\\end{document}\n"
)


class Server:
    def __init__(self, program, directory):
        self.process = subprocess.Popen(
            [program], cwd=directory, stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        assert self.process.stdin and self.process.stdout
        self.input, self.output = self.process.stdin, self.process.stdout
        self.next_id = 0

    def send(self, message):
        body = json.dumps(message).encode()
        self.input.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        self.input.flush()

    def receive(self):
        length = None
        while True:
            line = self.output.readline().decode().strip()
            if not line:
                break
            name, _, value = line.partition(":")
            if name.lower() == "content-length":
                length = int(value)
        if length is None:
            sys.exit("texlab sent a message without Content-Length")
        return json.loads(self.output.read(length))

    def request(self, method, params):
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": self.next_id, "method": method,
                   "params": params})
        while True:
            message = self.receive()
            if message.get("id") == self.next_id and "method" not in message:
                return message
            if "method" in message and "id" in message:  # a request to the client
                result = ([{}] * len(message["params"]["items"])
                          if message["method"] == "workspace/configuration" else None)
                self.send({"jsonrpc": "2.0", "id": message["id"], "result": result})

    def notify(self, method, params):
        self.send({"jsonrpc": "2.0", "method": method, "params": params})


def main():
    program = sys.argv[1] if len(sys.argv) > 1 else "texlab"
    directory = tempfile.mkdtemp(prefix="texlab-repro-")
    path = os.path.join(directory, "main.tex")
    with open(path, "w") as file:
        file.write(SOURCE)
    uri = "file://" + path
    server = Server(program, directory)
    try:
        init = server.request("initialize", {
            "processId": os.getpid(), "rootUri": "file://" + directory,
            "capabilities": {"textDocument": {"formatting": {}, "rangeFormatting": {}}}})
        info = init["result"].get("serverInfo", {})
        capabilities = init["result"]["capabilities"]
        print("server:", info.get("name"), info.get("version"))
        for key in ("documentFormattingProvider", "documentRangeFormattingProvider"):
            print(f"  {key}: {json.dumps(capabilities.get(key))}")
        server.notify("initialized", {})
        server.notify("textDocument/didOpen", {"textDocument": {
            "uri": uri, "languageId": "latex", "version": 0, "text": SOURCE}})

        print("\ntextDocument/rangeFormatting, lines 3 - 6 (0-based 2 - 5):")
        reply = server.request("textDocument/rangeFormatting", {
            "textDocument": {"uri": uri},
            "range": {"start": {"line": 2, "character": 0},
                      "end": {"line": 6, "character": 0}},
            "options": {"tabSize": 2, "insertSpaces": True}})
        print("  " + json.dumps(reply.get("error", reply.get("result"))))

        print("\ntextDocument/formatting, insertSpaces true, tabSize 2:")
        reply = server.request("textDocument/formatting", {
            "textDocument": {"uri": uri},
            "options": {"tabSize": 2, "insertSpaces": True}})
        for edit in reply.get("result") or []:
            for line in edit["newText"].splitlines():
                print("  " + repr(line))

        print("\nlatexindent --lines 3-6 main.tex:")
        output = subprocess.run(
            ["latexindent", "-c", directory + "/", "--lines", "3-6", path],
            capture_output=True, text=True, check=True).stdout
        for line in output.splitlines():
            print("  " + repr(line))

        server.request("shutdown", None)
        server.notify("exit", None)
        server.process.wait(timeout=10)
    finally:
        if server.process.poll() is None:
            server.process.kill()
        shutil.rmtree(directory)


if __name__ == "__main__":
    main()
