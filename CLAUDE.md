# CLAUDE.md - emacs-cpp

Standard: llm_vibecoding_standard v2.15.1

Guidance for LLM sessions in this repo. **New session: if any `*_handoff.md` exists in the
root, apply it first, delete it, commit.** Then read `DESIGN.md` sections 1-3 and the open
questions ledger, `JOURNAL.md` (newest entries), `TASKS.md` and `TODO_human.md`.

## Project
An Emacs 31 configuration giving the owner a CLion-like C++ environment (navigation,
refactoring, diagnostics, CMake presets, debugger, git, jump-to-anything) on an Arch
Linux workstation and a macOS machine (D-050). It will never be an Emacs distribution, a
Windows config or a CLion keymap emulation (DESIGN 2).
**Status (2026-10-10):** v0.4.1 tagged (navigation, build, debug, polish), design ruled
through D-073. clangd stays (T-004); a locally patched clangd
(`packaging/clangd-index-nav`, pkgrel 7 with patches 0008, 0009, selected by
`emacs-cpp-clangd-program`) answers navigation from its index and gives headers an
includer's flags, also when opened first (D-026 .. D-028, D-046, D-047, D-059), and
re-indexes sources whose shards had errors (D-060). Python rides along (D-045). macOS
supported, MacPorts only (D-050, D-053): starts and tests there (T-021, D-054),
`lldb-preset` (D-051), patched clangd 23.1.3 from `build-macos.sh` (D-052, D-100);
per-platform defaults files (D-055, T-031); debug targets from CMake's file API (D-056,
T-030). Budgets bind on
Arch only (D-057); `make test` on the machine at hand (D-058). Owner runs left: S10
(O-12), build-macos.sh to ~/opt (T-023); owner sends the eglot watch report (T-032)
and the three c-ts-mode reports (T-036, T-037, T-039). RET and TAB indent by Emacs's
rules (D-065, superseding D-061), from plain `.dir-locals.el` values (D-062).
Tree follow options, not into library files (D-067, D-070); eglot refused loudly on
any preset or database error (D-018), a warning for a source missing from the
database (D-068); fixes to vendored packages as patch files (D-069). which-key after
3 s (D-071), narrow keys 0.2 s after `<` in prompts (D-080, 0054). `# %%` cells in
Python and R, ESS for R (D-072, 0047); owner's RMO check left.
Go to anything: one consult prompt (D-074) on `M-o` (D-076); S11 (0048): one letter
over deal.II accepted (D-075); speed settings (D-077), S11 run 2 PASS (0049); built
(T-049, 0050, no `#`: D-078), runs and hand check pass; narrowed to symbols: consult
patch 0001 (D-079, 0052), confirmed with deal.II's files (0053). `C-c p ?` over
projectile's files, ripgrep on macOS (D-081, 0055). `M-o` symbols: the project's, all
on `< l` (D-082, 0056), capped at 10000 (D-083, 0057), any server's URIs (D-085);
`< l` as `C-c l s` (D-086),
preview after a pause (D-088); macOS PATH from MacPorts at startup (D-089). LaTeX:
AUCTeX from GNU ELPA and texlab, `C-c l b` (D-090), `C-c l f` by latexindent (D-101);
eglot in init-lsp.el (D-091).
Rename without file limit (D-092); CLion's navigation clicks, right-click menu (D-093);
clang-tidy fixes, clang-move (D-094); snippets: yasnippet, its collection on `C-c y`
(D-095); a click shows no tooltip (D-096); patched clang-change-namespace, `C-c l N`
(D-097); no LyX keys (D-102). No module switch, modules load alone (D-098); `M-o` its
own module (D-099).
S12 change signature: FAIL, calls in templates (0066), O-43 (b) to the owner.
Open: O-39 R server (AUR verified, CRAN install on Arch); O-68 (researched, S19
proposed); O-38, O-43, O-44, O-47, O-56 ruled 2026-10-21 (D-135 .. D-139);
O-50 resolved: patch 0010 with T-104 (D-114);
O-64 resolved: limits kept (D-115); O-65 resolved: eglot patch 0003 (D-117, T-106,
0079); O-66 resolved: "Project Symbol" heading (D-118); O-67 resolved: mid-word
matches ranked by shape: S15 PASS (D-119, T-107, 0080), patch 0013 built (T-108,
0081; pkgrel 9, owner's install and Mac build left); D-120 LSP 3.18 matching with
tiers in every prompt: done (T-109, 0082; S11 run 6 PASS on RMO); O-68 clangd
pre-filter, later; O-69 resolved: Emacs's own eglot, macOS watch advice (removed by T-119),
project-only watches (D-121, T-110, 0083);
O-57 CLion's extra symbol matches;
D-105 symbols in clangd's order, `M-o` ignores case: built (T-084, 0072);
D-106 `M-o` symbol sources per server (T-087, 0073); D-107 `build*/` in
step-1's `.gitignore` (owner); D-108 eglot vendored with a
watch patch: T-090 done when proposed (no startup check); O-61 watched files,
large repositories: drafts (c) (e) (g), IDE research, (h) tree watcher via fswatch /
Watchman researched, fswatch patch prototyped (T-092 .. T-097);
D-109 patched fswatch built locally (T-098, 0074; Arch check passes at pkgrel 2,
Mac re-check left); fswatch backend for eglot ruled (D-110, DESIGN 7.1), watch items
ruled (D-111, 7.2); eglot vendored
(T-090, 0075; Arch passes); shared watches as patch 0002
(T-102, 0076; Arch passes);
clangd patches 0010 - 0012 built (T-104, 0077; pkgrel 8, Arch passes);
D-113 0011 / 0012 switched per request, announced as a capability;
T-025 round 2, T-026 queued. D-116 `make packages` resets patched files, submodules
at the pin (T-105, 0078).

2026-10-20: review of c031e2b folded in (0084): MIT license (D-122), the Arch clangd
follows pacman's LLVM through `make clangd` (D-123, T-111), match tiers as a function
(D-124, S16) only with compiled `lisp/` (D-125, DESIGN 11.1, S17: native modules load
magit at startup); DESIGN 1 ruled (D-126); llm_vibecoding_standard 2.14.0 (0086),
2.15.1 without its `B-n` ids (D-129, 0088). Owner's Arch runs folded in (0089):
S16 PASS compiled (criteria to confirm), S18 FAIL on cost on Arch, S10 FAIL (its
config turned off the project index), runs 2 the session's; ty researched, O-72.
2026-10-21 (0090): S18 PASS on Arch (`dedup`, Mac rerun H-13); S10 run 2 FAIL on the
first `M-.` only; library index by `--index-file` (D-130), a waiting patch researched
(T-117); S17 FAIL (native modules +222 ms); S16 criteria confirmed.
Then (0091): O-73 (a) with diagnostics (D-131, T-118 proposed); T-027 done on Arch;
S17 runs 2, 3: the JIT's own Emacs lacks use-package's settings, PASS with them
at compile time, shape O-74. D-131 amended (probe symbol, RIFF check), pyright
stays (D-132), S17 criteria confirmed, T-115 test, T-108 / T-111 done.
T-118 built (0092): `--index-file` from `.dir-locals.el`, `make library-index`
(clangd-indexer in pkgrel 10, D-133); hand check H-14. S17 run 4: O-74 pays via D-124.
T-119 built (0094): eglot's watches through the patched fswatch on both machines,
required at startup (D-127); S18 run 5 `shipped` PASS on Arch, Mac run H-15.
Python: ty on Arch, pyright on the Mac (D-140, T-120, 0095); ty on the Mac deferred
(T-121). Matches: gaps inside a word, `M-o` words match file names (D-141, 0096).
ty's return type inference per project (D-142, 0097); ruff deferred (D-143, T-124).
Mac run of H-15 by the session (0098): S18 run 6 `shipped` PASS; FSEvents kept
`Created` on recent files, fswatch patch 0005 (pkgrel 3, D-144, T-125); Mac clangd
rebuilt with `clangd-indexer`. H-15 left: the mouse's side buttons.

## Self-test (before the first edit of a session)
Answer from the docs, not from memory; a miss means re-read, not edit.
- Which two machines does the config serve, and on which one do budgets bind (DESIGN 3,
  D-050, D-057)?
- What did the newest journal entry assume, and what would break it?
- Which `TODO_human.md` item does the newest open task wait on, and what is its done
  when?
- Which O-n waits on the owner's ruling, and what does the session recommend?

## Hard rules (each with its reason)
- Change-size ladder: tier 1 trivial = commit with Reasoning only; tier 2 feature = `done
  when` agreed first, then code + journal entry. LLM proposes the tier, owner rules,
  commit body names it. No tier 2 work without a DESIGN section.
- Tier 3 risky (new subsystem, real-data path, performance or hardware claim, anything
  the risk register names) = PASS spike first; no tier 3 code without one. Reason:
  the ccls hybrid (D-023, D-024) passed its spike in one session and aborted in one run
  in five once built; spike and branch kept it out of main (POSTMORTEM 2026-10-08).
- Spike code is never promoted to app code; lift numbers and patterns, write fresh.
- Every decision is a `D-nnn` row in the DESIGN decisions ledger; cite ids, not section
  numbers; another repo's decision is cited `<repo>:D-nnn`. A new dependency, network
  call, credential or file outside the repo needs its `D-nnn` before code.
- Plans and audits are grounded: every file, function, API or command the plan names is
  verified to exist or marked NEW; every recorded defect cites its evidence or is marked
  UNVERIFIED. A plan with more than a few commits is written as `- [ ] step (~N min)` lines
  in the plan file when it is approved, the estimate on the step's first line and alone in
  its parentheses (a note goes after them), ticked `- [x]` as steps land, with `done N of
  M, now: <step> (~X min, Y in)` in chat every few commits. A task the owner calls small
  means minutes. Estimate the session's own work; owner wait is reported apart. A step off
  by more than twice its estimate, either way, is one clause of the progress line; keep
  working: the owner stops a plan, the session never does; scope that grows becomes a new
  step with its own estimate. The session-close block is not a plan step. Tick with the
  Edit tool, never a shell edit; the plan-approval call goes after a confirmed successful
  plan write, never in the same parallel batch.
- Real-data / real-device work is a conversation: the session runs what it can reach
  (the Mac this session runs on, its trees, its tools), dry-runs first, reads the logs;
  the owner's part (the Arch machine, RMO, accounts, sending reports) is an `H-n` item of
  numbered steps with each command inline, printed in chat when created and continued with
  "step N of M"; only what the owner's hands must do, never a pointer to RUN.md; a system
  action (install, reboot) is named and agreed alone before it enters a step. Each step
  carries literal values, never a variable from an earlier step or session; a secret is
  restated in chat only, never in a tracked file.
- `TASKS.md` is the LLM's work, `TODO_human.md` the owner's queue. A done `H-n` is deleted
  in the commit that folds its result into the journal or DESIGN; an `H-n` the owner puts
  off moves to `## Parked` unchanged. Reason: owner runs sat in CLAUDE.md's status
  paragraph, TASKS rows and RUN.md files at once; S10 has waited since 2026-10-09 (O-12).
- RESEARCH docs carry findings, DESIGN carries verdicts; never the other way round.
- External reviews (LLM chats, human critiques) are folded into a journal entry (taken /
  not taken, each with a reason, attribution, date) plus DESIGN edits; the raw transcript
  is then deleted. Reason: transcripts rot and get re-read instead of DESIGN.
- Fail loudly: strict config, no silent fallbacks, no swallowed errors.
- `make docs-check` (from `standard.mk`) passes before a commit that touches docs. It
  reads docs only; code checks are `make test`. `docs-check` stays docs-only; never chain
  tests or lint into it.
- Every package is configured in exactly one `use-package` form; modules load via
  `require` in the order listed in `init.el`. Reason: a missing module or package must
  fail at startup (DESIGN 4, 5), not half-load.
- Makefile / justfile default target is `help`; bare `make` / `just` never builds.
- ASCII in code (checked) and in docs (this repository's choice; the check notes dashes,
  smart quotes and emoji). No invented abbreviations.
- Shell scripts are `#!/bin/sh` or `#!/bin/bash`; no zsh-only syntax; quote globs that
  must not expand; loops go in a script file, not a one-liner. A command left running
  unattended (background, a long test suite) gets `</dev/null`, so a prompt fails at once
  instead of waiting forever. Reason: C-11, `make test` sat on a grammar prompt for
  1 h 50 min on the reviewer's machine (0084).
- Work for a sibling repo goes into `<sibling>/emacs-cpp_handoff.md` (shape:
  `llm_vibecoding_standard/templates/handoff.md`); never edit a sibling's other files. A
  pending handoff from this repo already there is rewritten, still-standing content carried
  forward (`## Still standing`).
- Ask before launching subagents; do not propose them either.
- A choice offered to the owner: every option states its case against, the recommended one
  included; the premises are verified first or marked UNVERIFIED; check for an option that
  combines the others before asking. Reason: review 0084's "compiling lisp/ gains nothing"
  rested on a harness the review itself withdrew; S17 measured 510 ms where it said none.
- A failure that reached a person or did damage gets a short POSTMORTEM entry in the commit
  that fixes it; a failed direction a full one; normal work (a test failing before done, a
  typo, a rerun) none. Reason: the standard's rule (llm_vibecoding_standard 2.14.0).
- No first-person authorship for the owner in any file, commit or text for others: the
  work was written by the models named in the `Co-Authored-By` trailers. Reason: the
  standard's rule (2.14.0).
- A generated `STATUS.md` is a hint, never the project's record; never commit it, it sits
  in `.gitignore`. Reason: the standard's rule (2.14.0).
- Never kill a process by name or pattern (`pkill`, `killall`, `kill $(pgrep ...)`); kill
  only a pid recorded at start, or its process group. Reason: the standard's rule (2.14.0;
  a `pkill` closed every terminal of its owner); `docs-check` fails on these forms.

