# <Project> - implementation journal

A teaching + decision log that runs alongside `git log`. Two jobs:

1. **Understand the code.** Each entry explains, in plain English, WHAT was built, WHY, and
   the language idioms it used, so the owner can open the code and ask informed questions.
2. **Recover / postmortem.** Each entry carries an assumptions + risks ledger. Milestone
   tags give clean revert points; `POSTMORTEM.md` reads the ledgers to update DESIGN.

## How it works
- One entry per feature / work chunk / spike result (may span several commits).
- `docs/journal/NNNN-slug.md` (zero-padded), newest listed on top here. Copy
  `docs/journal/TEMPLATE.md`.
- Committed WITH the code it describes; links commit hash + D-nnn; does not duplicate
  the diff. Tier 1 changes (see CLAUDE.md) get no entry.
- Milestone tags `vX.Y.Z` only when the owner confirms; risky directions branch from a tag.
- Plain teaching English, not chat style.
- An external review (LLM chat, human critique) is folded in as an entry: each point taken
  / not taken with a reason, attribution and date; the transcript is deleted afterwards.

## Index (newest first)
| #    | date       | title | commits | decisions |
|------|------------|-------|---------|-----------|
| 0073 | 2026-10-15 | T-087: `M-o` symbol sources per server | T-087 | D-106 |
| 0072 | 2026-10-15 | T-084: symbols in clangd's order, `M-o` ignores case | T-084 | D-105 |
| 0071 | 2026-10-14 | T-080: `make test` in a temporary HOME | T-080 | D-104 |
| 0070 | 2026-10-14 | T-078: latexindent as texlab runs it | T-078 | D-103 |
| 0069 | 2026-10-14 | S13: index through a symlink, PASS on Arch | S13, T-077 | none |
| 0068 | 2026-10-14 | T-074: LaTeX buffers and regions by latexindent | T-074 | D-101 |
| 0067 | 2026-10-14 | T-073: patched clangd on macOS at LLVM 23.1.3 | T-073 | D-100 |
| 0066 | 2026-10-14 | S12: change signature, FAIL; calls in templates | S12, T-069 | none |
| 0065 | 2026-10-14 | patched clang-change-namespace, `C-c l N` | T-072 | D-097 |
| 0064 | 2026-10-14 | snippets: yasnippet, its collection on `C-c y` | T-071 | D-095 |
| 0063 | 2026-10-14 | clang-tidy fixes and clang-move on `C-c l` | T-068 | D-094 |
| 0062 | 2026-10-13 | navigation clicks, right-click menu | T-066 | D-093 |
| 0061 | 2026-10-13 | LaTeX: AUCTeX, texlab, `C-c l b`; init-lsp.el | T-065 | D-090..91 |
| 0060 | 2026-10-13 | `M-o` previews after a pause in typing | T-064 | D-088 |
| 0059 | 2026-10-13 | `M-o` `< l` lists as `C-c l s` for empty input | T-063 | D-086 |
| 0058 | 2026-10-13 | project symbols: one URI matcher for every server | T-062 | D-085 |
| 0057 | 2026-10-13 | project symbols: cap, URI encoding, case | T-061 | D-083 |
| 0056 | 2026-10-13 | `M-o` symbols: the project's, all on `l` | T-060 | D-082 |
| 0055 | 2026-10-13 | `C-c p ?` over projectile's files, ripgrep on macOS | T-057 | D-081 |
| 0054 | 2026-10-12 | narrow keys listed 0.2 s after `<` | T-056 | D-080 |
| 0053 | 2026-10-11 | S11 run 4: narrowed `M-o` as calm as `C-c l s` | S11 | D-079 |
| 0052 | 2026-10-11 | consult patch: hidden sources leave the list | T-055 | D-079 |
| 0051 | 2026-10-11 | S11 run 3: PASS, the shipped command on RMO | S11 | D-074..78 |
| 0050 | 2026-10-11 | T-049: go to anything on `M-o` | T-049 | D-074..78 |
| 0049 | 2026-10-11 | S11 run 2: PASS, the whole prompt on RMO | S11 | D-077 |
| 0048 | 2026-10-11 | S11 run 1: go to anything, one letter slow on deal.II | S11 | D-074 |
| 0047 | 2026-10-10 | T-046: `# %%` cells in Python and R, ESS | T-046 | D-072 |
| 0046 | 2026-10-10 | T-044: fixes to vendored packages as patch files | T-044 | D-069 |
| 0045 | 2026-10-10 | T-042: warning for a source not in the database | T-042 | D-068 |
| 0044 | 2026-10-10 | T-038: C++ indentation from plain dir-locals | T-038 | D-062 |
| 0043 | 2026-10-10 | T-035: RET by clangd (superseded, D-065) | T-035 | D-061 |
| 0042 | 2026-10-09 | T-033: patch 0009, re-index flagged shards | T-033 | D-060 |
| 0041 | 2026-10-09 | T-020: patch 0008, a known includer at once | T-020 | D-059 |
| 0040 | 2026-10-09 | T-030: debug targets from CMake's file API | T-030 | D-056 |
| 0039 | 2026-10-09 | T-031: platform defaults files | T-031 | D-055 |
| 0038 | 2026-10-09 | T-027: load measurements on the Mac | T-027 | O-24 |
| 0037 | 2026-10-09 | T-028: review of the debug and presets code | T-028 | D-016, O-25 |
| 0036 | 2026-10-09 | T-023: the patched clangd built on macOS | T-023 | D-052 |
| 0035 | 2026-10-09 | T-022: lldb-preset next to gdb-preset | T-022 | D-051 |
| 0034 | 2026-10-09 | T-021: the config starts on macOS | T-021 | D-050, D-054 |
| 0033 | 2026-10-08 | v0.4.1: the tree opens only on C-c t again | v0.4.1 | D-049 |
| 0032 | 2026-10-08 | Milestone v0.4.0: polish | v0.4 | D-038..D-048 |
| 0031 | 2026-10-08 | Code review v0.2.0..HEAD folded in | review | D-045, D-048 |
| 0030 | 2026-10-08 | T-018: Python rides along | T-018 | D-045 |
| 0029 | 2026-10-08 | T-019: patch 0007, header wait ends at the includers | T-019 | D-047 |
| 0028 | 2026-10-08 | T-019: patch 0006, header waits for the handover | T-019 | D-046 |
| 0027 | 2026-10-08 | S9 run 1: PASS, header races the index handover | S9 | none |
| 0026 | 2026-10-08 | T-016, T-017: diff-hl and breadcrumb | T-016, T-017 | D-042, D-043 |
| 0025 | 2026-10-08 | T-007: code commands on `C-c l` | T-007 | D-004 |
| 0024 | 2026-10-08 | T-010: package manuals in `C-h i` | T-010 | D-039 |
| 0023 | 2026-10-08 | T-008: performance baseline, startup GC | T-008 | D-038 |
| 0022 | 2026-10-08 | Milestone v0.2.0: build and debug | v0.2 | D-030..D-037 |
| 0021 | 2026-10-08 | T-005: build the active preset from any buffer | T-005 | D-035 |
| 0020 | 2026-10-08 | T-006 fix: `gdb-preset` targets from build.ninja | T-006 | D-033 |
| 0019 | 2026-10-08 | T-006: dape `gdb-preset`, a preset program | T-006 | D-031, D-032 |
| 0018 | 2026-10-08 | S2 run 1: PASS, dape + gdb on RMO | S2 | D-002 |
| 0017 | 2026-10-08 | Milestone v0.1.0: navigation | v0.1 | D-001..D-029 |
| 0016 | 2026-10-08 | Project tree on `C-c t`, following the project | owner | D-029 |
| 0015 | 2026-10-08 | T-011: header flags from the index (patch 0005) | T-011 | D-028 |
| 0014 | 2026-10-08 | T-014: the patched clangd in the config | T-014 | D-026, D-027 |
| 0013 | 2026-10-08 | S8 run 2: PASS, patched clangd 7x faster on RMO | S8 | D-025 |
| 0012 | 2026-10-08 | S8 run 1: 7x faster, a references bug found and fixed | S8 | D-025 |
| 0011 | 2026-10-08 | clangd answers navigation from its index (local patch) | S8 | D-025 |
| 0009 | 2026-10-08 | S6 PASS: ccls answers from its disk index | S6 | none yet |
| 0008 | 2026-10-08 | S5 closed; ccls and PR 175209 spikes set up | S5-S7 | D-021, D-022 |
| 0007 | 2026-10-08 | S5 run 1: warm-up tenfold faster, FAIL | S5 | none |
| 0006 | 2026-10-08 | T-004 fixes: library headers, completion | T-004 | D-019, D-020 |
| 0005 | 2026-10-07 | T-004: eglot + clangd from the active preset | T-004 | D-016..18 |
| 0004 | 2026-10-07 | T-003: completion stack | T-003 | D-006 |
| 0003 | 2026-10-07 | S1 run 2: PASS, cold headers open | S1 | D-016 |
| 0002 | 2026-10-07 | T-002: config skeleton and pinned packages | T-002 | D-006, D-014 |
| 0001 | 2026-10-07 | S1 run 1: database found, standard missing | S1 | D-011..13 |
| 0000 | YYYY-MM-DD | Spike phase recap / prototype review | | |
