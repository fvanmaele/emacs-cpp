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

## Parked
- **H-8** (2026-10-20, 0084 review:B-3 to review:B-5, deferred; T-114) The upstream
  reports and patches in the review's order: treemacs and clang-change-namespace first,
  then consult, projectile, yasnippet-snippets, consult-eglot's ordering half; clangd 0009,
  0010, then 0005 - 0008 squashed, then 0001 - 0004 as an RFC; fswatch 0002 and 0004.
  Steps written when the owner moves this item back.

## Decide
