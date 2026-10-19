# RESEARCH - dropping the eglot fork

Question (owner, 2026-10-20): how could the vendored, patched eglot (D-108) be dropped?
Findings only; verdicts go to DESIGN (O-69). Arch, 2026-10-20: Emacs 31.1's built-in
eglot read from `/usr/share/emacs/31.1/lisp/progmodes/eglot.el.gz`; the vendored one
from `lib/eglot` (c79f727); GNU ELPA's mirror and release pages fetched the same day;
pyright 1.1.412 driven by a small JSON-RPC client in the session's scratch directory.

## 1. What the fork is and why it exists
- `lib/eglot` is a submodule of github.com/emacs-straight/eglot, which mirrors GNU
  ELPA's *devel* eglot, i.e. Emacs master's `eglot.el` (D-108). It shadows the
  built-in eglot through `lib/load-path.el`. Three patch files (D-069):
  - 0001 (22 lines changed): at `eglot-max-file-watches`, or when the system refuses
    a watch (kqueue's "no file descriptor left" at 975 on macOS, inotify's ENOSPC on
    Linux), keep the watches made so far, warn, and answer the registration with
    success. Stock eglot answers with an error; pyright exits about 0.1 s later,
    and eglot reconnects in a loop when a round lasts over `eglot-autoreconnect`
    (`RESEARCH_platform_differences.md` 3.8, 3.14; 38 connections in 15 s on the
    toy).
  - 0002 (106 lines): one watch per directory shared by a server's registrations
    (pyright registers three times), so the cap counts directories (D-111).
  - 0003 (34 lines): eglot's finders with Emacs 31's xref 1.7.0 (D-117). Needed only
    because the vendored eglot is master's: its 2026-09-08 rewrite calls
    `xref-find-by-kind`, which only master's xref has, while declaring
    `(xref "1.7.0")`.
- Why the patches were needed at all: macOS. Emacs watches with kqueue there, one
  descriptor per directory, and pyright asks to watch its library and site-packages
  (about 2000 directories). The config caps eglot at 500 on the Mac and keeps pyright
  inside the project (`init-lsp.el`, D-054). Without 0001 the cap itself makes
  pyright exit.
- Who uses file watches: pyright (Python) and texlab (LaTeX) register
  `workspace/didChangeWatchedFiles`; clangd registers none. The C++ loop does not
  depend on the fork; the riders do.

