# TODO_human - the owner's queue

The LLM's work lives in `TASKS.md`; this file is the owner's. It holds only what the LLM
cannot do: runs on the Arch machine and on RMO, root and system actions, downloads and
accounts, reports sent to other projects, and decisions waiting on the owner. The LLM adds
items as numbered steps and prints them in chat the moment it adds them; the owner deletes
an item once it is done. Results go to the journal or DESIGN, never back into this file;
`git log` is the history.

Item shape: id `H-n` | date added | what it unblocks (`T-nnn`, `O-n`, `Sn`) | one line of
what and why | numbered steps, each with its command inline, only what the owner's hands
must do, literal values only, never a secret | what to report back, only for what the LLM
cannot read itself. An approval another session asks the owner for itself (a bench
service's plan) is not an item.

## Run now
- **H-32** (2026-11-08, unblocks S22, T-138, D-190, D-192) pdf-tools on the Mac:
  build its server with MacPorts' poppler, run S22, judge sharpness. Install agreed
  2026-11-08.
  1. On Arch: `cd ~/source/repos/emacs-cpp && git push` (the session does not push).
  2. On the Mac: `sudo port install poppler autoconf automake pkgconfig`
  3. On the Mac: `cd ~/source/repos/emacs-cpp && git pull --ff-only`
  4. On the Mac: `cd ~/source/repos/emacs-cpp/spikes/s22-pdf-tools && mkdir -p src &&
     git clone -q --depth 1 --branch v1.3.0 https://github.com/vedang/pdf-tools
     src/pdf-tools && git clone -q --depth 1 https://github.com/emacsorphanage/tablist
     src/tablist`
  5. On the Mac: `cd ~/source/repos/emacs-cpp/spikes/s22-pdf-tools/src/pdf-tools/server
     && (./autogen.sh && ./configure && make) > ../../../build-mac.log 2>&1; echo exit
     $?; tail -5 ../../../build-mac.log`
  6. On the Mac: `cd ~/source/repos/emacs-cpp/spikes/s22-pdf-tools/src && cp
     ../../../docs/CHEATSHEET.md cheat.md && pandoc cheat.md -o test-orig.pdf
     --pdf-engine=xelatex -V monofont=DejaVuSansMono.ttf -V geometry:margin=3cm &&
     pandoc cheat.md -o test-new.pdf --pdf-engine=xelatex -V
     monofont=DejaVuSansMono.ttf -V geometry:margin=1cm`
  7. On the Mac (an Emacs window opens, scrolls by itself for about 30 s and closes;
     do not touch it): `cd ~/source/repos/emacs-cpp/spikes/s22-pdf-tools &&
     S22_CLAMP=1 S22_LOG=mac-run1.log /Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs
     -Q --eval '(condition-case e (load (expand-file-name "s22.el")) (error
     (append-to-file (format "S22 load error: %S\n" e) nil (expand-file-name
     "mac-run1.log")) (kill-emacs 2)))'; cat mac-run1.log`
  8. On the Mac, the same with the window kept open at the end: `cd
     ~/source/repos/emacs-cpp/spikes/s22-pdf-tools && S22_HOLD=1 S22_CLAMP=1
     S22_LOG=mac-run2.log /Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs -Q
     --eval '(load (expand-file-name "s22.el"))'`. When it stops scrolling, look at the
     text; in your usual Emacs open the same PDF in DocView: `C-x C-f
     ~/source/repos/emacs-cpp/spikes/s22-pdf-tools/src/test.pdf RET`; compare; quit the
     spike's Emacs with `C-x C-c`.
  Report back: step 5's `exit` line and tail; step 7's printed log; step 8: is
  pdf-tools' text as sharp as DocView's, sharper, or blurrier?

- **H-33** (2026-11-08, unblocks D-192's upstream report) Report pdf-tools' roll-mode
  revert defect.
  1. In a browser, signed in to GitHub, open https://github.com/vedang/pdf-tools/issues/new
  2. On Arch: `cat ~/source/repos/emacs-cpp/spikes/s22-pdf-tools/upstream-issue.md`;
     paste the line under `Title:` as the title and the text under `Body:` as the
     body; submit.
  Report back: the issue's URL.

- **H-31** (2026-11-07, unblocks T-135, D-184 - D-186) Markdown to PDF on Arch: the
  install (agreed 2026-11-07), the tests, one export by hand.
  1. On the Mac: `cd ~/source/repos/emacs-cpp && git push` (the session does not push).
  2. On Arch: `sudo pacman -S pandoc-cli texlive-xetex mupdf-tools`
  3. On Arch: `cd ~/source/repos/emacs-cpp && git pull --ff-only && kpsewhich
     DejaVuSansMono.ttf && make test </dev/null`
  4. On Arch: quit Emacs, start it again, open
     `~/source/repos/RMO-drafts/md/exact_coarse_model.md`, press `C-c C-c x`.
  Report back: what `kpsewhich` printed (or nothing); `make test`'s `Ran ...` line and
  any FAILED test names; whether step 4's PDF shows the Greek letters, sharply, and
  any `*Warnings*` text.

- **H-14** (2026-10-21, unblocks T-118) Hand check: deal.II's own sources from RMO.
  The index is built (`indexes/dealii.dex`, deal.II 9.8.0).
  1. In Emacs on Arch, open `~/source/repos/RMO-gross-pitaevskii/.dir-locals.el` and
     add the line `(emacs-cpp-project-libraries . (dealii))` after
     `(c-ts-indent-offset . 4)`; save.
  2. In Emacs: `M-x eglot-shutdown-all RET`, then `C-x C-f
     ~/source/repos/RMO-gross-pitaevskii/src/main.cc RET`.
  3. After a few seconds: `C-c l s n_active_cells RET`.
  Report back: the file it lands in (expected
  `.../emacs-cpp/indexes/dealii-9.8.0/source/grid/tria.cc`) and any `*Warnings*`.

- **H-15** (2026-10-21, unblocks T-067, D-138) The mouse's side buttons on the Mac
  (`make test` and S18 there were run by the session, 0098).
  1. On the Mac: quit Emacs and start it again (graphical), so it loads this commit.
  2. In Emacs: open a C++ file, `M-.` on a name, then press the mouse's back button,
     then its forward button.
  3. On Arch: `cd ~/source/repos/emacs-cpp && git push` (the session does not push).
  4. On the Mac: `cd ~/source/repos/emacs-cpp && git pull --ff-only && sh
     packaging/fswatch-no-loss/check.sh ~/opt/fswatch-no-loss/bin/fswatch </dev/null`
     (its check 5 changed on Arch, 2026-10-21; the binary stays as built).
  Report back: whether step 2 went back and forward (if not, `C-h k` and the button:
  the event name shown); the last line of step 4.

## Parked
- **H-7** (2026-10-20, unblocks T-032, T-036, T-037, T-039) Four reports to the Emacs bug
  tracker, drafted 2026-10-09 / 10, outward so yours to send.
  1. In Emacs, for each of `docs/upstream/eglot-watch-cap-partial-watches.md`,
     `docs/upstream/c-ts-mode-namespace-class-braces.md`,
     `docs/upstream/c-ts-mode-local-indent-style.md`,
     `docs/upstream/c-ts-mode-member-after-blank-line.md`: `M-x report-emacs-bug`, the
     file's title as the subject, its text as the body, the `.el` reproduction it names
     attached; send.
  Report back: the four bug numbers.
- **H-24** (2026-11-04, O-80, D-165) Send the report on `process-attributes` CPU times
  to the Emacs bug tracker (outward, so yours); the draft is
  `docs/upstream/process-attributes-cpu-time-apple-silicon.md`.
  1. In Emacs on the Mac: `M-x report-emacs-bug`, subject `31.1; process-attributes:
     utime, stime and time about 42 times too small on Apple silicon (Mach ticks read as
     nanoseconds)`, the draft's text below its `---` line as the body; attach
     `docs/upstream/process_attributes_cpu_repro.el`; send.
  Report back: the bug number.
- **H-8** (2026-10-20, 0084 review:B-3 to review:B-5, deferred; T-114) The upstream
  reports and patches in the review's order: treemacs and clang-change-namespace first,
  then consult, projectile, yasnippet-snippets, consult-eglot's ordering half; clangd 0009,
  0010, then 0005 - 0008 squashed, then 0001 - 0004 as an RFC; fswatch 0002 and 0004.
  Steps written when the owner moves this item back.

## Decide
