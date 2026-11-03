# 0104 - S20 eglot's share on RMO-drafts: PASS on the Mac; O-79

- **Date:** 2026-11-03
- **Commits:** see `git log -- spikes/s20-fswatch-reverter` (this entry's commit)
- **Tier:** 3 (spike S20)
- **Decisions:** D-153 (eglot's share measured before T-128 ships); O-79 opened
- **Done when:** three runs of `eglot-share.sh` pass E1 - E3 in
  `spikes/s20-fswatch-reverter/RUN.md` (confirmed with the session's plan
  2026-11-03, the CPU condition added by the owner after the dry run).

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
D-153's reverter leaves eglot's own revert hooks in place: on every revert eglot tells
clangd the file was closed and opened again, sending the whole new text, and clangd
reparses it. S20's generated repository has two-line toy files, so that cost had to
be measured on real code. The owner added `~/source/repos/RMO-drafts`, RMO's code on
the Mac. `eglot-share.sh` clones it under TMPDIR (its working tree has uncommitted
work and is never touched), configures preset `mac-debug`, and makes a branch that
shifts all 39 files by 19 lines. A batch Emacs opens the 39 files, starts eglot with
the patched clangd exactly as the config builds its command, waits for clangd to
finish, then checks out the shifted branch and back.

In three runs the judged checkouts pass: every buffer is current within 0.18 s, Emacs
is blocked at most 0.183 s, and clangd's document symbols in three reverted headers
all sit on the lines the buffers show them, none 19 lines off, so clangd works on the
new text. clangd then reparses for about 45 s at full CPU.

The first dry run showed that "clangd sent nothing for 5 s" does not mean clangd is
done: it publishes diagnostics early and keeps reparsing. A checkout started then
blocked Emacs 0.33 s. The owner ruled that settled also means clangd's CPU time grows
by less than 0.1 s over 5 s, and asked to keep the early checkout as a contrast. That
contrast blocks Emacs 0.36 - 0.98 s in one filter call, against 19 - 36 ms without
eglot. That contrast ran with no clangd at all, so it does not tell eglot's sends
from every revert being slowed by the busy machine (corrected the same day; the
first text said eglot's work). O-79 asks what T-128 does about it; D-154 measures
the split first.

## Concepts (Emacs Lisp) explained
- `eglot--connect` with `eglot--guess-contact`: what `eglot-ensure` runs from
  `post-command-hook`. Batch Emacs runs no commands, so the spike calls it itself;
  once connected, eglot takes over every open buffer of the project and mode.
- Advice on `eglot-handle-notification` (a generic function) sees every
  `textDocument/publishDiagnostics`; advice on `jsonrpc-connection-receive` sees
  every message from the server. Both only record times.
- `process-attributes` returns a process's CPU times (`utime`, `stime`); the spike
  samples clangd's every 0.25 s to tell an idle clangd from a quiet one.
- `jsonrpc-request` blocks until the answer comes; its default timeout is 10 s, too
  short while clangd reparses (the first dry run), so the check passes 120 s.

## Key files walked
- `spikes/s20-fswatch-reverter/eglot-share.sh` - the clone, the branches, the modes.
- `spikes/s20-fswatch-reverter/eglot-share.el` - `s20--setup-eglot` (the config's
  command and settings), `s20--settled-p` and `s20--clangd-idle-p`,
  `s20--symbols-check` (E3), `s20--checkout`.
- `spikes/s20-fswatch-reverter/mac-eglot-run1.log` .. `mac-eglot-run3.log`.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** RMO-drafts stands for RMO (39 files against RMO's 38 in DESIGN 3, the
  same deal.II). **Would break if:** RMO's files or includes are much heavier; Arch
  has the real RMO. **DESIGN bet:** D-153.
- **Assumed:** a checkout usually starts with clangd idle. **Would break if:**
  checkouts often follow each other within a minute, or start during clangd's
  startup indexing; then O-79's block applies. **DESIGN bet:** D-153, O-79.
- **Assumed:** 0.1 s of CPU over 5 s means idle. **Would break if:** clangd works in
  short bursts with longer gaps (background indexing); E2's window would end early.
  **DESIGN bet:** D-153.
- **Assumed:** the batch Emacs stands for the GUI one. **Would break if:** redisplay
  or the shipped profile's other hooks add work per revert (flymake's display of
  39 buffers' diagnostics is in it; the mode line is not). **DESIGN bet:** D-153.

## How to verify
On the Mac: `sh spikes/s20-fswatch-reverter/eglot-share.sh </dev/null`, then read
`spikes/s20-fswatch-reverter/eglot-share.log` against `RUN.md`'s E1 - E3; the
contrast lines are recorded, not judged.

## Open questions (optional)
O-79 in DESIGN: what T-128 does when a checkout lands during clangd's reparse.
