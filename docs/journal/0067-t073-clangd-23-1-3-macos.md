# 0067 - T-073: the patched clangd on macOS at LLVM 23.1.3

- **Date:** 2026-10-14
- **Commits:** the commit that adds this entry
  (`packaging/clangd-index-nav/build-macos.sh`, DESIGN, README, CHEATSHEET, TASKS)
- **Tier:** 2
- **Decisions:** D-100 (built here), amends D-052; D-027 unchanged
- **Done when:** build-macos.sh builds 23.1.3 with patches 0001 - 0009,
  checksum-checked; run on the Mac it installs to ~/opt/clangd-index-nav a clangd
  whose `--version` says 23.1.3 and that lists both hidden flags;
  `init-cpp-patched-clangd-navigates` and make test pass on the Mac; DESIGN (D-100),
  README and a journal entry updated. Met on the Mac 2026-10-14: built and installed
  in 12.5 min (`--tarball`, the 23.1.1 install kept in a scratch copy),
  `clangd version 23.1.3`, both flags; make test with it 107 / 109, 2 skipped (gdb).
  A first full run had `init-debug-lldb-preset-builds-stops-and-steps` time out
  (121 s); alone it passed in 5.5 s, and the next full run passed: flaky, not
  clangd (the test uses lldb-dap only).
- **Tag:** none

> Plain English for someone who does not read shell fluently.

## What + why
The Mac's patched clangd was built from LLVM 23.1.1 because the script took its
release from the Arch package's PKGBUILD, and Arch's package must match pacman's
LLVM (D-027). MacPorts ships 23.1.3, so the Mac ran an older clangd than its own
system's. The script now names its release (23.1.3) and the tarball's checksum
itself; the patches and their checksums still come from the PKGBUILD, so both
platforms keep applying exactly the same patches while each follows its own
system's LLVM. All nine patches apply to 23.1.3 without fuzz; between 23.1.1 and
23.1.3 clangd's own sources changed only in code completion (`CodeComplete.cpp`),
which no patch touches.

## Concepts explained
- **Sourcing the PKGBUILD:** a PKGBUILD is a shell file; `. PKGBUILD` runs it in
  the script, which then sees its arrays `source` and `sha256sums`. Entry 0 of both
  is Arch's tarball; the script now skips that entry and uses its own `version` and
  `tarball_sha256` instead (`"${sha256sums[@]:1}"` is the array from entry 1 on).
- **The resume stamp:** after extracting and patching, the script writes all
  checksums into `src/.prepared`; a rerun with the same checksums keeps the tree and
  resumes the build. The stamp now holds the 23.1.3 tarball's checksum, so the
  first run after this change rebuilds from scratch, as it must.
- **Where the checksum comes from:** github.com lists a sha256 digest for each
  release file (`api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-23.1.3`);
  the downloaded tarball matched it before the value went into the script.

## Key files walked
- `packaging/clangd-index-nav/build-macos.sh` - `version`, `tarball_sha256` at the
  top; `sums` (the tarball's checksum plus the patches') for the stamp.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** MacPorts' `llvm-23` stays at 23.1.3 for a while. **Would break
  if:** a newer port lands; nothing fails then (the build is self-contained), but
  the two lines at the top of the script want the same bump. **DESIGN bet:** D-100.
- **Assumed:** index shards written by the 23.1.1 build are read by 23.1.3: the
  index code is unchanged between the two (only `CodeComplete.cpp` differs).
  **Would break if:** a later release bumps the shard format; clangd then
  re-indexes, slow once, not wrong. **DESIGN bet:** D-100.
- **Risk:** Arch and Mac now run different clangd releases; a behaviour seen on one
  may not show on the other. Small: only code completion differs.

## How to verify
```sh
packaging/clangd-index-nav/build-macos.sh        # Mac; about 15 min the first time
~/opt/clangd-index-nav/bin/clangd --version      # clangd version 23.1.3
EMACS_CPP_PATCHED_CLANGD=~/opt/clangd-index-nav/bin/clangd make test
```
