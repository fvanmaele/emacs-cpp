# emacs-cpp postmortems

Two sizes. A full entry per direction that went bad enough to revert, rewrite, or reopen a
DESIGN decision: input = the assumptions + risks ledgers of the journal entries that bet on
the direction, output = a DESIGN change so it cannot recur the same way. A short entry per
failure that reached a person or did damage: the owner or a user hit it, or it cost data,
a process, a device or the owner's time. Normal work gets neither: a test that fails
before the work is called done, a typo, a command that errored and was rerun. Write the
entry while the failure is fresh, in the commit that fixes it. In "Which assumptions
broke", each line as `D-nnn, journal NNNN: <the line>` (since 2026-10-20, standard 2.14.0).

Short entry shape:
- What failed / Caught by / Cause / Fix (commit) / Lesson, one line each, under
  `## <YYYY-MM-DD> - <short title> (short)`.

Entries below were written on 2026-10-08 from the git history (79 commits, v0.1.0 to
v0.4.1) and the journal; oldest first. Not entries: spikes that failed as designed (S1
run 1, S5, S8 run 1), which is the process working. Entries from 2026-10-09 on were
added on 2026-10-14 from the 129 commits after 10e676e (journal 0034 - 0070), followed
by a list of smaller issues that reopened nothing; again not entries: S11 run 1 and
S12, which failed as designed.

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

## 2026-10-09 - The config assumed Arch Linux (D-050, D-054, D-089)

### Trigger / symptom
On the owner's Mac startup stopped in `init-cmake.el` (`cmake-mode` looked for
`/usr/share/emacs/site-lisp`) and `make test` failed 17 of 45. pyright exited:
Emacs ran out of file descriptors at 975 watches (kqueue, one per directory). Four days
later an Emacs started from the Dock stopped with "emacs-cpp: rg is not on exec-path"
while `which rg` found it, and AUCTeX's preview said "LaTeX found no preview images".

### Timeline
- 0102577 (T-021, 0034, 2026-10-09): platform paths, `${hostSystemName}`, CMake 3.31's
  `build.ninja`, eglot watches only project files, at most 500 (D-054); tests by true
  name and waiting for eglot's handshake.
- D-055 (T-031, 0039): per-platform defaults files instead of `if`s in the modules.
- d7bc180, 7c70dd0 (D-089, 2026-10-13): launchd's PATH lacks `/opt/local/bin` and
  `/Library/TeX/texbin`; the config puts them in front of `exec-path` and PATH.

### Root cause
Everything was written and tested on one machine, from a terminal: paths, program
versions and the process environment were Arch's, and a graphical launch (Dock,
Finder) has a different environment from a shell's even on the same machine.

### Which assumptions broke
None was in a ledger; all were implicit. Written down since: 0034 "**Assumed:**
MacPorts' prefix is `/opt/local`" and "500 watched directories leave enough
descriptors on macOS" (D-054).

### Blast radius / recovery
- Arch unaffected throughout; nothing to revert. Keep: D-055's defaults files, the
  test `init-starts-with-launchd-path`.

### DESIGN updates
D-050 (macOS supported), D-053 (MacPorts only), D-054, D-055, D-057, D-058, D-089.

### Lessons
- A second platform is a second test run before its first commit: `make test` on the
  machine at hand (D-058).
- Test the way the owner starts the program: the owner found the Dock failure; a
  child Emacs with launchd's PATH reproduces it, a terminal never would.

## 2026-10-10 - RET indented by clangd (D-061), superseded by D-065

### Trigger / symptom
Owner report: "symbols are copied/inserted". With RMO's `.clang-format`
(`BraceWrapping: AfterFunction`), `double value() {}` RET left an extra `{}` line.

### Timeline
- 28dc924, 83d3d9a (D-061, T-035, 0043): RET asks clangd's on-type formatting for the
  new line's indentation and restores the line above as typed.
- Same day, owner report; 5592b4e restores everything from the saved line to the new
  line (tier 1).
- a8f4798 (D-065): RET by Emacs's rules again; eglot ignores on-type formatting.

