# CLAUDE.md - emacs-cpp

Standard: llm_vibecoding_standard v1.0.0

Guidance for LLM sessions in this repo. **New session: read `DESIGN.md` sections 1-3 and the
open questions ledger first**, then `JOURNAL.md` (newest entries) and `TASKS.md`.

## Project
An Emacs 31 configuration giving the owner a CLion-like C++ environment (navigation,
refactoring, diagnostics, CMake presets, debugger, git, jump-to-anything) on an Arch
Linux workstation and a macOS machine (D-050). It will never be an Emacs distribution, a
Windows config or a CLion keymap emulation (DESIGN 2).
**Status (2026-10-09):** v0.4.1 tagged (navigation, build, debug, polish), design ruled
through D-060. clangd stays (T-004); a locally patched clangd
(`packaging/clangd-index-nav`, pkgrel 7 with patches 0008, 0009, selected by
`emacs-cpp-clangd-program`) answers navigation from its index and gives headers an
includer's flags, also when opened first (D-026 .. D-028, D-046, D-047, D-059), and
re-indexes sources whose shards had errors (D-060). Python rides along (D-045). macOS
supported, MacPorts only (D-050, D-053): starts and tests there (T-021, D-054),
`lldb-preset` (D-051), patched clangd from `build-macos.sh` (D-052); per-platform defaults
files (D-055, T-031); debug targets from CMake's file API (D-056, T-030). Budgets bind on
Arch only (D-057); `make test` on the machine at hand (D-058). Owner runs left: S10
(O-12), build-macos.sh to ~/opt (T-023); owner sends the eglot watch report (T-032)
and the three c-ts-mode reports (T-036, T-037, T-039). RET and TAB indent by Emacs's
rules (D-065, superseding D-061), from plain `.dir-locals.el` values (D-062).
Open: O-12; T-025 round 2, T-026 research queued.

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
- New logic ships with tests. `make test` before committing code, on the machine at
  hand, Arch or the Mac (D-058). Docs-only commits skip it. Test in the profile you
  ship.

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
