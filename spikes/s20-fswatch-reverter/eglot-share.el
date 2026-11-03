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

(defun s20--shown-step ()
  "Refresh the oldest queued buffer; arm the timer again while any is left."
  (setq s20-shown-timer nil)
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
            (let ((after-revert-hook (remq 'diff-hl-after-revert after-revert-hook)))
              (s20--timed 'revert #'revert-buffer t t t))
            (if (get-buffer-window buffer t)
                (s20--queue-shown buffer)
              (setq s20--stale t)))))))))

(defun s20--filter ()
  (let ((pending ""))
    (lambda (_process output)
      (let* ((start (float-time))
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
        (maphash (lambda (path _) (s20--revert path)) paths)
        (when s20-skipped
          (message "s20: skipped %S" s20-skipped)
          (setq s20-skipped nil))
        (let ((spent (- (float-time) start)))
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
                    ,@(and log '("--log=verbose")))))
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
                          (s20--sending t))
                      (puthash 'bytes (+ (gethash 'bytes s20-split 0) (string-bytes string))
                               s20-split)
                      (prog1 (s20--timed 'send fn process string)
                        ;; T-129: which write stalled, at clangd's log's local time.
                        (let ((seconds (- (float-time) start)))
                          (when (> seconds 0.05)
                            (push (list start seconds (string-bytes string)
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

(defun s20--clangd-cpu ()
  (let ((attributes (process-attributes s20-clangd-pid)))
    (+ (float-time (alist-get 'utime attributes))
       (float-time (alist-get 'stime attributes)))))

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

(defun s20--checkout (branch buffers shown shifted &optional label quiet-only)
  "Check out BRANCH; wait for BUFFERS to be current (SHIFTED or not) and settled.
LABEL marks a contrast checkout (no symbol check); QUIET-ONLY as `s20--settled-p'."
  (setq s20-reverted nil s20-stall 0.0 s20-shown-steps nil s20-filter-max 0.0
        s20-cpu-samples nil s20-stalled nil)
  (clrhash s20-timer-names)
  (clrhash s20-split)
  (let* ((records s20-records) (calls s20-calls) (total s20-filter-total)
         (opened s20-did-open)
         (t0 (float-time))
         (_ (s20--git "checkout" "-q" branch))
         (t1 (float-time))
         (current (s20--wait (lambda ()
                               (cl-every (lambda (b) (s20--current-p b shifted)) buffers))
                             15))
         (t2 (float-time))
         (settled (s20--wait (lambda ()
                               (and (null s20-shown-timer) (null s20-shown-queue)
                                    (s20--settled-p buffers quiet-only)))
                             300))
         (t3 (float-time)))
    (s20--emit "%scheckout %s: git %.2f s; all %d buffers current: %s, %.2f s after git; settled%s: %s, %.1f s after git; Emacs blocked at most %.3f s"
               (if label (concat label ", ") "") branch (- t1 t0) (length buffers)
               (if current "yes" "NO") (- t2 t1) (if quiet-only " (quiet only)" "")
               (if settled "yes" "NO") (- t3 t1) s20-stall)
    (s20--emit "  reverts %d; didOpen %d; diagnostics after didOpen in %d of %d; filter %d calls, %d records, %.1f ms total, longest %.1f ms"
               (length s20-reverted) (- s20-did-open opened)
               (cl-count-if (lambda (b) (> (gethash b s20-diagnosed 0.0)
                                           (gethash b s20-opened 1.0e20)))
                            buffers)
               (length buffers) (- s20-calls calls) (- s20-records records)
               (* 1000 (- s20-filter-total total)) (* 1000 s20-filter-max))
    (let ((part (lambda (key)
                  (let ((entry (gethash key s20-split (list 0.0 0 0.0))))
                    (format "%d, %.1f ms total, max %.1f ms" (nth 1 entry)
                            (* 1000 (nth 0 entry)) (* 1000 (nth 2 entry))))))
          (total (lambda (key) (* 1000 (car (gethash key s20-split (list 0.0)))))))
      (s20--emit "  split (D-154): revert-buffer %s; didClose %s; didOpen %s; sends to clangd %s, %d KB; revert without didClose and didOpen %.1f ms"
                 (funcall part 'revert) (funcall part 'close) (funcall part 'open)
                 (funcall part 'send) (/ (gethash 'bytes s20-split 0) 1024)
                 (- (funcall total 'revert) (funcall total 'close) (funcall total 'open)))
      (s20--emit "  clangd's output (T-129): read inside sends %s; elsewhere %s; publishDiagnostics handled inside sends %s; elsewhere %s"
                 (funcall part 'output-in-send) (funcall part 'output)
                 (funcall part 'diagnostics-in-send) (funcall part 'diagnostics))
      (s20--emit "  timers inside sends (T-129): reverter's queue step %s; others %s %S"
                 (funcall part 'queue-step-in-send) (funcall part 'other-timer-in-send)
                 (let (names) (maphash (lambda (k v) (push (cons k v) names)) s20-timer-names)
                      names)))
    (dolist (s (reverse s20-stalled))
      (s20--emit "  stalled send (T-129): %s +%.0f ms, %d bytes, %s %s"
                 (format-time-string "%H:%M:%S.%3N" (nth 0 s)) (* 1000 (nth 1 s))
                 (nth 2 s) (nth 3 s) (nth 4 s)))
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
    (s20--checkout "s20-shift" buffers shown t "contrast back-to-back 1" t)
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
