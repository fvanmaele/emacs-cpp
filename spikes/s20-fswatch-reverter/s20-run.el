;;; s20-run.el --- S20: one measured run  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-147, T-128).  Batch Emacs reads process output
;; and runs timers inside `accept-process-output', which is all a fswatch reverter
;; and polling need (file-notify events, which batch does not deliver, are not used).
;;   S20_ROOT=... S20_MODE=fswatch|fswatch-queued|fswatch-novc|poll S20_FSWATCH=... S20_OUT=... \
;;     emacs -Q --batch -l s20-run.el
;; fswatch: one patched fswatch on the root; its filter reverts each unedited buffer
;; visiting a reported path whose file is newer than the buffer, then refreshes its
;; VC state as `auto-revert-handler' does.  fswatch-queued: the VC states from a
;; queue, one buffer per 0.05 s timer step.  fswatch-novc: no VC refresh.
;; poll: D-147's Mac setting, `global-auto-revert-mode' polling every 5 s.
;; fswatch-shown (D-153) and fswatch-diffhl load diff-hl (S20_DIFF_HL) as the config
;; does, skip unreadable files (D-152) and message the buffers they skip (D-151).
;; fswatch-shown holds diff-hl's revert hook back and refreshes VC state and diff-hl
;; for shown buffers from a queue, one per step of a one-shot 0.05 s timer armed
;; again after each step, and for other buffers when a window shows them.
;; fswatch-chunked (D-167): fswatch-shown with the reverts out of the filter: it
;; queues the buffers, shown ones first, and a one-shot 0.01 s timer reverts until
;; S20_BUDGET seconds (default 0.05) are spent, armed again while any is left.
;; fswatch-diffhl: no VC refresh, diff-hl's revert hook live.
;; shipped (D-162 (d)): the config's lisp/emacs-cpp-reverter.el (T-128) with its
;; program S20_FSWATCH and projectile from lib/, counted by advice; it starts its own
;; fswatch when the files are visited and stops it when their buffers are killed.
;; Opens every file branch b (c for the diff-hl modes: b plus one deleted file)
;; changes plus 10 it does not, edits one changed file's buffer, then checks out b
;; (c) and a again, each time waiting up to 15 s for every unedited changed buffer to
;; show the file's first line.  Appends one block to S20_OUT.

