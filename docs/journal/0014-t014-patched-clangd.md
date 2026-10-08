# 0014 - T-014: the patched clangd in the config

- **Date:** 2026-10-08
- **Commits:** see `git log -- lisp/emacs-cpp-presets.el packaging/clangd-index-nav`
- **Tier:** 2
- **Decisions:** D-026, D-027 (supersede D-023, D-024)
- **Done when:** the config starts the patched clangd with --navigation-from-index when
  its path is set (customize variable, default: the system clangd), fails loudly if the
  configured binary is missing or lacks the flag; make test covers both the system and
  the patched server; on RMO, after a restart, M-. on a deal.II / std name answers
  within 2 s (agreed 2026-10-08)
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
After S8 passed, the owner chose the patched clangd over the ccls hybrid: it keeps
everything clangd offers (clang-tidy, refactorings, type hierarchy, inlay hints) and,
after a restart, answers the first `M-.` on RMO in 1.4 s instead of 9.3 s. Two pieces:
a package that builds the patched clangd from the release sources plus the local
patches (three, four since pkgrel 2) and installs it to `/opt/clangd-index-nav`
(D-027), and a setting that tells the config to use it (D-026). Without the setting
nothing changes: the system clangd runs as before.

## Concepts (Emacs Lisp) explained
- **defcustom:** a user setting with a type, editable with `M-x customize-variable`;
  the value lands in `~/.emacs.d/custom.el`, outside the repository (D-003).
- **Checking the program once:** asking the binary for its help text costs a process
  start; the answer is cached per file version, so eglot starts stay fast.
- **ert-skip:** a test that cannot run here (the package is not installed) reports
  itself as skipped, visibly, instead of passing silently.

## Key files walked
- `lisp/emacs-cpp-presets.el` - `emacs-cpp-clangd-program`,
  `emacs-cpp-presets--clangd-program`, `emacs-cpp-presets--supports-navigation-p`.
- `packaging/clangd-index-nav/PKGBUILD` and the `000*.patch` files.
- `test/emacs-cpp-presets-test.el` (fake programs for the checks) and
  `test/init-cpp-test.el` (`init-cpp-patched-clangd-navigates`, real binary).

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** LLVM stays at 23.1.1 long enough to be useful. **Would break if:** pacman
  upgrades llvm-libs; the package's exact dependency makes that visible, and the
  patches must then be rebased and the package rebuilt. **DESIGN bet:** D-027.
- **Assumed:** first-session behaviour is unchanged (no stored index yet). Measured on
  the toy: the system and the patched clangd both return only the call as reference
  in a first session, before the other files are indexed.
- **Risk:** the patches are local; upstream may never take them.

## Package build (2026-10-08)
`makepkg` (not installed) built `clangd-index-nav-23.1.1-1-x86_64.pkg.tar.zst`
(6.6 MB, 2171 build steps); `check()` found `--navigation-from-index`. The first build
left the build directory in the binary's library search path (makepkg warned "Package
contains reference to $srcdir"). The binary links only `/usr/lib` libraries, so the
PKGBUILD now sets `CMAKE_SKIP_RPATH=ON`; after a relink, the binary has no search path
and every library resolves. `make test` with the packaged binary: 24 / 24.

## Owner report: `#include` lines (patch 0004, 2026-10-08)
After installing pkgrel 1 the owner found `M-.` on `#include <rmo/option.h>` still
slow, and `M-.` in a second file too. Reproduced the first on the synthetic project
(6226 ms; every name lookup took 2 - 606 ms, so the second did not reproduce, O-13).
Why: clangd answers an `#include` line from the parsed file, and the patches covered
names only. The stored index already lists, for the exact content indexed, which
headers the file included; clangd commit 8df32dbe5 picks the one whose path ends with
the name written on the line (`rmo/option.h`) and answers without the parse. It does
not answer when no or two headers match, for `..` paths or macro includes; those wait
as before. The same commit makes clangd say, in its verbose log, why a request had to
wait. ClangdTests 1412 / 1412; synthetic project 1 ms; pkgrel 2 built (incremental,
from the pkgrel 1 tree with the patch applied as `prepare()` does), `make test` 24 / 24
with its binary.
- **Assumed:** an `#include` in an inactive `#if` block names a header that no active
  include of the same file ends with. **Would break if:** an inactive
  `#include "x.h"` and an active `#include <dir/x.h>`: the jump goes to `dir/x.h`
  where clangd's AST answer would be none.

## Owner verification (2026-10-08)
With pkgrel 3 installed: `M-.` on `#include <rmo/option.h>` instant (log: answered
from the index shard), `M-.` on a name works. T-014 done.

## How to verify
`make test` (24 tests; the patched-server test is skipped until the package is
installed, or run it now with `EMACS_CPP_PATCHED_CLANGD=<path> make test`). Owner:
install the package, set the variable, restart Emacs, `M-.` in RMO.

## Open questions
O-13: `M-.` in a second RMO file still waits; not reproduced on the synthetic project.
