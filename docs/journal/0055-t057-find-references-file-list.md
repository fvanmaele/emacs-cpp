# 0055 - T-057: `C-c p ?` over projectile's files, ripgrep on macOS

- **Date:** 2026-10-13
- **Commits:** the commit that adds this entry (`patches/projectile/0001-...`,
  `.gitmodules`, `lisp/init-project.el`, `lisp/defaults-*.el`,
  `test/init-project-test.el`, `docs/upstream/projectile-find-references-file-list.md`)
- **Tier:** 2
- **Decisions:** D-081 (built here), D-069 (patch files), D-055 (per-platform
  defaults), O-36
- **Done when:** on the Mac, `C-c p ?` for `make_array_view` in deal.II lists its
  matches in about 12 s or less (from 156 s); a test on a toy project gives tracked
  and untracked files, not git-ignored ones, and fails without the patch; startup
  fails loudly without the program; `make test`; owner measures on Arch.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
`C-c p ?` asks "Find references to:" and lists every line of the project that
contains the symbol, as plain text (`M-?` asks clangd instead). On deal.II it took
130 - 156 s on the Mac. projectile 3.4.0 does the search with `find` and then `grep`,
one file after another, and never looks at `xref-search-program`, the Emacs setting
that names the search program. On this Mac, opening a file costs about 14 ms (reading
all 33768 files one by one: 480 s; only asking their sizes: 0.2 s), so a one-file-at-
a-time search is slow whatever it looks for. A three-line projectile patch makes the
command search the files projectile itself lists (what `C-c p f` offers) through
`xref-matches-in-files`, which runs the program `xref-search-program` names. The
config sets that per platform: ripgrep on macOS (it opens files in parallel), GNU
grep on Arch (no ripgrep installed there). Now 10.6 - 11.3 s, with the same matches.

## Concepts explained
- **xref:** Emacs's common layer for "go to definition / list references". A
  command hands it a fetcher, a function that returns the matches when called;
  xref (here through consult) shows them. `xref-matches-in-files` builds the
  matches by piping a file list into the search program (`xargs ... rg ...`).
- **Patch file (D-069):** projectile stays pinned at 3.4.0; `make packages` applies
  `patches/projectile/0001-...` before compiling. Made with `git format-patch` from a
  temporary commit in the submodule, which was then reset.
- **Per-platform default (D-055):** `defaults-darwin.el` and `defaults-gnu-linux.el`
  define the same names; `emacs-cpp-default-xref-search-program` is the new one.
  `init-project.el` checks the executable exists and stops startup otherwise.

## Key files walked
- `patches/projectile/0001-...` - the fetcher of `projectile-find-references` lists
  the project's files at each call (so `g` in the results sees new files) and passes
  them, as absolute names, to `xref-matches-in-files`.
- `lisp/init-project.el` - `emacs-cpp-search-program-check` and the `xref` form that
  sets `xref-search-program`.
- `test/init-project-test.el` - a toy git project with a tracked, an untracked and a
  git-ignored file containing the symbol; with grep and (where installed) ripgrep the
  command finds the first two only. Run against the unpatched function, it fails
  (the ignored file is found).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** projectile's file list is the right scope for a text search.
  **Would break if:** someone needs matches in git-ignored generated files; they
  were searched before. **DESIGN bet:** D-081.
- **Assumed:** GNU grep is fast enough on Arch, where opening a file is cheap. **Would
  break if:** the owner's Arch measurement is slow too; then ripgrep there (O-36's
  other answer). **DESIGN bet:** D-081.
- **Assumed:** the about 14 ms per file opened on the Mac is the machine, not Emacs:
  `cat` from the shell shows it. **Would break if:** it goes away; then the search
  gets faster, nothing breaks.
- **Risk:** a projectile release that changes `projectile-find-references` stops
  `make packages` (`git apply` fails); then drop or redo the patch.

## How to verify
- `make test`: `init-project-search-program`,
  `init-project-find-references-searches-project-files`.
- Done here (Mac, batch, the repo's config, deal.II): `make_array_view` 607 matches
  in 10.76 / 11.25 s, `DoFHandler` 9429 in 10.71 / 10.60 s.
- Owner: on Arch, in deal.II or RMO, `C-c p ?` on a symbol, note the time until the
  list appears; on the Mac, the same by hand.