(require 'cl-lib)
(require 'subr-x)

(defun s20--env (name)
  (or (getenv name) (error "s20: %s is not set" name)))

(defvar s20-here (file-name-directory load-file-name))
(defvar s20-root (file-name-as-directory (expand-file-name (s20--env "S20_ROOT"))))
(defvar s20-real-root (file-name-as-directory (file-truename s20-root)))
(defvar s20-mode (s20--env "S20_MODE"))
(defvar s20-reverted nil "(BUFFER . TIME) of each revert, newest first.")
(defvar s20-calls 0)
(defvar s20-records 0)
(defvar s20-overflows 0)
(defvar s20-filter-total 0.0)
(defvar s20-filter-max 0.0)
(defvar s20-probe-seen nil)
(defvar s20-stall 0.0 "Longest single wait step of `s20--wait': Emacs blocked.")
(defvar s20-diff-hl (member s20-mode '("fswatch-shown" "fswatch-chunked" "fswatch-diffhl" "shipped")))
(defvar s20-chunked (equal s20-mode "fswatch-chunked"))
(defvar s20-shown-like (member s20-mode '("fswatch-shown" "fswatch-chunked")))
(defvar s20-shipped (equal s20-mode "shipped"))
(defvar s20-skipped nil "(BUFFER . WHY) the current filter call did not revert.")
(defvar s20-messages nil "Texts of the filter's messages, newest first.")
(defvar s20-filter-errors nil)

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

;;;; The reverter (fswatch mode)

(defun s20--path-buffer (path)
  "The buffer visiting PATH (a real path) under the root, or nil."
  (and (string-prefix-p s20-real-root path)
       (get-file-buffer (concat s20-root (substring path (length s20-real-root))))))

(defun s20--revert (path)
  "Revert the unedited buffer visiting PATH (a real path) if its file is newer."
  (s20--revert-buffer (s20--path-buffer path)))

(defun s20--revert-buffer (buffer)
  "Revert BUFFER if it is live, unedited and its file is newer."
  (when (and buffer (buffer-live-p buffer) (not (verify-visited-file-modtime buffer)))
    (cond
     ((buffer-modified-p buffer) (push (cons buffer 'edited) s20-skipped))
     ;; D-152: `revert-buffer' signals for a missing file.
     ((and s20-diff-hl (not (file-readable-p (buffer-file-name buffer))))
      (push (cons buffer 'deleted) s20-skipped))
     (t
      (with-current-buffer buffer
        (if s20-shown-like
            (let ((after-revert-hook (remq 'diff-hl-after-revert after-revert-hook)))
              (revert-buffer t t t))
          (revert-buffer t t t))
        ;; As `auto-revert-handler': VC's state (mode line branch) per buffer,
        ;; one git process each.
        (pcase s20-mode
          ("fswatch" (vc-refresh-state))
          ("fswatch-queued" (s20--queue-vc buffer))
          ((or "fswatch-shown" "fswatch-chunked")
           (if (get-buffer-window buffer t)
               (s20--queue-shown buffer)
             (setq s20--stale t)))))))))

(defun s20--message-skipped ()
  "One message naming the buffers this filter call skipped (D-151 (2b), D-152)."
  (when (and s20-diff-hl s20-skipped)
    (let* ((names (lambda (why)
                    (mapcar (lambda (s) (buffer-name (car s)))
                            (cl-remove-if-not (lambda (s) (eq (cdr s) why)) s20-skipped))))
           (edited (funcall names 'edited))
           (deleted (funcall names 'deleted))
           (text (string-join
                  (delq nil
                        (list (and edited
                                   (format "%d %s with unsaved edits changed on disk: %s"
                                           (length edited)
                                           (if (cdr edited) "buffers" "buffer")
                                           (string-join edited ", ")))
                              (and deleted
                                   (format "%d %s deleted on disk: %s"
                                           (length deleted)
                                           (if (cdr deleted) "buffers' files" "buffer's file")
                                           (string-join deleted ", ")))))
                  "; ")))
      (push text s20-messages)
      (message "%s" text)))
  (setq s20-skipped nil))

;;;; fswatch-shown: VC state and diff-hl for shown buffers (D-153)

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

(defvar s20-vc-queue nil "Buffers whose VC state waits for a refresh, oldest last.")
(defvar s20-vc-timer nil)
(defvar s20-vc-last 0.0 "Time of the last queued VC refresh.")

(defun s20--queue-vc (buffer)
  "Refresh BUFFER's VC state later, one buffer per timer step."
  (unless (memq buffer s20-vc-queue) (push buffer s20-vc-queue))
  (unless s20-vc-timer
    (setq s20-vc-timer
          (run-with-timer
           0.05 0.05
           (lambda ()
             (if-let* ((next (car (last s20-vc-queue))))
                 (progn
                   (setq s20-vc-queue (butlast s20-vc-queue))
                   (when (buffer-live-p next)
                     (with-current-buffer next (vc-refresh-state)))
                   (setq s20-vc-last (float-time)))
               (cancel-timer s20-vc-timer)
               (setq s20-vc-timer nil)))))))

;;;; fswatch-chunked: reverts from a queue, a time budget per step (D-167)

(defvar s20-budget (string-to-number (or (getenv "S20_BUDGET") "0.05"))
  "Seconds of reverting per revert step.")
(defvar s20-revert-queue nil "Buffers waiting for a revert, next first.")
(defvar s20-revert-timer nil)
(defvar s20-revert-steps nil "(DURATION . REVERTS) of each revert step, newest first.")

(defun s20--enqueue (buffer)
  "Queue BUFFER for a revert; a shown buffer goes to the front."
  (when (and buffer (not (memq buffer s20-revert-queue)))
    (if (get-buffer-window buffer t)
        (push buffer s20-revert-queue)
      (setq s20-revert-queue (nconc s20-revert-queue (list buffer)))))
  (unless s20-revert-timer
    (setq s20-revert-timer (run-with-timer 0.01 nil #'s20--revert-step))))

(defun s20--revert-step ()
  "Revert queued buffers until `s20-budget' is spent; arm again while any is left."
  (setq s20-revert-timer nil)
  (let ((start (float-time)) (n 0))
    (while (and s20-revert-queue (< (- (float-time) start) s20-budget))
      (s20--revert-buffer (pop s20-revert-queue))
      (cl-incf n))
    (push (cons (- (float-time) start) n) s20-revert-steps))
  (if s20-revert-queue
      (setq s20-revert-timer (run-with-timer 0.01 nil #'s20--revert-step))
    (s20--message-skipped)))

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
        (condition-case err
            (maphash (lambda (path _)
                       (if s20-chunked
                           (s20--enqueue (s20--path-buffer path))
                         (s20--revert path)))
                     paths)
          ;; Recorded for the output, then signalled again as Emacs would.
          (error (push err s20-filter-errors) (signal (car err) (cdr err))))
        (unless s20-chunked (s20--message-skipped))
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

;;;; shipped: the config's reverter (D-162 (d))

(defvar emacs-cpp-default-fswatch-program)
(defvar emacs-cpp-reverter--timer)
(defvar emacs-cpp-reverter--queue)
(declare-function emacs-cpp-reverter-processes "emacs-cpp-reverter" ())
(declare-function emacs-cpp-reverter--on-show "emacs-cpp-reverter" (frame))

(defun s20--load-shipped ()
  "Load lisp/emacs-cpp-reverter.el (T-128) with S20_FSWATCH and count for it.
A filter call's records are counted where they enter `emacs-cpp-reverter--handle',
its messages where `emacs-cpp-reverter--message' returns them, the queue's steps
where `emacs-cpp-reverter--refresh' runs; the module itself carries no counters."
  (add-to-list 'load-path (expand-file-name "../../lib/projectile" s20-here))
  (setq emacs-cpp-default-fswatch-program (s20--env "S20_FSWATCH"))
  (load (expand-file-name "../../lisp/emacs-cpp-reverter.el" s20-here) nil t)
  (advice-add 'emacs-cpp-reverter--handle :around
              (lambda (fn root real-root records overflowed)
                (let ((start (float-time)))
                  (dolist (record records)
                    (cl-incf s20-records)
                    (when (string-search "/.s20-probe " record) (setq s20-probe-seen t)))
                  (when overflowed (cl-incf s20-overflows))
                  (prog1 (funcall fn root real-root records overflowed)
                    (let ((spent (- (float-time) start)))
                      (cl-incf s20-calls)
                      (cl-incf s20-filter-total spent)
                      (setq s20-filter-max (max s20-filter-max spent)))))))
  (advice-add 'emacs-cpp-reverter--message :filter-return
              (lambda (text) (when text (push text s20-messages)) text))
  (advice-add 'emacs-cpp-reverter--refresh :around
              (lambda (fn buffer)
                (let ((start (float-time)))
                  (prog1 (funcall fn buffer)
                    (setq s20-shown-last (float-time))
                    (push (- s20-shown-last start) s20-shown-steps))))))

(defun s20--descriptors (pid)
  "Open descriptors of PID: /proc on Linux, lsof elsewhere."
  (if (file-directory-p (format "/proc/%d/fd" pid))
      (length (directory-files (format "/proc/%d/fd" pid) nil "\\`[0-9]"))
    (with-temp-buffer
      (call-process "lsof" nil t nil "-p" (number-to-string pid))
      (max 0 (1- (count-lines (point-min) (point-max)))))))

(defun s20--rss-mb (pid)
  (with-temp-buffer
    (call-process "ps" nil t nil "-o" "rss=" "-p" (number-to-string pid))
    (/ (string-to-number (string-trim (buffer-string))) 1024.0)))

;;;; The run

(defun s20--median (xs)
  (if xs (nth (/ (length xs) 2) (sort (copy-sequence xs) #'<)) 0.0))

(defun s20--names-branch-p (buffer branch)
  "Non-nil if BUFFER's mode line VC string names BRANCH (\" Git-c\")."
  (let ((mode (buffer-local-value 'vc-mode buffer)))
    (and mode (string-match-p (concat "[-:!?@]" (regexp-quote branch) "\\'")
                              (substring-no-properties mode)))))

(defvar s20-diff-hl-calls (make-hash-table :test #'eq) "BUFFER -> `diff-hl-update' calls.")

(defun s20--shown-report (branch t1 shown)
  "Emit fswatch-shown's queue, then show one hidden reverted buffer and emit."
  (s20--wait (lambda ()
               (if s20-shipped
                   (and (null emacs-cpp-reverter--timer) (null emacs-cpp-reverter--queue))
                 (and (null s20-shown-timer) (null s20-shown-queue)
                      (null s20-revert-timer) (null s20-revert-queue))))
             30)
  (s20--emit "  shown buffers: queue done %.2f s after git; %d steps, median %.3f s, longest %.3f s; VC names %s: %d of %d; diff-hl updates %s; Emacs blocked at most %.2f s"
             (- s20-shown-last t1) (length s20-shown-steps) (s20--median s20-shown-steps)
             (apply #'max 0.0 s20-shown-steps) branch
             (cl-count-if (lambda (b) (s20--names-branch-p b branch)) shown) (length shown)
             (mapcar (lambda (b) (gethash b s20-diff-hl-calls 0)) shown) s20-stall)
  (let* ((stale-var (if s20-shipped 'emacs-cpp-reverter--stale 's20--stale))
         (stale (cl-remove-if-not (lambda (b) (buffer-local-value stale-var b))
                                  (buffer-list)))
         (hidden (car stale))
         (window (selected-window))
         (before (window-buffer window)))
    (if (not hidden)
        (s20--emit "  hidden: no stale buffer")
      (let ((start (float-time)))
        (set-window-buffer window hidden)
        ;; Batch runs no window change functions (2026-11-03); call the handler.
        (if s20-shipped
            (emacs-cpp-reverter--on-show (selected-frame))
          (s20--on-show (selected-frame)))
        (s20--emit "  hidden: %d stale; showing one took %.3f s; VC names %s: %s; diff-hl updates %d"
                   (length stale) (- (float-time) start) branch
                   (if (s20--names-branch-p hidden branch) "yes" "NO")
                   (gethash hidden s20-diff-hl-calls 0)))
      (set-window-buffer window before))))

(defun s20--checkout (branch changed edited marker &optional deleted shown)
  "Check out BRANCH; wait for CHANGED's unedited buffers to show MARKER; emit.
DELETED is the buffer whose file BRANCH deletes, SHOWN the buffers in windows."
  (setq s20-reverted nil s20-stall 0.0 s20-messages nil s20-shown-steps nil
        s20-revert-steps nil)
  (clrhash s20-diff-hl-calls)
  (let* ((records s20-records) (calls s20-calls) (total s20-filter-total)
         (t0 (float-time))
         (_ (s20--git "checkout" "-q" branch))
         (t1 (float-time))
         (waiting (cl-remove deleted (cl-remove edited changed)))
         (done (s20--wait
                (lambda ()
                  (cl-every (lambda (b)
                              (with-current-buffer b
                                (save-excursion
                                  (goto-char (point-min))
                                  (looking-at-p (regexp-quote marker)))))
                            waiting))
                15))
         (t2 (float-time))
         (unchanged-reverted (cl-count-if (lambda (r) (not (memq (car r) changed)))
                                          s20-reverted)))
    (s20--emit "checkout %s: git %.2f s; all %d unedited buffers current: %s, %.2f s after git; Emacs blocked at most %.2f s"
               branch (- t1 t0) (length waiting) (if done "yes" "NO") (- t2 t1) s20-stall)
    (s20--emit "  reverts %d, first %.2f s, last %.2f s after git (unchanged files' buffers: %d); edited buffer kept: %s"
               (length s20-reverted)
               (if s20-reverted (- (cdar (last s20-reverted)) t1) -1)
               (if s20-reverted (- (cdar s20-reverted) t1) -1)
               unchanged-reverted
               (with-current-buffer edited
                 (if (and (buffer-modified-p)
                          (string-suffix-p "// mine\n" (buffer-string)))
                     "yes" "NO")))
    (when (equal s20-mode "fswatch-queued")
      (s20--wait (lambda () (null s20-vc-timer)) 30)
      (s20--emit "  VC states all refreshed %.2f s after git; Emacs blocked at most %.2f s"
                 (- s20-vc-last t1) s20-stall))
    (when (member s20-mode '("fswatch-shown" "fswatch-chunked" "shipped"))
      (s20--shown-report branch t1 shown))
    (when s20-chunked
      (s20--emit "  revert queue: %d steps, reverts per step %s, longest step %.1f ms, budget %.0f ms"
                 (length s20-revert-steps) (mapcar #'cdr (reverse s20-revert-steps))
                 (* 1000 (apply #'max 0.0 (mapcar #'car s20-revert-steps)))
                 (* 1000 s20-budget)))
    (when s20-diff-hl
      (when deleted
        (s20--emit "  deleted file's buffer: live %s, reverted %s, file exists %s"
                   (if (buffer-live-p deleted) "yes" "NO")
                   (if (assq deleted s20-reverted) "yes" "no")
                   (if (file-exists-p (buffer-file-name deleted)) "yes" "no")))
      (s20--emit "  messages: %S; filter errors: %S" (reverse s20-messages)
                 s20-filter-errors))
    (when (or s20-shipped (string-prefix-p "fswatch" s20-mode))
      (s20--emit "  filter: %d calls, %d records, %.1f ms total"
                 (- s20-calls calls) (- s20-records records)
                 (* 1000 (- s20-filter-total total))))))

(defun s20-main ()
  (add-hook 'after-revert-hook
            (lambda () (push (cons (current-buffer) (float-time)) s20-reverted)))
  (when s20-diff-hl
    ;; As `lisp/init-git.el': diff-hl per visited file, after `vc-refresh-state'.
    (add-to-list 'load-path (s20--env "S20_DIFF_HL"))
    (require 'diff-hl)
    (add-hook 'find-file-hook #'turn-on-diff-hl-mode 90)
    (advice-add 'diff-hl-update :before
                (lambda () (cl-incf (gethash (current-buffer) s20-diff-hl-calls 0))))
    ;; shipped: the module adds its own handler.
    (unless s20-shipped
      (add-hook 'window-buffer-change-functions #'s20--on-show)))
  ;; Before the visits below: the module adopts buffers in `find-file-hook'.
  (when s20-shipped (s20--load-shipped))
  (s20--git "checkout" "-q" "a")
  (let* ((branch (if s20-diff-hl "c" "b"))
         (names (split-string (s20--git "diff" "--name-only" "a" branch) "\n" t))
         (others (seq-take (cl-set-difference
                            (split-string (s20--git "ls-files" "t000") "\n" t)
                            names :test #'equal)
                           10))
         (changed (mapcar (lambda (n) (find-file-noselect (concat s20-root n))) names))
         (edited (car changed))
         (deleted (and s20-diff-hl (get-file-buffer (concat s20-root "t000/l01/f000001.cc"))))
         (shown (and (member s20-mode '("fswatch-shown" "fswatch-chunked" "shipped"))
                     (seq-take (cl-remove deleted (cdr changed)) 3)))
         process ready)
    (mapc (lambda (n) (find-file-noselect (concat s20-root n))) others)
    (with-current-buffer edited
      (goto-char (point-max))
      (insert "// mine\n"))
    (when shown
      (delete-other-windows)
      (let* ((w1 (selected-window)) (w2 (split-window w1)) (w3 (split-window w2)))
        (cl-mapc #'set-window-buffer (list w1 w2 w3) shown)))
    (s20--emit "S20 %s, %s %s, %s" s20-mode system-type
               (car (split-string (emacs-version) "\n")) (format-time-string "%FT%TZ" nil t))
    (s20--emit "buffers: %d changed on %s (1 edited%s), %d unchanged%s" (length changed)
               branch (if deleted ", 1 deleted" "") (length others)
               (if shown (format "; %d shown in windows" (length shown)) ""))
    (pcase s20-mode
      ((or "fswatch" "fswatch-novc" "fswatch-queued" "fswatch-shown" "fswatch-chunked"
           "fswatch-diffhl" "shipped")
       (setq process (if s20-shipped
                         (let ((processes (emacs-cpp-reverter-processes)))
                           (unless (= 1 (length processes))
                             (error "s20: the reverter runs %d fswatch processes, not 1"
                                    (length processes)))
                           (car processes))
                       (s20--start-fswatch)))
       (let ((t0 (float-time)) (probe (concat s20-root ".s20-probe")))
         (setq ready
               (s20--wait (lambda ()
                            (write-region (format "%f" (float-time)) nil probe nil 'silent)
                            (s20--wait (lambda () s20-probe-seen) 0.5))
                          30))
         (delete-file probe)
         (s20--emit "ready: %s after %.2f s" (if ready "yes" "NO") (- (float-time) t0)))
       (s20--wait #'ignore 2)
       (let ((pid (process-id process)))
         (s20--emit "idle fswatch: pid %d, %d descriptors, %.1f MB RSS"
                    pid (s20--descriptors pid) (s20--rss-mb pid))))
      ("poll"
       (setq auto-revert-use-notify nil auto-revert-interval 5)
       (global-auto-revert-mode 1))
      (_ (error "s20: unknown mode %s" s20-mode)))
    (s20--checkout branch changed edited "// s20 b" deleted shown)
    (s20--checkout "a" changed edited "// s20 a" deleted shown)
    (when process
      (s20--emit "filter: longest call %.1f ms; overflows %d"
                 (* 1000 s20-filter-max) s20-overflows)
      (let ((pid (process-id process)))
        (if s20-shipped
            ;; The module's own way: its fswatch stops with the root's last buffer.
            (progn
              (with-current-buffer edited (set-buffer-modified-p nil))
              (dolist (buffer (buffer-list))
                (when (buffer-file-name buffer) (kill-buffer buffer))))
          (delete-process process))
        (s20--wait #'ignore 1)
        (s20--emit "shutdown: fswatch pid %d %s" pid
                   (if (eql 0 (call-process "ps" nil nil nil "-p" (number-to-string pid)))
                       "STILL RUNNING" "gone"))))
    (when (buffer-live-p edited)
      (with-current-buffer edited (set-buffer-modified-p nil)))))

(s20-main)

;;; s20-run.el ends here
