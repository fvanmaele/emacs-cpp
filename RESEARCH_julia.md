# RESEARCH - Julia: language servers and the rest

Question (owner, 2026-10-25): "Research julia language server interfacing and other
functionality". Findings only; verdicts go to DESIGN (O-76).

Context: D-145 (the same day) narrowed the config to C/C++ and Python; DESIGN 2 lets
other languages ride along, never drive design.

Sources, all read 2026-10-25: archlinux.org's package search (JSON), the AUR's RPC
interface, `port info` / `port search` on the Mac, NonGNU ELPA's index, the READMEs of
LanguageServer.jl, JETLS.jl (and its user guide: index, Launching), eglot-jl,
julia-emacs (julia-mode), julia-ts-mode and julia-snail, dap-mode's `dap-julia.el`,
web search results on LanguageServer.jl 6.0, SymbolServer.jl's deprecation and
DebugAdapter.jl. Emacs 31.1's own `eglot.el` read on the Mac. No hands-on: no working
Julia on the Mac (section 1); claims from documentation are marked so.

## 1. Julia itself, both machines
- Arch: pacman `extra/julia` 2:1.13.2-1 (updated 2026-10-15), built against Arch's
  own `llvm-julia-libs` 20.1.8.3. AUR alternatives: `juliaup` 1.22.10, `julia-bin`
  1.13.0 (flagged out of date), `julia-git`.
- Mac: MacPorts `julia` @1.13.1 (variants `+app`, `gcc14`, `gcc15`), not installed.
  `/usr/local/bin/julia` is a dangling symlink to
  `/Applications/Julia-1.11.app/...` (the app is gone); `~/.julia` holds a 1.11 depot
  (`environments/v1.11`: BenchmarkTools, Plots, Pluto, RCall, Suppressor). D-145 took
  `/usr/local/bin` out of the startup PATH, so that symlink is not seen from the Dock
  anyway.
- Current releases (web search): 1.13.2 (2026-10-15), LTS 1.10.12.

## 2. Language servers
Emacs 31.1's `eglot-server-programs` has no Julia entry (checked: `eglot.el.gz` on the
Mac); a server must be named, as pyright and clangd are (D-091).

### 2.1 LanguageServer.jl (julia-vscode)
- The server VS Code's Julia extension uses; a Julia package, so it lives in a Julia
  environment (depot `~/.julia`), not in pacman or MacPorts. Started as
  `julia --project=<server env> -e "using LanguageServer; runserver()" <env_path>`
  over stdio; `env_path` is the project to analyse (else the parent project, else
  `~/.julia/environments/v#.#`).
