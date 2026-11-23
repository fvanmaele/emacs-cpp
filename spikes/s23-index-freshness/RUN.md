# S23 - index freshness of navigation from the index

Asked by the owner 2026-11-22: when do patches 0001 - 0004 and 0014 - 0017 lose
accuracy, and what do the cheap fixes cost? Run by the session on the Mac the same day.
No pass criteria were written before the runs; the one applied afterwards is D-026's own
premise: on an unchanged file the index answer equals the AST answer of stock clangd.
The cost has no budget and is recorded only.

Parts:
- `reproduce/`: cases 1 (header changed: on disk, unsaved, saved while running), 2
  (definition moved in another file), 3 (header opened after a `-D` change), each with
  three servers: the patched clangd with `--navigation-from-index`, without it, and
  MacPorts' `clangd-mp-23`. Command: `sh run.sh </dev/null` in `reproduce/`.
- `measure-cost/`: per deal.II TU, the include closure (`clang++ -M`) and the time to
  hash, open, `stat` or hash-in-memory all of it. Command: `sh run.sh > results.log
  2>&1 </dev/null` in `measure-cost/`.

Open for the owner (after O-95): the cost run on Arch, and on the Mac with G DATA's
on-access scan off.
