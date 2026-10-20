# 0084 - External review of c031e2b folded in

- **Date:** 2026-10-20
- **Commits:** `64ba133` (C-11, C-12), `0cb3fca` (A-1, A-2), `006dd64` (A-5),
  `4683f20` (review:B-1, T-111); this entry with D-124, D-125 and spikes S16, S17
- **Tier:** 1 (fixes) / review fold-in; 2 (T-111); 3 (S16, S17: spikes first)
- **Decisions:** D-122 (license), D-123 (LLVM pin), D-124 (match function), D-125
  (compiled `lisp/`); O-70 (fswatch), O-71 (stale `.elc`) opened
- **Done when:** every finding verified against c031e2b and either fixed with a test,
  recorded as not taken with a reason, or handed to the owner with the question named
- **Tag:** none

> Plain English record of what an outside review found and what was done with it.

## What + why
`HANDOFF.md` invited an outside review. A reviewer's fork (`pepopepopepo/emacs-cpp`,
branch `audit/main`, commit ed29327) published `REVIEW_2026-10-20_c031e2b.md`, prepared
with an LLM, human review pending by its own header, plus three patch files and the
scripts behind its numbers. Its own `FORK.md` asks that findings be treated as claims;
each one below was checked against this tree at c031e2b before acting. Overall the
review is careful and mostly right; four points in it are wrong or overstated (below).
The owner ruled the same day: "A2 - mark as superseded. Revisit A-3 and A-1. Tier 2
under own D-nnn llvm-unpin.patch. Ruling for the matcher / section 3. Run
portable-bench.sh on this machine. A-5 license, MIT. Review review:B-2, defer review:B-3 to
review:B-5.
Design for compile-lisp.patch and spike."; matcher: "C, spike first"; A-3: "Draft,
you check"; A-1's reason: "I pick from the record". The review's ids are
prefixed `review:` in these quotes since standard 2.15.1 (0088), no other word changed.

## Review fold-in
Source: `pepopepopepo/emacs-cpp` `audit/main` ed29327, `REVIEW_2026-10-20_c031e2b.md`
(rounds 1 and 2), 2026-10-20. The review lives in the reviewer's repository, not here;
nothing to delete.

- **Taken: C-12, the pyright rename test raced the analysis.** Checked by reading:
  the test waited for `eglot-managed-p` only, then renamed at once; the review logged
  pyright replying null to an early rename. `test/init-test.el` now records
  `textDocument/publishDiagnostics` through `eglot-handle-notification` (a public
  generic, no new internal) and the test waits for the file's first diagnostics.
  Passes here in 2.1 s. `64ba133`.
- **Taken: C-11, `make test` prompted for a missing grammar.** Emacs 31's
  `treesit-auto-install-grammar` defaults to `ask` and asks through `y-or-n-p`, in
  batch too. The `ERT` line sets it to `never`. Not in the configuration: startup
  already refuses without the grammar (D-008). `64ba133`.
- **Taken: A-2, the refuted Lisp budget.** DESIGN 1's "about fifteen direct packages
  and under ~600 lines of own Lisp" marked SUPERSEDED with the numbers (33
  submodules, 3111 lines); no size budget replaces it. `0cb3fca`.
- **Taken in part: A-1, template leftovers.** `CLAUDE.md:79`'s placeholder now names
  the ccls hybrid (D-023, D-024, POSTMORTEM 2026-10-08); `JOURNAL.md`'s template title
  and 0000 row gone. `0cb3fca`. Not taken: the standard's upgrade to 2.13.0 (no
  checkout of the standard on this machine; the owner's `make upgrade`); RESULTS.md
  for S7 and S10 (both wait for owner runs, O-12; the newer check's demand is met by
  the runs, not by stubs).
- **Taken, draft for the owner: A-3, DESIGN 1's status column.** Each shipped row
  DECIDED with its D-nnn under one new decision, gaps kept; left uncommitted for the
  owner's check.
- **Taken: A-4, HANDOFF 10 lists 8 of 29 internal symbols.** For the next HANDOFF
  update, from a command (the review's `review/counts.sh`), not by hand.
- **Taken: A-5, no license.** MIT for the repository's own work, the patch files
  keep their projects' licenses (D-122). `006dd64`.
- **Taken: review:B-1, the LLVM pin, tier 2 (D-123, T-111, 0085).** The review's
  `review/llvm-unpin.patch` through `git am`, author kept; its version check was a
  glob that let "24.0.0git" through to `sed -i`; fixed and tested here. `4683f20`.
- **Taken: section 3, the matcher, option C, spike first (D-124, S16, T-112).** Mac
  dry run (`spikes/s16-match-function/DRY-RUN.md`): the function keeps the 15 rows
  and gives the regexps' tier on all 270144 pairs (8 inputs, 33768 deal.II names);
  interpreted it is 1.3 - 1.9 times slower on a prompt's filtered set, compiled a
  third (byte) or a quarter (native) of the regexps' time. So it ships only with
  D-125.
- **Taken: C-7, C-10, M-6, compiling `lisp/`, as a design and a spike (D-125, DESIGN
  11.1, S17, T-113).** The patch's shape (prelude, warnings as errors, temporary
  HOME for `make packages`, freshness test) is the design; one gap added: a stale
  `.elc` loads silently after an edit (O-71). S17 measures startup with
  `scripts/measure-startup.sh` in both states, JIT on and off. Mac dry run
  (`spikes/s17-compiled-lisp/DRY-RUN.md`): bytecode costs nothing (0.36 s against
  0.40 s interpreted); native modules start in 0.91 s because they load magit at
  startup and re-queue 45 files for compilation; the form behind it is S17 run 2's
  question (T-113).
