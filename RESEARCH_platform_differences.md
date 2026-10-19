# RESEARCH - platform differences: paths, file watches, tools (O-50)

Findings only; verdicts go to DESIGN. Supersedes `RESEARCH_file_watches_macos.md`
(T-029, 2026-10-09), whose findings are carried over unchanged in section 3. Owner
request 2026-10-14: "do proper research for the /tmp/ vs /private/tmp paths and other
platform differences such as file watches". Measured on the owner's Mac (Apple
silicon, Darwin 27, MacPorts Emacs 31.1, MacPorts CMake 3.31.12, clangd 23.1.3 stock
and 23.1.1 patched pkgrel 7), 2026-10-14, unless a section says otherwise. Arch
(owner's run of 2.6, and 2.8): 2026-10-14, clangd 23.1.1 stock, CMake 4.4.4.

## 1. Summary
- clangd's background index drops what each translation unit's own main file
  contributes (definitions and references in the `.cpp` itself; its headers are
  kept) when the compile database spells the file differently from its real path.
  A symlink anywhere in the project's path, such as `/tmp` on macOS, therefore loses
  most of the cross-file references (S12: 3 of 201). It is clangd's behaviour, not
  the local patches': the stock clangd 23.1.3 does the same. Upstream issue
  clangd/clangd#503 has been open since 2020.
- Who spells what: CMake 3.31 always writes `/tmp/...` for `/private/tmp/...`, and
  keeps the spelling of `$PWD` for any symlinked working directory. CMake 4 keeps
  `$PWD`'s spelling only. Emacs passes `default-directory` as the child's `PWD`.
  eglot sends clangd every file under its true name.
- A database rewritten to real paths brings every reference back (399 of 399 in the
  48-file project). clangd's `--path-mappings` does not (4 of 399).
- On macOS `/tmp`, `/var` (with `$TMPDIR` and Emacs's `temporary-file-directory`,
  `/var/folders/...`) and `/etc` are symlinks into `/private`. On Arch none of these
  is one, but any project reached through a symlink behaves the same.
- File watches: kqueue costs one descriptor per watch, and Emacs refuses at 975.
  inotify costs one descriptor for all watches, within a per-user limit that grows
  with RAM. Section 3 carries over T-029's measurements.

## 2. Paths: symlinks and the compile database

### 2.1 Mechanism, measured
A generated CMake project (S12's, 24 or 48 calling files, `calc::combine` called
from every file) under a path with a symlink. A minimal LSP client
(stdio, `initialize`, `didOpen`, 25 s wait, `textDocument/references` on `combine`'s
definition) against the stock clangd 23.1.3, with no Emacs involved:

| Project path, CMake run there | URI clangd was sent | References |
|---|---|---|
| `/tmp/s12r` (database: `/tmp/...`) | `/tmp/...` | 4 in 3 files |
| same | `/private/tmp/...` (eglot's) | 3 in 2 files |
| `~/.cache/s12link`, a symlink (database: link's path) | the link's path | 4 in 3 files |
| same | the real path | 3 in 2 files |
| `/tmp/s12r`, database rewritten to real paths | `/private/tmp/...` | 399 in 50 files |
| `/tmp/s12r`, `--path-mappings=/private/tmp=/tmp` | `/private/tmp/...` | 4 in 2 files |
| `~/.cache/emacs-cpp-s12/...`, no symlink (S12) | the same | 201 (24 files), 399 (48) |

In batch Emacs with the shipped config, the patched clangd answered 3 under `/tmp` and
201 under `~/.cache`, for references as for S12's tweak (`SymbolIndex::refs`). The
stock clangd 23.1.3 answered the same (run through PATH, as D-018 refuses an unpatched
`emacs-cpp-clangd-program`).

What is lost: references to `use::use_00` (declared in `use.h`, defined in
`use_00.cpp`, called from `tests/main.cpp`) list, under `/tmp`, the declaration and
the call twice (once per spelling) but not the definition. Under a real path they
list the definition. So the background index keeps the headers' part of each TU's
index and drops the main file's own symbols and references.

Where it comes from, from clangd 23.1.1's code (`index/`, `SourceCode.cpp`): the
symbol collector names files by `getCanonicalPath`, which resolves the directory to
its real name ("We always want to the real file path (instead of the symlink path)").
The indexer's include graph names them by `tryGetRealPathName`. The background index
receives the main file under the database's spelling. Which comparison drops it:
section 2.8 (2026-10-14), read in the code and checked on Arch.

### 2.2 Who spells the path how
- **CMake 3.31** (MacPorts' version): `cmsys::SystemTools::ClassInitialize` calls
  `AddKeepPath("/tmp/")`: "The tmp path is frequently a logical path so always keep
  it". Every path under `/private/tmp/` is translated back to `/tmp/`, even when
  given as an absolute `-S /private/tmp/...` (measured). The same function keeps the
  logical name of `$PWD` when it leads to the working directory. Source:
  `Source/kwsys/SystemTools.cxx`, tag v3.31.0, lines 4970 - 5010.
- **CMake 4.0 and later**: KWSys commit 47dce1a3 (2024-11-03, "SystemTools: Remove
  path translation map", cmake/cmake#16228) dropped both. CMake 4.1's
  `InitLogicalWorkingDirectory` still uses `$PWD` when its real path is the working
  directory. Paths keep their symlinks unless a `..` follows one
  (`cmPathResolver.h`). So under CMake 4, `cd /private/tmp/x && cmake` writes
  `/private/tmp/...` and `cd /tmp/x && cmake` writes `/tmp/...`. Read from the
  source; CMake 4 was not run here.
- **Emacs**: a child process gets `PWD` set to `default-directory`, as written
  (measured: a buffer in `~/.cache/link/` starts children with
  `PWD=/Users/.../link`). `find-file-visit-truename` is nil, as the config leaves it,
  so a file opened through a link keeps the link's name. A configure started from
  Emacs (`C-c p c c`) therefore writes the spelling the user opened the project
  under.
- **eglot** (Emacs 31): `eglot-path-to-uri` calls `file-truename`, and the server's
  root is `(file-truename (project-root project))`. clangd always gets real paths.
- **The config**: `emacs-cpp-presets--database-files` already resolves the
  database's directories to true names (D-068's "source missing" warning). So that
  warning works under a symlink, and nothing warns about the loss.
- **The tests**: `init-cpp-patched-clangd-navigates` asks for at least one reference
  ("the system clangd also returns just the call here", measured 2026-10-08), so it
  would not notice the loss. Its project is made by `make-temp-file`, which on macOS
  is under `/var/folders`, a symlink.

### 2.3 Where symlinks occur
- macOS: `/tmp -> private/tmp`, `/var -> private/var` (so `$TMPDIR` and every
  `make-temp-file`), `/etc -> private/etc`. `/Users` is not a symlink (a firmlink to
  `/System/Volumes/Data/Users`), `realpath` keeps it, and S12 in `~/.cache` was
  unaffected. Volumes defined in `/etc/synthetic.conf` show up as symlinks at the root
  (the setup of clangd/clangd#503).
- Arch: none of the system directories; any user symlink (a project directory linked
  into `~/src`, a home directory on another disk linked from `/home`) behaves the
  same, as the `~/.cache/s12link` row shows on the Mac. Arch, measured 2026-10-14
  (2.6, the owner's run, and 2.8): the same loss, 3 results through the symlink.

### 2.4 Upstream
clangd/clangd#503 "Indexing issues when root dir is symlinked" (opened 2020-08-22,
open, read 2026-10-14): symbols recorded under the real path while the main file uses
the symlinked path; reported for symlinks inside the tree too. The maintainers'
replies: resolving every database path is an expensive file system operation that
touches libTooling, which other tools share. The suggested workaround is
`--path-mappings`, which measured no help for this case (2.1). April 2026: eglot's
author proposed an optional flag and linked fork commits resolving symlinks in
`JSONCompilationDatabase` and in clangd's compile-command lookup; an earlier
contributor's commits do the same when parsing the database. No change merged.
Related: clangd/clangd#1317 (a `..` in the database's paths stops background
indexing).

### 2.5 Options (for the owner; not a verdict)
- (a) Fail loudly (DESIGN's rule): when eglot starts clangd, compare the database's
  directories with their true names (the table D-068 already builds) and warn that
  cross-file navigation will miss most results. Name the cause (a symlink, `/tmp` on
  macOS) and the fix (open and configure the project under its real path).
  Cheap; fixes nothing by itself.
- (b) Hand clangd a copy of the database with real paths, written next to the
  original (for example `build/debug/.clangd-truename/compile_commands.json`), and
  pass that directory as `--compile-commands-dir`. Measured to restore every
  reference. Costs: a file the config writes (needs its D-nnn); rewriting on each
  database change; `directory`, `file`, `output` and `-I` arguments all need
  resolving; with CMake 3.31 under `/tmp` the build itself keeps the `/tmp`
  spelling (harmless for the build).
- (c) A clangd patch (0010) resolving symlinks in the compile-command lookup and the
  background index, as in the fork commits of 2.4. It fixes every client and costs
  one `realpath` per database entry. It adds to the patched clangd's upkeep and wants
  a spike first (tier 3).
- (d) Document only: keep projects at their real path; never work under `/tmp` on
  macOS; set `find-file-visit-truename` to t, so that buffers, and so the `PWD` of a
  configure from Emacs, use true names. That last setting changes every buffer's
  file name and needs a check of what it breaks. Combinable with (a).
- (e) Report the measurements upstream on clangd/clangd#503 (an outward step, the
  owner's).
- Tests: make the references test require the definition's file too, and create
  test projects under their true name (`file-truename` of `make-temp-file`, as two
  tests already do).

### 2.6 To run on Arch (owner)
```
mkdir -p ~/s12real && ln -s ~/s12real ~/s12link
python3 -I spikes/s12-change-signature/gen_project.py ~/s12real/p 24
cd ~/s12link/p && cmake --preset debug
grep -m1 '"file"' build/debug/compile_commands.json
```
Then open `~/s12link/p/src/combine.cpp` in Emacs, `M-?` on `combine` in
`int combine(int base` once the index has finished (about 20 s). The database should
name `~/s12link` (CMake 4 keeps `$PWD`; `cmake --version` tells which), and eglot sends
`~/s12real`. Expected: under 10 results instead of about 200. For comparison, the
same with the project configured and opened from `~/s12real/p` (remove its `build`
first).

### 2.7 Case and Unicode in file names
Not measured. APFS, as macOS formats it by default, ignores case and Unicode
normalization in file names while preserving them. ext4 on Arch distinguishes both. An
`#include "Foo.h"` for `foo.h` compiles on the Mac only, and two spellings of one
file could split the index as symlinks do. CMake 4 loads the on-disk spelling on
macOS (`ToNormalizedPathOnDisk`); 3.31 does not.

### 2.8 A clangd patch (owner request 2026-10-14, after the Arch run)
Owner, running 2.6 on Arch: 3 results (`src/combine.cpp`, `include/calc/api.h`).
Owner: research a clangd patch (option (c) of 2.5). Read in clangd 23.1.1 with
patches 0001 - 0009 applied (`packaging/clangd-index-nav/src/llvm-project-23.1.1.src`);
none of the patches touches the lines named here. Nothing built.

**Arch check** (stock `/usr/bin/clangd` 23.1.1, CMake 4.4.4, the S12 project with 24
calling files, the client of 2.1 in a scratch directory, the file opened by its real
path): configured through a symlinked directory, 3 references in 2 files
(`api.h`, `combine.cpp`); configured at its real path, 201 in 26. The stored shard of
`use_00.cpp` is 442 bytes through the symlink, 1266 at the real path; `combine.cpp`'s
350 against 652. The shards were not decoded.

**Which comparison drops the main file** (the files are clangd's unless named):
- The background index asks for each translation unit's command by the database's
  spelling: `loadProject` gets the database's file list from the broadcast, and
  `indexFileTask(Path)` calls `CDB.getCompileCommand(Path)` with it.
- clangd's command mangler (`CompileCommands.cpp`, `CommandMangler::operator()`)
  drops the database's input file and appends the requested path after `--`. So the
  compiler's main file is the database's spelling.
- `prepareCompilerInstance` (`Compiler.cpp`) hands the file's text as a remapped
  buffer under that name. clang's `FileManager::getVirtualFileRef` fills
  `RealPathName` with `fillRealPathName`, which only makes the name absolute and
  removes dots ("This is not the same as `VFS::getRealPath()`, which resolves
  symlinks"). Headers are opened as real files, and their `RealPathName` comes from
  the operating system (`openNativeFileForRead`), so it is resolved.
- The include graph (`index/IndexAction.cpp`, `toURI`) names files by
  `tryGetRealPathName`: the main file under the database's spelling, headers under
  their real paths.
- The symbol collector (`index/SymbolCollector.cpp`, through `getCanonicalPath` in
  `SourceCode.cpp`) names every file by its directory's real path plus its file
  name. The main file's symbols and references thus carry the real path.
- `FileShardedIndex` (`index/FileIndex.cpp`) groups symbols and references by these
  URIs, and `BackgroundIndex::update` stores only the shards named in the include
  graph. The real-path shard of the main file, holding its definitions and
  references, is never stored or loaded into the index; the database-spelled one
  holds the include graph only.
- An opened file is unaffected (its references come from the dynamic index, as eglot
  opens it under its real path): hence `combine.cpp`'s own results in the 3.

**A patch (0010), in `index/Background.cpp` only:**
- Give the background index real paths for its translation units: in
  `changedFilesTask` (or `loadProject`), map each file of the database to its
  directory's real path plus its file name, the spelling `getCanonicalPath` gives
  the symbol collector. Everything downstream then uses that spelling: the shard
  loader's lookups and the `DependentTU` it records, `indexFileTask`, the mangler's
  input file, the remapped buffer, the include graph, and the includer table of
  patches 0005 - 0008.
- In `indexFileTask`, set `Cmd->Filename` to the requested path after
  `getCompileCommand`, since the JSON database returns its own spelling there and
  `index()` uses it as the main file for `update` (the `Path != MainFile` checks that
  keep a main file's command in its shard and count its references).
- The command lookup by real path already works: `JSONCompilationDatabase` finds
  files through `FileMatchTrie::findEquivalent`, which compares a candidate sharing
  the path's last components with `sys::fs::equivalent`. That is how eglot's
  real-path files get their flags today.
- Cost: one real-path lookup per distinct directory of the database, cached by
  directory. Measured on Arch in Python (`os.path.realpath`, slower than C's): 92990
  files under `/usr/include` take 1.03 s one by one, their 4205 directories 0.04 s.
  The upstream objection (2.4) was to resolving every path in libTooling, which this
  patch leaves alone.
- Shards written before the patch are stored under the database's spelling and are
  not found under the real one: one full re-index per project after the update.

**Left open (for the spike, tier 3):**
- A main file that is itself a symlink (not its directory): the symbol collector
  keeps the link's file name, the include graph would then resolve it fully. The
  patch's spelling matches the symbol collector, so only the include graph's could
  differ; not checked.
- Headers reached through a symlinked `-I` directory are already resolved on both
  sides (above); not checked.
- Whether `findEquivalent` stays unambiguous when the database lists two files that
  share their last components; `sys::fs::equivalent` decides then.
- Spike: build the patched clangd, run the 2.1 client through the symlink (expect
  201 in 26 files) and under `/tmp` on the Mac; restart and count the `Indexed` log
  lines (expect none: shards loaded, not re-indexed); a clangd unit test in
  `BackgroundIndexTests.cpp` with a symlinked directory (`InMemoryFileSystem`
  supports symbolic links).

## 3. File watches (carried over from RESEARCH_file_watches_macos.md, T-029)
Measured 2026-10-09 on the owner's Mac (MacPorts Emacs 31.1, `emacs-app` with kqueue).

### 3.1 Mechanism
- Emacs on macOS watches files with kqueue (`file-notify--library` is `kqueue`;
  `system-configuration-features` lists KQUEUE, not inotify). Linux uses inotify,
  where one descriptor carries any number of watches.
- `kqueue-add-watch` (Emacs `src/kqueue.c`, master, read 2026-10-09) opens the watched
  file or directory itself (`O_EVTONLY`, non-blocking, not following a final symlink):
  one descriptor per watch. A watched directory takes one descriptor; files inside it
  are not opened, changes are found by comparing directory listings.
- The same function refuses a new watch when `watches > soft RLIMIT_NOFILE - 50`
  ("File watching not possible, no file descriptor left"); 50 descriptors are kept
  for the rest of Emacs. Without `getrlimit` it assumes 256.
- Emacs keeps its own soft limit at `FD_SETSIZE` (1024) when the inherited one is
  higher (the `nofile_limit` comment in `src/process.c`; the code itself was not
  read, the measurement below agrees).

Measured: watches on empty temporary directories until Emacs refuses
(`emacs -Q --batch`, `file-notify-add-watch` in a loop):

| Soft limit Emacs started with | Watches before the refusal |
|---|---|
| 1048576 (the owner's shell) | 975 |
| 4096 | 975 |
| 256 | 207 |

`launchctl limit maxfiles` reports soft 256, hard unlimited. That is NOT what a
started app gets (corrected 2026-10-09, revisit of O-26). Emacs.app started through
Launch Services (`open -a`, as the Dock and Finder do), with `-Q` and a script that
counts, held 975 watches, and its child processes saw `ulimit -n` 1024. It was the
same when `open` ran from a shell lowered to 256, so the caller's limit does not carry
over. The 256 row above is a shell with `ulimit -n 256`, not a case met in use. An
Emacs started from a terminal also gets 975. `kern.maxfilesperproc` is 61440.

Linux, for comparison (from the kernel, not measured here): one inotify descriptor per
Emacs (`src/inotify.c`), and watches count against `fs.inotify.max_user_watches`,
shared by all of the user's processes. Since Linux 5.11 (kernel commit 92890123749b),
its default scales with RAM, 1 % of memory at about 1 KB per watch, between 8192 and
1048576 (about 130000 for 16 GB).

### 3.2 Who watches in a C++ session
Measured in batch with the shipped config, the patched clangd and a copy of RMO
(`CLionProjects/step-1`, 13 sources, 77 directories with the build tree). The files
were committed to git so that magit's auto-revert applies, and
`magit-auto-revert-mode` was on, as in an interactive session:

| Moment | Watches | From |
|---|---|---|
| after startup | 0 | - |
| `main.cc` open, eglot connected | 1 | auto-revert (magit) |
| 25 project files open | 24 | auto-revert, one per tracked file |
| clangd's own requests | 0 | clangd registers no file watchers with eglot |

Not measured, from the code:
- treemacs (`treemacs-filewatch-mode`, on by default): one watch per directory shown
  expanded in the tree.
- projectile: watches only with `projectile-auto-update-cache-with-watches`, off by
  default and not set here.
- pyright (Python, D-045): one watch per directory of the project and, unless D-054
  applies, of Python's library and site-packages: about 2000 on this Mac (0034).

A change across many files adds to auto-revert's count: S12's change signature
opened 20 - 50 files in buffers (section 4).

### 3.3 What happens at the limit
- **eglot:** a server's watch request (`client/registerCapability` for
  `workspace/didChangeWatchedFiles`) fails as a whole in two ways. Either kqueue
  refuses a watch ("no file descriptor left", 0034), or eglot reaches
  `eglot-max-file-watches`. Then eglot warns, removes the watches it already added
  and answers the request with an error (`eglot--watch-globs`, Emacs 31 eglot; its own
  comment notes that keeping the partial watches would be possible). pyright exits
  after either. Measured 2026-10-09 with D-054 (project files only, cap 500) on a
  generated project of 600 directories: eglot's warning "Reached
  `eglot-max-file-watches' limit of 500", then pyright exited. On 50 directories it
  stays up.
- **auto-revert:** catches the error and quietly switches that buffer to polling
  (every `auto-revert-interval`, 5 s). Reverts still happen, later.
- **treemacs:** ignores only "No file notification program found"; this error would
  surface when a directory is expanded.

### 3.4 Effects on C++ work
- clangd asks for no watches, so the size of the source tree (deal.II's 1813
  directories included) does not matter for the language server.
- What grows with use is auto-revert (open files) and treemacs (expanded
  directories), out of 975 whether Emacs was started from a terminal or the Dock.
  Then auto-revert polls and treemacs reports errors on expanding.
- A Python buffer in the same Emacs shares the budget: pyright's project watches count
  against the same 975.

### 3.5 pyright with and without eglot's watches
Measured 2026-10-09 in a terminal Emacs (tmux, real command loop). `main.py` imports
`newmod`, which does not exist; `newmod.py` is then written from outside Emacs. After
an edit, is the "could not be resolved" diagnostic gone? A control watch on the
project root saw the change in every run.

| Setting | 50 directories | 600 directories |
|---|---|---|
| A: D-054 (project only, cap 500) | sees the change; up | exits at the cap |
| B: cap 500, library watched too | exits (library about 2000 dirs) | not run |
| D: eglot offers no file watching | up; never sees the change | up; never sees the change |

So "project files only" is what keeps pyright running at all on the Mac; without
eglot's watches pyright does not watch by itself and goes stale silently.

pyright registers `workspace/didChangeWatchedFiles` three times at start (three ids;
the later two add the library roots) and unregisters the first two afterwards; eglot
watches every directory once per registration. With D-054 (cap 500, project only):
50 directories 153 watch calls, 150 directories 453 (running), 400 directories exit
at the cap. Without a cap the Mac refuses at 975, i.e. near 325 directories. Measured
2026-10-09 by counting `file-notify-add-watch` and `eglot--watch-globs` calls.

Method note: batch Emacs (`emacs --batch`) delivers no file notification events (a
control watch saw 0 events while `accept-process-output` and `sit-for` ran), so such
tests need a command loop; the descriptor counts of section 3.2 are unaffected.

### 3.6 Options for D-054 (2026-10-09; ruled)
- (a) Keep D-054 as it is: works for Python projects up to about 160 directories
  (the three registrations above; first stated as 500, corrected after the owner's
  ruling; the owner's projects so far: one directory); above that pyright exits,
  after eglot's warning.
- (b) Raise the cap towards the real limit, e.g. 800: larger projects; leaves about
  175 watches for auto-revert and treemacs before they poll or fail.
- (c) Offer no file watching on macOS: pyright never exits, but misses every change
  made outside Emacs (checkout, generated files) until it restarts, without a sign.
- (d) Ask eglot upstream to keep the partial watches at the cap instead of failing
  the request (its own comment says so); a local override would copy an internal
  function. Combinable with (a) or (b).
- Withdrawn: lowering the cap for a 207 limit, and raising launchd's limit; the 207
  case does not occur (section 3.1).

Ruled 2026-10-09: (a) + (d); D-054 confirmed; the report is
`docs/upstream/eglot-watch-cap-partial-watches.md` with `eglot_watch_cap_repro.sh`.

### 3.7 The cap met on deal.II's step-1 (owner report 2026-10-15, O-59)
Owner's `*Messages*` after visiting `staging/plot_theta.py` in
`~/CLionProjects/step-1`: eglot connected pyright, warned "Reached
`eglot-max-file-watches' limit of 500" three times, "[jsonrpc] Server exited with
status 1", "Not auto-reconnecting, last one didn't last long", and twice "Error
running timer: (error "Process EGLOT (step-1/(python-ts-mode python-mode)) not
running: exited abnormally with code 1")". Checked read-only in the project,
2026-10-15:
- eglot watches the directory of every file `project-files` lists (`eglot--watch-
  globs`, `subdirs-using-project`). For a git project that is tracked files plus
  untracked ones git does not ignore (`project-vc-include-untracked`, t by
  default): 14782 files in 1811 directories. Tracked alone: 17 directories.
- 1787 of those directories are under `build_cpu/` (14244 files, 2.0 GB: `bin`,
  `bin_v2` ..., logs, results; no `CMakeCache.txt`, so not a CMake build tree).
  step-1's `.gitignore` lists `build/` and `build-*/`, not `build_cpu/`; the CLion
  trees `cmake-build-*` hold no untracked files git sees.
- So the first of pyright's three registrations hits the cap of 500 at once: the
  case section 3.6 (a) foresaw (about 160 directories). pyright exits, as measured
  in 3.3. The two later warnings and the two timer errors are eglot answering
  pyright's other registrations after the process had exited (the reply cannot be
  sent); they are noise from the same cause. Not reproduced here; read from the
  order of the messages and `eglot--watch-globs`.
- The same untracked files fill `M-o`'s and `C-c p f`'s file lists: projectile
  lists untracked files too (`git ls-files -co --exclude-standard`).
- Unrelated, also in the report: `#plot_theta.py#` is an auto-save file from
  2026-10-14 19:08, newer than `plot_theta.py` (2026-07-09); it differs by `# %%`
  cell markers added then and never saved (`diff`). Emacs offers
  `M-x recover-this-file`; whether to recover is the owner's call. step-1's
  `.gitignore` ignores `#*#`.

Options (not ruled, O-59):
- (a) The owner adds `build_cpu/` (or `build_*/`) to step-1's `.gitignore`: 24
  directories left, so about 72 watch calls; the file lists shrink by 14244. Outside
  this repository, no code here.
- (b) Watch tracked files only: `project-vc-include-untracked` nil in the config
  (project.el, every user of `project-files`); a new untracked `.py` file is then not
  watched until added to git; projectile's lists unchanged.
- (c) Send the eglot report of 3.6 (d) (T-032, the owner's): with partial watches
  pyright would stay up, watching the first 500 directories.
- (d) Raise the cap (3.6 (b)): 1811 directories times three registrations is far
  above the 975 the Mac allows; does not help here.

Owner 2026-10-15: (a) with `build*/`; asked whether eglot still runs on untracked
`.py` buffers under (b); (c) research a patch for eglot. Section 3.8.

### 3.8 Untracked buffers, and a patch for eglot (owner 2026-10-15, T-089, O-60)
**(a) in step-1** (read-only count): with `build*/` added to `.gitignore`, the file
list holds 478 files in 22 directories; no tracked file lies under a `build*`
directory (`build/`, `build_cpu/`, `build_lumping/`, `interpolate_test/build/`, two
under `.qtcreator/`), so nothing tracked changes. The pattern covers `build/` and
`build-*/` too.

**(b) untracked `.py` buffers** (batch, shipped config, toy git project with
`vec.py` untracked, pyright, 2026-10-15):
- Which list eglot watches: projectile's. projectile adds `project-projectile` to
  `project-find-functions` ahead of project.el's VC backend, so `project-files`
  is projectile's file list, listed by `fd` when it is installed
  (`projectile-git-use-fd`, on here; `fd -H -E .git`, honouring `.gitignore`), else
  `git ls-files -zco --exclude-standard`. project.el's
  `project-vc-include-untracked` (option (b) as worded in 3.7) has no effect: with
  it nil the list still held `vec.py` (6 files either way).
- The equivalent knob: `projectile-git-use-fd` nil and `projectile-git-command`
  `git ls-files -zc` (tracked only): the list drops `vec.py` (5 files).
- Either way `vec.py` is managed by eglot, pyright runs, and `workspace/symbol`
  lists its symbols (`Vector`, `vector_norm`): eglot manages a buffer by its
  project (the directory), not by the file list, and pyright reads the workspace
  itself. What tracked-only costs: a directory holding only untracked files is not
  watched (pyright misses changes made there outside Emacs), and untracked files
  leave `M-o`'s and `C-c p f`'s lists until `git add` (same list).
- With (a) done, step-1 is at 22 directories; (b) is not needed for it.

**(c) a patch for eglot:**
- Upstream unchanged: Emacs master's `eglot.el` (GitHub mirror, fetched 2026-10-15)
  has the same watch code as 31.1's eglot 1.24.31, from `eglot-watch-files-outside-
  project-root` to `eglot-unregister-capability` (no difference); its other parts
  differ by 182 lines. The GNU ELPA package mirror `emacs-straight/eglot` equals
  master.
- The change (`docs/upstream/eglot-watch-cap-partial-watches.patch`, 13 lines in, 9
  out, one function): at the cap, warn once and stop adding watches instead of
  signalling `jsonrpc-error`; a watch the system refuses (`file-notify-error`, e.g.
  kqueue's "no file descriptor left") the same. The registration then succeeds
  with the watches added so far. Under the GNU maintainers' "around 15 lines" for
  a change without copyright paperwork (`Copyright-paperwork-exempt: yes`,
  Emacs's CONTRIBUTE).
- Checked with `docs/upstream/eglot_watch_cap_repro.sh` (a copy loading the
  patched `eglot.el` after eglot; Mac, pyright 1.1.414):

  | Case | eglot 1.24.31 | patched |
  |---|---|---|
  | 600 directories, cap 500 | pyright exits | runs; 3 warnings |
  | 1100 directories, no cap | pyright exits (1) | runs; a warning per refusal |

  (1) kqueue refuses at 975: "Error running timer: (file-notify-error ...)". The 3
  warnings: one per pyright registration.

  Not checked: that pyright sees changes in the watched directories with the patch
  (batch Emacs delivers no file events, 3.5 method note); a terminal run would.
- Side effect without a cap: the patched eglot keeps the 975 descriptors it took,
  leaving none for auto-revert and treemacs; D-054's cap of 500 stops it first.
- Not prototyped: one watch per directory shared by a server's registrations
  (the report's suggestion 2), which would divide pyright's watches by three;
  larger, needs paperwork.
- How the config could carry it:
  - (a) Upstream only: the owner sends the report (T-032) with the patch; the fix
    arrives with a later Emacs or GNU ELPA eglot; nothing here.
  - (b) Vendor eglot: `emacs-straight/eglot` as a submodule (D-006) plus the patch
    file (D-069). It shadows the built-in eglot (`lib/load-path.el` puts `lib/`
    first). Its Package-Requires are met by Emacs 31.1's bundled versions (jsonrpc
    1.0.29, flymake 1.4.6, eldoc 1.16.0, project 0.12.0, xref 1.7.0,
    external-completion 0.1, seq 2.24). Brings master's other 182 changed lines to
    both machines: a new dependency, D-nnn, tests.
  - (c) Override in the config: redefine `eglot--watch-globs` (an internal
    function, about 70 lines copied) after eglot loads, failing loudly at startup
    when eglot's version is not 1.24.31; breaks on any Emacs update by design.
  - (d) None: (a) of 3.7 holds step-1; the next large untracked tree repeats it.

### 3.9 Which files to watch, and large repositories (owner 2026-10-15, T-091, O-61)
Owner, ruling O-60 (b) (vendor eglot, D-108): "untracked buffers still undecided;
other definitions for files that should be tracked, outside of git status?; issue
may resurface for very large git repositories with many committed files". Mac,
2026-10-15; batch checks with the shipped config on the toy of 3.8.

**Ways to leave files out of eglot's watches without `.gitignore`.** eglot watches
the directories of `project-files`, which is projectile's list (3.8), so anything
that list honours works. Checked on the toy, one directory per mechanism, each
absent from `project-files`:
| Mechanism | Committed? | `fd` (Mac) | `git ls-files` (no `fd`) |
|---|---|---|---|
| `.git/info/exclude` | no, local to the clone | honoured | honoured |
| `.ignore`, `.fdignore` | either | honoured | not honoured |
| `.projectile`, a `-/dir` line | either | honoured | (1) |
| `projectile-globally-ignored-directories` | config, every project | (1) | (1) |
(1) Not checked: projectile hands its own ignore rules to the tool as exclusions
(`projectile-alien-honors-ignores`, t by default; `git ls-files` by pathspecs,
`fd` by `--exclude`). The checked ones also leave the files out of `M-o` and
`C-c p f`; the `git ls-files` column was checked with git alone. Not checked
here: whether Arch has `fd` (projectile then takes `git ls-files`, which ignores
`.ignore` / `.fdignore`).

Other ways, not in place today:
- By the server's language: watch only directories holding files the server reads
  (for pyright `.py`, `.pyi`, `pyproject.toml`, `pyrightconfig.json`). pyright
  registers `**` and `**/pyrightconfig.json` (repro events), so eglot watches every
  directory today. A filter needs eglot code (a second patch on the vendored eglot,
  D-108). Risk: a `.py` file created in a directory that held none goes unnoticed.
- pyright's own `include` / `exclude` (`pyrightconfig.json`, `[tool.pyright]`):
  steer what pyright analyses, not what eglot watches.
- project.el's `project-vc-ignores`, `project-vc-include-untracked`: no effect,
  projectile is the backend (3.8).

**Large repositories with many committed files.** Counted with `git ls-files` in
the owner's checkouts:
| Repository | tracked files | directories | with `.py` / `.pyi` |
|---|---|---|---|
| `~/source/repos/dealii` | 33768 | 1754 | 6 (19 files) |
| `~/source/repos/llvm-project` | 187428 | 14419 | 1779 (3191 files) |
| step-1 with `build*/` ignored | 478 (with untracked) | 22 | not counted |
- Visiting a `.py` file in deal.II's or LLVM's checkout starts pyright, which asks
  for all 1754 / 14419 directories three times: past D-054's 500 on the Mac, and
  for LLVM past eglot's default 10000 on Arch too (inotify allows far more; not
  checked there). Unpatched, pyright exits; with D-108's patch it stays up,
  watching the first 500 directories in list order, the rest silently unwatched.
- By language, deal.II needs 6 directories, LLVM 1779 (still past 500).
- One watch per directory shared by a server's registrations (the report's
  suggestion 2) divides the count by three: LLVM 14419, still past every cap.
- A whole-tree watcher would need one descriptor: Emacs's backend on the Mac is
  kqueue (`file-notify--library`), one descriptor per directory; Emacs has no
  FSEvents backend. pyright does not watch by itself when the client offers
  watching (3.5).
- So for such trees the choice is which directories get the watches, not whether
  all can.

**Options** (not ruled, O-61):
- (a) Tracked-only lists (3.8 (b)): undecided by the owner; does not help with
  committed files.
- (b) Per-project exclusions as above, chosen per checkout (a `.projectile` line or
  `.git/info/exclude` for trees one does not edit);
  the config documents them, no code.
- (c) Language filter in the vendored eglot (patch 0002): pyright in deal.II from
  1754 to 6 directories.
- (d) Priority under the cap: with the patch the first 500 in list order win;
  instead the directories of open buffers and their parents first, then the rest
  (patch 0002 or 0003).
- (e) Suggestion 2, shared watches (patch, larger; also upstream).
- (f) Nothing beyond D-108: partial watches, a warning, pyright stays up.

### 3.10 Draft: watch patterns per server (owner 2026-10-15, T-092, O-61 (c))
Owner: "Draft a patch for the vendored eglot, which configured watch patterns for
different servers - although this does still not solve the issue on repositories
like LLVM." Draft: `docs/upstream/eglot-watch-file-patterns.patch`, against the
mirror (c79f727) with `eglot-watch-cap-partial-watches.patch` applied first (it
applies there unchanged). Mac, 2026-10-15, all in a scratch directory.

**What it adds:** `eglot-watch-file-patterns`, an alist `(MODES . PATTERNS)`, MODES
as in `eglot-server-programs`. For a server managing one of MODES, eglot watches a
project directory only if it holds a file whose base name matches one of PATTERNS
(shell wildcards), plus the project root. Servers without an entry, and
registrations based outside the project (library roots, `subdirs-using-find`), are
unchanged; which events are reported still follows the server's own globs. For
this config's servers it would read, for example:
`(((python-mode python-ts-mode) "*.py" "*.pyi" "pyproject.toml" "pyrightconfig.json")
((LaTeX-mode latex-mode bibtex-mode) "*.tex" "*.bib" "*.sty" "*.cls"))`; clangd
asks for no watches.

**Why base-name wildcards, not LSP globs:** a first version took LSP globs
(`**/*.py`) through eglot's own `eglot--glob-compile`; matching every file of the
list took 1157 ms for deal.II (33768 files) and 5678 ms for LLVM (187428): the
matcher inserts each name into a buffer. One regexp from `wildcard-to-regexp` over
the base names: 70 ms and 346 ms, the same 19 / 3199 matches. Both run once per
registration, after `project-files` has listed the files.

**Checked:**
- Byte-compiles with no new warning (the mirror's two xref warnings are there
  without it).
- Toy with pyright 1.1.414: 600 directories, `.py` files in 10 of them and
  `main.py` at the root, `eglot-max-file-watches` 500, project directories only,
  15 s after connecting:

  | eglot | pyright | watches at most | watches at the end |
  |---|---|---|---|
  | mirror + 0001, no patterns | runs | 500 | 0 |
  | mirror + 0001 + 0002, Python patterns | runs | 22 | 11 |
  | mirror + 0001 + 0002, no patterns set | runs | 500 | 0 |

**Found: 0001 alone ends with no watches.** pyright registers three times and then
unregisters the first two (3.5). With the cap reached by the first two, the third
gets none (0001 keeps it, empty); when the first two go, nothing is left. So 0001
keeps pyright alive but blind whenever the cap is reached. The patterns avoid it
where they shrink the list below a third of the cap. Remedies, not drafted: re-run
a registration that was cut short whenever another is removed (O-61 (g)), or one
watch per directory shared by a server's registrations (O-61 (e)).

**LLVM:** with the Python patterns, 1779 directories (of 14419) hold Python files:
past 500 by itself, and three registrations make it 5337. With 0001 the result is
the zero-watch case above. As the owner says, the draft does not solve it; per
project exclusions (3.9) or (e) / (g) would still be needed there.

**Risks of the draft:**
- A file matching the patterns created in a directory that held none goes
  unnoticed until the server registers again (that directory is not watched).
- The root is always watched, so a new top-level `.py` file is seen.
- 32 changed lines: for Emacs upstream, copyright paperwork.

### 3.11 Drafts for O-61 (e) and (g), and what CLion, Xcode, Qt Creator do (T-093, T-094)
Owner 2026-10-15: "Draft fixes for O-61. Do a thorough research what CLion, XCode
and QtCreator do on macos for file watches and large repositories." Mac, 2026-10-15.

**Drafts** (against the mirror c79f727 with 0001; each applies alone, also next to
the patterns draft of 3.10; not applied anywhere):
- (g) `docs/upstream/eglot-watch-retry-cut-short.patch`, 37 changed lines: a
  registration that hits the limit is remembered with its watchers; when another
  registration is removed and frees watches, the remembered ones are set up again
  (a guard stops the re-registration from recursing).
- (e) `docs/upstream/eglot-watch-shared-directories.patch`, 76 changed lines: one
  file watch per directory and server, a table directory -> (descriptor .
  handlers); each registration adds its handler to an existing watch instead of a
  second watch; the watch goes when its last registration does; the count is
  directories, not registration-directory pairs; shutdown stops them all.
- Both byte-compile without new warnings. Checked with pyright 1.1.414 (cap 500,
  project directories only, 15 s after connecting; a "created" event sent through
  the real watch callback of `d5`):

  | Toy | eglot | watches at most | at the end | event in `d5` |
  |---|---|---|---|---|
  | 400 directories | 0001 | 500 | 0 | not watched |
  | 400 directories | 0001 + (g) | 500 | 401 | 1 notification |
  | 400 directories | 0001 + (e) | 401 | 401 | 1 notification |
  | 600 directories | 0001 + (g) | 500 | 500 | not checked |
  | 600 directories | 0001 + (e) | 500 | 500 | not checked |

  (e) never goes past one watch per directory, so pyright's three registrations
  cost no more than one; (g) needs the cap headroom for a while, then recovers.
  Neither helps once the directories alone exceed the cap (LLVM: 14419, or 1779
  with Python files).

**CLion (IntelliJ platform):**
- The macOS file watcher is `fsnotifier`, a small native helper
  (`intellij-community/native/fsNotifier/mac/fsnotifier.c`, read 2026-10-15): one
  FSEvents stream on `/`, latency 0.3 s, no per-directory or per-file watches. It
  reports a dirty directory (`DIRTY`), a subtree to rescan (`RECDIRTY`, on
  `kFSEventStreamEventFlagMustScanSubDirs`) or `RESET`; the IDE filters by its
  project roots and refreshes its virtual file system from disk. The roots it is
  sent only decide which non-local mounts it reports as `UNWATCHEABLE` (network
  file systems; those are refreshed instead). So on macOS the number of directories
  costs nothing; the cost is the refresh after events.
- Large trees: excluded folders are still watched; open since 2011 (IJPL-2175:
  "When a folder is excluded from the project, is still tracked by file watcher").
  A "File system synchronization" popup that blocks the UI on large or busy trees
  is open too (IJPL-2189, 2020; CPP-42555 for CLion, 2024, resolved 2025). A
  replacement of the per-OS watchers by common code is planned (IJPL-251901,
  2026-08). Settings (CLion 2026.2 help, System Settings): "Sync external changes"
  when switching to the IDE window or opening a tab, or (experimental) every 15 s
  while inactive; the watcher can be turned off (`idea.filewatcher.disabled`,
  reported on JetBrains' forum, not checked), external changes are then found only
  by those refreshes.
- Linux, for comparison: inotify, one watch per directory, the IDE's warning "The
  current inotify watch limit ... is too low" (IJPL-2175's description).

**Xcode:**
- Not installed here, and Apple documents nothing about how Xcode watches files.
  What Apple documents is FSEvents itself (File System Events Programming Guide,
  updated 2012-12-13): notifications per directory ("only that something in the
  directory has changed"), for "passively monitoring a large tree of files",
  coalesced, with history across runs; for one particular file kqueue is the
  suggested tool.
- Project model: Xcode 16 added folders synchronized with the disk
  (`PBXFileSystemSynchronizedRootGroup`): the project file records only the folder,
  Xcode lists its contents. A third-party measurement (rules_xcodeproj PR #3373,
  Xcode 26.2, 200 targets, 3000 files, 200 synchronized folders) found each added
  or removed file costing Xcode about 1.5 - 2.5 s of CPU to re-evaluate target
  membership. Older group-based projects list every file and see only those.
- Not established: whether Xcode uses FSEvents for these folders (likely, not
  shown); behaviour with a 14000-directory tree.

**Qt Creator:**
- Qt's `QFileSystemWatcher` on macOS uses its FSEvents engine
  (`qtbase/src/corelib/io/qfilesystemwatcher.cpp` picks
  `QFseventsFileSystemWatcherEngine` for `Q_OS_MACOS`; kqueue only on the BSDs and
  iOS): one FSEvents stream over all watched paths, each path reference-counted
  (watched twice costs nothing extra), the stream restarted when the set changes;
  on an event the directory is listed again and compared with what was known
  (`qfilesystemwatcher_fsevents.mm`, dev branch, read 2026-10-15).
- Qt Creator wraps it in `Utils::FileSystemWatcher`
  (`src/libs/utils/filesystemwatcher.cpp`, master 2026-10-14): one shared watcher;
  on macOS it uses at most half of the process's open-file limit (`RLIMIT_NOFILE`,
  a rule from its kqueue days) and past that warns "File ... is not watched: Too
  many file handles are already open" and goes on with what it has: partial
  watches, as 0001 does.
- Its language client does not offer `workspace/didChangeWatchedFiles` at all
  (`src/plugins/languageclient/client.cpp` builds the workspace capabilities without
  it; the protocol types exist in `languageserverprotocol` only). A server such as
  pyright gets no watching from Qt Creator; per 3.5 it then misses changes made
  outside the editor.

**What follows for this config:**
- The IDEs that watch whole trees on macOS do it with one FSEvents stream per tree
  (or for `/`), not a descriptor per directory; that is why size does not matter
  to them. Emacs's backends on macOS are kqueue only (3.9); no per-directory
  scheme, (e) and (g) included, reaches LLVM's 14419 directories under 975.
- A tree-level watcher for eglot would be an external process: `fswatch` (FSEvents
  on macOS, inotify on Linux; MacPorts 1.20.1) or Watchman (MacPorts
  2026.07.27.00), neither installed; eglot would start one per server and root and
  turn its output into `didChangeWatchedFiles` with the server's globs. A new
  dependency (D-nnn) and a larger eglot patch; option O-61 (h). Not prototyped.
- Qt Creator's choice, offering servers no watching, is 3.6 (c) here (setting D
  of 3.5): the server never exits and goes stale.

### 3.12 A tree watcher for eglot: fswatch and Watchman (owner 2026-10-15, T-095, O-61 (h))
Owner: "Research O-61 (h). fswatch and watchman both installed through macports."
Mac, 2026-10-15: fswatch 1.20.1, Watchman 2026.07.27.00 (MacPorts). Test tree in
a scratch directory, sized like LLVM: 15408 directories, 187395 files (LLVM's
checkout: 16993 directories, 187428 tracked files). Watchman writes cookie files
into the root it watches, so it was kept off the owner's checkouts; `fswatch` was
also run read-only on `~/source/repos/llvm-project`. Prototype code (an Emacs
filter turning `fswatch` output into LSP changes) in the scratch directory only.

**What each is:**
- `fswatch`: a command printing one record per changed path, with flags
  (`fswatch -0 -r -x --event-flag-separator=, -l 0.1 -e '/\.git/' ROOT`); on macOS
  its `fsevents_monitor` (also `kqueue_monitor`, `poll_monitor`). No daemon.
- Watchman: a daemon per user (started on demand, socket under `$TMPDIR`); a
  client asks it to watch a root (`watch-project`), then queries "files changed
  since clock C" or subscribes (`subscribe`, JSON lines on a persistent
  connection, fields such as `name`, `exists`, `new`). It ignores `.git` itself,
  not `.gitignore`.

**Measured:**
| | fswatch | Watchman |
|---|---|---|
| start | at once, no crawl | crawl of 187395 files: 1.9 s (watch + first query) |
| descriptors | 8 (LLVM's checkout: 8) | 58 (daemon) |
| memory | 6 MB (LLVM: 6 MB) | daemon 21 MB idle, 101 MB with the tree |
| change to record | 15 - 106 ms at 0.1 s latency | not timed |
| 20000 changes, Emacs reading | all 20000, no overflow | not run with Emacs |
| 20000 changes, reader paused | 980 - 998, rest lost silently | all 20000 (5 messages) |
| writes into the tree | none | cookie files at the root, removed again |
| Arch | `extra` 1.22.0 | AUR only (`watchman-bin` 2026.07.27.00) |

- Emacs's share (prototype filter: split records, `file-exists-p`, eglot's glob
  matcher, `eglot-path-to-uri`): 3.7 - 4.1 s of CPU for 20000 records, spread over
  the 15 - 18 s the writes took; not broken down, but eglot's glob matcher is the
  known slow part (3.10). A regexp per pattern and a stat only for records flagged
  `Removed` would cut it.
- The loss with `fswatch`: while the reader does not read, `fswatch` fills the pipe
  (about 1000 records, 64 KB) and blocks; FSEvents drops what comes meanwhile, and
  `--allow-overflow` reported nothing. Records written after the reader resumed
  arrived. In Emacs: a filter not called for a while (a long synchronous command, a
  long collection) during a burst such as `git checkout` loses changes silently.
  Watchman's daemon keeps the changes and hands them over when read (clock-based),
  so a paused Emacs loses nothing.
- Flags with FSEvents add up per path: a file created and then removed was
  reported as `Created,IsFile,Updated,Removed,AttributeModified`. Deciding
  created / changed / deleted needs a stat at the time of the record. Watchman
  answers `exists` and `new` directly.
- Paths: both report the real path. `fswatch` given `/tmp/...` reports
  `/private/tmp/...`, and `watch-project` answers with `/private/tmp/...`; eglot
  would map them back to the project root's spelling (cf. O-50).

**On Linux (Arch), not measured:** both use inotify there, one watch per directory,
as Emacs's own `file-notify` does; the limit is the kernel's
`fs.inotify.max_user_watches` (owner: `sysctl fs.inotify.max_user_watches`), not
descriptors. A tree watcher changes little on Arch; the problem it solves is
macOS's kqueue.

**Prior art:** no Emacs package found that feeds `fswatch` or Watchman into eglot or
`file-notify` (one web search). lsp-mode watches with `file-notify` too and warns
past `lsp-file-watch-threshold` (1000), suggesting to raise it, to ignore
directories, or to turn watching off.

**How it would sit in the vendored eglot** (a patch, not drafted):
- A variable choosing the backend: `file-notify` (today), `fswatch`, or Watchman.
- One watcher process (or one Watchman subscription) per server and project root,
  shared by the server's registrations (as (e)); registrations based outside the
  project stay on `file-notify` or are skipped (D-054 skips them on macOS).
- Each record: map the real path back, skip `.git`, skip buffers eglot manages,
  match the registration's globs, decide the change type, batch the changes into
  one `didChangeWatchedFiles` per filter call.
- Shutdown: kill the process, or end the subscription (and `watch-del` the root,
  or leave the watch to Watchman's own aging).

**Options** (not ruled, O-61 (h1) - (h4)):
- (h1) `fswatch` backend: light (8 descriptors, 6 MB), no crawl, in Arch's `extra`;
  loses changes silently when Emacs does not read during a burst.
- (h2) Watchman backend: no loss, exact created / deleted; a 100 MB daemon for
  LLVM's size, a crawl at first watch, cookie files in the root, AUR on Arch.
- (h3) Either on macOS only, `file-notify` on Arch (a D-055 platform default).
- (h4) Neither: (e) / (g) and exclusions (3.9).

### 3.13 Patching fswatch: no loss, created vs deleted (owner 2026-10-15, T-096)
Owner: "(h1) Can fswatch be patched to not lose events and report created vs.
deleted events?" Yes, both, in a prototype. Read in fswatch 1.20.1 (the MacPorts
version; github.com/emcrisostomo/fswatch tag 1.20.1, 97757d7), built with CMake and
Ninja in a scratch directory, checked on the LLVM-sized tree of 3.12. Draft:
`docs/upstream/fswatch-fsevents-no-loss-present-state.patch` (71 lines in, 1 out,
two files).

**Why events were lost** (`libfswatch/.../fsevents_monitor.cpp`,
`fswatch/src/fswatch.cpp`): the FSEvents callback builds the events and calls the
monitor's callback, which prints each record to `std::cout` and flushes it. With a
full pipe the write blocks, so the FSEvents callback does not return, and the system
drops what arrives meanwhile. The drop is signalled: one record for the root with
the flags `PlatformSpecific` (fswatch maps `MustScanSubDirs`, `UserDropped`,
`KernelDropped` to `PlatformSpecific`, not to `Overflow`, so `--allow-overflow`
shows nothing), seen in a paused-reader run.

**Why created and deleted were mixed:** FSEvents with file events
(`kFSEventStreamCreateFlagFileEvents`) accumulates the flags of a path; fswatch
passes them on as they come. libfswatch already has the inode of each event
(extended data) but no state per path.

**The prototype:**
1. `fswatch.cpp`: `process_events` writes the records of a batch into a string and
   queues it; a writer thread takes the queue and writes to standard output. The
   callback never waits for the reader; records wait in memory instead (unbounded
   in the draft).
2. `fsevents_monitor.cpp`: an event with `MustScanSubDirs`, `UserDropped` or
   `KernelDropped` becomes `notify_overflow(path)`, as the inotify and kqueue
   monitors already do (an `Overflow` record with `--allow-overflow`, else an error).
3. `fsevents_monitor.cpp`: `lstat` at the time of the event decides: a missing path
   loses `Created` and `Updated` and gets `Removed`; a present one loses `Removed`.

**Checked** (10000 files created while the reader paused 5 s, then read; and four
single cases; `LC_ALL=C`, see below):
| | fswatch 1.20.1 (MacPorts) | patched |
|---|---|---|
| paused reader, 10000 creations | 959 records | 10001 records, no overflow |
| created `created.py` | `Created,IsFile,Updated,AttributeModified` | same |
| created, removed `gone.py` | all five flags (1) | `IsFile,Removed,AttributeModified` |
| appended to `f2.cc` | `IsFile,Updated` | same |
| removed `f3.cc` | `IsFile,Removed` | same |
(1) `Created,IsFile,Updated,Removed,AttributeModified`.
Not checked: change 2 (no drop happened once the callback stopped blocking; a
kernel-side drop was not provoked); memory while a reader never reads; the inotify
monitor (Arch), which the writer thread also serves.

**Side finding:** this build rejects `-l 0.1` under the owner's German locale
("Invalid value: 0.1", a decimal comma expected); MacPorts' build accepts it. A
local build would need `LC_NUMERIC=C` in its environment or a fix; not looked into.

**Upstream:** no fswatch issue found on a slow reader losing events or on mixed
flags (four searches of its issues, 2026-10-15); #233 ("macosX inconsistent event
reporting for options -x and -o", open since 2019) is the nearest.

**Ways to carry it** (not ruled, O-61 (h1)):
- (i) Offer the three changes upstream (GPL-3 project, a pull request); MacPorts
  and Arch would follow a release.
- (ii) A local build, as for clangd (`packaging/`), on both machines until then.
- (iii) Only change 1 in fswatch; decide created / deleted in Emacs with a stat
  per record (the prototype filter of 3.12 does so).

Owner 2026-10-15: (ii), a local build (D-109); "Check Change2 and memory use"
(T-097). Same tree and test scripts, scratch builds.

**Change 2, in a real drop:** a second build with changes 2 and 3 but fswatch's
own blocking output (so a paused reader still makes FSEvents drop): with
`--allow-overflow` one record `TREE Overflow` (989 records, the rest dropped, the
drop now named); without it fswatch ends with "libc++abi: terminating due to
uncaught exception of type fsw::libfsw_exception: Event queue overflow." (libfswatch
throws on overflow unless allowed, for every monitor; a client passes
`--allow-overflow`). With change 1 in place no drop was seen in any run.

**Memory, a reader that never reads:** the full prototype, 50000 files created and
removed again (100000 events) while nothing reads, then drained:
| | resident memory |
|---|---|
| idle | 6.1 MB |
| 100000 records waiting | 24.8 MB (+18.7 MB, about 192 bytes per record) |
| after reading them all | 24.8 MB |
Output was 16.8 MB (168 bytes per record), so the queue costs little beyond the
records themselves. The memory is not handed back after draining (the allocator
keeps it for the next burst). Without a bound, a reader stopped for good lets it
grow with every change; a cap (records or bytes) that empties the queue and emits
one `Overflow` record would bound it and still say so.

**The locale finding, explained:** with gettext found at configure time
(`ENABLE_NLS`), `main` calls `setlocale(LC_ALL, "")`, and `-l` is read with
`strtod`, so under `de_DE.UTF-8` the latency needs a decimal comma. MacPorts' build
links no libintl and stays in the C locale. A fswatch bug, in every build with NLS;
a local build either turns NLS off or sets `LC_NUMERIC` back to "C" after
`setlocale`.

**Version:** the newest release is 1.22.0 (2026-07-22; Arch `extra` ships it,
MacPorts 1.20.1); 33 commits since 1.20.1, none in `fsevents_monitor.cpp`. The
prototype applies to 1.22.0 unchanged; built there, the paused-reader run gave
10001 records and the four single cases the same flags as on 1.20.1.

### 3.14 Watch limits on Arch, and eglot reconnecting in a loop (owner 2026-10-19, O-64)
(Superseded in part 2026-10-20 by D-121: no vendored eglot; Arch runs the built-in
eglot and, like the Mac, watches only the project; the Mac's partial and shared
watches are advice in `lisp/emacs-cpp-eglot-watch.el`. RESEARCH_eglot_fork 7.)
Owner 2026-10-19: "Revisit maximum file watches (Arch, different variables) and eglot
restarting in a loop, if the watches are exceeded". Read from the kernel's
`fs/notify/inotify/inotify_user.c`, Emacs's `src/inotify.c`, `lisp/filenotify.el`
and the vendored eglot; the loop reproduced on the Mac, 2026-10-19.

**Two limits, of different owners.** On Arch a directory watch passes two limits:
- eglot's `eglot-max-file-watches`: 10000 (eglot's default; this config sets it to
  500 on the Mac only, D-054). Counted across all eglot servers of the Emacs
  session; with eglot patch 0002 one per directory and server, before 0002 one per
  directory and registration (pyright registers three times).
- the kernel's inotify limits, per user, shared by every program of the user (Emacs,
  the desktop, Syncthing, other editors), read with `sysctl`:
  - `fs.inotify.max_user_watches`: since Linux 5.11 1% of RAM divided by the cost of
    one watch (about 1 KB on 64-bit), clamped to 8192 .. 1048576: about 159000 at
    16 GB, 318000 at 32 GB. Above it `inotify_add_watch` fails with ENOSPC.
  - `fs.inotify.max_user_instances`: 128. Emacs opens one instance for all its
    watches (`inotify_init1` once), so this does not bind for Emacs.
  - `fs.inotify.max_queued_events`: 16384 events waiting per instance; beyond them
    the kernel drops events and sends one `IN_Q_OVERFLOW`. Emacs reads its queue
    whenever it waits for input, so only a burst while Emacs is busy (a large `git
    checkout` during a long command) fills it; the lost events are not noticed by
    eglot, the server misses those changes until the next one in the directory.
  The kernel shares one watch per inode, so Emacs watching a directory twice (eglot,
  auto-revert, dired) costs one kernel watch; eglot's own count is per eglot watch.
  At 16 GB and more the kernel limit is far above 10000, so eglot's cap binds first;
  near the minimum of 8192 (under 1 GB of RAM, or a limit set lower in
  `/etc/sysctl.d`) the kernel's binds first.

**What exceeding them does.** Either way eglot's watch request for a registration
fails or stops short:
- eglot's cap: stock eglot answers the server's `client/registerCapability` with
  an error; eglot patch 0001 (D-108) keeps the watches made so far, warns "Reached
  `eglot-max-file-watches' limit", and answers success.
- the kernel's: Emacs signals `file-notify-error` ("Could not add watch for file
  ...", `report_file_notify_error`); stock eglot again fails the registration;
  patch 0001 catches it, warns "Cannot watch DIR: ..., not watching some
  directories" and answers success.
pyright exits about 0.1 s after a failed registration (3.3, 3.7); clangd registers
no watches.

**The loop.** eglot restarts a server that exits on its own only when the connection
lasted longer than `eglot-autoreconnect` (3 s by default, untouched here); a shorter
one ends with "Not auto-reconnecting, last one didn't last long" (the owner's report
in 3.7). So with stock eglot a failed registration loops when connecting, listing
the project's directories and failing take longer than 3 s together: a large tree
on Arch (many directories to list and watch before the cap) or a slow first
`project-files`. Each round starts pyright afresh, walks the tree again and warns
again. Reproduced on the Mac (600-directory toy of 3.11, pyright, cap 500,
`eglot-autoreconnect` lowered to 0.1 s so the toy's 0.33 s rounds count as long),
15 s each:

| eglot | connections | server at the end |
|-------|-------------|-------------------|
| stock (mirror c79f727) | 38, "Server exited with status 1" each | restarting |
| vendored (patches 0001, 0002) | 1, the cap warning three times | running |

With the vendored eglot the registration no longer fails, so neither limit makes
pyright exit and no loop starts; a server exiting for another reason after 3 s
still reconnects, as wanted. The loop is left only where the stock eglot is loaded
instead (the vendored one is not forced, owner 2026-10-15, D-108).

**Left over with the vendored eglot:**
- Exhausting the kernel limit hurts others: once eglot has taken the user's last
  watches, auto-revert, dired, magit and other programs fail to watch until eglot
  releases them. Only possible where the kernel limit is below eglot's cap plus the
  other programs' watches.
- The warnings say which limit was hit but not the numbers to change: the kernel's
  message names the directory, not `fs.inotify.max_user_watches`.

Options (not ruled, O-64):
- (a) Keep as is: eglot's 10000 on Arch, the kernel's limit above it on the owner's
  machine (to check with the commands below); this section and the corrected comment
  in `init-lsp.el` record why no loop.
- (b) On Arch, cap eglot below the kernel's limit: read
  `/proc/sys/fs/inotify/max_user_watches` at startup and set
  `eglot-max-file-watches` to the smaller of 10000 and half of it, so the cap binds
  first and leaves the rest to other programs. A per-platform default (D-055).
- (c) Name the kernel limit in patch 0001's warning when the error is ENOSPC
  ("raise fs.inotify.max_user_watches"); a change to a vendored patch (D-069).
- (d) Guard the stock eglot: set `eglot-autoreconnect` to nil when the vendored
  eglot is not the one loaded, losing reconnects after real crashes; or warn at
  startup. Against the owner's ruling that the vendored eglot is the user's choice
  (D-108); listed for completeness.
Recommendation: (a), plus (b) only if the owner's numbers show the kernel limit near
10000.

Owner's commands (Arch), read only:
```
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances \
       fs.inotify.max_queued_events
free -g
grep -rs inotify /etc/sysctl.d /usr/lib/sysctl.d /run/sysctl.d
for p in /proc/[0-9]*; do
  n=$(cat $p/fdinfo/* 2>/dev/null | grep -c '^inotify')
  [ "$n" -gt 0 ] && echo "$n $(cat $p/comm)"
done | sort -rn | head
```
The last line counts each process's inotify watches (largest first); run it once
with Emacs and pyright up on step-1.

## 4. Other differences met so far
Decided already; listed so that one document points at all of them.

| Difference | macOS | Arch | Where decided |
|---|---|---|---|
| Packages, tools | MacPorts only | pacman | D-050, D-053 |
| PATH of a GUI Emacs | launchd's; MacPorts added at startup | the session's | D-089 |
| Debugger | lldb (`lldb-preset`) | gdb | D-051 |
| Per-platform defaults | `lisp/defaults-darwin.el` | `lisp/defaults-gnu-linux.el` | D-055 |
| Performance budgets | not binding | binding | D-057 |
| Search tool for `C-c p ?` | ripgrep | GNU grep | D-081 |
| eglot file watches | project files only, cap 500 | eglot's defaults | D-054 |
| Patched clangd | `build-macos.sh`, from source | PKGBUILD, to /opt | D-052, D-027 |

Measured or read in this round:
- **eglot applying a multi-file edit** opens every file it edits, about 95 ms per file
  on the Mac with the shipped config (S12, 20 - 50 files: 1.5 - 4.9 s). Not measured
  on Arch.
- **Scripts:** `/proc/loadavg` does not exist on macOS (S9's `run.sh` writes it in
  its log header and would fail there); BSD `sed -i` needs a suffix argument
  (`sed -i ''`); `cp -c` clones on APFS where GNU has `cp --reflink`; `date
  -Iseconds` works on this macOS. Spike scripts meant for both machines should use
  `uptime` or `sysctl -n vm.loadavg` on the Mac and avoid GNU-only flags.
- **Temporary directories:** `temporary-file-directory` is
  `/var/folders/.../T/` on the Mac, a symlinked path (2.3); `make-temp-file` results
  need `file-truename` wherever a test compares paths with clangd's.

## 5. Sources
- clangd/clangd#503, https://github.com/clangd/clangd/issues/503 (read 2026-10-14).
- clangd/clangd#1317, https://github.com/clangd/clangd/issues/1317.
- CMake v3.31.0 `Source/kwsys/SystemTools.cxx`; KWSys commit 47dce1a3,
  https://gitlab.kitware.com/utils/kwsys (2024-11-03); CMake v4.1.0
  `Source/cmSystemTools.cxx`, `Source/cmPathResolver.h`.
- clangd 23.1.1 sources: `index/Background.cpp` (`BackgroundIndex::update`),
  `index/SymbolCollector.cpp` (`toURI`), `index/IndexAction.cpp` (`toURI`),
  `SourceCode.cpp` (`getCanonicalPath`), `index/FileIndex.cpp`
  (`FileShardedIndex`), `CompileCommands.cpp` (`CommandMangler`), `Compiler.cpp`
  (`prepareCompilerInstance`), `GlobalCompilationDatabase.cpp` (`OverlayCDB`);
  clang's `lib/Basic/FileManager.cpp` (`getVirtualFileRef`, `fillRealPathName`),
  `lib/Tooling/JSONCompilationDatabase.cpp`, LLVM's
  `lib/Support/VirtualFileSystem.cpp` (`RealFile`).
- Emacs 31 `lisp/progmodes/eglot.el` (`eglot-path-to-uri`).
- Linux commit 92890123749b, "inotify: Increase default inotify.max_user_watches
  limit to 1048576",
  https://github.com/torvalds/linux/commit/92890123749bafc317bbfacbe0a62ce08d78efb7.
- S12 logs: `spikes/s12-change-signature/RESULTS.md`, finding 6.