### Root cause
clangd's reply to a newline reformats the whole statement it ended, splitting and
joining lines by `.clang-format`; D-061 took part of that reply and assumed the rest
stayed on one line.

### Which assumptions broke
- 0043: "**Assumed:** clangd's edits on newline touch only the line above and the new
  line, and do not join or split lines." (D-061). Checked on toy files in LLVM style,
  not with the project's `.clang-format`.

### Blast radius / recovery
- One day; no tag contained D-061. Keep D-062's rules, which place RET's line as
  `.clang-format` would in RMO's cases; `C-c l f` remains for exact formatting.

### DESIGN updates
D-065 supersedes D-061 (b); 0043 marked superseded.

### Lessons
- Before taking part of a server's edit, test with the owner's project settings, not
  only the server's defaults.
- A server edit is all or nothing; a partial one needs a reason the server documents.

## 2026-10-10 - eglot refused quietly (D-018 half built)

### Trigger / symptom
A mistyped `CMakePresets.json`, a preset without `binaryDir` or a half-written
`compile_commands.json` showed one echo-area line from eglot, nothing in view; an empty
database (`[]`) started clangd silently on fallback flags, giving false errors in every
file.

### Timeline
- D-018 (2026-10-07): eglot refuses loudly when the database or `-std` is missing.
- 8ebacfc (2026-10-10): every error on the way to clangd's command gets D-018's
  error-level warning; invalid JSON names the file; an empty database is refused.

### Root cause
D-018 was built for the two failures known when it was written. Other errors raised
inside eglot's contact function reached only eglot's own log level, which does not pop
up. The hard rule "fail loudly" was met for listed cases, not for the path.

### Which assumptions broke
Not in a ledger: that a raised error in the contact function is seen. Found by a batch
probe of seven broken projects with the real config (3 refused quietly, 1 connected).

### Blast radius / recovery
- Since T-004 (c0a3142, 2026-10-07); misleading, not destructive. Keep the probe as the test
  `emacs-cpp-presets-clangd-contact-refuses-every-mistake-loudly`.

### DESIGN updates
D-018 extended 2026-10-10 (any preset or database error, an empty database); D-068
(a source missing from the database warns).

### Lessons
- "Fail loudly" is tested against a list of broken inputs through the real entry
  point, and the refusal goes through one function that cannot be quiet.

## 2026-10-13 - Project symbols matched by URI spelling (D-082, D-083, D-085)

### Trigger / symptom
`M-o` listed no project symbols for a project under a path with `+ ( ) @`, opened in
another case on the Mac, or, for pyright, under a path holding `:` and `+`.

### Timeline
- d605e09 (D-082, T-060, 0056): project symbols kept by comparing each symbol's URI
  with the project root's URI, as eglot spells it.
- 31b8948 (D-083, T-061, 0057): clangd's spelling and case added.
- 0304078 (D-083): pyright's third spelling added.
- 0619b4b (D-085, T-062, 0058): one rule for every server, from the characters any
  encoder leaves unescaped.

### Root cause
Percent-encoded URIs compared as strings: each server escapes a different set of
characters, so each new server or path was a new spelling to add.

### Which assumptions broke
- 0056: "**Assumed:** clangd and eglot percent-encode a path the same way." (D-082)
- 0056: "a file system's case matches between the compilation database and
  projectile's root."
- 0057: "**Assumed:** other language servers in `M-o` (pyright for Python) encode like
  eglot or like clangd." (D-083), broken the same day.

### Blast radius / recovery
- Three commits in one day before the owner's hand check passed; `< l` (all symbols)
  worked throughout.

