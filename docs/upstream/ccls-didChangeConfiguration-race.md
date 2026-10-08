# ccls issue draft: assertion `v >= 0` in DB::applyIndexUpdate after didChangeConfiguration

Draft for https://github.com/MaskRay/ccls/issues (not filed; the owner files it).
Reproduction script: `ccls_race_repro.py` in this directory.

---

**Title:** Assertion `v >= 0` in `DB::applyIndexUpdate` when
`workspace/didChangeConfiguration` arrives during initial indexing (indexer race)

### Environment
- ccls 0.20250815.1 (Arch Linux package `extra/ccls 0.20250815.1-3`, built with
  assertions enabled), clang 23.1.1, GCC 16.2.1 headers, Linux x86_64, 16 hardware
  threads.
- Client: Emacs 31.1 eglot 1.24.31; also reproduced with the stand-alone script below
  (no editor).

### What happens
ccls aborts shortly after start:

```
ccls: /usr/src/debug/ccls/ccls-0.20250815.1/src/query.cc:275: auto ccls::DB::applyIndexUpdate(IndexUpdate *)::(lambda)::operator()(std::unordered_map<int, int> &, Usr, Kind, DeclRef &, int) const: Assertion `v >= 0' failed.
```

The last log lines before it are `pipeline.cc:380 I store index for <libstdc++ header>
(delta: 1)`. `coredumpctl` shows SIGABRT in the main thread via `__assert_fail`.

### Reproduction
`ccls_race_repro.py DIR [RUNS] [THREADS]` creates a three-file CMake project in DIR,
then RUNS times starts ccls with an empty cache and sends exactly:

1. `initialize` (rootUri, `initializationOptions`: `compilationDatabaseDirectory`,
   `cache.directory`; empty client capabilities)
2. `initialized`
3. `textDocument/didOpen` for `src/main.cc`
4. `workspace/didChangeConfiguration` with `{"settings": null}` (eglot sends this
   right after `initialized`)

and counts runs that end with SIGABRT.

| variant (25 runs each) | aborted runs |
|---|---|
| default `index.threads` (all cores) | 11 |
| `index.threads` = 1 | 0 |
| default threads, step 4 omitted | 0 |

### Likely cause
`MessageHandler::workspace_didChangeConfiguration` (src/messages/workspace.cc) reloads
the project and calls `project->index(wfiles, RequestId())`, re-queuing every file
while the initial indexing is still running. With several indexer threads, two index
tasks for the same file (or for a header shared by two translation units) can compute
their update against the same previous index; both updates then remove the previous
references, and the `refDecl` lambda in `DB::applyIndexUpdate` (query.cc:270 - 278)
drives `symbol2refcnt` below zero. With one indexer thread the tasks are serialised
and nothing fails. Issue #197 (2019) reported the same assertion for a different cause
(an lvalue-reference loop over `symbol2refcnt`, fixed then).

### Suggestions
- Do not re-index already-queued or in-flight files on `didChangeConfiguration`, or
  serialise index tasks per path.
- Since the handler ignores the settings (`EmptyParam`), re-indexing on every
  configuration notification also doubles the start-up indexing work for clients that
  send it at connect time (eglot does).

### Client-side workaround (used in our Emacs configuration)
Do not send `workspace/didChangeConfiguration` to ccls at connect time (eglot:
replace `eglot-signal-didChangeConfiguration` in `eglot-connect-hook` for a ccls
server class).

---

Second, minor finding (separate issue if wanted): ccls sends the server-to-client
request `workspace/semanticTokens/refresh` with a `uri` parameter; the LSP
specification defines this request without parameters, and eglot's handler, which
takes none, raised `wrong-number-of-arguments` for it once per session.
