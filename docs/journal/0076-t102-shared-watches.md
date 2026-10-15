# 0076 - T-102: one watch per directory, shared by a server's registrations

- **Date:** 2026-10-15
- **Commits:** see `git log --grep T-102` (the code and this entry in one commit)
- **Tier:** 2
- **Decisions:** D-111 (O-61 (e)); D-108, D-069
- **Done when:** the revised shared-watches draft as `patches/eglot/0002` after 0001;
  8 patches in force; shipped-profile tests with pyright (cap 500, 400 directories:
  at most 401 watches, 401 left), a simulated `stopped` and re-creation, a failing
  handler, the last registration stopping its watches, `eglot-describe-connection`;
  `make test` on the Mac, Arch by the owner.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
pyright asks eglot to watch the project three times at start (three registrations),
then cancels two. eglot gave each registration its own watch on every directory, so
for a while each directory cost three watches; on macOS each is a file descriptor,
and the cap of 500 (D-054) counted each. With patch 0001 alone the first two
registrations filled the cap, the third got nothing, and once the first two were
cancelled no watch was left. Patch 0002 keeps one watch per directory and server,
shared by the registrations that need it.

## Concepts (Emacs Lisp) explained
- **A table per server.** `eglot--directory-watches` maps a server to a hash table
  from a directory to `(DESCRIPTOR . HANDLERS)`; `HANDLERS` is an alist of
  registration id and function. A registration adds its handler to an existing
  entry, or creates the watch; removing a registration takes its handler out and
  stops the watch with the last one.
- **One dispatcher.** The watch's callback calls `eglot--dispatch-directory-event`,
  which passes the event to each handler inside `condition-case`, so one failing
  handler is reported with `eglot--warn` and the others still run.
- **`stopped`.** When a watched directory is deleted, the system ends the watch
  (`deleted`, then `stopped`; `file-notify-valid-p` turns nil). The dispatcher then
  forgets the entry, and `add-watch` replaces an entry whose watch is no longer
  valid, so a directory created again is watched again.

## Key files walked
- `patches/eglot/0002-Share-one-file-watch-per-directory-among-a-server-s-.patch` -
  `eglot--watch-globs`' `add-watch`, `eglot-unregister-capability`, the count, the
  shutdown, and the two new functions above.
- `test/init-lsp-test.el` - `init-lsp-eglot-shares-directory-watches` with
  `init-lsp-test--with-pyright`; checked to fail with 0002 reversed (500 reached).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** registrations of one server may share a watch because each keeps
  its own globs and base directory in its handler. **Would break if:** eglot one
  day passed per-registration options to `file-notify-add-watch`; today all use
  `'(change)`. **DESIGN bet:** D-111.
- **Risk:** directories are keyed by their spelled path; one reached by two
  spellings (a symlink) keeps two watches, as before.
- **Risk:** 101 more changed lines in the vendored eglot to carry across mirror
  updates; a pin bump that no longer applies stops `make packages`.
- **Risk:** the gain is in descriptors on macOS; on Linux inotify shares one kernel
  watch per directory already, and 0002 only fixes eglot's own count there.

## How to verify
- `make packages` reports 8 patches; `make test`.
- A Python project with many directories on the Mac: `M-x eglot-describe-connection`
  lists one registration with as many watchers as directories, not three times as
  many.
- Arch (owner): `make packages && make test`.
