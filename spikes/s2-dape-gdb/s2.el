;;; s2.el --- S2: dape + gdb DAP on a preset-built binary  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S2_ROOT (project), S2_PROGRAM (binary), S2_SOURCE (file relative to
;; S2_ROOT), S2_BREAK (regexp; breakpoint on the first matching line), S2_WATCH
;; (expression), S2_ADAPTER (gdb | lldb-dap), S2_ARGS (extra adapter arguments, split
;; on "|"), S2_OUT (log).
;; Sequence: breakpoint, launch, stop, stack, locals, watch, step over, step in, end;
;; then breakpoints saved, removed and loaded again.
(require 'init-test)
(init-test--load)
(require 'dape)
(defvar root (file-name-as-directory (getenv "S2_ROOT")))
(defvar out (getenv "S2_OUT"))
(defvar adapter (intern (or (getenv "S2_ADAPTER") "gdb")))
(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (round (* 1000 (float-time (time-subtract (current-time) t0)))))
(defun wait-for (pred seconds)
  "Process events until PRED is non-nil or SECONDS pass; return PRED's value."
  (let ((end (+ (float-time) seconds)) value)
    (while (and (not (setq value (funcall pred))) (< (float-time) end))
      (accept-process-output nil 0.1))
    value))
(defun call-and-wait (fn &rest args)
  "Call dape's continuation-passing FN with ARGS and a callback; wait for it."
  (let (done)
    (apply fn (append args (list (lambda (&rest _) (setq done t)))))
    (wait-for (lambda () done) 30)))
;; No windows, REPL or focus changes in batch; count stops instead.
(defvar stops 0)
(setq dape-start-hook nil
      dape-update-ui-hook nil
      dape-display-source-hook nil
      dape-stopped-hook (list (lambda () (setq stops (1+ stops)))))
(defun conn () (dape--live-connection 'stopped t))
(defun top-frame (c)
  (call-and-wait #'dape--stack-trace c (dape--current-thread c) 50)
  (car (plist-get (dape--current-thread c) :stackFrames)))
(defun frame-string (frame)
  (format "%s %s:%s" (plist-get frame :name)
          (file-name-nondirectory (or (plist-get (plist-get frame :source) :path) "?"))
          (plist-get frame :line)))
(defun wait-stop (before seconds)
  (wait-for (lambda () (and (> stops before) (conn))) seconds))

(let* ((source (find-file-noselect (expand-file-name (getenv "S2_SOURCE") root)))
       (break-line nil)
       (program (getenv "S2_PROGRAM")))
  (say "adapter %s: %s" adapter
       (car (process-lines (if (eq adapter 'gdb) "gdb" "lldb-dap") "--version")))
  (say "program %s" program)
  (with-current-buffer source
    (goto-char (point-min))
    (re-search-forward (getenv "S2_BREAK"))
    (beginning-of-line)
    (setq break-line (line-number-at-pos))
    (dape-breakpoint-toggle))
  (say "breakpoint %s:%d; adapter arguments: %S" (getenv "S2_SOURCE") break-line
       (getenv "S2_ARGS"))
  (let* ((base (copy-tree (alist-get adapter dape-configs)))
         (extra (split-string (or (getenv "S2_ARGS") "") "|" t))
         (base (if extra
                   (plist-put base 'command-args
                              (vconcat (plist-get base 'command-args) extra))
                 base))
         (config (dape--config-eval-1
                  (plist-put (plist-put base :program program) :cwd root)))
         (t0 (current-time)))
    (let ((default-directory root))
      (with-current-buffer source (dape config)))
    (if (not (wait-stop 0 120))
        (say "FAIL no stop within 120 s")
      (let* ((c (conn)) (frame (top-frame c)))
        (say "stopped after %d ms at %s (breakpoint line %d)" (ms t0) (frame-string frame)
             break-line)
        (say "stack: %s" (mapconcat #'frame-string
                                    (seq-take (plist-get (dape--current-thread c)
                                                         :stackFrames)
                                              6)
                                    " <- "))
        ;; Locals: the first scope (gdb: "Locals"; lldb-dap: "Locals").
        (call-and-wait #'dape--scopes c frame)
        (let ((scope (car (plist-get frame :scopes))))
          (call-and-wait #'dape--variables c scope)
          (say "scope %S: %s" (plist-get scope :name)
               (mapconcat (lambda (v)
                            (format "%s=%s" (plist-get v :name)
                                    (truncate-string-to-width
                                     (or (plist-get v :value) "") 40 nil nil "...")))
                          (seq-take (plist-get scope :variables) 8) ", "))
          ;; One level into the first composite local (its members, or a pretty
          ;; printer's children).
          (when-let* ((var (seq-find (lambda (v)
                                       (> (or (plist-get v :variablesReference) 0) 0))
                                     (plist-get scope :variables))))
            (call-and-wait #'dape--variables c var)
            (say "  %s (%s): %s" (plist-get var :name) (plist-get var :type)
                 (mapconcat (lambda (v)
                              (format "%s=%s" (plist-get v :name)
                                      (truncate-string-to-width
                                       (or (plist-get v :value) "") 30 nil nil "...")))
                            (seq-take (plist-get var :variables) 5) ", "))))
        ;; Watch: evaluate an expression in this frame, as dape's watch window does.
        (let (result)
          (dape-request c :evaluate
                        (list :expression (getenv "S2_WATCH") :frameId (plist-get frame :id)
                              :context "watch")
                        (lambda (body error) (setq result (or error body))))
          (wait-for (lambda () result) 30)
          (say "watch %s = %s" (getenv "S2_WATCH")
               (if (stringp result) (concat "error: " result) (plist-get result :result))))
        ;; Step over, then step in.
        (let ((n stops))
          (dape-next c)
          (say "next: %s"
               (if (wait-stop n 60) (frame-string (top-frame (conn))) "no stop")))
        (let ((n stops))
          (dape-step-in (conn))
          (say "step in: %s"
               (if (wait-stop n 60) (frame-string (top-frame (conn))) "no stop")))
        ;; End the session.
        (dape-kill (conn))
        (say "session ended: %s"
             (if (wait-for (lambda () (null (dape--live-connections))) 30) "yes" "no")))))
  ;; Breakpoints across sessions: save, remove, load.
  (let ((file (make-temp-file "s2-breakpoints")))
    (cl-flet ((sources () (seq-count #'dape--source-breakpoint-p dape--breakpoints)))
      (let ((before (sources)))
        (dape-breakpoint-save file)
        (dape-breakpoint-remove-all)
        (let ((removed (sources)))
          (dape-breakpoint-load file)
          (say "source breakpoints: %d, after remove-all %d, after load %d" before removed
               (sources)))))
    (delete-file file)))
(sleep-for 1)
(say "debugger processes left: %s"
     (string-trim (shell-command-to-string
                   "pgrep -x gdb; pgrep -x lldb-dap; true")))
(kill-emacs 0)
