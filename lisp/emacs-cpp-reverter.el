;;; emacs-cpp-reverter.el --- project buffers follow their files through fswatch  -*- lexical-binding: t; -*-

;;; Commentary:

;; A buffer without unsaved edits follows its file when a program outside Emacs
;; changes it (`git checkout' in a shell): eglot gives the server a buffer's text in
;; place of its file, so a stale buffer misleads clangd (D-147).  In a project root
;; (version control or a .projectile file, D-163) one patched fswatch (D-109) per
;; root reports the changes and its filter reverts the root's unedited buffers at
;; once (T-128, D-153; DESIGN "The reverter as built"; S20 PASS on both machines).
;;
;; Reverting holds diff-hl's revert hook back; VC state and diff-hl's marks follow
;; from a queue, one shown buffer per timer step, and for a hidden buffer when a
;; window shows it: per-buffer VC refreshes after a large checkout froze Emacs for
;; seconds on the Mac (O-78).  The queue step waits while the filter runs (D-156
;; (e)), and a filter never runs inside itself (D-161 (p)): Emacs runs filters and
;; timers while a send to a busy server waits (O-79).  Edited and deleted files'
;; buffers are kept and named in a message (D-151, D-152); an overflow or an fswatch
;; that dies is warned about, never hidden.  Buffers it does not cover are left to
;; auto-revert (init-project), which asks `emacs-cpp-reverter-covers-p'.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(declare-function projectile-root-local "projectile" (dir))
(declare-function projectile-root-marked "projectile" (dir))
(declare-function projectile-root-bottom-up "projectile" (dir &optional list))
(declare-function diff-hl-update "diff-hl" ())
(defvar emacs-cpp-default-fswatch-program)

(defconst emacs-cpp-reverter-latency 0.1
  "Seconds fswatch gathers events before it writes them (its -l).")

(defconst emacs-cpp-reverter-exclude '("/\\.git/")
  "Regexps of paths fswatch does not report (its -e): git's own churn.")

(defconst emacs-cpp-reverter-step 0.05
  "Seconds between two steps of the VC and marks queue (D-153).")

(defvar emacs-cpp-reverter--roots (make-hash-table :test #'equal)
  "Root, as buffers visit it, with its slash -> its fswatch process.")

(defvar-local emacs-cpp-reverter--root nil
  "The root whose fswatch reverts this buffer, or nil.")

(defvar-local emacs-cpp-reverter--stale nil
  "Non-nil: reverted while hidden; VC state and marks wait until a window shows it.")

(defvar emacs-cpp-reverter--queue nil
  "Shown buffers waiting for VC state and marks, oldest last.")

(defvar emacs-cpp-reverter--timer nil
  "The queue's one-shot timer, or nil.")

(defvar emacs-cpp-reverter--in-filter nil
  "Non-nil while a filter call reverts (D-156 (e), D-161 (p)).")

(defvar emacs-cpp-reverter--deferred nil
  "(PROCESS . OUTPUT) of filter calls made while one ran, oldest first.")

;;;; Which buffers

(defun emacs-cpp-reverter--set-option (symbol value)
  "Set SYMBOL to VALUE and apply it at once (D-163 (b))."
  (set-default-toplevel-value symbol value)
  (emacs-cpp-reverter--rescan))

(defcustom emacs-cpp-revert-project-buffers t
  "Non-nil: one fswatch per project root reverts its unedited buffers (T-128).
nil: auto-revert covers project buffers too, polled every 5 s on the Mac, with a
VC refresh per reverted buffer (O-78).  For one project, its .dir-locals.el,
((nil . ((emacs-cpp-revert-project-buffers . nil)))); it applies to buffers
visited after it.  Set from Customize it applies at once (D-163 (b))."
  :type 'boolean
  :safe #'booleanp
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-reverter--set-option
  :group 'tools)

(defun emacs-cpp-reverter-root (dir)
  "Return the root the reverter watches for DIR, with its slash, or nil.
Version control or a .projectile file, the tree's rule too (D-070, D-163 (a)):
projectile's first three ways, in its order; a directory it takes for a project
by another marker (deal.II's install has a Makefile) has none."
  (require 'projectile)
  (when-let* ((root (or (projectile-root-local dir)
                        (projectile-root-marked dir)      ; .projectile
                        (projectile-root-bottom-up dir)))) ; .git and the like
    (file-name-as-directory (expand-file-name root))))

(defun emacs-cpp-reverter--covered-root (buffer)
  "Return the root whose fswatch would revert BUFFER, or nil."
  (with-current-buffer buffer
    (and buffer-file-name
         emacs-cpp-revert-project-buffers
         (not (file-remote-p buffer-file-name))
         (emacs-cpp-reverter-root (file-name-directory buffer-file-name)))))

(defun emacs-cpp-reverter-covers-p (buffer)
  "Non-nil if the reverter follows BUFFER's file, nil if auto-revert does.
The default of `global-auto-revert-ignore-buffer' (init-project).  auto-revert asks
once, when it adds a buffer, maybe before `find-file-hook' has the reverter adopt
it, so this answers \"would cover\", not \"has adopted\"."
  (and (emacs-cpp-reverter--covered-root buffer) t))

(defun emacs-cpp-reverter--buffers (root &optional except)
  "Return the live buffers ROOT's fswatch reverts, but EXCEPT."
  (cl-loop for buffer in (buffer-list)
           when (and (not (eq buffer except))
                     (equal (buffer-local-value 'emacs-cpp-reverter--root buffer) root))
           collect buffer))

(defun emacs-cpp-reverter--adopt ()
  "Follow the current buffer's file if covered; start its root's fswatch if none.
On `find-file-hook' and `after-set-visited-file-name-hook'."
  (let ((root (emacs-cpp-reverter--covered-root (current-buffer))))
    (unless (equal root emacs-cpp-reverter--root)
      (emacs-cpp-reverter--release))
    (when root
      (setq emacs-cpp-reverter--root root)
      (unless (process-live-p (gethash root emacs-cpp-reverter--roots))
        (puthash root (emacs-cpp-reverter--start root) emacs-cpp-reverter--roots)))))

(defun emacs-cpp-reverter--release ()
  "Stop following the current buffer's file; with the root's last buffer its fswatch.
On `kill-buffer-hook'."
  (when-let* ((root emacs-cpp-reverter--root))
    (setq emacs-cpp-reverter--root nil
          emacs-cpp-reverter--stale nil
          emacs-cpp-reverter--queue (delq (current-buffer) emacs-cpp-reverter--queue))
    (unless (emacs-cpp-reverter--buffers root (current-buffer))
      (emacs-cpp-reverter--stop root))))

(defun emacs-cpp-reverter--rescan ()
  "Adopt every covered file buffer and release the others; then auto-revert asks
`emacs-cpp-reverter-covers-p' again for every buffer (off and on: it adds buffers
when it starts and only then)."
  (dolist (buffer (buffer-list))
    (when (buffer-file-name buffer)
      (with-current-buffer buffer (emacs-cpp-reverter--adopt))))
  (when (bound-and-true-p global-auto-revert-mode)
    (global-auto-revert-mode -1)
    (global-auto-revert-mode 1)))

;;;; Processes

(defun emacs-cpp-reverter--command (real-root)
  "Return the fswatch command line watching REAL-ROOT."
  `(,emacs-cpp-default-fswatch-program
    "-0" "-r" "-x" "--event-flag-separator=," ; NUL-ended records, recursive, flags
    "-l" ,(number-to-string emacs-cpp-reverter-latency)
    "--allow-overflow"                  ; report lost changes, not exit
    ,@(cl-loop for regexp in emacs-cpp-reverter-exclude
               append (list "-e" regexp))
    ,(directory-file-name real-root)))

(defun emacs-cpp-reverter--sentinel (root stderr)
  "Return the sentinel of ROOT's fswatch.
It warns when fswatch ends unasked, then kills the STDERR buffer."
  (lambda (process event)
    (unless (process-live-p process)
      (unless (process-get process 'emacs-cpp-stopping)
        (let ((text (with-current-buffer stderr (string-trim (buffer-string)))))
          (display-warning
           'emacs-cpp
           (format "fswatch for %s ended (%s)%s; its buffers no longer follow \
their files; `M-x emacs-cpp-reverter-restart' starts it again"
                   root (string-trim event)
                   (if (string-empty-p text) "" (format ": %s" text)))
           :warning)))
      (when (buffer-live-p stderr) (kill-buffer stderr)))))

(defun emacs-cpp-reverter--start (root)
  "Start the fswatch reverting ROOT's buffers; return it."
  (let* ((real-root (file-name-as-directory (file-truename root)))
         (stderr (generate-new-buffer (format " *emacs-cpp-reverter %s stderr*" root))))
    (make-process
     :name (format "emacs-cpp-reverter %s" root)
     :command (emacs-cpp-reverter--command real-root)
     :connection-type 'pipe :noquery t :coding 'utf-8-unix
     :stderr stderr
     :filter (emacs-cpp-reverter--filter root real-root)
     :sentinel (emacs-cpp-reverter--sentinel root stderr))))

(defun emacs-cpp-reverter--stop (root)
  "Stop ROOT's fswatch."
  (when-let* ((process (gethash root emacs-cpp-reverter--roots)))
    (process-put process 'emacs-cpp-stopping t)
    (when (process-live-p process) (delete-process process)))
  (remhash root emacs-cpp-reverter--roots))

(defun emacs-cpp-reverter-processes ()
  "Return the live fswatch processes of the reverter."
  (cl-loop for process being the hash-values of emacs-cpp-reverter--roots
           when (process-live-p process) collect process))

(defun emacs-cpp-reverter-restart ()
  "Start the fswatch of every root a buffer follows again."
  (interactive)
  (dolist (root (hash-table-keys emacs-cpp-reverter--roots))
    (emacs-cpp-reverter--stop root))
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (setq emacs-cpp-reverter--root nil)))
  (emacs-cpp-reverter--rescan))

