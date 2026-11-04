# Architecture

How emacs-cpp is put together, for readers who know neither Emacs nor C++ tooling.
Decisions are cited by id (`D-nnn`); each is explained once, in `DESIGN.md`'s decisions
ledger. Install and daily use: `README.md`, `docs/MANUAL.md`.

## What it is
Emacs is a text editor whose behaviour is a program, written in Emacs Lisp, that the
user can change. emacs-cpp is such a program: a configuration that turns Emacs 31 into
an IDE for C++ (and Python) close to JetBrains CLion, on Arch Linux and macOS (D-050).
It writes little of the IDE itself. Emacs and outside tools do the work; the
configuration chooses them, connects them and gives them keys.

## The picture
```
                 +--------------------- Emacs 31 ----------------------+
 you  -- keys -> |  modules in lisp/ (init-*.el, emacs-cpp-*.el)        |
                 |  packages pinned in lib/ (completion, git, tree ...) |
                 +---+-----------+-----------+-----------+----------+---+
                     | LSP       | DAP       | processes | files    |
                     v           v           v           v          v
                 clangd       gdb, lldb    cmake,      git      fswatch
                 (patched)    debugpy      ninja,                (patched)
                 ty/pyright                compiler
```
- **LSP** (Language Server Protocol): a separate program, the language server,
  understands the code and answers "where is this defined", "what is wrong here",
  "rename this". Emacs's built-in client, eglot, talks to it. C++: clangd; Python: ty
  on Arch, pyright on the Mac (D-140).
- **DAP** (Debug Adapter Protocol): the same idea for debuggers; the client is dape,
  the debuggers gdb, lldb and debugpy (D-031, D-051).
- **Builds** run CMake with the project's own presets (`CMakePresets.json`), so the
  editor builds exactly as the command line does (D-016, D-035).
- **File watching** tells the editor and clangd when files change outside Emacs, for
  example after `git checkout` (D-127, D-162).

## Repository layout
| path | holds |
|---|---|
| `early-init.el`, `init.el` | startup: load path, then every module in a fixed order |
| `lisp/` | the configuration's own code, one module per concern (C++, Python, git ...) |
| `lib/` | 31 third-party packages as git submodules at pinned commits (D-006) |
| `patches/` | fixes to those packages, applied by `make packages` (D-069, D-116) |
| `packaging/` | locally patched tools: clangd, fswatch, clang-change-namespace |
| `scripts/`, `Makefile` | builds and checks; bare `make` only prints help |
| `test/` | automated tests (ERT, Emacs's test framework), `make test` |
| `spikes/` | experiments that must pass before risky code is written |
| `DESIGN.md`, `docs/journal/` | decisions with reasons; one journal entry per change |

## Four rules the structure follows
1. **Nothing changes by itself.** Every package is a pinned submodule and nothing is
   downloaded at startup (D-014), so the editor is the same every day until a commit
   changes it.
2. **Fail loudly.** A missing module, package, grammar or misconfigured project stops
   with a message instead of half-working (DESIGN 4, 5; D-018).
3. **One place per thing.** Each package is configured in one `use-package` form, each
   module loads alone after the startup prelude (D-098), each decision lives in one
   ledger row.
4. **Measure before risky code.** Performance claims and new subsystems first pass a
   spike with criteria agreed beforehand (`spikes/`); budgets bind on the Arch machine
   (D-057).

## Where the work is done
| need | who answers | the configuration adds |
|---|---|---|
| definitions, usages, rename, diagnostics | clangd | a patched clangd that answers from its index at once and gives headers their includer's flags (D-026 - D-028); a prebuilt index of libraries such as deal.II (D-130) |
| jump to anything | vertico, consult, projectile | one prompt on `M-o` for files, buffers and symbols (D-074), matched as LSP 3.18 ranks matches, in tiers (D-120) |
| build | CMake presets | the active preset per project, read once, applied to clangd and the build (D-016 - D-018) |
| debug | dape | one entry per debugger, targets from CMake's file API (D-056) |
| outside changes | patched fswatch | one watcher per project root that reverts unedited buffers in timer steps (D-127, D-162 - D-169) |
| git | magit, diff-hl | as installed (D-006, D-042) |

## Compared with common environments
| | advantages here | disadvantages here |
|---|---|---|
| CLion | same daily loop (navigate, refactor, build, debug, git) without a JVM IDE; every behaviour inspectable and changeable | fewer refactorings (no change signature, inline, pull members up: DESIGN 1); weaker GUI; setup is a git checkout plus builds |
| VS Code + clangd | same language server; no extension updates that change behaviour unasked; keyboard-first | smaller ecosystem for this setup; one owner maintains patches to clangd, fswatch and packages |
| Vim / Neovim + LSP | comparable speed and keyboard control; Emacs Lisp covers the whole UI | Emacs's own keys and concepts to learn; startup and memory above a minimal Vim |

The cost common to all three: the configuration is code. It needs its tests, its
patches rebased when LLVM or a package moves, and decisions recorded to stay coherent.
