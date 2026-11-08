# 0132 - T-139: an edited buffer whose file changed is asked, as CLion asks

- **Date:** 2026-11-08
- **Commits:** see `git log --grep T-139`
- **Tier:** 2
- **Decisions:** D-191 (amends D-151 (2b))
- **Done when:** agreed 2026-11-08 (T-139's row): asked load / keep / diff; asked when
  shown in the focused frame (shown, focus regained, 1 s idle); one at a time, never in
  the minibuffer; the message for the others; ERT tests; `make test` on Arch, the Mac
  by an H-n item.

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
The reverter (`lisp/emacs-cpp-reverter.el`) reloads a project buffer when another
program changes its file, but not a buffer with unsaved edits: reloading would throw
the edits away. Until now such a buffer got a one-line message, soon gone. D-151
assumed Emacs would ask at the next edit; checked today, it does not for a buffer that
already had edits, only at save. The owner asked for a question instead and chose
CLion's: "load the disk version / keep yours / show the difference", asked when you
are looking at the buffer.

## Concepts (Emacs Lisp) explained
- **Hooks and advice on Emacs's own events.** `window-buffer-change-functions` runs
  when a window starts showing another buffer; `after-focus-change-function` when a
  frame gains or loses focus (wrapped with `add-function`, as it is one function, not
  a list); `minibuffer-exit-hook` when a prompt closes.
- **Timers.** A question must not appear inside redisplay or a process filter, so each
  trigger only arms a timer; the timer asks. `run-with-idle-timer` waits for the next
  idle period, so when Emacs is already idle the code uses an ordinary timer for the
  rest of the second instead.
- **`read-multiple-choice`** shows the three keys `l`, `k`, `d` with their meanings.

## Key files walked
- `lisp/emacs-cpp-reverter.el` - `emacs-cpp-reverter--conflict` notes the buffer (the
  revert step finds it edited); `--ask` asks each noted buffer the focused frame
  shows; `--ask-one` re-checks (saved meanwhile, edits undone, file deleted) and asks.
  Keep and diff remember the file's modification time, so only a newer change asks
  again. `--message` leaves out the buffers about to be asked.
- `test/emacs-cpp-reverter-test.el` - `emacs-cpp-reverter-ask`: the real fswatch, each
  trigger, each answer, the minibuffer case, a second change after keep.

## Assumptions + risks
- **Assumed:** `frame-focus-state` tells a focused frame on the owner's desktops.
  **Would break if:** a window manager sends no focus events: the frame counts as
  focused only when Emacs says `t` or `unknown`; with `nil` the question waits for a
  window change. Tested by stubbing the function, not on a real desktop.
  **DESIGN bet:** D-191.
- **Assumed:** a change written by Emacs itself onto a file an edited buffer visits is
  Emacs's own business: `write-region` then asks through Emacs's lock check (found
  while testing: the test writes through `sh`).
- **Risk:** `init-debug-lldb-preset-builds-stops-and-steps` timed out on lldb's
  `:launch` 3 times between 21:30 and 21:35 on Arch, then passed 4 times, with and
  without this change: T-140.
- **T-140, the same day (D-197):** the cause is lldb-dap asking Arch's debuginfod server
  for system libraries' debug info at launch; each test run's fresh HOME has no cache,
  and dape gave a request 10 s. With the server address pointing nowhere the failure
  repeats exactly; without it the test passes in 4 - 5 s. dape now waits 60 s, and
  `make test` runs without the server: 5 runs in a row pass. An unreachable server still
  holds the launch past 60 s: T-141.

## How to verify
`make test`. By hand: open a project file, type a character, change the file in a
shell (`echo x >> file`); within a second Emacs asks `l` / `k` / `d`.
