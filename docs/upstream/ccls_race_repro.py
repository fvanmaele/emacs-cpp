#!/usr/bin/env python3
"""Reproduce ccls aborting in DB::applyIndexUpdate (query.cc: Assertion `v >= 0').

Creates a three-file CMake project in DIR, configures it, then RUNS times: starts ccls
with an empty cache, sends initialize / initialized / didOpen(main.cc) /
didChangeConfiguration (the sequence eglot sends), waits, shuts down.  Prints how many
runs ended with SIGABRT.  Needs ccls, cmake, ninja, a C++ compiler, Python 3.

Usage: ccls_race_repro.py DIR [RUNS] [THREADS]   (THREADS: omit for ccls's default)
"""
import json, os, re, shutil, subprocess, sys, threading, time

FILES = {
    "CMakeLists.txt": "cmake_minimum_required(VERSION 3.28)\nproject(toy CXX)\n"
                      "set(CMAKE_CXX_STANDARD 20)\nset(CMAKE_CXX_EXTENSIONS OFF)\n"
                      "add_executable(toy src/main.cc src/answer.cc)\n"
                      "target_include_directories(toy PRIVATE include)\n",
    "include/toy/answer.h": "#pragma once\nint answer();\n",
    "src/answer.cc": "#include <toy/answer.h>\nint answer() { return 42; }\n",
    "src/main.cc": "#include <toy/answer.h>\n#include <vector>\nint main() {\n"
                   "  int* unused = 0;\n  std::vector<int> values;\n"
                   "  return answer() + (unused == 0) + static_cast<int>(values.size());\n}\n",
}

def setup(root):
    for name, text in FILES.items():
        path = os.path.join(root, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
    subprocess.run(["cmake", "-S", root, "-B", os.path.join(root, "build"), "-G", "Ninja",
                    "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"], check=True,
                   stdout=subprocess.DEVNULL)

def run_once(root, threads):
    build = os.path.join(root, "build")
    cache = os.path.join(build, ".ccls-cache")
    shutil.rmtree(cache, ignore_errors=True)
    options = {"compilationDatabaseDirectory": build, "cache": {"directory": cache}}
    if threads is not None:
        options["index"] = {"threads": threads}
    proc = subprocess.Popen(["ccls"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL)
    lock = threading.Lock()

    def send(msg):
        body = json.dumps(msg).encode()
        with lock:
            proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
            proc.stdin.flush()

    def reader():  # answer server requests with null, like eglot; drop the rest
        while True:
            header = b""
            while not header.endswith(b"\r\n\r\n"):
                ch = proc.stdout.read(1)
                if not ch:
                    return
                header += ch
            msg = json.loads(proc.stdout.read(int(re.search(rb"Content-Length: (\d+)", header)[1])))
            if "method" in msg and "id" in msg:
                try:
                    send({"jsonrpc": "2.0", "id": msg["id"], "result": None})
                except BrokenPipeError:
                    return
    threading.Thread(target=reader, daemon=True).start()
    main = os.path.join(root, "src/main.cc")
    try:
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
              "params": {"processId": os.getpid(), "rootUri": "file://" + root,
                         "capabilities": {}, "initializationOptions": options}})
        time.sleep(0.03)
        send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
        send({"jsonrpc": "2.0", "method": "textDocument/didOpen",
              "params": {"textDocument": {"uri": "file://" + main, "languageId": "cpp",
                                          "version": 0, "text": FILES["src/main.cc"]}}})
        if os.environ.get("NO_CONFIGURATION_CHANGE") != "1":
            send({"jsonrpc": "2.0", "method": "workspace/didChangeConfiguration",
                  "params": {"settings": None}})
        time.sleep(6)
        send({"jsonrpc": "2.0", "id": 2, "method": "shutdown"})
        time.sleep(0.5)
        send({"jsonrpc": "2.0", "method": "exit"})
    except BrokenPipeError:
        pass
    try:
        proc.stdin.close()
    except BrokenPipeError:   # ccls already died
        pass
    try:
        return proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        return 0

if __name__ == "__main__":
    root = os.path.abspath(sys.argv[1])
    runs = int(sys.argv[2]) if len(sys.argv) > 2 else 25
    threads = int(sys.argv[3]) if len(sys.argv) > 3 else None
    setup(root)
    aborts = sum(run_once(root, threads) == -6 for _ in range(runs))
    print(f"ccls {subprocess.run(['ccls', '--version'], capture_output=True, text=True).stdout.split()[2]}"
          f", threads={threads if threads is not None else 'default'}: {aborts} of {runs} runs aborted")
    sys.exit(1 if aborts else 0)
