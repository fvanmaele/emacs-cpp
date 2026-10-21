# ty feedback draft: return type inference, cost on a large unannotated project

Draft comment for https://github.com/astral-sh/ty/issues/4739 ("Return type inference:
your feedback"); not posted (the owner posts it). Reproduction script:
`ty_return_type_inference_repro.py` in this directory. Findings behind it:
`RESEARCH_python_ty.md` sections 8 and 9 (2026-10-21).

---

Feedback from an editor setup (Emacs 31.1 eglot) on ty 0.0.90, Arch Linux x86_64, 16
hardware threads, Python 3.14.8, ty from the Arch package `extra/ty 0.0.90`.

### Performance: the first find-references on a large unannotated project

On SymPy 1.14 (1532 files, almost no annotations; the package directory copied into a
git repository), the first `textDocument/references` on `Symbol` (its class
definition, `sympy/core/symbol.py` line 212) with `"always"` takes about 12 times as
long and the server ends with about 7 times the memory. Two runs each, the setting
sent as inline configuration (`ty.configuration`):

| `return-type-inference` | first references | references | server RSS after |
|---|---|---|---|
| `"never"` | 1.79 s | 5628 in 408 files | 1.11 - 1.16 GB |
| `"always"` | 21.8 - 22.3 s | 5628 in 408 files | 8.2 - 8.3 GB |

Later references requests cost the same either way (82 ms), as does go-to-definition.
`ty check` on the same tree: 2.5 s and 1.12 GB with `"never"`, 9.2 s and 1.43 GB with
`"always"`, so the language server pays much more than the CLI.

On a small project (102 files) there was no measurable difference (first references
114 ms, 209 MB).

Reproduction (standard library only):

```
mkdir -p /tmp/sympy-tree
cp -r "$(python3 -c 'import sympy, os; print(os.path.dirname(sympy.__file__))')" \
    /tmp/sympy-tree/sympy
git -C /tmp/sympy-tree init -q
python3 ty_return_type_inference_repro.py /tmp/sympy-tree sympy/core/symbol.py 211 6 never
python3 ty_return_type_inference_repro.py /tmp/sympy-tree sympy/core/symbol.py 211 6 always
```

The script starts `ty server` in the tree, answers `workspace/configuration` with
`{"configuration": {"analysis": {"return-type-inference": MODE}}}`, opens the file and
times one `textDocument/references` (with `includeDeclaration`).

### Diagnostics

`ty check` on the same SymPy tree: 13076 errors with `"never"`, 27653 with
`"always"`; the largest increases are `unresolved-attribute` (4816 -> 10099),
`unsupported-operator` (848 -> 5948), and `not-subscriptable` / `not-iterable`
(new among the six most frequent). They were not classified as true or false
positives.

On `argparse.py` of Python 3.14 (checked as a project's `main.py`), `"always"` adds:
- two `index-out-of-bounds` at line 475 (`part[0]`, `part[-1]` on `Literal[""]`):
  `_format_args` can return an empty string there, so these look plausible;
- `no-matching-overload` for `str.join` at lines 2010, 2345, 2360 and 2573; pyright
  reports the call at 2360 too, not the other three, which have the same shape; not
  traced further.

### Inferred types checked

All as expected: `def ret(): return 1` gives `Literal[1]`; a function returning `None`
or `"x"` gives `None | Literal["x"]` and `.upper()` on it is reported; a method of a
non-final class gives `Literal["c"] | Unknown`.

### How it is used here

Off by default, turned on per project.
