# S22 plan (T-138, D-190)

Session on Arch, 2026-11-08. Spike code stays under `spikes/s22-pdf-tools/` and is never
promoted; a PASS on both machines leads to pdf-tools in `lib/` written fresh. Names
marked NEW do not exist yet.

- [x] 1. D-190, S22 in spikes/README and the risk register, T-138, RUN.md (~15 min)
- [x] 2. Fetch pdf-tools v1.3.0 and tablist, build epdfinfo on Arch (~15 min)
  Network (D-190): https://github.com/vedang/pdf-tools,
  https://github.com/emacsorphanage/tablist, into `spikes/s22-pdf-tools/src/` (NEW,
  ignored by git).
- [x] 3. Arch run in a graphical Emacs: criteria 1 - 5 (~30 min)
  `s22.el` (NEW) drives pdf-tools on a long PDF from a timer, logs to `arch-run1.log`.
- [x] 4. RESULTS.md (Arch half), spikes/README status (~10 min)
- [x] 5. H-n for the Mac run, printed in chat (~10 min)

Added 2026-11-08 (same session; not S22's, kept here as the session's one plan):
- [x] 6. T-139: kept buffer asked as CLion, code + tests + journal (~60 min)
  `lisp/emacs-cpp-reverter.el`, `test/emacs-cpp-reverter-test.el`; D-191 DECIDED.
