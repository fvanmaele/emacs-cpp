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
