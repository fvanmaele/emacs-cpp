# 0054 - T-056: narrow keys listed 0.2 s after `<`

- **Date:** 2026-10-12
- **Commits:** the commit that adds this entry (`lisp/init-ui.el`,
  `test/init-ui-test.el`)
- **Tier:** 2
- **Decisions:** D-080 (built here), D-071 (kept for every other prefix), O-35
- **Done when:** in a prompt with consult's narrow keys, `<` lists them after about
  0.2 s; ESC, `C-x` and other prefixes still wait 3 s, in the prompt and outside it;
  after the prompt closes every prefix waits 3 s again; an ERT test checks the delays
  for `<` and ESC inside and outside a prompt; owner's hand check with `M-o` and
  `C-x b`.
- **Tag:** none

> Plain English for someone who does not read Emacs Lisp fluently.

## What + why
In `M-o` (and `C-x b`, `M-g i` and the other consult prompts with narrow keys), `<`
followed by a letter narrows the list to one source. which-key shows those letters,
but only after 3 s, the delay D-071 chose for every prefix because 1 s brought up the
list of all `M-` commands after every ESC. In a prompt, 3 s is longer than anyone
waits, so the letters were never seen. Now `<` in such a prompt lists them after
0.2 s. ESC and every other prefix still wait 3 s, in prompts too, so D-071's reason
still holds.

## Concepts explained
- **One idle timer:** which-key does not time each prefix. It runs one repeating
  idle timer ("call me when Emacs has been idle for N seconds") and, when it fires,
  looks at the keys typed so far. The timer's delay is set once, when which-key
  turns on, so changing `which-key-idle-delay` later does nothing until the timer is
  restarted.
- **Delay functions only add:** `which-key-delay-functions` lets a function return
  extra seconds to wait for a given prefix; it cannot make the popup come sooner.
  So the config makes the timer fast (0.2 s) while a prompt is open and gives every
  prefix except `<` the missing 2.8 s back through such a function.
- **Minibuffer hooks:** `minibuffer-setup-hook` runs when a prompt opens,
  `minibuffer-exit-hook` when one closes (also on `C-g`). Prompts can nest; while the
  exit hook runs, `minibuffer-depth` still counts the prompt being closed (checked
  in a terminal Emacs: 1 for the outermost), so the timer goes back to 3 s only when
  the depth is 1.

## Key files walked
- `lisp/init-ui.el` - `emacs-cpp-ui--which-key-prompt-opened` / `-closed` restart
  the timer; `emacs-cpp-ui--which-key-delay` returns 2.8 s for any prefix but
  consult's narrow key typed in the prompt; the which-key form adds the three hooks.
- `test/init-ui-test.el` - batch Emacs reads prompts without a minibuffer, so the
  test replaces `minibuffer-depth` with a stub and calls the hook functions the way
  the minibuffer would: timer delay 3 s / 0.2 s / still 0.2 s after an inner prompt
  closes / 3 s after the last; extra wait none for `<`, 2.8 s for ESC, `C-x`,
  `C-c l` and for `<` outside the prompt buffer.

## Assumptions + risks  (the postmortem ledger)
- **Assumed:** `which-key--start-timer` (internal, Emacs 31.1 which-key.el) keeps its
  name and optional delay argument. **Would break if:** a later Emacs renames it; the
  test then fails with a void function. **DESIGN bet:** D-080.
- **Assumed:** `<` is a prefix only in prompts that have consult's narrow keys.
  **Would break if:** another package binds `<` as a prefix in the minibuffer; its
  keys would also show after 0.2 s. **DESIGN bet:** D-080.
- **Known gap:** paging inside an open popup (`C-h n`) restarts which-key's timer at
  3 s; the next `<` in the same prompt then waits 3 s, until a prompt opens again.

## How to verify
- `make test`: `init-ui-which-key-narrow-key-in-prompts`.
- Done here in a terminal Emacs (`emacs -Q -nw`, the repo's config, `C-x b`, key
  pushed by a timer, popup checked at 0.15 / 0.4 / 1 / 2.5 / 3.5 s): after `<`
  shown from 0.4 s on, not at 0.15 s; after ESC shown only at 3.5 s.
- Owner's hand check: `M-o`, type `<`, pause: the letters `b r m f s x p` appear at
  once; `C-x b`, `<`: its letters appear; ESC in a prompt, or `C-c l` in a buffer,
  still shows its list only after 3 s.
