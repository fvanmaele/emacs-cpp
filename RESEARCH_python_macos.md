# RESEARCH - Python language servers and debugger on macOS (T-025)

Findings only; verdicts go to DESIGN (D-045, D-053). Owner request 2026-10-09: evaluate
functional alternatives to pyright and debugpy on macOS, for performance and
stability. First round, measured on the owner's Mac (Apple silicon, MacPorts Emacs
31.1, Python 3.14.8 from MacPorts, numpy 2.4.4 and matplotlib 3.10.8 in the user
site-packages), 2026-10-09. Load average 4 - 8 throughout (G DATA antivirus active),
so the times are not idle-machine numbers.

## 1. Candidates and where they come from
| Server | Version | MacPorts (D-053) |
|---|---|---|
| pyright (in use, D-045) | 1.1.414 | `pyright` |
| basedpyright (pyright fork) | 1.40.2 | no |
| python-lsp-server (pylsp) | 1.15.0 | `py314-python-lsp-server` |
| jedi-language-server | 0.47.0 | no |
| ty (Astral) | 0.0.85 | no |
| pyrefly (Meta) | 1.3.2 | no |

The four unported ones were installed into a throwaway virtual environment from PyPI
for this evaluation only. `ruff` is ported but its server lints and formats; it does
not navigate. Debuggers: debugpy 1.8.20 (port `py314-debugpy` 1.8.21) is the only
Debug Adapter Protocol implementation for Python that dape configures (`debugpy`,
`debugpy-module`); the built-in `M-x pdb` (gud, D-044) is the non-DAP alternative.

## 2. Language servers through eglot
Method: batch Emacs with the shipped config; the server named in front of
`eglot-server-programs`; three projects, three runs each (54 sessions):
- **toy:** `a.py` defines `area`, `b.py` uses it.
- **pip:** pip's own source (404 files, 53 directories); `ensure_dir`, defined in
  `pip/_internal/utils/misc.py`, 27 occurrences in 11 files by text search.
- **staging:** the four plotting scripts of the owner's RMO (`staging/*.py`, copied);
  `M-.` on the first `np.` call, i.e. into numpy.

Times are the range over the three runs; "M-?" is the number of references found;
memory is the server's process tree after the requests.

| Server | connect | M-. pip | M-? pip | M-. into numpy | memory (pip) |
|---|---|---|---|---|---|
| pyright | 0.7-1.1 s | 1.0-1.2 s | 1.3-1.5 s (27) | 1.4-1.7 s stub | 200 MB |
| basedpyright | 0.8-1.2 s | 2.8-3.1 s | 0.3-0.4 s (27) | 1.3-1.5 s stub | 430-440 MB |
| pylsp | 4.0-7.2 s | 1.4-2.0 s | 1.9-2.3 s (26) | 1.6-2.2 s source | 120-170 MB |
| jedi | 1.9-9.2 s | 0.9-2.6 s | 1.0-4.0 s (26) | 1.1-2.1 s source | 85-130 MB |
| ty | 0.6-1.0 s | 0.15-0.26 s | 0.12-0.16 s (26) | none (see below) | 135 MB |
| pyrefly | 0.6-0.8 s | 0.24-0.35 s | 0.43-0.45 s (**3**) | 0.3-0.4 s stub | 275-280 MB |

- **Rename:** every server renamed `ensure_dir` in all 11 files and `area` in both
  toy files. Edit counts differ only in form (pylsp sends one whole-file edit per
  file, jedi line diffs).
- **Stability:** no server exited, hung or failed a request in the 64 sessions
  (54 above plus 10 rename checks). Not tested under heavy load.
- **27 vs 26 references:** pyright and basedpyright count the definition too.
- **pyrefly** found references only in the open file (3 of 27), in every run.
- **ty** resolved nothing in numpy: it does not search the user site-packages
  (`~/Library/Python/3.14/...`, where `pip install --user` put numpy); `ty check
  --python /opt/local/bin/python3` resolves it, so its `environment.python` setting
  would.
- **pylsp and jedi** start slowly (several seconds before the first answer).

## 3. debugpy: the adapter's start against dape's wait
dape starts `python -m debugpy.adapter --port N` and then tries to connect 30 times,
0.1 s apart (`dape--create-connection`, not configurable), about 3 s in all. Measured:
seconds from starting the adapter until its port accepts a connection, 10 runs each:

| Machine | median | range | over 3 s |
|---|---|---|---|
| idle (load from the antivirus only) | 1.7 s | 0.7 - 1.9 s | 0 of 10 |
| 11 cores busy (`yes` x 11) | 6.4 s | 2.8 - 10.1 s | 7 of 10 |

The idle times alternate between about 0.8 and 1.8 s, as Emacs's own startup does
(DESIGN 11); the antivirus scanning each new process is a suspect, not measured. The
adapter's Python import itself takes 40 - 50 ms (`-X importtime`).

Whole sessions (start, stop at a breakpoint on line 2), one run each idle, 3 - 5
under the same load:
- dape's configuration (TCP): idle 5.1 s; loaded 1 of 3 stopped (13.6 s), the other
  two ended with dape's "Unable to connect to server".
- the adapter over stdio (no `--port`, dape talks through a pipe, no listening port
  at all): idle 7.2 s; loaded 0 of 5 stopped within 60 s, cause not found.
So removing dape's connect race is not enough under load; something in debugpy's own
start (the debuggee connecting back to the adapter) also stalls.

## 4. Open for the next round
- pyrefly's references with project indexing configured; ty with
  `environment.python`; then both again on pip and on a real project of the owner's.
- debugpy under load: debugpy's own timeouts (`DEBUGPY_PROCESS_SPAWN_TIMEOUT`,
  `DEBUGPY_LAUNCH_TIMEOUT`) and the antivirus as causes.
- Any non-ported server needs a ruling against D-053 (MacPorts only) before it can be
  adopted on the Mac; pylsp is the only ported alternative to pyright.
