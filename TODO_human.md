# TODO_human - the owner's queue

The LLM's work lives in `TASKS.md`; this file is the owner's. It holds only what the LLM
cannot do: runs on the Arch machine and on RMO, root and system actions, downloads and
accounts, reports sent to other projects, and decisions waiting on the owner. The LLM adds
items as numbered steps and prints them in chat the moment it adds them; the owner deletes
an item once it is done. Results go to the journal or DESIGN, never back into this file;
`git log` is the history.

Item shape: id `H-n` | date added | what it unblocks (`T-nnn`, `O-n`, `Sn`) | one line of
what and why | numbered steps, each with its command inline, only what the owner's hands
must do, literal values only, never a secret | what to report back, only for what the LLM
cannot read itself. An approval another session asks the owner for itself (a bench
service's plan) is not an item.

## Run now
- **H-7** (2026-10-20, unblocks T-032, T-036, T-037, T-039) Four reports to the Emacs bug
  tracker, drafted 2026-10-09 / 10, outward so yours to send.
  1. In Emacs, for each of `docs/upstream/eglot-watch-cap-partial-watches.md`,
     `docs/upstream/c-ts-mode-namespace-class-braces.md`,
     `docs/upstream/c-ts-mode-local-indent-style.md`,
     `docs/upstream/c-ts-mode-member-after-blank-line.md`: `M-x report-emacs-bug`, the
     file's title as the subject, its text as the body, the `.el` reproduction it names
     attached; send.
  Report back: the four bug numbers.
- **H-14** (2026-10-21, unblocks T-118) Hand check: deal.II's own sources from RMO.
  The index is built (`indexes/dealii.dex`, deal.II 9.8.0).
  1. In Emacs on Arch, open `~/source/repos/RMO-gross-pitaevskii/.dir-locals.el` and
     add the line `(emacs-cpp-project-libraries . (dealii))` after
     `(c-ts-indent-offset . 4)`; save.
  2. In Emacs: `M-x eglot-shutdown-all RET`, then `C-x C-f
     ~/source/repos/RMO-gross-pitaevskii/src/main.cc RET`.
  3. After a few seconds: `C-c l s n_active_cells RET`.
  Report back: the file it lands in (expected
  `.../emacs-cpp/indexes/dealii-9.8.0/source/grid/tria.cc`) and any `*Warnings*`.

- **H-15** (2026-10-21, unblocks T-119, D-127) The shipped fswatch backend on the Mac:
  tests, startup and S18's `shipped` mode (Arch passes).
  1. On Arch: `cd ~/source/repos/emacs-cpp && git push` (the session does not push).
  2. On the Mac: `cd ~/source/repos/emacs-cpp && git pull --ff-only`
  3. On the Mac: `make test </dev/null`
  4. On the Mac, idle machine: `S18_RUNS=shipped:fake,shipped:pyright sh
     spikes/s18-fswatch-backend/run.sh 20000 </dev/null`
  5. On the Mac: `rm -rf /tmp/s18-tree`
  Report back: the last line of `make test`, and paste
  `spikes/s18-fswatch-backend/s18.log`.

- **H-16** (2026-10-21, unblocks T-067, O-44 (c)) The mouse's side buttons: which
  events reach Emacs, so back / forward can be bound.
  1. In Emacs on the Mac (graphical): `C-h k`, then press the mouse's back button.
  2. Same, `C-h k`, then the forward button.
  3. In Emacs on Arch (graphical): steps 1 and 2 again.
  Report back: the event name each press shows (such as `<mouse-8>`), or that
  nothing arrived, per machine.

## Parked
- **H-8** (2026-10-20, 0084 review:B-3 to review:B-5, deferred; T-114) The upstream
  reports and patches in the review's order: treemacs and clang-change-namespace first,
  then consult, projectile, yasnippet-snippets, consult-eglot's ordering half; clangd 0009,
  0010, then 0005 - 0008 squashed, then 0001 - 0004 as an RFC; fswatch 0002 and 0004.
  Steps written when the owner moves this item back.

## Decide
