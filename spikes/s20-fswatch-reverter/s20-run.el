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
;; Opens every file branch b changes plus 10 it does not, edits one changed file's
;; buffer, then checks out b and a again, each time waiting up to 15 s for every
;; unedited changed buffer to show the file's first line.  Appends one block to
;; S20_OUT.

(require 'cl-lib)
(require 'subr-x)

(defun s20--env (name)
  (or (getenv name) (error "s20: %s is not set" name)))

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

(defun s20--revert (path)
  "Revert the unedited buffer visiting PATH (a real path) if its file is newer."
  (when (string-prefix-p s20-real-root path)
    (let ((buffer (get-file-buffer
                   (concat s20-root (substring path (length s20-real-root))))))
      (when (and buffer
                 (not (buffer-modified-p buffer))
                 (not (verify-visited-file-modtime buffer)))
        (with-current-buffer buffer
          (revert-buffer t t t)
          ;; As `auto-revert-handler': VC's state (mode line branch) per buffer,
          ;; one git process each.
          (pcase s20-mode
            ("fswatch" (vc-refresh-state))
            ("fswatch-queued" (s20--queue-vc buffer))))))))

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

(defun s20--checkout (branch changed edited marker)
  "Check out BRANCH; wait for CHANGED's unedited buffers to show MARKER; emit."
  (setq s20-reverted nil s20-stall 0.0)
  (let* ((records s20-records) (calls s20-calls) (total s20-filter-total)
         (t0 (float-time))
         (_ (s20--git "checkout" "-q" branch))
         (t1 (float-time))
         (waiting (cl-remove edited changed))
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
    (when (string-prefix-p "fswatch" s20-mode)
      (s20--emit "  filter: %d calls, %d records, %.1f ms total"
                 (- s20-calls calls) (- s20-records records)
                 (* 1000 (- s20-filter-total total))))))

(defun s20-main ()
  (add-hook 'after-revert-hook
            (lambda () (push (cons (current-buffer) (float-time)) s20-reverted)))
  (s20--git "checkout" "-q" "a")
  (let* ((names (split-string (s20--git "diff" "--name-only" "a" "b") "\n" t))
         (others (seq-take (cl-set-difference
                            (split-string (s20--git "ls-files" "t000") "\n" t)
                            names :test #'equal)
                           10))
         (changed (mapcar (lambda (n) (find-file-noselect (concat s20-root n))) names))
         (edited (car changed))
         process ready)
    (mapc (lambda (n) (find-file-noselect (concat s20-root n))) others)
    (with-current-buffer edited
      (goto-char (point-max))
      (insert "// mine\n"))
    (s20--emit "S20 %s, %s %s, %s" s20-mode system-type
               (car (split-string (emacs-version) "\n")) (format-time-string "%FT%TZ" nil t))
    (s20--emit "buffers: %d changed on b (1 edited), %d unchanged" (length changed)
               (length others))
    (pcase s20-mode
      ((or "fswatch" "fswatch-novc" "fswatch-queued")
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
       (let ((pid (process-id process)))
         (s20--emit "idle fswatch: pid %d, %d descriptors, %.1f MB RSS"
                    pid (s20--descriptors pid) (s20--rss-mb pid))))
      ("poll"
       (setq auto-revert-use-notify nil auto-revert-interval 5)
       (global-auto-revert-mode 1))
      (_ (error "s20: unknown mode %s" s20-mode)))
    (s20--checkout "b" changed edited "// s20 b")
    (s20--checkout "a" changed edited "// s20 a")
    (when process
      (s20--emit "filter: longest call %.1f ms; overflows %d"
                 (* 1000 s20-filter-max) s20-overflows)
      (let ((pid (process-id process)))
        (delete-process process)
        (s20--wait #'ignore 1)
        (s20--emit "shutdown: fswatch pid %d %s" pid
                   (if (eql 0 (call-process "ps" nil nil nil "-p" (number-to-string pid)))
                       "STILL RUNNING" "gone"))))
    (with-current-buffer edited (set-buffer-modified-p nil))))

(s20-main)

;;; s20-run.el ends here