- **Taken: portable-bench.sh on the Mac (5b item 6).** 2026-10-20, 64ba133, Emacs
  31.1, 11 cores, load 6.0 / 5.1 / 4.8 (not idle): startup median 0.410 s (0.390 -
  0.485, 1 collection each), against the 0.852 s of 2026-10-09 (DESIGN 11; Mac
  numbers are recorded, not judged, D-057); `make test` 133 tests, 131 passed, 2
  skipped, exit 0, 56.6 s wall. The review's machine: 0.097 s, 20.2 s. Arch's block
  is the owner's to paste.
- **Reviewed: review:B-2, fswatch.** The review is right: DESIGN 7.1's backend was designed
  on the vendored eglot that D-121 removed, nothing runs fswatch, two builds stay to
  keep. Opened O-70: (a) keep, (b) park on a branch (recommended), (c) own
  repository. Owner rules.
- **Deferred: review:B-3 - review:B-5, sending the reports and patches (owner).**
  Recorded as
  T-114 in the review's order, with review:B-5a's staleness question for 0001's message and
  fswatch 0002 / 0004.
- **Not taken: A-7, "vim or an IDE could do the same".** An answer to the owner's
  question, not a finding: the wait is clangd's, so any editor on stock clangd
  waits the same.
- **No action: C-1 .. C-6, C-8, C-9, review:B-6.** Confirmations (internals exist at their
  pins, presets resolution follows CMake, D-018 refusals are loud, indentation is
  buffer-local, the eglot advice is version-pinned and loud).

## Where the review is wrong or overstated
- **The spec size.** Section 3 and M-4 say "19 rows"; `init-completion-match-tiers`
  holds 15 rows and one sort example, as the review's own M-5 says.
- **Option C's sketch.** It lowercases the candidate before `string-search`, but its
  `emacs-cpp-word-start-p` needs the original capitals (`HTTPServer`, `ATVfoo` would
  lose their word starts): search the lowercased copy, test word starts on the
  original (S16 does). It also treats non-ASCII letters as separators where the
  regexps use `[[:alnum:]]`, and binds `case-fold-search`, which `string-search`
  ignores.
- **"Compiling `lisp/` gains nothing measurable"** (verdict table) rests on M-6, whose
  harness 4c withdraws for this configuration. Open; S17 measures it.
- **The llvm-unpin patch's version check** let "24.0.0git" pass (a glob's `*`).
- **Line numbers** off by one or two in places (`JOURNAL.md:106`, `init-cmake.el:26`);
  review:B-6 "replaces two internals" omits the `:around` on `eglot-unregister-capability`.

## Found while checking
- **A stale `lib/load-path.el` loads the old vendored eglot.** After D-121 removed the
  `lib/eglot` submodule, its directory stayed untracked and `lib/load-path.el` still
  listed it until `make packages` ran again; the session then loaded eglot 1.24 and
  `emacs-cpp-eglot-watch` refused it (loudly, as designed). T-115 proposes the
  check; removing `lib/eglot/` is the owner's.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** pyright publishes diagnostics for every opened file, an empty list for
  a clean one. **Would break if:** a pyright release stops pushing for clean files;
  the test then fails after 30 s at the wait, not at the rename. **DESIGN bet:** D-045.
- **Assumed:** the review's measurements on its Linux machine (build logs, timings)
  are as reported; only claims checkable in this tree were checked here.
- **Assumed:** the Mac dry runs' orderings (function against regexps, compiled
  against interpreted) hold on Arch. **Would break if:** Arch's numbers order
  differently; the owner's runs decide (D-057). **DESIGN bet:** D-124, D-125.

## How to verify
`make test </dev/null` (135 tests: 133 passed, 2 skipped on the Mac, 2026-10-20). On a
machine without tree-sitter-cpp, `make test` ends with failures instead of a prompt.
Owner, Arch: `sh spikes/s16-match-function/run.sh ~/source/repos/dealii`; `sh
spikes/s17-compiled-lisp/run.sh 10 2`; the review's `portable-bench.sh` block.