## Git
- Commit each self-contained change unasked; conventional prefixes; body has a
  `Reasoning:` section with the labels `What was wrong:`, `Evidence:`, `Ruled out:` and a
  `Tier: 1|2|3` line; explicit paths, never `-A`; push only when asked.
- Milestone tags only when the owner confirms; risky directions branch from a tag.

## Journal
- Every tier 2 / 3 change and every spike result gets `docs/journal/NNNN-slug.md` from
  `docs/journal/TEMPLATE.md`, committed WITH the code; update the `JOURNAL.md` index.
- Teaching-style plain English if the owner does not read the language fluently; each entry
  carries the assumptions + risks ledger.

## Tests
- New logic ships with tests. `make test` before committing code, on the machine at
  hand, Arch or the Mac (D-058). Docs-only commits skip it. Test in the profile you
  ship. `make test` runs in a temporary HOME; `REAL_HOME=1` uses the real one (D-104).

## Docs-sync
A change that affects DESIGN, README, TASKS, TODO_human, spikes/README or the journal
updates them in the same commit; contradicted older text is marked superseded in that
commit.

## Session close
The plan checklist is ticked through before this block. An `H-n` added or continued this
session has its remaining steps printed in the final message, "step N of M".
Every session ends with this block, verbatim headings:
```
OPEN questions: Q-n ..., O-n ...   (or: none)
TASKS delta: opened T-nnn ..., done T-nnn -> NNNN ...
TODO_human delta: added H-n ..., parked H-n ..., removed H-n ... (or: none)
Docs touched: DESIGN X.Y (D-nnn), ...
Next blocking spike: Sn <name> / none
Commits: <hash> tier N <subject> ...
Failures: <POSTMORTEM entries written this session> (or: none)
Estimates: <step> ~E min, work W, wait V; ...   (one per plan step)
```

# Compact instructions
When the conversation is compacted, keep: the plan file path, its checklist state and its
Checkpoint block verbatim; the current step; the D-nnn ids and files touched this session;
the OPEN Q-n and O-n; the last session-close block. Drop: tool outputs, file contents,
exploration and dead ends. After a compaction, re-read the plan file first, then only the
DESIGN sections the current step names.

## Layout
- `DESIGN.md`, `POSTMORTEM.md`, `JOURNAL.md` + `docs/journal/`, `TASKS.md`,
  `TODO_human.md`, `spikes/`,
  `HANDOFF.md` (summary for outside reviewers, 2026-10-20; cites ids, not a source),
  `RESEARCH_*.md`, `standard.mk` + `scripts/check-standard.sh` + `scripts/commit-msg.sh`,
  then the code directories.
