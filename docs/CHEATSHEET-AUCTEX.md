# AUCTeX cheatsheet

LaTeX in this configuration (D-090): `.tex` files open in AUCTeX's `LaTeX-mode`;
in a project texlab adds cross-file navigation (`M-.` on `\ref`, `\cite`, your own
commands; `M-?` usages; `C-c l r` rename; `M-o` sections and labels). Every key
below was read from AUCTeX 14.2.0's keymaps in the shipped config. AUCTeX's manual:
`C-h i`, then "AUCTeX"; preview: "preview-latex".

## Build and view
| Key | Does |
|---|---|
| `C-c l b` | build with texlab (latexmk), then show this line in Skim / zathura (D-090) |
| `C-c C-c` | AUCTeX: run what the document needs next (LaTeX, BibTeX, View) |
| `C-c C-a` | AUCTeX: run everything needed, then view |
| `C-c C-r` / `C-c C-b` | typeset the region / the buffer only |
| `C-c C-v` | view the output |
| ``C-c ` `` | next error of the last run, with its help |
| `C-c C-l` / `C-c C-k` | show the output buffer / stop the run |
| `C-c C-t C-p` | PDF output on / off |

## Insert
| Key | Does |
|---|---|
| `C-c C-e` | an environment (asks its name; labels and captions where they belong) |
| `C-c ]` | close the innermost open environment |
| `C-c C-s` | a section (asks the level and the title; adds a label) |
| `C-c C-m` | a macro, asking for its arguments |
| `C-c C-j` / `M-RET` | a new `\item` (or the item of the list you are in) |
| `C-c {` | a pair of braces |

## Fonts: `C-c C-f` then
| Key | Gives |
|---|---|
| `C-b` | `\textbf{}` bold |
| `C-i` (`TAB`) | `\textit{}` italic |
| `C-e` | `\emph{}` emphasis |
| `C-t` | `\texttt{}` typewriter |
| `C-s` | `\textsl{}` slanted |
| `C-c` | `\textsc{}` small caps |
| `C-f` | `\textsf{}` sans serif |
| `C-r` | `\textrm{}` roman |
| `C-n` | `\textnormal{}` |
| `C-d` | delete the font command around point |

With a region the font goes around it; in math, the math variants (`\mathbf` ...).

## Math: `C-c ~` turns on the math keys, then `` ` `` and a letter
| `` ` `` + | Gives | `` ` `` + | Gives |
|---|---|---|---|
| `a` `b` `g` `d` | alpha beta gamma delta | `G` `D` `L` `S` | Gamma Delta Lambda Sigma |
| `e` `z` `h` `j` | epsilon zeta eta theta | `P` `F` `Y` `W` | Pi Phi Psi Omega |
| `k` `l` `m` `n` | kappa lambda mu nu | `v e` `v f` `v j` | varepsilon varphi vartheta |
| `x` `p` `r` `s` | xi pi rho sigma | `*` `.` | times cdot |
| `t` `f` `q` `y` `w` | tau phi chi psi omega | `<` `>` | leq geq |
| `i` `0` `I` | in emptyset infty | `{` `}` `[` `]` | subset supset subseteq supseteq |
| `A` `E` `N` | forall exists nabla | `+` `-` `\|` `&` | cup cap vee wedge |
| `/` | not | `c` | `\mathcal{}` |

## Preview formulas in the buffer: `C-c C-p` then
| Key | Does |
|---|---|
| `C-p` | the formula / figure at point (again: back to the source) |
| `C-e` / `C-s` / `C-r` | the environment / the section / the region |
| `C-b` / `C-d` | the buffer / the whole document |
| `C-c C-p` / `C-c C-b` | remove the preview at point / of the buffer |
| `C-f` / `C-c C-f` | cache the preamble (faster previews) / stop caching it |

The first preview asks "Cache preamble?": `y` makes later previews faster.

## Fold: `C-c C-o C-f` turns folding on, then `C-c C-o` and
| Key | Does |
|---|---|
| `C-o` | fold or unfold what is at point |
| `C-m` / `C-e` / `C-c` | fold the macro / the environment / the comment at point |
| `C-p` / `C-s` / `C-b` | fold the paragraph / the section / the buffer |
| `i` / `b` | unfold the item / the buffer |

## Fill, mark, comment
| Key | Does |
|---|---|
| `C-c C-q C-p` / `C-e` / `C-s` / `C-r` | fill the paragraph / environment / section / region |
| `C-c .` / `C-c *` | mark the environment / the section |
| `C-c ;` / `C-c %` | comment or uncomment the region / the paragraph |
| `C-c ?` | documentation of a package or command (texdoc) |
| `C-c _` | ask which file is the master document |
