# NNNN - <short title>

- **Date:** YYYY-MM-DD
- **Commits:** `<hash>` (one or more; the code this entry describes)
- **Tier:** 2 | 3 (spike Sn)
- **Decisions:** D-nnn, D-mmm (what this implements or changes)
- **Done when:** <the line agreed before code was written>
- **Tag:** vX.Y.Z (only if this entry lands a milestone tag)

> Plain English for someone who does not read <language> fluently. Explain the WHY and the
> idioms; do NOT restate the commit diff.

## What + why
One or two paragraphs: what changed and why (the problem, the D-nnn it implements).

## Concepts (<language>) explained
Only the idioms actually used, two or three sentences each, enough to follow the code.

## Key files walked
- `path/to/file` - what it does + the one function that matters here.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** <treated as true>. **Would break if:** <what invalidates it>.
  **DESIGN bet:** D-nnn.

## How to verify
Concrete commands and what to look for. Real-data steps are the owner's to run.

## Open questions (optional)
Add design questions to the DESIGN open questions ledger, not only here.

## Review fold-in (only for external-review entries)
Source: <who / which tool>, <date>. Transcript deleted after this entry.
- **Taken:** <point>. Reason. D-nnn added or superseded / task id.
- **Not taken:** <point>. Reason.
