"""Minimal LSP client over stdin/stdout for clangd (S23 reproduce).

Starts clangd as a child process (its own process group, pid recorded),
answers the server's requests with null, records $/progress notifications
and lets the caller send requests and wait for their replies.
"""
import json
import os
import signal
import subprocess
import threading
import time


def uri(path):
    return "file://" + os.path.abspath(path)


class Client:
    def __init__(self, argv, cwd, log_path):
        self.log_file = open(log_path, "w")
        self.t0 = time.time()
        self.proc = subprocess.Popen(
            argv, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self.log_file, start_new_session=True)
        self.pid = self.proc.pid
        self.next_id = 1
        self.lock = threading.Condition()
        self.replies = {}
        self.progress = []      # (time, token, kind, message)
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _send(self, msg):
        body = json.dumps(msg).encode()
        self.proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        self.proc.stdin.flush()

    def _read(self):
        out = self.proc.stdout
        while True:
            length = None
            while True:
                line = out.readline()
                if not line:
                    return
                line = line.strip()
                if not line:
                    break
                if line.lower().startswith(b"content-length:"):
                    length = int(line.split(b":")[1])
            msg = json.loads(out.read(length))
            if "id" in msg and "method" in msg:
                # A server request: progress creation, registration, config.
                self._send({"jsonrpc": "2.0", "id": msg["id"], "result": None})
            elif "id" in msg:
                with self.lock:
                    self.replies[msg["id"]] = msg
                    self.lock.notify_all()
            elif msg.get("method") == "$/progress":
                v = msg["params"].get("value", {})
                with self.lock:
                    self.progress.append((time.time(), msg["params"].get("token"),
                                          v.get("kind"), v.get("message")))
                    self.lock.notify_all()

    def request_async(self, method, params):
        with self.lock:
            rid = self.next_id
            self.next_id += 1
        self._send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params})
        return rid

    def wait_reply(self, rid, timeout=60):
        end = time.time() + timeout
        with self.lock:
            while rid not in self.replies:
                left = end - time.time()
                if left <= 0:
                    raise TimeoutError("no reply to request %d" % rid)
                self.lock.wait(left)
            return self.replies.pop(rid)

    def request(self, method, params, timeout=60):
        return self.wait_reply(self.request_async(method, params), timeout)

    def notify(self, method, params):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def initialize(self, root):
        caps = {"window": {"workDoneProgress": True},
                "textDocument": {"definition": {"linkSupport": False},
                                 "synchronization": {"didSave": True}}}
        self.request("initialize", {"processId": os.getpid(), "rootUri": uri(root),
                                    "capabilities": caps}, timeout=30)
        self.notify("initialized", {})

    def wait_index_end(self, timeout):
        """Wait for the background index's progress to end; True if it did."""
        end = time.time() + timeout
        with self.lock:
            while True:
                kinds = [p[2] for p in self.progress
                         if p[1] == "backgroundIndexProgress"]
                if "end" in kinds:
                    return True
                left = end - time.time()
                if left <= 0:
                    return False
                self.lock.wait(left)

    def did_open(self, path, text=None):
        if text is None:
            with open(path) as f:
                text = f.read()
        self.notify("textDocument/didOpen", {"textDocument": {
            "uri": uri(path), "languageId": "cpp", "version": 1, "text": text}})

    def stop(self):
        try:
            self.request("shutdown", None, timeout=15)
            self.notify("exit", None)
            self.proc.wait(timeout=15)
        except Exception:
            # Only this child's own process group, by the pid recorded at start.
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            self.proc.wait()
        self.log_file.close()
