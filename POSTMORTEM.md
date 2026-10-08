# emacs-cpp postmortems

One entry per direction that went bad enough to revert, rewrite, or reopen a DESIGN
decision. Input = the assumptions + risks ledgers of the journal entries that bet on the
direction. Output = a DESIGN change so it cannot recur the same way. Write it while the
failure is fresh.

Entries below were written on 2026-10-08 from the git history (79 commits, v0.1.0 to
v0.4.1) and the journal; oldest first. Not entries: spikes that failed as designed (S1
run 1, S5, S8 run 1), which is the process working.

## 2026-10-07 - Startup figures that measured the wrong thing

### Trigger / symptom
The startup budget (DESIGN 11, 0.5 s) was first reported as met with 0.21 - 0.30 s.
That figure was `emacs-init-time`, which stops before `after-init-hook`, where
projectile, vertico and corfu start. Later, the measurement script of T-008 set `HOME`
before calling `tmux`; with a tmux server already running, the session gets the
server's environment, so a run from inside tmux would have measured, and written to,
the owner's real `~/.emacs.d`.

### Timeline
- e0c8bff (T-002, journal 0002): 0.21 - 0.30 s reported.
- 2026-10-07: DESIGN 11 redefines the budget (to the end of `after-init-hook`), marks
  the old figure superseded; new figures 0.60 - 1.21 s, taken under 390 % CPU load.
- ec1b786 (T-008, 0023): `scripts/measure-startup.sh`, idle machine: 0.355 s, 0.151 s
  with D-038.
- b78fbfe (code review, 0031): the tmux environment leak found and fixed.

### Root cause
Each measurement was trusted without a check that it measured the intended thing:
first the endpoint, then the machine's load, then the process environment.

### Which assumptions broke
- 0002: "**Assumed:** just-in-time native compilation is enough; startup measured
  0.21 - 0.30 s against a 0.5 s budget." The number was right for the wrong endpoint
  (D-010).
- T-008's script assumed, without saying so, that `HOME=...` in front of `tmux`
  reaches the program in the session. Not in any ledger.

### Blast radius / recovery
- No decision rested on a wrong number: D-038's variant measured 0.146 s against
  0.355 s, which only the throwaway HOME's early-init.el could produce.
- Keep: the script, now with a private tmux server and `env HOME=` in the command.

### DESIGN updates
DESIGN 11 budget redefined and the old figure superseded (2026-10-07); D-038.

### Lessons
- A measurement names its endpoint and its environment, and contains a check that it
  measured the intended setup (a variant that can only show up if it was loaded).
- Measure on an idle machine; record the load next to the number.

## 2026-10-08 - The ccls hybrid (D-023, D-024)

### Trigger / symptom
The ccls + clang-tidy hybrid, built on branch `t013-ccls-hybrid`, aborted in about one
test run in five (`query.cc:275 ... Assertion 'v >= 0' failed`) during indexing. A fix
reduced the aborts but did not remove them, and T-013 stayed blocked.

### Timeline
- 0007 (S5 FAIL): warming up clangd by opening files is too costly (D-021).
- fb8ec93 (S6 PASS, 0009): ccls answers `M-.` 1.2 s after start from its disk index.
- 293789c: O-8 ruled, hybrid (D-023, D-024); T-013 on the branch (70229cf).
- 29d6e33 .. 2cc5899 (O-10): the abort, its cause (ccls re-indexes everything on
  `workspace/didChangeConfiguration`, which eglot sends at connect, and its indexer
  threads race), branch fix f3313c0, upstream report draft.
- 27db769 .. ce833ae (S8): a locally patched clangd answers `M-.` from its own index:
  9.3 -> 1.4 s on RMO. D-026 adopts it; T-013 closed, branch kept.

### Root cause
S6 measured speed and correctness in single sessions; the abort only shows across many
sessions, during indexing. ccls's indexer has a race that eglot's connect triggers.

### Which assumptions broke
- 0009: "**Risk:** ccls is maintained far less actively than clangd; future clang
  versions may break it." It broke sooner, in the current release, as a concurrency
  bug (D-023).
- Not recorded, and wrong: one PASS session on RMO shows the server is stable.

### Blast radius / recovery
- Nothing merged into main; last good: main before 70229cf, i.e. all of main.
- Keep: branch `t013-ccls-hybrid`, `docs/upstream/` (report draft, repro script).

### DESIGN updates
D-023, D-024 superseded by D-026; O-8 resolved, O-10 closed; D-016 kept.

### Lessons
- A spike for replacing a core component repeats sessions (S9 later ran 10 per
  variant) and watches for crashes (`coredumpctl`), not only for answers.
- Patching the well-maintained component (clangd) cost less than working around a
  bug in the less-maintained one.

## 2026-10-08 - Header flags from the index raced the project handover (D-028)

### Trigger / symptom
Owner report (O-21): right after a restart, `iteration.h` opened from `C-x C-r` showed
"too many errors"; opening another file first was fine.

### Timeline
- e191461 (patch 0005, T-011, 0015): a header borrows an includer's flags from the
  index; fmt toy "opened first: 0 errors"; owner check on RMO (`assemble.h` opened
  first) clean; T-011 done.
- 14e7745: O-21 diagnosed by reading clangd.
- a3b7dfe, e3d4d08 (S9, 0027): toy 1 / 5 header-first sessions guessed; RMO 10 / 10.
- a5504e2 (patch 0006, pkgrel 4, 0028): 10 / 10 correct, but 1.48 - 1.56 s.
- aca5e3e (patch 0007, pkgrel 5, 0029), 5c4f294 (S9 run 3): 0.91 - 1.02 s.