### DESIGN updates
D-083, then D-085 (one matcher; owner's hand check 30c48bd).

### Lessons
- Compare identifiers in a form independent of who encoded them; test with hostile
  paths (space, `+ ( ) @ :`, non-ASCII, another case) against every shipped server
  before the first commit.
- A ledger risk with a cheap check (a toy path) is checked, not only written down.

## 2026-10-14 - Tests wrote into the owner's ~/.emacs.d

### Trigger / symptom
`~/.emacs.d/projects.eld` grew by the temporary preset projects of every `make test`.

### Timeline
- Since the presets tests (c0a3142, 2026-10-07): project.el fixes `project-list-file`
  when it loads, before `init-test` redirects `user-emacs-directory`.
- 7416ce8 (2026-10-14): the presets test file points it into a temporary directory.

### Root cause
The same as the tmux leak of 2026-10-07: the test environment was assumed to be
isolated without a check that it was. A library computed its file name from the real
home before the redirect.

### Which assumptions broke
Not in a ledger: that `init-test`'s temporary `user-emacs-directory` covers every file
a package writes.

### Blast radius / recovery
- Extra entries in `projects.eld` pointing at deleted temporary directories; nothing
  lost, the stray lines can be removed by hand.

### DESIGN updates
D-104 (O-54 (b)): `make test` runs in a temporary HOME and checks it got one.

### Lessons
- The 2026-10-07 lesson recurred: isolation needs a check that fails, here a
  before/after comparison of the real home, run by the suite itself.

## 2026-10-14 - LaTeX formatting: a parity claim nobody checked (D-101, D-103)

### Trigger / symptom
`C-c l f` on a region in LaTeX failed: "[eglot] Unsupported or ignored LSP capability
':documentRangeFormattingProvider'". The replacement, latexindent called directly,
then indented with a tab where texlab gave two spaces in a project with a
`.latexindent.yaml`, and with tabs where AUCTeX's `TAB` uses spaces.

### Timeline
- 8df56f8 (O-51): texlab 5.25.1 has no range formatting.
- c0b0c15 (D-101, T-074, 0068): latexindent for regions, then, by the owner's ruling,
  for buffers too; DESIGN said "latexindent's defaults, as texlab calls it".
- 5ae4bf9 (O-53): texlab's source read: it passes `--local` from its own directory and
  ignores `insertSpaces`; D-101's claim marked wrong.
- f5559fc (D-103, T-078, 0070): `--local`, texlab's directory, the buffer's indent.

### Root cause
D-101 replaced a server feature by a direct tool call and claimed the same result
from one sample in a project without settings, without reading how the server calls
the tool (arguments, working directory).

### Which assumptions broke
- 0068: "**Assumed:** latexindent's defaults are what texlab used, so nothing changes
  for anyone who formatted whole buffers before." (D-101)

### Blast radius / recovery
- Same day, no tag; only projects with latexindent settings affected.

### DESIGN updates
D-101 marked, D-103; upstream report `docs/upstream/texlab-range-formatting.md`
(T-079, owner sends).

### Lessons
- Replacing a server's call of a tool starts with reading that call; a parity claim
  names the cases checked, including one with project settings.

## Smaller issues, 2026-10-09 .. 2026-10-14
Fixed once, no decision reopened; listed so the pattern stays visible.
- 2e778ee: `M-o` listed files before binding the GC threshold; deal.II-sized projects
  collected garbage while the prompt opened (S11 run 3 on RMO's 2673 files missed it).
  Lesson as 2026-10-07: measure at the target scale (D-010).
- 8121303 (D-070): the tree followed `M-.` into deal.II's install directory, which
  projectile took for a project (a Makefile).
- f35ba4b (D-073): the line number column changed width while scrolling.
- 94626cc, b8e0918 (D-062, T-039, T-040): `c-ts-mode` indentation gaps (member after a
  blank line, constructor initializers), worked around, three upstream reports drafted
  (T-036, T-037, T-039).
- a36c149 (D-079): consult kept hidden sources in the candidate list; patch 0001.
- b30a5a2 (D-093): navigation clicks on Ctrl took Emacs's own Ctrl clicks on Arch; Super
  on both platforms.
- 9782c0e (D-098): `init-python` worked only because `init.el` loaded `init-lsp` first;
  every module is now loaded alone in a test.
- D-094: LLVM 23's `clang-change-namespace` crashes on two sources; patched (D-097),
  upstream report T-070.
- O-50: clangd's index loses cross-file references when the database spells a path
  through a symlink (`/tmp`); open.
- 0067: `init-debug-lldb-preset-builds-stops-and-steps` timed out once (121 s) in a full
  run, passed alone and in the next run; flaky, watched.

## 2026-11-05 - Kept project file lists, built and reverted (T-133, D-177, D-178)

### Trigger / symptom
The owner reverted T-133 after its benchmarks: the first call, and the first after any
change of structure, cost up to four times the old listing on large trees (LLVM's
sources 1366 ms against 336; deal.II 178 against 64), which the owner ruled not
acceptable (D-179), after first accepting deal.II's.

### Timeline
RESEARCH_go_to_anything 22 (T-133 researched) -> O-85 (f), D-177 -> owner: tier 3 ->
S21 (criteria confirmed; PASS with `m2`, 0126) -> b7e3692 (built, 0127; done when 3's
"first call as today" not met on deal.II, put to the owner) -> 7487e53 (opt-out,
D-178) -> 0c885c4 (benchmarks over 14 trees; deal.II accepted) -> this commit (reverted,
D-179, 0128).

### Root cause
S21's criteria bounded the call with the list current (criterion 3) but not the first
call, nor the call after a change of structure, which is a first call again: the
feature's own cost (reading every directory and its names) sat on that path, and the
spike never measured it. It surfaced only after building, in done when 3, and its
scale (four times on the largest tree) only in the wider benchmarks afterwards.

### Which assumptions broke
- D-177, journal 0127: "190 ms for deal.II's first call after a change is acceptable
  (68 ms today)" / "Would break if: the owner judges it slower than before in a
  project that changes structure often".
- D-177, journal 0126 (S21): "The first call per root costs a listing as today (444 -
  493 ms on emacs-cpp) plus reading the directories" - recorded as a finding, never as
  a criterion, and measured on emacs-cpp only, where the listing dominates.

### Blast radius / recovery
- Last known-good tag: v1.0.0 (before T-133). Discarded: the module code, its test,
  the option, the manual paragraph, H-28. Kept: S21's harness and results, journal
  0126 - 0128, RESEARCH 22's measurements.

### DESIGN updates
D-179 supersedes D-177 and D-178; O-85 reopened with the constraint that no call may
be slower than today's listing.

### Lessons
- A spike's criteria bound every path the change makes slower, not only the one it
  makes faster: here the first call and the call after a change.
- Benchmark across tree sizes, the largest at hand included, in the spike, before
  building: the cost that decided it showed only on deal.II and LLVM's sources.
- An unmet done-when point is a FAIL to report as such before asking whether it is
  acceptable.

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

## 2026-10-20 - S10's command named a file RMO had removed (short)
- What failed: H-6 ran `run.sh` on `src/main_sparsity.cc`; RMO has no such file now.
- Caught by: the owner, on Arch; the runner refused, the owner chose another file.
- Cause: the item copied RUN.md's command of 2026-10-08 unchecked against RMO's tree.
- Fix (commit): this commit; S10 run 2 names a probe file the runner writes itself.
- Lesson: an `H-n` naming a path in another repository checks that path when written.

## 2026-11-03 - A commit that failed docs-check was pushed (short)
- What failed: 60f352c (D-156) reached origin with a 118-column line in DESIGN's O-79.
- Caught by: the session, reading the chain's output after the push.
- Cause: `make docs-check | tail -1 && git commit ... && git push`: the pipe gave
  `tail`'s status, not make's; the same day an edit script's failure was likewise
  followed by a commit (fixed by amending before push).
- Fix (commit): this commit re-wraps the line; checks run alone, their status read,
  before any commit or push.
- Lesson: never pipe a gate's output in an `&&` chain; run the gate, then commit.

## 2026-11-03 - A clangd mechanism stated from log lines, ruled on, then refuted (short)
- What failed: 0106 and O-79 (f) said clangd's main thread runs the includer lookup;
  the owner ruled D-156 (f) / T-130 on it; it was pushed (95fa027, 60f352c).
- Caught by: the session, reading `TUScheduler.cpp` when T-130 started.
- Cause: log lines from worker threads, interleaved in the main thread's gaps, read
  as the main thread's work; the source was not opened before the option was offered.
- Fix (commit): this commit corrects 0106, O-79, D-156, S20 RESULTS; T-130 blocked.
- Lesson: a mechanism inside another program is UNVERIFIED until its source or a
  trace of that thread shows it; offer no fix built on it before that.

## 2026-11-03 - CPU times on the Mac read 41.7 times too small (short)
- What failed: S18's Mac criterion 3 (2 - 9 ms per 1000 records, "PASS on both
  machines", D-127) and S20's settle test (0.1 s over 5 s) used `process-attributes`
  CPU times, which Emacs 31.1 gives 41.7 times too small on Apple silicon.
- Caught by: the session (D-160): clangd's CPU over a 186 ms filter call read 40 ms
  while a sample showed about 21 of its threads busy; a 1 s burner read 0.027 s.
- Cause: Emacs's Darwin `system_process_attributes` takes proc_pid_rusage's Mach
  ticks for ns (`sysdep.c`); the spikes never checked the unit against a known load.
- Fix (commit): this commit (S18 reads `current-cpu-time`; its verdict, D-127,
  T-116 corrected; O-80); S20's spike gets a scale measured against
  `current-cpu-time` with D-160's spike commit.
- Lesson: a measurement source a verdict rests on is checked once against a known
  quantity on each machine before its first verdict.

## 2026-11-03 - A send's duration read as a pipe stall (short)
- What failed: 0105 - 0109 reported `process-send-string`'s duration as the write's
  stall ("one write stalls 0.26 - 1.04 s", the residual 74 - 181 ms); D-155 set
  O-79 (b) aside on it, D-158 and D-159 were ruled on it.
- Caught by: the session (D-160): a trace of Emacs's writes showed the pipe held the
  write 10 - 15 ms; the rest was the reverter's filter and timers run inside the send.
- Cause: `send_process` runs timers and other processes' filters while it waits; a
  timer around the call counted all of it as the callee's own time.
- Fix (commit): this commit corrects O-79, D-155, the D-159 result, S20 RESULTS; (b)
  is offered again as O-79 (o).
- Lesson: a duration around a call that can wait counts what runs inside the wait;
  name the place of a stall only from a measurement at that level.

## 2026-11-07 - Markdown's PDF dropped the formulas' symbols silently (short)
- What failed: `C-c C-c x` on RMO-drafts' `md/exact_coarse_model.md` gave a PDF without
  its formulas' Greek letters and math symbols, and said nothing.
- Caught by: the owner, the first real file after T-135 (0131).
- Cause: the file writes formulas as code spans with Unicode (rho_I = Sigma p_i); pandoc's
  default monospace font, Latin Modern Mono, has no such glyphs; xelatex drops them,
  pandoc exits 0 with a `[WARNING] Missing character` line per drop, and the command
  showed pandoc's output only on failure. The tests used `$x^2$` only.
- Fix (commit): this commit, D-185: DejaVu Sans Mono for code
  (`emacs-cpp-markdown-pdf-monofont`), missing characters a warning naming them.
- Lesson: test a converter on the owner's real files, not only on the textbook input;
  a tool's warnings on exit 0 are part of its result.

## 2026-11-08 - Commits under the machine's identity reached GitHub (short)
- What failed: 49 commits (2026-11-02 to 2026-11-08), 37 of them pushed to `origin/main`
  and 3 to `origin/S20-arch`, and `v1.0.0`'s tag carried `this machine's global git identity
  <the machine's address>`, this Arch machine's global git identity, not the owner's.
- Caught by: the session, while building the release branch (D-194); the owner ruled the
  fix.
- Cause: the repository had no `user.name` / `user.email` of its own, so sessions on this
  machine committed under the global identity; nothing checked the author.
- Fix (commit): the history rewrite of D-195 and the repository's own identity, with the
  commit that records them; GitHub after H-34.
- Lesson: a session committing on a machine for the first time checks `git config
  user.name` against the history's author before its first commit.