- Churn in 2026 (web search, not checked by hand): SymbolServer.jl (the package
  indexer) was archived 2026-07-13, its work and StaticLint's moved into
  JuliaWorkspaces.jl (VS Code extension 1.220.0, 2026-07-21). LanguageServer.jl 6.0
  (registered 2026-09-12) removed `runserver`'s `depot_path` argument; unpinned
  installers crashed with `MethodError: no method matching runserver(...)`.
  positron-julia pinned 5.x, which on Julia 1.13 also needed a patch to SymbolServer's
  `jl_module_names` ccall. Julia 1.12.0 broke LanguageServer 4.5.1 (issue #1366) until
  fixes in 2025-11. So each Julia minor release has broken a pinned server once.
- Startup (eglot-jl's README): the first start installs the server and indexes every
  dependency, "over a minute per dependency" with SymbolServer; eglot's 30 s
  `eglot-connect-timeout` must be raised or the index pre-built by hand.
- Features (eglot-jl's README): completion, hover, docstrings, definition, rename,
  linting, imenu. Formatting through JuliaFormatter (v2 since 2026-05).

### 2.2 JETLS.jl (aviatesk, the JET.jl author)
- A new server on JET (type inference), JuliaSyntax and JuliaLowering. "Experimental,
  not production-ready"; Julia 1.12.2 - 1.13.x only (not 1.14 / nightly).
- Install: `julia -e 'using Pkg; Pkg.Apps.add(; url=URL, rev="release")'` with URL
  `"https://github.com/aviatesk/JETLS.jl"` puts a `jetls` executable in
  `~/.julia/bin/`; dated tags (`rev="YYYY-MM-DD"`) pin it.
  A network fetch into the depot, outside this repository and outside pacman /
  MacPorts.
- eglot, from its user guide: `("jetls" "serve" "--socket" :autoport)` for
  `julia-mode` / `julia-ts-mode` with `:language-id "julia"`; `--stdio` works but is
  called less stable (anything the analysed code prints to stdout corrupts the
  stream). Socket mode does not work over TRAMP. Also `--pipe`.
- Listed features: diagnostics (type-aware), completion, definition, type
  definition, references, rename, formatting, hover, signature help, document and
  workspace symbols, inlay hints, code actions, highlights, semantic tokens, a test
  runner. Known defect in its own docs: memory grows with each re-analysis
  (`analysis_overrides` as a temporary workaround). Its docs warn not to run it on
  untrusted code (it loads the project's code to analyse it).
- Not documented: how it picks the project environment, first-start time, whether it
  asks for `workspace/didChangeWatchedFiles` (which D-127's fswatch would serve).
- Zed's Julia extension uses JETLS by default.

### 2.3 How eglot would start either
- Per project: both analyse the Julia environment of `Project.toml`; a script outside
  a project gets the default environment. That matches this config's rule of
  servers only inside a project (pyright, D-045).
- `M-o`'s project symbols (D-085) take any server's `workspace/symbol` URIs; neither
  server checked.

## 3. Major modes
- `julia-mode` (JuliaEditorSupport/julia-emacs): NonGNU ELPA 1.1.0, so a pinned
  submodule from NonGNU ELPA's git like yasnippet-snippets (D-095). Font-lock,
  indentation, `\alpha` -> unicode substitution through Emacs's generic API. No REPL.
- `julia-ts-mode`: MELPA only, "experimental", derived from `julia-mode` (needs it).
  Grammar `tree-sitter-julia`: no pacman package (AUR `tree-sitter-julia` 0.25.0, 0
  votes), no MacPorts port; julia-ts-mode's README suggests `treesit-auto`, which
  downloads and compiles at runtime (a network call at run time, against D-007).
  Contrast: the C++ and Python grammars come from pacman / MacPorts (D-008, D-045).

## 4. REPL, cells, plots
- No built-in inferior Julia in Emacs 31 (org-babel's `ob-julia` exists, needs a
  REPL package).
- `julia-snail` (MELPA, MELPA Stable): Julia's own REPL in a terminal buffer (vterm,
  eat or ghostel) plus a socket to it; sends line / region / top-level form / file /
  `# %%` cell (example config with code-cells, D-072's package); `M-.` and completion
  from the running session, module-aware; Plots / Gadfly images into Emacs buffers;
  Revise friendly. Installs its Julia side (JuliaSnail, CSTParser) into the session at
  start. Its debug extension (1.3.3, 2026-04-02) drives dape (D-002's debugger UI)
  through DebugAdapter.jl, attached from the REPL (`@run`, `@enter`).
- Terminal: `eat` is NonGNU ELPA 0.9.4, pure Lisp; vterm needs a compiled module (a
  build step per machine).
- `julia-repl` (MELPA): a plain terminal REPL with send-region; no xref.

## 5. Debugger
- DebugAdapter.jl (julia-vscode) speaks DAP over a TCP socket. dap-mode's
  `dap-julia.el` starts `julia --project=<root> -e "import DebugAdapter: DebugSession;
  using Sockets; port = N; server = listen(port); while true; conn = accept(server);
  @async begin; session = DebugSession(conn); run(session); close(conn); end; end;"`
  and launches with `type "Julia"`, `request "launch"`, `program` the file; it
  requires `Project.toml` / `JuliaProject.toml` upward. dape has no Julia entry
  (checked: `lib/dape/dape.el`); a `dape-configs` entry with the same command would
  be own Lisp (UNVERIFIED: not run). DebugAdapter.jl itself installs through Pkg.

## 6. Packaging summary
| piece | Arch | Mac | Emacs side |
|---|---|---|---|
| Julia 1.13 | pacman `julia` | MacPorts `julia` | - |
| LanguageServer.jl / JETLS | Pkg (network, `~/.julia`) | same | eglot (built in) |
| julia-mode | - | - | NonGNU ELPA submodule |
| julia-ts-mode + grammar | AUR grammar only | none | MELPA |
| julia-snail | Pkg side auto-installed | same | MELPA, + eat (NonGNU) |
| DebugAdapter.jl | Pkg | same | dape config (own Lisp) |

Every server and debugger comes from Julia's package manager, not the system package
managers D-053 / DESIGN 12 rely on; each needs a D-nnn (dependency, network, files
outside the repository: CLAUDE.md hard rules).

## 7. Not checked
Hands-on with any server (no Julia on the Mac; installing MacPorts `julia` is a system
action to agree first); JETLS's file watches and environment choice; `M-o` with
Julia symbols; startup cost of julia-mode; julia-snail with eat on both machines.
