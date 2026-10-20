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
- **H-1** (2026-10-20, unblocks T-111, T-108) The session's commits reach Arch, then the
  patched clangd at pacman's LLVM (23.1.3) with patch 0013 (pkgrel 9).
  1. On the Mac: `cd ~/source/repos/emacs-cpp && git push` (the session does not push).
  2. On Arch: `cd ~/source/repos/emacs-cpp && git pull --ff-only && make packages`
  3. On Arch: `make clangd MAKEPKG_FLAGS=-si` (about 8 minutes; pacman asks for your
     password to install).
  4. On Arch: `/opt/clangd-index-nav/bin/clangd --version`
  Report back: the version line of step 4, and the last 5 lines of step 3 if it failed.
- **H-2** (2026-10-20, unblocks S16, T-112) Spike S16 on Arch: the match function against
  the regexps on deal.II's file names.
  1. On Arch, if no deal.II source checkout exists yet: `git clone --depth 1 --branch
     v9.6.2 https://github.com/dealii/dealii.git ~/source/repos/dealii`
  2. On Arch, idle machine: `cd ~/source/repos/emacs-cpp && sh
     spikes/s16-match-function/run.sh ~/source/repos/dealii </dev/null`
  Report back: paste `spikes/s16-match-function/s16.log` (about 45 lines).
- **H-3** (2026-10-20, unblocks review 0084 5b item 6) The review's bench block on Arch.
  1. On Arch: `cd ~/source/repos/emacs-cpp && git fetch
     https://github.com/pepopepopepo/emacs-cpp.git audit/main && mkdir -p review && git show
     FETCH_HEAD:review/portable-bench.sh > review/portable-bench.sh`
  2. On Arch, idle machine: `sh review/portable-bench.sh 10 </dev/null; rm -r review`
  Report back: paste the block it prints.
- **H-6** (2026-10-20, unblocks O-12, S10) Spike S10 on Arch, waiting since 2026-10-09.
  1. On Arch: `cd ~/source/repos/emacs-cpp && sh spikes/s10-library-index/run.sh
     ~/source/repos/RMO-gross-pitaevskii src/main_sparsity.cc n_active_cells </dev/null`
  Report back: paste the last 40 lines it prints.
- **H-7** (2026-10-20, unblocks T-032, T-036, T-037, T-039) Four reports to the Emacs bug
  tracker, drafted 2026-10-09 / 10, outward so yours to send.
  1. In Emacs, for each of `docs/upstream/eglot-watch-cap-partial-watches.md`,
     `docs/upstream/c-ts-mode-namespace-class-braces.md`,
     `docs/upstream/c-ts-mode-local-indent-style.md`,
     `docs/upstream/c-ts-mode-member-after-blank-line.md`: `M-x report-emacs-bug`, the
     file's title as the subject, its text as the body, the `.el` reproduction it names
     attached; send.
  Report back: the four bug numbers.

- **H-12** (2026-10-20, unblocks S18, T-116, D-127) Spike S18 on Arch: the fswatch
  backend on an LLVM-sized tree, against Emacs's own watches. Needs fswatch-no-loss
  pkgrel 2 in `/opt/fswatch-no-loss` (installed 2026-10-19) and about 2 GB under /tmp.
  1. On Arch (after H-1's `git pull`), idle machine: `cd ~/source/repos/emacs-cpp && sh
     spikes/s18-fswatch-backend/run.sh 20000 </dev/null` (generates the tree first, a
     few minutes; then four runs of about a minute each).
  2. On Arch: `rm -rf /tmp/s18-tree`
  Report back: paste `spikes/s18-fswatch-backend/s18.log`; its first line must say
  `Linux` (the run of 2026-10-20 17:32Z was on the Mac). The criteria are confirmed.

## Parked
- **H-8** (2026-10-20, 0084 review:B-3 to review:B-5, deferred; T-114) The upstream
  reports and patches in the review's order: treemacs and clang-change-namespace first,
  then consult, projectile, yasnippet-snippets, consult-eglot's ordering half; clangd 0009,
  0010, then 0005 - 0008 squashed, then 0001 - 0004 as an RFC; fswatch 0002 and 0004.
  Steps written when the owner moves this item back.

## Decide
