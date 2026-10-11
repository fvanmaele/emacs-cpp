# consult issue draft: narrowing an async `consult--multi` keeps hidden candidates

Draft for https://github.com/minad/consult/issues. Not sent; the owner sends it (D-079,
T-053). Checked 2026-10-11: master's `consult--async-predicate` is unchanged from 3.10
(3c64214). The change below is applied locally as `patches/consult/0001-...` (D-069)
until upstream takes it or solves it differently; drop the patch and its `.gitmodules`
line when the pin moves past a fix.

---

**Title:** Narrowing a consult--multi prompt with an async source keeps the hidden
sources' candidates

### Environment
- consult 3.10 (3c64214), vertico 2.x, Emacs 31.1.

### What happens
A `consult--multi` prompt with static sources and one `:async` source (here: project
files as `:items`, LSP workspace symbols as `:async`). After narrowing to the async
source, every key still costs as much as with all candidates visible: with 34583
file candidates hidden, 15 - 35 ms per key in Vertico; with the change below 0.6 -
4.7 ms. A prompt with static sources only does not have this cost.

### Cause
With an `:async` source, `consult--multi-async` runs every source through
`consult--async-predicate`. Narrowing sets `consult--narrow` and refreshes; the
predicate step then holds back new input from a hidden source, but the candidates
that source computed before stay in the merged list (`consult--async-merge-sink`).
Vertico's `completion-all-completions` checks each of them against
`consult--multi-async-predicate` at every update. `consult--multi-static` instead
rebuilds its list from the visible sources only.

### Change (applied locally)
- `consult--async-predicate`: when input reaches a hidden source, send `flush`
  downstream, so the merge sink drops its sub-list.
- `consult--async-dynamic`: on a `flush` from upstream, forget the last input
  (`current`), so widening at the same input computes it again. Without this, typing
  `vec`, narrowing, typing `t`, deleting it and widening leaves the hidden source
  empty: the stored input equals `current` and is not computed again.

```diff
          (pcase action
            ('setup (setq pred (consult--in-buffer pred)))
            ((or 'cancel 'destroy) (setq input nil))
            ((pred stringp) (setq input action)))
-          (when (and input (funcall pred))
-            (funcall sink input)
-            (setq input nil)))))))
+          (when input
+            (if (funcall pred)
+                (progn
+                  (funcall sink input)
+                  (setq input nil))
+              (funcall sink 'flush))))))))
...
          (pcase action
            ((or 'cancel 'destroy) (cancel-timer timer))
+            ('flush (setq current nil))
            ((pred stringp)
```

Full patch: `patches/consult/0001-Drop-a-hidden-source-s-candidates-in-asynchronous-co.patch`.
A different design (dropping hidden sub-lists in the merge, or a narrowing hook for
async pipelines) may suit consult better; the measurements above are the point.

### Reproduction
`emacs -Q --batch -L <consult> -l repro.el`, with `repro.el`:

```elisp
;;; -*- lexical-binding: t; -*-
(require 'consult)
(defvar shown nil)
(let* ((files (list :name "File" :narrow ?f :items '("vec.h" "vector.cc" "other.cc")))
       (symbols (list :name "Symbol" :narrow ?s
                      :async (consult--async-dynamic
                              (lambda (input) (list (concat "symbol-" input))))))
       (async (funcall (consult--multi-async
                        (consult--multi-enabled-sources (list files symbols)))
                       (lambda (action) (when (consp action) (setq shown action)) nil))))
  (cl-flet ((type (label input)
              (funcall async input)
              (accept-process-output nil 0.1)
              (message "%-18s %S" label
                       (mapcar (lambda (c) (substring-no-properties c 0 (1- (length c))))
                               shown))))
    (with-temp-buffer
      (funcall async 'setup)
      (type "vec" "vec")
      (setq consult--narrow ?s)
      (type "narrowed, vect" "vect")
      (type "narrowed, vec" "vec")
      (setq consult--narrow nil)
      (type "widened, vec" "vec"))))
```

3.10 prints the file candidates in all four lines (narrowed too). With the change:
narrowed lines show only `symbol-vect` / `symbol-vec`, the widened line all three
again. With only the first hunk, the widened line lacks the files.
