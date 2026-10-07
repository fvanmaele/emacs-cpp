# CLAUDE.md - emacs-cpp

Standard: llm_vibecoding_standard v1.0.0

Guidance for LLM sessions in this repo. **New session: read `DESIGN.md` sections 1-3 and the
open questions ledger first**, then `JOURNAL.md` (newest entries) and `TASKS.md`.

## Project
An Emacs 31 configuration giving the owner a CLion-like C++ environment (navigation,
refactoring, diagnostics, CMake presets, debugger, git, jump-to-anything) on one Arch
Linux workstation. It will never be an Emacs distribution, a multi-OS config or a CLion
keymap emulation (DESIGN 2).
**Status (2026-10-07):** design ruled through D-018. T-002, T-003 done. T-004 (eglot +
clangd from the active preset) built, `make test` 21/21; owner check left (configure
RMO, add `.clang-tidy`). Cold headers (O-5) need spike S4 before T-011.

## Hard rules (each with its reason)
- Change-size ladder: tier 1 trivial = commit with Reasoning only; tier 2 feature = `done
  when` agreed first, then code + journal entry; tier 3 risky = PASS spike first. LLM
  proposes the tier, owner rules, commit body names it.
- No tier 2 code without a DESIGN section; no tier 3 code without a PASS spike. Reason:
  <the dead direction or shipped bug that taught this>.
- Every decision is a `D-nnn` row in the DESIGN decisions ledger; cite ids, not section
  numbers. A new dependency, network call, credential or file outside the repo needs its
  `D-nnn` before code.
- Plans are grounded before code: every file, function, API or command the plan names is
  verified to exist or marked NEW.
- Real-data / real-device work is the owner's to run; hand over exact commands.
- Spike code is never promoted to app code; lift numbers and patterns, write fresh.
- RESEARCH docs carry findings, DESIGN carries verdicts; never the other way round.
- External reviews (LLM chats, human critiques) are folded into a journal entry (taken /
  not taken, each with a reason, attribution, date) plus DESIGN edits; the raw transcript
  is then deleted. Reason: transcripts rot and get re-read instead of DESIGN.
- Fail loudly: strict config, no silent fallbacks, no swallowed errors.
- `make check` (from `standard.mk`) passes before every commit.
- Every package is configured in exactly one `use-package` form; modules load via
  `require` in the order listed in `init.el`. Reason: a missing module or package must
  fail at startup (DESIGN 4, 5), not half-load.
- Makefile / justfile default target is `help`; bare `make` / `just` never builds.
- ASCII only; no invented abbreviations.
- Ask before launching subagents.

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
- New logic ships with tests. `make test` before committing code. Docs-only commits
  skip it. Test in the profile you ship.

## Docs-sync
A change that affects DESIGN, README, TASKS, spikes/README or the journal updates them in
the same commit; contradicted older text is marked superseded in that commit.

## Session close
Every session ends with this block, verbatim headings:
```
OPEN questions: Q-n ..., O-n ...   (or: none)
TASKS delta: opened T-nnn ..., done T-nnn -> NNNN ...
Docs touched: DESIGN X.Y (D-nnn), ...
Next blocking spike: Sn <name> / none
Commits: <hash> tier N <subject> ...
```

## Layout
- `DESIGN.md`, `POSTMORTEM.md`, `JOURNAL.md` + `docs/journal/`, `TASKS.md`, `spikes/`,
  `RESEARCH_*.md`, `standard.mk` + `scripts/check-standard.sh`, then the code directories.