;;;; Reverting

(defun emacs-cpp-reverter--overflow-p (record)
  "Non-nil when RECORD's flags include `Overflow': fswatch lost changes."
  (when-let* ((space (cl-position ?\s record :from-end t)))
    (member "Overflow" (split-string (substring record (1+ space)) ","))))

(defun emacs-cpp-reverter--path (record)
  "Return RECORD's path: all before its last space (paths may hold spaces)."
  (substring record 0 (cl-position ?\s record :from-end t)))

(defun emacs-cpp-reverter--revert (buffer)
  "Revert BUFFER if its file is newer and it has no unsaved edits.
Return `reverted', `edited' or `deleted' for a buffer kept as it is (D-151 (2b),
D-152: `revert-buffer' signals for a missing file), or nil when the file is not
newer."
  (with-current-buffer buffer
    (cond
     ((verify-visited-file-modtime buffer) nil)
     ((buffer-modified-p) 'edited)
     ((not (file-readable-p buffer-file-name)) 'deleted)
     (t
      ;; diff-hl's hook is buffer-local; its marks wait with VC's state (D-153).
      (let ((after-revert-hook (remq 'diff-hl-after-revert after-revert-hook)))
        (revert-buffer t t t))
      (if (get-buffer-window buffer t)  ; any frame, visible or not (D-162 (b))
          (emacs-cpp-reverter--enqueue buffer)
        (setq emacs-cpp-reverter--stale t))
      'reverted))))

(defun emacs-cpp-reverter--message (kept)
  "One message naming KEPT, (BUFFER . WHY) the filter call did not revert."
  (let* ((names (lambda (why)
                  (cl-loop for (buffer . reason) in (reverse kept)
                           when (eq reason why) collect (buffer-name buffer))))
         (edited (funcall names 'edited))
         (deleted (funcall names 'deleted))
         (parts (delq nil
                      (list (and edited
                                 (format "%d %s with unsaved edits changed on disk: %s"
                                         (length edited)
                                         (if (cdr edited) "buffers" "buffer")
                                         (string-join edited ", ")))
                            (and deleted
                                 (format "%d %s deleted on disk: %s"
                                         (length deleted)
                                         (if (cdr deleted) "buffers' files" "buffer's file")
                                         (string-join deleted ", ")))))))
    (when parts
      (message "%s" (string-join parts "; ")))))

(defun emacs-cpp-reverter--warn-overflow (root)
  (display-warning
   'emacs-cpp
   (format "fswatch for %s overflowed: changes were lost; every buffer of the \
project was checked against its file" root)
   :warning))

(defun emacs-cpp-reverter--handle (root real-root records overflowed)
  "Revert ROOT's buffers whose files RECORDS name (REAL-ROOT's paths).
OVERFLOWED: changes were lost, so every buffer of ROOT is checked."
  (let ((buffers (if overflowed
                     (emacs-cpp-reverter--buffers root)
                   (delete-dups
                    (cl-loop for record in records
                             for path = (emacs-cpp-reverter--path record)
                             for buffer = (and (string-prefix-p real-root path)
                                               (get-file-buffer
                                                (concat root (substring path (length real-root)))))
                             when (and buffer
                                       (buffer-local-value 'emacs-cpp-reverter--root buffer))
                             collect buffer))))
        kept)
    (dolist (buffer buffers)
      (pcase (emacs-cpp-reverter--revert buffer)
        ((and why (or 'edited 'deleted)) (push (cons buffer why) kept))))
    (emacs-cpp-reverter--message kept)))

(defun emacs-cpp-reverter--filter (root real-root)
  "Return the process filter of ROOT's fswatch, which reports REAL-ROOT's paths."
  (let ((pending "")
        (overflow-warned 0))
    (lambda (process output)
      (if emacs-cpp-reverter--in-filter
          ;; D-161 (p): while a revert's send to a busy server waits, Emacs runs
          ;; filters; this output waits until the running call returns.
          (emacs-cpp-reverter--defer process output)
        (let ((emacs-cpp-reverter--in-filter t)
              ;; Records end in NUL; the last piece is the start of one still coming.
              (pieces (split-string (concat pending output) "\0")))
          (setq pending (car (last pieces)))
          (let* ((records (butlast pieces))
                 (overflowed (cl-some #'emacs-cpp-reverter--overflow-p records)))
            (when overflowed
              (when (> (- (float-time) overflow-warned) 60) ; at most once a minute
                (setq overflow-warned (float-time))
                (emacs-cpp-reverter--warn-overflow root)))
            (emacs-cpp-reverter--handle
             root real-root
             (cl-remove-if #'emacs-cpp-reverter--overflow-p records)
             overflowed)))))))

(defun emacs-cpp-reverter--defer (process output)
  "Keep PROCESS's OUTPUT for its filter once the running filter call returns."
  (setq emacs-cpp-reverter--deferred
        (nconc emacs-cpp-reverter--deferred (list (cons process output))))
  (run-at-time 0 nil #'emacs-cpp-reverter--replay))

(defun emacs-cpp-reverter--replay ()
  "Hand the deferred outputs to their filters, oldest first (D-161 (p))."
  (if emacs-cpp-reverter--in-filter
      ;; A timer run inside the filter's wait: later.
      (run-at-time emacs-cpp-reverter-step nil #'emacs-cpp-reverter--replay)
    (let ((calls emacs-cpp-reverter--deferred))
      (setq emacs-cpp-reverter--deferred nil)
      (pcase-dolist (`(,process . ,output) calls)
        (when (process-live-p process)
          (funcall (process-filter process) process output))))))