## 2. Where upstream stands (2026-10-20)
- Emacs master / ELPA devel: identical to the pin. The mirror's newest commit is
  c79f727 (2026-10-14, "Sourced from eglot version 1.24.0.20261013.24 on GNU ELPA
  Devel"); the watch code and the xref dependency are unchanged; the finders still
  call `xref-find-by-kind`, and the menu still names the removed
  `eglot-find-typeDefinition`.
- GNU ELPA's latest *release* is 1.24 (2026-06-23), before the finder rewrite.
  Emacs 31.1 ships eglot 1.24.31 (its header), whose watch code equals master's
  (3.8); it has neither the watch fixes nor the xref problem.
- None of the reports is sent: the watch report with 0001 (and 0002 as its second
  suggestion) is T-032; the xref / `typeDefinition` regression in devel eglot is not
  drafted yet. Size matters for acceptance: 0001 fits the "around 15 lines" a
  contributor may send without FSF copyright paperwork (Emacs's CONTRIBUTE, as noted
  in 3.8); 0002 does not, so it needs the paperwork or a rewrite by a maintainer.

## 3. Checked: can watching simply be turned off for pyright?
The cheapest way to drop 0001 / 0002 would be to not offer file watching: eglot's
`eglot-client-capabilities` is a generic function, so a method for one server could
leave out `workspace.didChangeWatchedFiles`. Measured with pyright 1.1.412, a
32-directory workspace, `a.py` open and importing `pkg/b.py` (not open):

| client offers watching | registrations | pyright's inotify watches | outside change seen |
|---|---|---|---|
| yes (the client sends nothing) | 2 | 0 | no |
| no | 0 | 0 | no |

pyright does not fall back to watching files itself: without the client's watches
it misses changes made outside Emacs (a `git checkout`, a generator) until the file
is opened or the server restarts. Turning watching off trades the loop for stale
diagnostics. texlab not checked.

## 4. Ways to drop the fork
**(a) Upstream first, then an unpatched eglot.** Send the watch report with 0001
(T-032) and the xref / `typeDefinition` regression; 0002 as a suggestion, with
paperwork if wanted. Once accepted:
- With Emacs master: the next GNU ELPA eglot release carries them; the submodule
  can then pin that release's commit unpatched (no fork, still vendored, D-006), or
  the config can return to the built-in eglot when an Emacs release includes them
  (a behaviour change normally lands in the next major release, not a 31.x bugfix
  release; not checked for eglot, a :core package with its own ELPA releases).
- Until then the fork stays. Cost: none new. Risk: acceptance and timing are not in
  our hands; 0002 may not be taken as is.

**(b) Built-in eglot now, on both machines.** Drop `lib/eglot` and patches 0001 -
0003. 0003 goes away for free (the built-in finders work with xref 1.7.0; the config
names `eglot-find-type-definition`, which 1.24.31 lacks: `init-lsp.el` would go back
to `eglot-find-typeDefinition`). Effects by platform:
- Arch: eglot's cap is 10000, the kernel's inotify limit 524288 on the owner's
  machine (D-115). pyright's three registrations need three watches per directory
  without 0002: RMO has 18 directories with tracked files, this repository 35; a
  failure needs over 3333 directories in one project. Practically unaffected.
- macOS: the cap of 500 (or kqueue's 975) is reached by any project with more than
  about 166 directories (three registrations), and then pyright exits and eglot may
  loop. Mitigations without a patch: keep the trees small with the ignore files of
  3.9; or turn watching off for pyright (section 3: stale diagnostics after outside
  changes); or both.
- The fswatch backend (D-110, DESIGN 7.1) was to be an eglot patch; it would need
  another home (section 5).
- Cost: low (remove a submodule, three patches, two tests' expectations). Risk: the
  loop returns on the Mac for larger Python trees.

**(c) Built-in eglot on Arch, vendored on the Mac.** A per-platform choice (D-055)
of the load path. Keeps the fixes where they matter and the stock eglot where they
do not. Cost: two eglot versions to test, `make packages` and the load path aware
of the platform, against D-098's "every module on both machines" in spirit.

**(d) Built-in eglot plus the fixes in the config.** `eglot-register-capability` is
a generic function, so a method in the config could replace the watch handling for
`workspace/didChangeWatchedFiles`. It would have to use eglot's internals (the
`eglot--file-watches` slot, `eglot--glob-compile`, `eglot--watch-globs`'s logic),
about 100 lines copied: the Lisp workaround D-069 rejects, and it breaks silently on
an Emacs update unless pinned to eglot's version with a startup check.

**(e) Keep the fork, but follow ELPA releases instead of devel.** The fork exists for
0001 / 0002; 0003 exists only because devel moved ahead of Emacs 31's xref. Pinning
the release (1.24, from GNU ELPA's tarball or the commit it was cut from) instead of
emacs-straight's devel head would avoid master-only dependencies and could drop
0003, at the cost of master's other changes since June (182 lines when vendored,
3.8). emacs-straight has no tags; the release commit would have to be found in
Emacs's or ELPA's history. Not a way to drop the fork, a way to shrink it.

## 5. The fswatch backend without a fork
D-110 planned an fswatch backend inside eglot (an fswatch process per server and
root instead of one kqueue descriptor per directory). Emacs's `filenotify.el` picks
one built-in backend at build time (inotify, kqueue, gfilenotify, w32notify) and
offers no hook for an external-process backend, so outside eglot it would mean
advising `file-notify-add-watch` (internals) or proposing a backend to Emacs.
Comparable clients: lsp-mode prompts above `lsp-file-watch-threshold` and can turn
watchers off (`lsp-enable-file-watchers`); VS Code watches on the client side with
recursive native watchers (FSEvents' one stream per tree on macOS); other editors
use external watchers such as Watchman or fswatch for large trees. The LSP
specification leaves watching to the client (`workspace/didChangeWatchedFiles`).

## 6. Summary for the owner
- The C++ loop does not need the fork; Python and LaTeX on macOS do.
- 0003 is a cost of tracking devel, not a reason for the fork.
- Turning watching off is not free with pyright: it then misses outside changes.
- The paths: (a) upstream first (no new cost, timing unknown); (b) built-in now
  (Arch fine, the Mac loses large Python trees); (c) split per platform; (d) copy the
  fix into the config (rejected by D-069); (e) shrink the fork by following ELPA
  releases.

## 7. Ruling, and a correction (2026-10-20)
- Owner: "(c) + (d) - use the mac specific fixes as Lisp in the config, and keep it as
  platform-specific code" (D-121): the built-in eglot on both machines, the former
  0001 / 0002 as advice in `lisp/emacs-cpp-eglot-watch.el` on macOS only.
- Correction to section 4 (b), "Arch: practically unaffected": that counted the
  project's directories only. The config let eglot watch outside the project on
  Arch, and pyright asks to watch Python's library and site-packages: 6358
  directories on the owner's Arch machine (`/usr/lib/python3.14`), three
  registrations, about 19000 watches against eglot's 10000. With the built-in eglot
  the registration failed and pyright exited (`make test`:
  `init-python-pyright-navigates-and-renames`, "Server died"). Watching only the
  project (`eglot-watch-files-outside-project-root` nil) and raising the cap to
  30000 both made the test pass (1.3 s and 2.1 s); the owner chose project-only on
  both platforms.
