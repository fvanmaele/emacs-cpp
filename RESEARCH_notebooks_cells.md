# RESEARCH - cells, notebooks and Quarto for Python and R (T-045)

Findings only; verdicts go to DESIGN (O-29). Owner request 2026-10-10: cell modes for
Python and R, notebooks, Quarto, and other options. Arch, Emacs 31.1 (module support
on), Python 3.14.7 (numpy, matplotlib), R 4.6.1, pandoc 3.12, 2026-10-10. Package facts
from their source, READMEs, the GitHub API, GNU ELPA and ports.macports.org the same
day; hands-on checks in `emacs -Q --batch` with the packages cloned into a scratch
directory, never into this repository.

Starting point (D-045): Python has `python-ts-mode`, pyright and debugpy; R has no mode
(`.R` opens in fundamental mode); RMO has 8 R scripts (`R/`, `checkgradient.R`) and 6
Python plotting scripts (`staging/*.py`), none with cell markers.

## 1. What Emacs 31.1 has built in
- **`python.el`** sends code to a `run-python` shell: statement `C-c C-e`, block
  `C-c C-b`, region `C-c C-r`, buffer `C-c C-c`, function `C-M-x`. No notion of cells.
- **org-babel** (org in Emacs 31.1): `ob-python` and `ob-R` ship. Checked: two Python
  blocks with `:session py` share state (the second prints 14.142 from the first's
  `x`); an R block without `:session` runs through `Rscript`, no ESS needed. An R block
  with `:session` needs ESS: without it, "failed to load required package ESS".
- **`compat`** is built in, so packages requiring `(compat "29.1")` load as they are.

## 2. Candidates
| Package | What | Source, version | Last push | Needs |
|---|---|---|---|---|
| code-cells | `# %%` cells in any script; eval a cell in the mode's REPL | GNU ELPA 0.5 | 2025-06-08 | compat (built in) |
| ESS | R mode, R process, eval line / region / function, help | MELPA / NonGNU, 26.05.0 | 2026-09-28 | Emacs 25.1 |
| emacs-jupyter | Jupyter kernels: REPL, `ob-jupyter` org blocks, rich output | MELPA, 1.0 | 2026-08-13 | `zmq` native module, websocket, simple-httpd, Jupyter |
| EIN | edit and run `.ipynb` against a Jupyter server | MELPA | 2025-12-12 | Jupyter server |
| quarto-mode | `.qmd` editing via polymode, `quarto-preview` | MELPA | 2024-01-05 | polymode, poly-markdown, markdown-mode, request, quarto CLI |
| polymode + poly-R | several modes in one buffer (R Markdown) | MELPA | 2026-05-05 / 2025-05-02 | |
| drepl | REPL protocol over comint; IPython shell with completion | GNU ELPA | 2026-07-15 | IPython |
| comint-mime | images, HTML, LaTeX in `run-python` / IPython / `M-x shell` | GNU ELPA | 2024-11-16 | IPython recommended |
| jupytext | `.ipynb` <-> `# %%` script conversion (command line) | PyPI | | Python |

- **code-cells** (220 KB, one file) recognises `# %%` (jupytext's percent format, also
  VS Code and Spyder) and `# In[n]:`. `code-cells-eval` sends the cell to the REPL its
  table names for the buffer's mode: drepl, emacs-jupyter, `python-mode` /
  `python-ts-mode` (`python-shell-send-region`), Emacs Lisp. **No R entry**: ESS must be
  added to `code-cells-eval-region-commands` by the user. Keys on the prefix `C-c %`
  (`e` eval, `s` eval and step); its README suggests `C-c C-c` and `M-p` / `M-n` in
  `code-cells-mode-map`. Opening an `.ipynb` converts it to a script through jupytext
  (or pandoc); outputs are not kept.
- **ESS** (3.5 MB, 30 Lisp files) loads from source without a build step. Its eglot
  server for R is `languageserver::run()`, the CRAN package `languageserver` (not
  installed; not in the Arch repositories nor in MacPorts).
- **emacs-jupyter** talks to kernels directly through ZMQ or through a Jupyter server's
  websockets. The `zmq` module is required (Package-Requires `zmq 0.10.10`): it
  downloads a prebuilt binary or builds one with autotools, pkg-config and libzmq. R
  kernels need the CRAN package `IRkernel` (not installed). It does not edit `.ipynb`.
- **EIN**: its README, as of 2023, says it "has been sunset for a number of years having
  been unable to keep up with jupyter's web-first ecosystem", and that its architecture
  "is fundamentally incompatible with LSP". A successor (xjupyter) is announced.
- **quarto-mode** depends on polymode, which EIN's README calls "complex and fragile";
  last change January 2024.

## 3. Checked by hand (batch, 2026-10-10)
| Check | Result |
|---|---|
| code-cells 0.5 in `python-ts-mode`, `run-python`, eval cell 1 then cell 2 | cell 2 printed `cell2 14.142` using cell 1's `math` and `x` |
| code-cells + ESS (`ess-r-mode`), R 4.6.1, the ESS entry added | cell 2 printed `cell2 14.142` using cell 1's `x` |
| org-babel Python `:session` | shared state, result inline |
| org-babel R, no session | ran through `Rscript`, result inline |
| org-babel R `:session`, ESS on the load path but not loaded | error "Don't know how to make a let-bound variable an alias: ess-directory-function" |
| the same, ESS loaded first | ran, result inline |

The last two rows matter for a config that loads ESS lazily: the first R session block
before any R buffer was opened fails until ESS is loaded.

Not checked: emacs-jupyter (no Jupyter installed, no zmq module built), EIN, quarto-mode
(no quarto CLI), drepl and comint-mime (no IPython), jupytext, inline plots.

## 4. Tools outside Emacs
| Tool | Arch repositories | MacPorts (D-053) |
|---|---|---|
| Jupyter (`jupyter-notebook`, `jupyterlab`) | yes (7.6.3, 4.6.4) | not looked up |
| ipykernel | `python-ipykernel` 7.4.0 | `py314-ipykernel` 7.2.0 |
| jupytext | no (PyPI) | `py-jupytext` 1.16.1, up to py312 only (the Mac runs 3.14) |
| quarto CLI | no | no (only `R-quarto`, the R interface, which needs the CLI) |
| R `languageserver` | no (CRAN) | no |
| IRkernel | no (CRAN) | not looked up |
| zeromq | yes, installed | not looked up |

## 5. What this leaves (for O-29)
- **Cells in plain scripts** (`# %%`) need one small GNU ELPA package (code-cells) and,
  for R, ESS; both verified here. The files stay ordinary `.py` / `.R`, so pyright,
  git diffs and other editors keep working, and jupytext-format notebooks share the
  syntax.
- **Notebooks in org** need nothing new for Python; R sessions need ESS (loaded before
  the first session block). Results live in the `.org` file, not in an `.ipynb`.
- **Jupyter kernels** (rich output, widgets, `.ipynb` interop) cost a native module and
  a Jupyter install; unchecked.
- **`.ipynb` editing**: EIN is sunset; the remaining route is conversion (jupytext),
  which is not packaged for the Mac's Python.
- **Quarto** needs the quarto CLI, packaged neither on Arch nor in MacPorts, plus
  polymode; on the Mac that conflicts with D-053 (MacPorts only).
- **R at all** means ESS; the R language server is CRAN-only on both machines.
