;;; init-ui-test.el --- which-key's delays in prompts  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-080): while a prompt is open, which-key's timer
;; runs at 0.2 s; consult's narrow key `<' in the prompt waits no longer, ESC and
;; any other prefix wait up to 3 s, as outside prompts (D-071).  Closing the last
;; prompt gives the timer its 3 s back, closing an inner one does not.  Batch Emacs
;; reads prompts without a minibuffer, so `minibuffer-depth' is replaced by a stub
;; and the hook functions are called as the minibuffer would call them.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defun init-ui-test--timer-delay ()
  "Return the idle delay of which-key's timer in seconds."
  (float-time (timer--time which-key--timer)))

(defun init-ui-test--wait (keys)
  "Return the extra wait `which-key-delay-functions' gives the prefix KEYS."
  (run-hook-with-args-until-success 'which-key-delay-functions keys 1))

(ert-deftest init-ui-which-key-narrow-key-in-prompts ()
  "D-080: `<' in a prompt lists the narrow keys after 0.2 s; other prefixes 3 s."
  (init-test--load)
  (require 'consult)
  (should (equal consult-narrow-key "<"))
  (should (memq #'emacs-cpp-ui--which-key-prompt-opened minibuffer-setup-hook))
  (should (memq #'emacs-cpp-ui--which-key-prompt-closed minibuffer-exit-hook))
  ;; No prompt open: the usual 3 s for every prefix, nothing added.
  (should (= (init-ui-test--timer-delay) 3.0))
  (should-not (init-ui-test--wait "<"))
  (should-not (init-ui-test--wait "ESC"))
  (unwind-protect
      (with-current-buffer (window-buffer (minibuffer-window))
        (should (minibufferp))
        (cl-letf (((symbol-function 'minibuffer-depth) (lambda () 1)))
          (emacs-cpp-ui--which-key-prompt-opened)
          (should (= (init-ui-test--timer-delay) 0.2))
          (should-not (init-ui-test--wait "<"))
          (dolist (keys '("ESC" "C-x" "C-c l"))
            (should (< (abs (- (init-ui-test--wait keys) 2.8)) 1e-9)))
          ;; Another window's buffer while the prompt is open: `<' there is no
          ;; narrow key, so it waits the full 3 s.
          (with-temp-buffer
            (should (< (abs (- (init-ui-test--wait "<") 2.8)) 1e-9))))
        ;; An inner prompt closes: the outer one is still open.
        (cl-letf (((symbol-function 'minibuffer-depth) (lambda () 2)))
          (emacs-cpp-ui--which-key-prompt-closed)
          (should (= (init-ui-test--timer-delay) 0.2)))
        ;; The last prompt closes.
        (cl-letf (((symbol-function 'minibuffer-depth) (lambda () 1)))
          (emacs-cpp-ui--which-key-prompt-closed)
          (should (= (init-ui-test--timer-delay) 3.0))))
    (which-key--start-timer)))

(provide 'init-ui-test)
;;; init-ui-test.el ends here