### Root cause
Patch 0005 waited while a load counter was above 0. The counter rose in
`BackgroundIndex::enqueue`, which the compile database calls from its broadcast thread
after the first lookup has returned; a header opened as the first file asked in that
gap, saw 0 and did not wait. Once fixed, the wait still covered all of `loadProject`
(rebuilding the in-memory index) instead of only reading the shards.

### Which assumptions broke
- 0015: "**Assumed:** waiting up to 5 s for the stored shards is better than a wrong
  guess. **Would break if:** loading takes longer on a much larger project." The wait
  did not start at all; its length was never the problem (D-028).
- 0028: "**Risk:** the fix makes a header opened first wait about 0.4 s longer (the
  load)." It was about 1 s, the whole of `loadProject` (D-046).

### Blast radius / recovery
- No revert; fixed forward pkgrel 3 -> 4 -> 5. The earlier passes (toy, owner check)
  were timing luck.

### DESIGN updates
D-046, D-047 extend D-028; O-21 resolved; spike S9 kept as a regression check.

### Lessons
- A check of a timing-dependent path that passes once proves little: repeat it and
  read the log order (S9: ten sessions, "decision" against "Enqueueing").
- A unit test that forces the bad order (`AnnounceOnIdleCDB`) belongs with the first
  patch, not the third.
- An estimated cost is measured before it goes into a done-when.

## 2026-10-08 - gdb-preset offered only programs already built (D-031)

### Trigger / symptom
Owner's first RMO try of T-006: "no program in .../build/debug"; the preset was
configured but never built.

### Timeline
113d473 (T-006, 0019) -> owner report -> 98dea7b (D-033, 0020) the same hour.

### Root cause
The program list came from scanning the build directory for built executables, while
the same feature promised to build the program first. The session test built the toy
before debugging, so it matched the assumption instead of testing it.

### Which assumptions broke
- 0019: "**Assumed:** a CMake executable's target name is its file name. **Would
  break if:** a target sets `OUTPUT_NAME`" (D-031); removed with the scan.
- Not recorded: the program exists before the first debug session.

### Blast radius / recovery
One commit; D-031's program list superseded; nothing else depended on it.

### DESIGN updates
D-033: targets and their output paths from `build.ninja`.

### Lessons
- Test the first use (configured, never built); the session test now starts unbuilt.
- Read the build system's own description of its targets instead of inferring them
  from what it produced.

## 2026-10-08 - Settings that never took effect

### Trigger / symptom
Three times a setting was in the configuration, the tests passed, and it did nothing:
- treemacs-projectile, configured with `:after` under `use-package-always-defer`,
  never loaded from T-002 to T-015 (found while writing T-015);
- the default theme, loaded unconditionally before `custom.el`, left no theme in
  effect when the owner had saved one with Customize (owner report);
- a buffer-local `project-vc-extra-root-markers` for Python buffers, ignored by
  project.el (code review).

### Timeline
- e0c8bff (T-002): treemacs-projectile form and unconditional `load-theme`.
- d66d5b4 (T-015): `:demand t`, now loads.
- 3a8fc5f (D-040): default theme only when none is saved.
- 0eda303 (T-018) -> b78fbfe (review, 0031): dead line removed.

### Root cause
The tests checked the configuration (a variable's value, a keymap entry, `featurep`
after a manual `require`) instead of its effect for the user. The theme case only shows
in a graphical frame with a saved `custom.el`; the Python case passed because
projectile found the project anyway.

### Which assumptions broke
- 0002: "**Assumed:** pinning the installed commits reproduces the old behaviour."
  The retired `~/.emacs` loaded packages through package.el; `:after` under
  always-defer does not (D-006).
- D-045 (as first written): "for Python buffers only, `pyproject.toml` and `setup.py`
  also mark a project root, buffer-local".

### Blast radius / recovery
No data lost; all fixed forward; tags v0.1.0 and v0.2.0 carry the first two.

### DESIGN updates
D-040; D-045 corrected (0031); `:demand t` on both `:after` forms (T-015).

### Lessons
- Test the effect at the user's level: the faces of the theme in effect in a child
  Emacs with a saved `custom.el`; a package loaded after its trigger alone; a project
  root found with the one mechanism under test.
- A new test is run once against the old code to see it fail (done for D-040 and the
  S9 unit test; not done for the Python markers, which is how they slipped).

## 2026-10-08 - The tree opened by itself (D-048), reverted

### Trigger / symptom
The owner asked, the same day, to return to the tree opening only on `C-c t`.

### Timeline
ac094ae (D-048) -> b78fbfe (two review fixes to it) -> 5a098b7 (v0.4.0, includes it)
-> a748f3a (D-049, 0033), tag v0.4.1.

### Root cause
"Open treemacs by default (set option)" was built as on-by-default with rules of its
own (once per session, not for files under `.git/`) without asking which trigger the
owner wanted in daily use; it went into a milestone tag hours later.

### Which assumptions broke
- D-048: that "by default" meant "with the first project file of a session". Tier 1,
  so no ledger recorded it.

### Blast radius / recovery
- v0.4.0 contains it; v0.4.1 removes it, code and option; nothing depended on it.

### DESIGN updates
D-049 supersedes D-048; D-029's "not opened at startup" in force again.

### Lessons
- For a change of visible behaviour, ask for the trigger and the default before
  building, even at tier 1.
- Let a behaviour change be used for a while before tagging a milestone with it.

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
