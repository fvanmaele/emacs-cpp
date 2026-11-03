;;; eglot-share.el --- S20: eglot's share of the reverter  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-153).  The reverter, its queue and its show handler
;; are copied from `s20-run.el''s fswatch-shown mode.
;;   S20_ROOT=<clone> S20_MODE=eglot|no-eglot S20_FSWATCH=... S20_CLANGD=... \
;;     S20_OUT=... S20_DIFF_HL=... emacs -Q --batch -l eglot-share.el
;; Opens every tracked file under src/ and include/ in `c++-ts-mode', with diff-hl as
;; the config turns it on.  eglot mode: starts eglot with the config's clangd command
;; and settings (`lisp/emacs-cpp-presets.el', `lisp/init-lsp.el') and waits until
;; clangd settles.  Then checks out s20-shift and s20-base, each time waiting for
;; every buffer to be current and clangd to settle.  Settled: every reverted buffer
;; had a publishDiagnostics after its didOpen, clangd was quiet 5 s and used less
;; than 0.1 s of CPU over 5 s (at most 300 s; owner 2026-11-03, the dry run's
;; quiet clangd was still reparsing).  Contrast: the same two checkouts back to back,
;; the second once clangd is only quiet.  Appends one block to S20_OUT.

(require 'cl-lib)
(require 'subr-x)
(require 'eglot)

(defun s20--env (name)
  (or (getenv name) (error "s20: %s is not set" name)))

;; D-160: pipetrace.c stays in this Emacs, out of clangd, git and fswatch.
(setenv "DYLD_INSERT_LIBRARIES")
(defvar s20-pipetrace (getenv "PIPETRACE_OUT"))

(defvar s20-root (file-name-as-directory (expand-file-name (s20--env "S20_ROOT"))))
(defvar s20-real-root (file-name-as-directory (file-truename s20-root)))
(defvar s20-mode (s20--env "S20_MODE"))
(defvar s20-eglot (pcase s20-mode ("eglot" t) ("no-eglot" nil)
                         (_ (error "s20: unknown mode %s" s20-mode))))
(defvar s20-reverted nil "(BUFFER . TIME) of each revert, newest first.")
(defvar s20-calls 0)
(defvar s20-records 0)
(defvar s20-overflows 0)
(defvar s20-filter-total 0.0)
(defvar s20-filter-max 0.0)
(defvar s20-probe-seen nil)
(defvar s20-stall 0.0 "Longest single wait step of `s20--wait': Emacs blocked.")
(defvar s20-skipped nil "(BUFFER . WHY) the current filter call did not revert.")
(defvar s20-opened (make-hash-table :test #'eq) "BUFFER -> time of its last didOpen.")
(defvar s20-diagnosed (make-hash-table :test #'eq) "BUFFER -> time of its last diagnostics.")
(defvar s20-did-open 0)
(defvar s20-last-message 0.0 "Time of the last message from the server.")
(defvar s20-split (make-hash-table :test #'eq)
  "Per checkout (D-154): KEY -> (SECONDS-TOTAL COUNT SECONDS-MAX); `bytes' -> total.")

(defun s20--split-add (key seconds)
  (let ((entry (gethash key s20-split (list 0.0 0 0.0))))
    (puthash key (list (+ (nth 0 entry) seconds) (1+ (nth 1 entry))
                       (max (nth 2 entry) seconds))
             s20-split)))

(defun s20--timed (key fn &rest args)
  "Call FN with ARGS; add its time to KEY in `s20-split'."
  (let ((start (float-time)))
    (prog1 (apply fn args)
      (s20--split-add key (- (float-time) start)))))

(defun s20--emit (fmt &rest args)
  (write-region (concat (apply #'format fmt args) "\n") nil (s20--env "S20_OUT") t 'silent))

(defun s20--git (&rest args)
  (with-temp-buffer
    (unless (eql 0 (apply #'call-process "git" nil t nil "-C" s20-root args))
      (error "s20: git %S: %s" args (buffer-string)))
    (buffer-string)))

(defun s20--wait (pred seconds)
  "Read process output and run timers until PRED is non-nil or SECONDS pass."
  (let ((deadline (+ (float-time) seconds)) v)
    (while (and (not (setq v (funcall pred))) (< (float-time) deadline))
      (let ((start (float-time)))
        (accept-process-output nil 0.02)
        (setq s20-stall (max s20-stall (- (float-time) start)))))
    v))

;;;; The reverter (fswatch-shown, D-151 .. D-153)

(defvar-local s20--stale nil "Reverted while hidden; VC state and marks wait.")
(defvar s20-shown-queue nil "Shown buffers waiting for a refresh, oldest last.")
(defvar s20-shown-timer nil)
(defvar s20-shown-last 0.0 "Time the last queue step ended.")
(defvar s20-shown-steps nil "Durations of the queue's steps.")

(defun s20--refresh (buffer)
  (with-current-buffer buffer
    (vc-refresh-state)
    (diff-hl-update)
    (setq s20--stale nil)))

(defvar s20--in-filter nil "Non-nil while the reverter's filter runs.")
(defvar s20-step-waits (getenv "S20_STEP_WAITS")
  "D-156 (e): a queue step that finds the filter running arms its timer again.")
(defvar s20-steps-deferred 0)

(defun s20--shown-step ()
  "Refresh the oldest queued buffer; arm the timer again while any is left."
  (setq s20-shown-timer nil)
  (if (and s20-step-waits s20--in-filter)
      (progn (cl-incf s20-steps-deferred)
             (setq s20-shown-timer (run-with-timer 0.05 nil #'s20--shown-step)))
    (s20--shown-step-1)))

(defun s20--shown-step-1 ()
  (when-let* ((next (car (last s20-shown-queue))))
    (setq s20-shown-queue (butlast s20-shown-queue))
    (let ((start (float-time)))
      (when (buffer-live-p next) (s20--refresh next))
      (setq s20-shown-last (float-time))
      (push (- s20-shown-last start) s20-shown-steps)))
  (when s20-shown-queue
    (setq s20-shown-timer (run-with-timer 0.05 nil #'s20--shown-step))))

(defun s20--queue-shown (buffer)
  (unless (memq buffer s20-shown-queue) (push buffer s20-shown-queue))
  (unless s20-shown-timer
    (setq s20-shown-timer (run-with-timer 0.05 nil #'s20--shown-step))))

(defun s20--on-show (frame)
  "Refresh each stale buffer FRAME's windows show (`window-buffer-change-functions')."
  (dolist (window (window-list frame 'no-minibuf))
    (let ((buffer (window-buffer window)))
      (when (buffer-local-value 's20--stale buffer)
        (s20--refresh buffer)))))

(defvar s20--reverting nil "Non-nil inside the reverter's `revert-buffer'.")

;; D-160: each revert's file read, wall and Emacs's CPU time.
(advice-add 'insert-file-contents :around
            (lambda (fn &rest args)
              (if (not s20--reverting)
                  (apply fn args)
                (let ((cpu (current-cpu-time)))
                  (prog1 (apply #'s20--timed 'read fn args)
                    (s20--split-add 'read-cpu (s20--cpu-since cpu)))))))

(defun s20--revert (path)
  "Revert the unedited buffer visiting PATH (a real path) if its file is newer."
  (when (string-prefix-p s20-real-root path)
    (let ((buffer (get-file-buffer
                   (concat s20-root (substring path (length s20-real-root))))))
      (when (and buffer (not (verify-visited-file-modtime buffer)))
        (cond
         ((buffer-modified-p buffer) (push (cons buffer 'edited) s20-skipped))
         ((not (file-readable-p (buffer-file-name buffer)))
          (push (cons buffer 'deleted) s20-skipped))
         (t
          (with-current-buffer buffer
            ;; eglot's own revert hooks (didClose, didOpen) stay.
            (let ((after-revert-hook (remq 'diff-hl-after-revert after-revert-hook))
                  (s20--reverting t)
                  (cpu (current-cpu-time)))
              (s20--timed 'revert #'revert-buffer t t t)
              (s20--split-add 'revert-cpu (s20--cpu-since cpu)))
            (if (get-buffer-window buffer t)
                (s20--queue-shown buffer)
              (setq s20--stale t)))))))))

(defvar s20-filter-calls nil
  "D-160: (WALL CPU CLANGD-CPU DEPTH REVERTS) of each filter call, newest first.
CPU is Emacs's (`current-cpu-time'), CLANGD-CPU clangd's over the same span.")
(defvar s20--filter-depth 0 "Filter calls running: above 0 inside one.")

(defun s20--cpu-since (cpu)
  (let ((now (current-cpu-time)))
    (/ (float (- (car now) (car cpu))) (cdr now))))

(defun s20--filter ()
  (let ((pending ""))
    (lambda (_process output)
      (let* ((start (float-time))
             (cpu (current-cpu-time))
             (clangd-cpu (and s20-clangd-pid (s20--clangd-cpu)))
             (depth s20--filter-depth)
             (reverts (length s20-reverted))
             (records (split-string (concat pending output) "\0"))
             (complete (butlast records))
             (paths (make-hash-table :test #'equal)))
        (setq pending (car (last records)))
        (dolist (record complete)
          (let* ((space (cl-position ?\s record :from-end t))
                 (path (substring record 0 space)))
            (cl-incf s20-records)
            (if (string-search "Overflow" (substring record space))
                (cl-incf s20-overflows)
              (when (string-suffix-p "/.s20-probe" path) (setq s20-probe-seen t))
              (puthash path t paths))))
        (let ((s20--in-filter t)
              (s20--filter-depth (1+ depth)))
          (maphash (lambda (path _) (s20--revert path)) paths))
        (when s20-skipped
          (message "s20: skipped %S" s20-skipped)
          (setq s20-skipped nil))
        (let ((spent (- (float-time) start)))
          (push (list spent (s20--cpu-since cpu)
                      (and clangd-cpu (- (s20--clangd-cpu) clangd-cpu))
                      depth (- (length s20-reverted) reverts))
                s20-filter-calls)
          (cl-incf s20-calls)
          (cl-incf s20-filter-total spent)
          (setq s20-filter-max (max s20-filter-max spent)))))))

(defun s20--start-fswatch ()
  (make-process
   :name "s20-fswatch"
   :command (list (s20--env "S20_FSWATCH") "-0" "-r" "-x" "--event-flag-separator=,"
                  "-l" "0.1" "--allow-overflow" "-e" "/\\.git/"
                  (directory-file-name s20-real-root))
   :connection-type 'pipe :noquery t :coding 'utf-8-unix
   :filter (s20--filter)))

;;;; eglot, as the config sets it up

(defvar s20-stalled nil "(START SECONDS BYTES METHOD URI) of sends over 50 ms, newest first.")
(defvar s20--sending nil "Non-nil while a send to clangd runs (T-129).")
(defvar s20-timer-names (make-hash-table :test #'equal) "Timer function -> runs inside sends.")

(defun s20--timer-name (function)
  "A short name for timer FUNCTION: its symbol, or the first symbol a closure calls."
  (cond ((symbolp function) (symbol-name function))
        (t (let ((text (format "%S" function)))
             (if (string-match "(\\(\\(?:jsonrpc\\|eglot\\|flymake\\|s20\\)[-a-z/]*\\)" text)
                 (match-string 1 text)
               (substring text 0 (min 60 (length text))))))))

(defun s20--setup-eglot ()
  "The config's clangd command (`emacs-cpp-presets--clangd-command') and settings.
T-129: S20_CLANGD_FLAGS=stock drops the patched flags; S20_CLANGD_LOG names a file
for clangd's stderr with --log=verbose (through sh's exec, so the pid stays clangd's)."
  (let* ((log (getenv "S20_CLANGD_LOG"))
         (command `(,(s20--env "S20_CLANGD")
                    ,(concat "--compile-commands-dir=" s20-root "build/mac-debug")
                    "--rename-file-limit=0"
                    ,@(pcase (or (getenv "S20_CLANGD_FLAGS") "patched")
                        ("patched" '("--navigation-from-index" "--header-flags-from-index"))
                        ("stock" nil)
                        ("navigation" '("--navigation-from-index"))
                        ("header-flags" '("--header-flags-from-index"))
                        (other (error "s20: S20_CLANGD_FLAGS %s" other)))
                    ,@(and log '("--log=verbose"))
                    ;; D-157: S20_CLANGD_JOBS caps clangd's worker threads.
                    ,@(when-let* ((jobs (getenv "S20_CLANGD_JOBS")))
                        (list (concat "-j=" jobs))))))
    (add-to-list 'eglot-server-programs
                 `((c++-ts-mode c++-mode)
                   . ,(if log
                          `("/bin/sh" "-c" "exec \"$0\" \"$@\" 2>\"$S20_CLANGD_LOG\"" ,@command)
                        command))))
  (setq eglot-events-buffer-config '(:size 0 :format full)
        eglot-autoshutdown t
        eglot-extend-to-xref t)
  (add-to-list 'eglot-ignored-server-capabilities :documentOnTypeFormattingProvider)
  (advice-add 'eglot--signal-textDocument/didOpen :after
              (lambda ()
                (cl-incf s20-did-open)
                (puthash (current-buffer) (float-time) s20-opened)))
  (advice-add 'jsonrpc-connection-receive :before
              (lambda (&rest _) (setq s20-last-message (float-time))))
  ;; D-154: the parts of a revert while clangd reparses.
  (advice-add 'eglot--signal-textDocument/didClose :around
              (lambda (fn &rest args) (apply #'s20--timed 'close fn args)))
  (advice-add 'eglot--signal-textDocument/didOpen :around
              (lambda (fn &rest args) (apply #'s20--timed 'open fn args)))
  ;; T-129: clangd's output read while a send waits on a full pipe
  ;; (`wait_reading_process_output' inside `send_process').
  (advice-add 'jsonrpc--process-filter :around
              (lambda (fn &rest args)
                (apply #'s20--timed (if s20--sending 'output-in-send 'output) fn args)))
  (advice-add 'timer-event-handler :around
              (lambda (fn timer)
                (if s20--sending
                    (let ((function (timer--function timer)))
                      (unless (eq function #'s20--shown-step)
                        (cl-incf (gethash (s20--timer-name function) s20-timer-names 0)))
                      (s20--timed (if (eq function #'s20--shown-step)
                                      'queue-step-in-send 'other-timer-in-send)
                                  fn timer))
                  (funcall fn timer))))
  (advice-add 'eglot-handle-notification :around
              (lambda (fn server method &rest params)
                (if (eq method 'textDocument/publishDiagnostics)
                    (apply #'s20--timed (if s20--sending 'diagnostics-in-send 'diagnostics)
                           fn server method params)
                  (apply fn server method params))))
  (advice-add 'process-send-string :around
              (lambda (fn process string)
                (if (and s20-clangd-pid (processp process)
                         (eql (process-id process) s20-clangd-pid))
                    (let ((start (float-time))
                          (gcs gcs-done)
                          (gc-time gc-elapsed)
                          (s20--sending t))
                      (puthash 'bytes (+ (gethash 'bytes s20-split 0) (string-bytes string))
                               s20-split)
                      (prog1 (s20--timed 'send fn process string)
                        ;; T-129: which write stalled, at clangd's log's local time.
                        (let ((seconds (- (float-time) start)))
                          (when (> seconds 0.05)
                            (push (list start seconds (string-bytes string)
                                        ;; D-158: garbage collections inside the send.
                                        (- gcs-done gcs) (- gc-elapsed gc-time)
                                        (and (string-match "\"method\":\"\\([^\"]+\\)\"" string)
                                             (match-string 1 string))
                                        (and (string-match "\"uri\":\"file://[^\"]*/\\([^/\"]+\\)\"" string)
                                             (match-string 1 string)))
                                  s20-stalled)))))
                  (funcall fn process string))))
  (advice-add 'eglot-handle-notification :before
              (lambda (_server method &rest params)
                (when (eq method 'textDocument/publishDiagnostics)
                  ;; By true name: clangd's URIs may use /private/var for /var.
                  (when-let* ((buffer (find-buffer-visiting
                                       (eglot-uri-to-path (plist-get params :uri)))))
                    (puthash buffer (float-time) s20-diagnosed))))))

(defvar s20-clangd-pid nil)
(defvar s20-cpu-samples nil "(TIME . CLANGD-CPU-SECONDS), newest first, at most 0.25 s apart.")

(defun s20--attributes-cpu (pid)
  (let ((attributes (process-attributes pid)))
    (+ (float-time (alist-get 'utime attributes))
       (float-time (alist-get 'stime attributes)))))

(defvar s20-cpu-scale
  (let* ((cpu (current-cpu-time))
         (attributes (s20--attributes-cpu (emacs-pid)))
         (end (+ (float-time) 0.2))
         (_ (while (< (float-time) end)))
         (seen (- (s20--attributes-cpu (emacs-pid)) attributes))
         (scale (and (> seen 0) (/ (s20--cpu-since cpu) seen))))
    (unless (and scale (< 0.5 scale 100))
      (error "s20: process-attributes CPU scale %S (0.2 s of work seen as %S s)"
             scale seen))
    scale)
  "D-160: `process-attributes' CPU seconds to real ones, measured at load against
`current-cpu-time' over 0.2 s of work.  Emacs 31.1 on Apple silicon reads
proc_pid_rusage's times, Mach ticks of 125/3 ns, as ns (sysdep.c): 41.7 there.")

(defun s20--clangd-cpu ()
  (* s20-cpu-scale (s20--attributes-cpu s20-clangd-pid)))

(defun s20--clangd-idle-p ()
  "Non-nil if clangd used less than 0.1 s of CPU over the last 5 s (owner 2026-11-03)."
  (let ((now (float-time)))
    (when (or (null s20-cpu-samples) (> (- now (caar s20-cpu-samples)) 0.25))
      (push (cons now (s20--clangd-cpu)) s20-cpu-samples))
    (when-let* ((old (cl-find-if (lambda (s) (>= (- now (car s)) 5.0)) s20-cpu-samples)))
      (< (- (cdar s20-cpu-samples) (cdr old)) 0.1))))

(defun s20--settled-p (buffers &optional quiet-only)
  "Non-nil if each of BUFFERS had diagnostics after its didOpen, clangd is quiet 5 s
and, unless QUIET-ONLY, idle (`s20--clangd-idle-p')."
  (or (not s20-eglot)
      (and (cl-every (lambda (b)
                       (> (gethash b s20-diagnosed 0.0) (gethash b s20-opened 1.0e20)))
                     buffers)
           (> (- (float-time) s20-last-message) 5.0)
           (or quiet-only (s20--clangd-idle-p)))))

(defun s20--symbols-check (buffer)
  "Count BUFFER's document symbols whose name is on the buffer line clangd gives.
Return (ON-LINE TOTAL OFFSET-19 SECONDS)."
  (with-current-buffer buffer
    (let* ((on 0) (total 0) (offset 0)
           (start (float-time))
           (symbols (jsonrpc-request (eglot-current-server) :textDocument/documentSymbol
                                     (list :textDocument (eglot--TextDocumentIdentifier))
                                     :timeout 120))
           (seconds (- (float-time) start)))
      (cl-labels
          ((line-text (n)
             (save-excursion
               (goto-char (point-min))
               (if (zerop (forward-line n))
                   (buffer-substring-no-properties (line-beginning-position)
                                                   (line-end-position))
                 "")))
           (walk (symbol)
             (let* ((name (plist-get symbol :name))
                    (word (and (string-match "\\`[A-Za-z_][A-Za-z0-9_]*" name)
                               (match-string 0 name)))
                    (line (plist-get (plist-get (plist-get symbol :selectionRange) :start)
                                     :line)))
               (when (and word line)
                 (cl-incf total)
                 (cond ((string-search word (line-text line)) (cl-incf on))
                       ((or (string-search word (line-text (+ line 19)))
                            (string-search word (line-text (- line 19))))
                        (cl-incf offset))))
               (mapc #'walk (plist-get symbol :children)))))
        (mapc #'walk symbols))
      (list on total offset seconds))))

;;;; The run

(defun s20--median (xs)
  (if xs (nth (/ (length xs) 2) (sort (copy-sequence xs) #'<)) 0.0))

(defun s20--names-branch-p (buffer branch)
  (let ((mode (buffer-local-value 'vc-mode buffer)))
    (and mode (string-match-p (concat "[-:!?@]" (regexp-quote branch) "\\'")
                              (substring-no-properties mode)))))

(defun s20--current-p (buffer shifted)
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (eq (and (looking-at-p "// s20 shift 0$") t) shifted))))

(defun s20--start-sample ()
  "D-158: start macOS `sample' on clangd (3 s, 1 ms apart) into S20_SAMPLE.
D-160: S20_SAMPLE_EMACS samples this Emacs instead.
Return the process once `sample' has attached, or nil without either."
  (when-let* ((file (or (getenv "S20_SAMPLE") (getenv "S20_SAMPLE_EMACS"))))
    (let ((process (make-process
                    :name "s20-sample" :buffer (generate-new-buffer " *s20-sample*")
                    :command (list "/usr/bin/sample"
                                   (number-to-string (if (getenv "S20_SAMPLE")
                                                         s20-clangd-pid
                                                       (emacs-pid)))
                                   "3" "1" "-mayDie" "-file" file)
                    :noquery t)))
      (process-put process 'started (float-time))
      (unless (s20--wait (lambda ()
                           (with-current-buffer (process-buffer process)
                             (string-search "Sampling process" (buffer-string))))
                         10)
        (error "s20: sample did not start: %s"
               (with-current-buffer (process-buffer process) (buffer-string))))
      process)))

(defun s20--checkout (branch buffers shown shifted &optional label settle)
  "Check out BRANCH; wait for BUFFERS to be current (SHIFTED or not) and settled.
LABEL marks a contrast checkout (no symbol check).  SETTLE nil waits until clangd
is quiet and idle, `quiet' until it is quiet only, a number of seconds until that
long after `git' (D-157's gap)."
  (setq s20-reverted nil s20-stall 0.0 s20-shown-steps nil s20-filter-max 0.0
        s20-cpu-samples nil s20-stalled nil s20-steps-deferred 0 s20-filter-calls nil)
  (clrhash s20-timer-names)
  (clrhash s20-split)
  (let* ((records s20-records) (calls s20-calls) (total s20-filter-total)
         (opened s20-did-open)
         (sampler (and (equal label "contrast back-to-back 2") (s20--start-sample)))
         (gcs gcs-done) (gc-time gc-elapsed)
         (t0 (float-time))
         (_ (s20--git "checkout" "-q" branch))
         (t1 (float-time))
         (current (s20--wait (lambda ()
                               (cl-every (lambda (b) (s20--current-p b shifted)) buffers))
                             15))
         (t2 (float-time))
         (settled (s20--wait (lambda ()
                               (and (null s20-shown-timer) (null s20-shown-queue)
                                    (if (numberp settle)
                                        (>= (float-time) (+ t1 settle))
                                      (s20--settled-p buffers (eq settle 'quiet)))))
                             300))
         (t3 (float-time)))
    (s20--emit "%scheckout %s: git %.2f s; all %d buffers current: %s, %.2f s after git; settled%s: %s, %.1f s after git; Emacs blocked at most %.3f s"
               (if label (concat label ", ") "") branch (- t1 t0) (length buffers)
               (if current "yes" "NO") (- t2 t1)
               (pcase settle
                 ('quiet " (quiet only)")
                 ((pred numberp) (format " (gap %.1f s, not settled)" settle))
                 (_ ""))
               (if settled "yes" "NO") (- t3 t1) s20-stall)
    (when s20-pipetrace
      (s20--emit "  pipetrace window (D-160): git %.6f, settled %.6f" t0 t3))
    (s20--emit "  reverts %d; didOpen %d; diagnostics after didOpen in %d of %d; filter %d calls, %d records, %.1f ms total, longest %.1f ms"
               (length s20-reverted) (- s20-did-open opened)
               (cl-count-if (lambda (b) (> (gethash b s20-diagnosed 0.0)
                                           (gethash b s20-opened 1.0e20)))
                            buffers)
               (length buffers) (- s20-calls calls) (- s20-records records)
               (* 1000 (- s20-filter-total total)) (* 1000 s20-filter-max))
    (s20--emit "  filter calls (D-160): %s"
               (mapconcat (pcase-lambda (`(,wall ,cpu ,clangd ,depth ,reverts))
                            (format "wall %.1f ms, Emacs CPU %.1f ms, clangd CPU %s, depth %d, %d reverts"
                                    (* 1000 wall) (* 1000 cpu)
                                    (if clangd
                                        (format "%.0f ms (%.1f cores)" (* 1000 clangd)
                                                (/ clangd (max wall 1e-6)))
                                      "-")
                                    depth reverts))
                          (reverse s20-filter-calls) "; "))
    (let ((part (lambda (key)
                  (let ((entry (gethash key s20-split (list 0.0 0 0.0))))
                    (format "%d, %.1f ms total, max %.1f ms" (nth 1 entry)
                            (* 1000 (nth 0 entry)) (* 1000 (nth 2 entry))))))
          (total (lambda (key) (* 1000 (car (gethash key s20-split (list 0.0)))))))
      (s20--emit "  split (D-154): revert-buffer %s; didClose %s; didOpen %s; sends to clangd %s, %d KB; revert without didClose and didOpen %.1f ms"
                 (funcall part 'revert) (funcall part 'close) (funcall part 'open)
                 (funcall part 'send) (/ (gethash 'bytes s20-split 0) 1024)
                 (- (funcall total 'revert) (funcall total 'close) (funcall total 'open)))
      (s20--emit "  reverts (D-160): Emacs CPU %.1f ms of %.1f ms; their file reads (insert-file-contents) %s, Emacs CPU %.1f ms"
                 (funcall total 'revert-cpu) (funcall total 'revert) (funcall part 'read)
                 (funcall total 'read-cpu))
      (s20--emit "  clangd's output (T-129): read inside sends %s; elsewhere %s; publishDiagnostics handled inside sends %s; elsewhere %s"
                 (funcall part 'output-in-send) (funcall part 'output)
                 (funcall part 'diagnostics-in-send) (funcall part 'diagnostics))
      (s20--emit "  timers inside sends (T-129): reverter's queue step %s; others %s %S"
                 (funcall part 'queue-step-in-send) (funcall part 'other-timer-in-send)
                 (let (names) (maphash (lambda (k v) (push (cons k v) names)) s20-timer-names)
                      names)))
    (s20--emit "  garbage collection (D-158): %d GCs, %.0f ms, from git to settled; gc-cons-threshold %d; queue steps deferred (D-156 (e)): %s"
               (- gcs-done gcs) (* 1000 (- gc-elapsed gc-time)) gc-cons-threshold
               (if s20-step-waits s20-steps-deferred "off"))
    (dolist (s (reverse s20-stalled))
      (s20--emit "  stalled send (T-129): %s +%.0f ms, %d bytes, %d GCs %.0f ms, %s %s"
                 (format-time-string "%H:%M:%S.%3N" (nth 0 s)) (* 1000 (nth 1 s))
                 (nth 2 s) (nth 3 s) (* 1000 (nth 4 s)) (nth 5 s) (nth 6 s)))
    (s20--emit "  shown buffers: queue done %.2f s after git; %d steps, median %.3f s, longest %.3f s; VC names %s: %d of %d"
               (- s20-shown-last t1) (length s20-shown-steps) (s20--median s20-shown-steps)
               (apply #'max 0.0 s20-shown-steps) branch
               (cl-count-if (lambda (b) (s20--names-branch-p b branch)) shown)
               (length shown))
    (let* ((hidden (cl-find-if (lambda (b) (buffer-local-value 's20--stale b)) buffers))
           (window (selected-window))
           (before (window-buffer window)))
      (when hidden
        (let ((start (float-time)))
          (set-window-buffer window hidden)
          ;; Batch runs no window change functions (2026-11-03); call the handler.
          (s20--on-show (selected-frame))
          (s20--emit "  hidden: showing one took %.3f s; VC names %s: %s"
                     (- (float-time) start) branch
                     (if (s20--names-branch-p hidden branch) "yes" "NO")))
        (set-window-buffer window before)))
    (when sampler
      (s20--wait (lambda () (not (process-live-p sampler))) 60)
      (s20--emit "  sample (D-158): %s, started %.2f s before git; %s"
                 (or (getenv "S20_SAMPLE") (getenv "S20_SAMPLE_EMACS"))
                 (- t0 (process-get sampler 'started))
                 (string-trim (with-current-buffer (process-buffer sampler)
                                (buffer-string)))))
    (when (and s20-eglot (not label))
      (dolist (b shown)
        (pcase-let ((`(,on ,all ,offset ,seconds) (s20--symbols-check b)))
          (s20--emit "  symbols %s: %d of %d on their lines, %d offset by 19 (answered in %.1f s)"
                     (buffer-name b) on all offset seconds))))))

(defun s20-main ()
  (unless (treesit-language-available-p 'cpp)
    (error "s20: no tree-sitter C++ grammar"))
  (add-to-list 'auto-mode-alist '("\\.\\(cc\\|h\\)\\'" . c++-ts-mode))
  (add-to-list 'load-path (s20--env "S20_DIFF_HL"))
  (require 'diff-hl)
  (add-hook 'find-file-hook #'turn-on-diff-hl-mode 90)
  (add-hook 'window-buffer-change-functions #'s20--on-show)
  (add-hook 'after-revert-hook
            (lambda () (push (cons (current-buffer) (float-time)) s20-reverted)))
  (when s20-eglot (s20--setup-eglot))
  (s20--git "checkout" "-q" "s20-base")
  (let* ((names (split-string (s20--git "ls-files" "src" "include") "\n" t))
         (buffers (mapcar (lambda (n) (find-file-noselect (concat s20-root n))) names))
         (headers (cl-remove-if-not (lambda (b) (string-suffix-p ".h" (buffer-name b)))
                                    buffers))
         (shown (seq-take headers 3))
         process ready)
    (delete-other-windows)
    (let* ((w1 (selected-window)) (w2 (split-window w1)) (w3 (split-window w2)))
      (cl-mapc #'set-window-buffer (list w1 w2 w3) shown))
    (s20--emit "S20 eglot-share %s, %s %s, %s" s20-mode system-type
               (car (split-string (emacs-version) "\n")) (format-time-string "%FT%TZ" nil t))
    (s20--emit "buffers: %d (%d headers), %S major mode; %d shown in windows"
               (length buffers) (length headers)
               (buffer-local-value 'major-mode (car buffers)) (length shown))
    (s20--emit "process-attributes CPU scale (D-160): %.1f" s20-cpu-scale)
    (when s20-eglot
      (let ((t0 (float-time)))
        (with-current-buffer (car buffers)
          (apply #'eglot--connect (eglot--guess-contact)))
        (s20--wait (lambda () (cl-every (lambda (b) (gethash b s20-opened)) buffers)) 60)
        (let* ((server (with-current-buffer (car buffers) (eglot-current-server)))
               (_ (setq s20-clangd-pid (process-id (jsonrpc--process server))))
               (settled (s20--wait (lambda () (s20--settled-p buffers)) 600)))
          (s20--emit "eglot: %d of %d buffers managed; server %S; settled: %s after %.1f s"
                     (cl-count-if (lambda (b) (buffer-local-value 'eglot--managed-mode b))
                                  buffers)
                     (length buffers)
                     (and server (process-command (jsonrpc--process server)))
                     (if settled "yes" "NO") (- (float-time) t0)))))
    (setq process (s20--start-fswatch))
    (let ((t0 (float-time)) (probe (concat s20-root ".s20-probe")))
      (setq ready
            (s20--wait (lambda ()
                         (write-region (format "%f" (float-time)) nil probe nil 'silent)
                         (s20--wait (lambda () s20-probe-seen) 0.5))
                       30))
      (delete-file probe)
      (s20--emit "ready: %s after %.2f s" (if ready "yes" "NO") (- (float-time) t0)))
    (s20--wait #'ignore 2)
    (s20--checkout "s20-shift" buffers shown t)
    (s20--checkout "s20-base" buffers shown nil)
    ;; Contrast (owner 2026-11-03): the second checkout during clangd's reparse.
    (s20--checkout "s20-shift" buffers shown t "contrast back-to-back 1"
                   ;; D-157: S20_GAP seconds after the first checkout's git.
                   (if-let* ((gap (getenv "S20_GAP"))) (string-to-number gap) 'quiet))
    (s20--checkout "s20-base" buffers shown nil "contrast back-to-back 2")
    (s20--emit "filter: overflows %d" s20-overflows)
    (let ((pid (process-id process)))
      (delete-process process)
      (s20--wait #'ignore 1)
      (s20--emit "shutdown: fswatch pid %d %s" pid
                 (if (eql 0 (call-process "ps" nil nil nil "-p" (number-to-string pid)))
                     "STILL RUNNING" "gone")))
    (when s20-eglot
      (with-current-buffer (car buffers) (eglot-shutdown (eglot-current-server))))))

(s20-main)

;;; eglot-share.el ends here
