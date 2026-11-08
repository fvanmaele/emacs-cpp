# 0134 - S22: pdf-tools PASS on the Mac, Arch's look left

- **Date:** 2026-11-08
- **Commits:** `16c2937` (the script's fix, run 1), `af7d7fe` and `9f1c437` (Arch), and the
  commit that carries this entry
- **Tier:** 3 (spike S22)
- **Decisions:** D-190, D-192
- **Done when:** S22's five criteria (`spikes/s22-pdf-tools/RUN.md`) PASS on each machine.
  Not met yet: criterion 5 on Arch (H-35).

> Plain English: can pdf-tools, a PDF viewer with its own compiled helper program, replace
> DocView for the Markdown PDF on both machines? The Mac says yes; Arch owes one look.

## What + why
DocView shows one page at a time; pdf-tools 1.3.0 scrolls across pages. Its price is a C
program, `epdfinfo`, built on each machine against that machine's poppler library, so D-190
tests it before anything enters `lib/`.

Arch passed criteria 1 - 4 first, the fourth amended (D-192). This entry adds the Mac, the
riskier machine: pdf-tools documents Homebrew, this project allows MacPorts only (D-053).
It built without a change. Criteria 1 - 4 pass with the same figures in both runs; the
owner compared the text with DocView's and found it as sharp (criterion 5). Figures:
`spikes/s22-pdf-tools/RESULTS.md`.

The sharpness look had been filed for the Mac only. Criteria hold on each machine, and
nobody has judged Arch's, so S22 is not yet PASS and DocView stays (D-190): H-35.

## Concepts (shell, Emacs) explained
- **A graphical Emacs on the Mac may change directory by itself.** Started with stdin not
  a terminal, it moves to HOME before reading its arguments; a relative file name then
  means a file in HOME. The first run failed this way (POSTMORTEM, 2026-11-08). `--chdir`
  names the directory and overrides the move.
- **`S22_HOLD`** cancels the run's watchdog and leaves Emacs open, so a person can judge
  what no script can.

## Key files walked
- `spikes/s22-pdf-tools/mac-run.sh` - clones, builds, makes the test PDFs, runs `s22.el`.
- `spikes/s22-pdf-tools/s22.el` - `s22-scrolled` judges criterion 2 from real `C-n` keys.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** the Mac's small frame (597 x 508 px) stands for daily use. **Would break
  if:** a full-screen frame scrolls slower or stops; large frames were run on Arch only.
  **DESIGN bet:** D-190.
- **Assumed:** one look at one PDF settles sharpness. **Would break if:** text blurs at
  another window width or at `+` / `-` zoom; only `fit-width` was compared.
  **DESIGN bet:** D-190.
- **Assumed:** `epdfinfo` keeps working across `port upgrade poppler`. **Would break if:**
  the library's version changes; a rebuild is then needed, D-190's own case against.
  **DESIGN bet:** D-190.

## How to verify
`cat spikes/s22-pdf-tools/mac-run1.log` shows `S22 done: 0 failures (clamp t)`. To rerun:
`spikes/s22-pdf-tools/mac-run.sh`, then look and quit with `C-x C-c`.

## Open questions (optional)
None. S22's PASS on both leads to D-190's replacement of DocView, a tier 2 change whose
done when is agreed first.
