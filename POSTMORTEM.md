# <Project> postmortems

One entry per direction that went bad enough to revert, rewrite, or reopen a DESIGN
decision. Input = the assumptions + risks ledgers of the journal entries that bet on the
direction. Output = a DESIGN change so it cannot recur the same way. Write it while the
failure is fresh.

## Template

## <YYYY-MM-DD> - <short title>

### Trigger / symptom
What went wrong and how it showed up.

### Timeline
Journal entries, commits, tags, in order: what was built, when the problem entered, when it
surfaced.

### Root cause
The underlying cause, not the symptom.

### Which assumptions broke
The specific **Assumed / Would break if** lines from the journal ledgers that were wrong,
each with the D-nnn it bet on. This is the heart of the entry.

### Blast radius / recovery
- Last known-good tag to revert or branch from: `vX.Y.Z`.
- Keep vs discard.

### DESIGN updates
D-nnn rows superseded, D-mmm rows added, sections changed.

### Lessons
Short, concrete; include any spike that should have run first, and any rule that should be
encoded structurally rather than in a comment.
