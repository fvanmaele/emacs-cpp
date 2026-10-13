# projectile issue draft: `projectile-find-references` ignores `xref-search-program`

Draft for https://github.com/bbatsov/projectile/issues. Not sent; the owner sends it
(D-081, T-058). The change below is applied locally as `patches/projectile/0001-...`
(D-069) until upstream takes it or solves it differently; drop the patch and its
`.gitmodules` line when the pin moves past a fix.

---

**Title:** projectile-find-references is slow on large projects: it ignores
xref-search-program and the project's file list

### Environment
- projectile 3.4.0 (b60bb09), Emacs 31.1, macOS (BSD grep) and Arch Linux (GNU grep).

### What happens
`projectile-find-references` (`C-c p ?`) on deal.II (33768 files) takes 130 - 156 s
on macOS, for a symbol with 607 matches as for one with 9429. With
`xref-search-program` set to `ripgrep`, it takes as long.

### Cause
It calls `xref-matches-in-directory`, which walks the tree with `find` and runs
`grep` (`grep-find-template`), one file at a time; `xref-search-program` is not
consulted. It also searches files the VCS ignores (build directories), which
`projectile-find-file` does not list.

### Change
Search the files `projectile-project-files` lists with `xref-matches-in-files`,
which honours `xref-search-program`:

```elisp
(fetcher (lambda ()
           (when-let* ((files (projectile-project-files project-root)))
             (xref-matches-in-files
              regexp
              (mapcar (lambda (file) (expand-file-name file project-root))
                      files)))))
```

Measured with ripgrep on the same tree: 10.6 - 11.3 s, the same matches (in that
tree no git-ignored file contains them); listing the files takes 0.16 s. The
remaining time on that machine is opening the files (`rg` alone in the tree:
5.5 - 6 s). `.projectile` ignores still apply, through `projectile-project-files`.
