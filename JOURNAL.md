# <Project> - implementation journal

A teaching + decision log that runs alongside `git log`. Two jobs:

1. **Understand the code.** Each entry explains, in plain English, WHAT was built, WHY, and
   the language idioms it used, so the owner can open the code and ask informed questions.
2. **Recover / postmortem.** Each entry carries an assumptions + risks ledger. Milestone
   tags give clean revert points; `POSTMORTEM.md` reads the ledgers to update DESIGN.

## How it works
- One entry per feature / work chunk / spike result (may span several commits).
- `docs/journal/NNNN-slug.md` (zero-padded), newest listed on top here. Copy
  `docs/journal/TEMPLATE.md`.
- Committed WITH the code it describes; links commit hash + D-nnn; does not duplicate
  the diff. Tier 1 changes (see CLAUDE.md) get no entry.
- Milestone tags `vX.Y.Z` only when the owner confirms; risky directions branch from a tag.
- Plain teaching English, not chat style.
- An external review (LLM chat, human critique) is folded in as an entry: each point taken
  / not taken with a reason, attribution and date; the transcript is deleted afterwards.

## Index (newest first)
| #    | date       | title | commits | decisions |
|------|------------|-------|---------|-----------|
| 0006 | 2026-10-08 | T-004 fixes: library headers, completion | T-004 | D-019, D-020 |
| 0005 | 2026-10-07 | T-004: eglot + clangd from the active preset | T-004 | D-016..18 |
| 0004 | 2026-10-07 | T-003: completion stack | T-003 | D-006 |
| 0003 | 2026-10-07 | S1 run 2: PASS, cold headers open | S1 | D-016 |
| 0002 | 2026-10-07 | T-002: config skeleton and pinned packages | T-002 | D-006, D-014 |
| 0001 | 2026-10-07 | S1 run 1: database found, standard missing | S1 | D-011..13 |
| 0000 | YYYY-MM-DD | Spike phase recap / prototype review | | |
