# eglot report draft: a watch limit fails the whole registration, and the server exits

Draft for the Emacs bug tracker (eglot is part of Emacs): `M-x report-emacs-bug`, or
mail to bug-gnu-emacs@gnu.org. Not sent; the owner sends it (O-26, D-054).
Reproduction script: `eglot_watch_cap_repro.sh` in this directory.

---

**Subject:** eglot: reaching eglot-max-file-watches (or a refused file watch) fails
the whole didChangeWatchedFiles registration; pyright then exits

### Environment
- GNU Emacs 31.1 (MacPorts `emacs-app`, macOS 27.0.1, Apple silicon), eglot 1.24.31
  as shipped with it.
- pyright 1.1.414 (`pyright-langserver --stdio`).
- Also seen on the same machine with Emacs's default `eglot-max-file-watches`
  (10000), where kqueue refuses the watch first (one file descriptor per watched
  directory, Emacs refuses beyond its limit at 975 watches).

### What happens
When a server's `client/registerCapability` for `workspace/didChangeWatchedFiles`
needs more directory watches than `eglot-max-file-watches` allows,
`eglot--watch-globs` warns "Reached `eglot-max-file-watches' limit of N, not watching
some directories", then signals `jsonrpc-error`; its `unwind-protect` removes every
watch already added for that registration, and the request is answered with an error
(-32603). pyright exits with status 1 about 80 ms later, writing nothing to stderr.
The warning says "not watching some directories", but in effect nothing is watched
and the server is gone.

The same path is taken when `file-notify-add-watch` itself fails, e.g. kqueue's "File
watching not possible, no file descriptor left" on macOS, which is reached long before
the default limit of 10000.

### Reproduction (emacs -Q)
`sh eglot_watch_cap_repro.sh /tmp/repro 600 500` creates a git project with 600
package directories and runs `emacs -Q --batch` with eglot and pyright,
`eglot-max-file-watches` 500 and `eglot-watch-files-outside-project-root` nil (so only
project directories count). Output:

```
[eglot] (warning) Reached 'eglot-max-file-watches' limit of 500, not watching some directories
[jsonrpc] Server exited with status 1
emacs 31.1, eglot 1.24.31, pyright 1.1.414; pyright EXITED after 20 s
<-- client/registerCapability[0] {... "method":"workspace/didChangeWatchedFiles", "watchers":
    [{"globPattern":"**/pyrightconfig.json"}, {"globPattern":"**"}] ...}
--> client/registerCapability[0] {"error":{"code":-32603,"message":"Reached 'eglot-max-file-watches' limit of 500"}}
Connection state change: `exited abnormally with code 1'
```

With 50 directories pyright keeps running.

### A second effect: watches are per registration
pyright registers its watchers three times at start (three ids; the later two add
the Python library roots) and unregisters the first two afterwards. eglot sets up a
full set of directory watches for each registration, so for a while every directory
is watched three times. Measured with the limit at 10000: a 400-directory project
asked for 976 watches (401 directories, each watched three times until refused); the
limit is therefore reached at about a third of the directories it suggests. On
macOS (kqueue) each watch is a file descriptor.

### Suggestions
1. When the limit is reached or a watch cannot be added, keep the partial watches and
   answer the registration successfully (the comment in `eglot--watch-globs`
   already notes "Could `(setq success t)' here to keep partial watches"), keeping the
   warning. A server then loses notifications for some directories instead of
   exiting.
2. Share one file watch per directory among registrations (count and limit
   directories, not registration-directory pairs).

(Separately, pyright exits when a `client/registerCapability` request fails; that is
pyright's behaviour and could be reported there.)