;;;; VC state and marks (D-153)

(defun emacs-cpp-reverter--refresh (buffer)
  "VC state, then diff-hl's marks, of BUFFER."
  (with-current-buffer buffer
    (setq emacs-cpp-reverter--stale nil)
    (vc-refresh-state)
    (when (bound-and-true-p diff-hl-mode)
      (diff-hl-update))))

(defun emacs-cpp-reverter--arm ()
  (setq emacs-cpp-reverter--timer
        (run-with-timer emacs-cpp-reverter-step nil #'emacs-cpp-reverter--step)))

(defun emacs-cpp-reverter--enqueue (buffer)
  (unless (memq buffer emacs-cpp-reverter--queue)
    (push buffer emacs-cpp-reverter--queue))
  (unless emacs-cpp-reverter--timer
    (emacs-cpp-reverter--arm)))

(defun emacs-cpp-reverter--step ()
  "Refresh the oldest queued buffer; arm the timer again while any is left.
While a filter call reverts, the step waits (D-156 (e))."
  (setq emacs-cpp-reverter--timer nil)
  (unless emacs-cpp-reverter--in-filter
    (when-let* ((next (car (last emacs-cpp-reverter--queue))))
      (setq emacs-cpp-reverter--queue (butlast emacs-cpp-reverter--queue))
      (when (buffer-live-p next)
        (emacs-cpp-reverter--refresh next))))
  (when emacs-cpp-reverter--queue
    (emacs-cpp-reverter--arm)))

(defun emacs-cpp-reverter--on-show (frame)
  "Refresh each stale buffer FRAME's windows show (`window-buffer-change-functions')."
  (dolist (window (window-list frame 'no-minibuf))
    (let ((buffer (window-buffer window)))
      (when (buffer-local-value 'emacs-cpp-reverter--stale buffer)
        (emacs-cpp-reverter--refresh buffer)))))

;; The function held back while reverting is diff-hl's own (D-153); a diff-hl
;; without it fails here, when it loads, not with marks drawn twice.
(with-eval-after-load 'diff-hl
  (unless (fboundp 'diff-hl-after-revert)
    (error "emacs-cpp: diff-hl lacks diff-hl-after-revert, which \
lisp/emacs-cpp-reverter.el holds back while reverting; update it (D-153)")))

(add-hook 'find-file-hook #'emacs-cpp-reverter--adopt)
(add-hook 'after-set-visited-file-name-hook #'emacs-cpp-reverter--adopt)
(add-hook 'kill-buffer-hook #'emacs-cpp-reverter--release)
(add-hook 'window-buffer-change-functions #'emacs-cpp-reverter--on-show)

(provide 'emacs-cpp-reverter)
;;; emacs-cpp-reverter.el ends here
