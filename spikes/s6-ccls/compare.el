;;; compare.el --- S6: ccls vs clangd on the same project  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S6_ROOT (configured copy), S6_OUT (log file).
(require 'init-test)
(init-test--load)
(require 'eglot)
(defvar root (file-name-as-directory (getenv "S6_ROOT")))
(defvar out (getenv "S6_OUT"))
(defvar server-kind 'clangd)
(defvar build-dir nil)

(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (round (* 1000 (float-time (time-subtract (current-time) t0)))))
(defun settle (secs) (let ((end (+ (float-time) secs))) (while (< (float-time) end) (accept-process-output nil 0.2))))
(defun servers () (apply #'append (hash-table-values eglot--servers-by-project)))
(defun rss-mb ()
  (let ((server (car (servers))))
    (if (not server) 0
      (/ (string-to-number (shell-command-to-string
                            (format "ps -o rss= -p %d" (process-id (jsonrpc--process server)))))
         1024))))
(defun du-mb (dir)
  (if (file-directory-p dir)
      (string-to-number (car (split-string (shell-command-to-string (format "du -sm %s" (shell-quote-argument dir))))))
    0))

;; ccls replaces clangd through the same contact function, so the hook path, the
;; preset and the database checks (D-016 - D-019) stay as shipped.
(advice-add 'emacs-cpp-presets-clangd-contact :filter-return
            (lambda (command)
              (if (eq server-kind 'clangd) command
                (list "ccls" :initializationOptions
                      `(:compilationDatabaseDirectory ,build-dir
                        :cache (:directory ,(expand-file-name ".ccls-cache" build-dir))
                        :index (:initialBlacklist ["/fmt/"]))))))

;; "Error running timer" was seen once in a dry run and not reproduced; log any.
(advice-add 'message :before
            (lambda (format-string &rest args)
              (when (and (stringp format-string)
                         (string-prefix-p "Error running timer" format-string))
                (say "TIMER ERROR: %s in timer function %S"
                     (apply #'format format-string args)
                     (and (boundp 'timer-event-last) timer-event-last
                          (timer--function timer-event-last))))))

(defun visit (file)
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer (run-hooks 'post-command-hook))
    buffer))
(defun shutdown-all ()
  (dolist (server (servers)) (eglot-shutdown server))
  (dolist (b (buffer-list))
    (when (and (buffer-live-p b) (buffer-file-name b)) (kill-buffer b))))
(defun at-library-name (buffer)
  (with-current-buffer buffer
    (goto-char (point-min))
    (unless (re-search-forward "\\_<dealii::\\([A-Za-z_]+\\)" nil t)
      (error "no dealii:: name in %s" (buffer-name)))
    (goto-char (match-beginning 1))
    (match-string 1)))
(defun timed-definition (buffer &optional limit retry-empty)
  "Return (MS . RESULT) for M-. on the first dealii:: name in BUFFER.
A refusal (ccls: \"not indexed\") is retried every second for up to LIMIT
seconds (default 600), as a user would retry; RESULT then notes the refusals.
With RETRY-EMPTY, an empty answer is retried the same way."
  (with-current-buffer buffer
    (at-library-name buffer)
    (let ((t0 (current-time)) (refusals 0) items done)
      (while (not done)
        (condition-case err
            (progn
              (setq items (xref-backend-definitions
                           'eglot (xref-backend-identifier-at-point 'eglot)))
              (if (or items (not retry-empty)
                      (> (float-time (time-subtract (current-time) t0)) (or limit 600)))
                  (setq done t)
                (cl-incf refusals)
                (settle 1)))
          (jsonrpc-error
           (cl-incf refusals)
           (when (> (float-time (time-subtract (current-time) t0)) (or limit 600))
             (setq done t items nil))
           (when (= refusals 1)
             (say "  (refused: %s; retrying)" (alist-get 'jsonrpc-error-message (cdr err))))
           (settle 1))))
      (cons (ms t0)
            (format "%s%s"
                    (if items (file-name-nondirectory
                               (xref-location-group (xref-item-location (car items))))
                      "no answer")
                    (if (> refusals 0) (format " after %d refusals" refusals) ""))))))
(defun reference-count (buffer)
  (with-current-buffer buffer
    (at-library-name buffer)
    (condition-case err
        (length (xref-backend-references 'eglot (xref-backend-identifier-at-point 'eglot)))
      (jsonrpc-error (format "refused: %s" (alist-get 'jsonrpc-error-message (cdr err)))))))
(defun error-count (buffer)
  (with-current-buffer buffer
    (flymake-start) (settle 10)
    (cl-count-if (lambda (d) (eq (flymake-diagnostic-type d) 'eglot-error)) (flymake-diagnostics))))
(defun ccls-wait-indexed (limit)
  "Poll $ccls/info until the pipeline is idle; return (MS . PEAK-RSS-MB)."
  (let ((t0 (current-time)) (peak 0) (idle 0))
    (while (and (< idle 3) (< (float-time (time-subtract (current-time) t0)) limit))
      (let* ((info (jsonrpc-request (car (servers)) :$ccls/info nil))
             (pipeline (plist-get info :pipeline)))
        (setq peak (max peak (rss-mb)))
        (if (>= (plist-get pipeline :completed) (plist-get pipeline :enqueued))
            (cl-incf idle) (setq idle 0)))
      (settle 1))
    (cons (ms t0) peak)))

(let* ((emacs-cpp-presets-state-file (expand-file-name "s6-state.eld" (file-name-directory out)))
       (main (expand-file-name "src/main.cc" root))
       (header (car (directory-files-recursively (expand-file-name "include" root) "\\.h\\'"))))
  (setq build-dir (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))
  (say "main: %s; header: %s; build dir: %s" (file-relative-name main root)
       (file-relative-name header root) build-dir)
  ;; clangd baseline, persisted index from earlier sessions of this copy if any.
  (setq server-kind 'clangd)
  (let* ((buffer (visit main)) (def (timed-definition buffer)))
    (say "clangd  first M-. %d ms -> %s; references %s; errors %d; RSS %d MB"
         (car def) (cdr def) (reference-count buffer) (error-count buffer) (rss-mb)))
  (shutdown-all)
  ;; ccls round 1: empty cache.
  (setq server-kind 'ccls)
  (let* ((t0 (current-time)) (buffer (visit main)) (def (timed-definition buffer)))
    (say "ccls r1 first M-. %d ms -> %s (empty cache)" (car def) (cdr def))
    (let ((indexed (ccls-wait-indexed 1800)))
      (say "ccls r1 indexing done %d ms after start; peak RSS %d MB" (ms t0) (cdr indexed)))
    (let ((def2 (timed-definition buffer)))
      (say "ccls r1 M-. after indexing %d ms -> %s; references %s; errors %d; RSS %d MB; cache %d MB"
           (car def2) (cdr def2) (reference-count buffer) (error-count buffer) (rss-mb)
           (du-mb (expand-file-name ".ccls-cache" build-dir)))))
  (shutdown-all)
  ;; ccls round 2: new process, persisted cache; M-. right after the start.
  (let* ((t0 (current-time)) (buffer (visit main)) (def (timed-definition buffer)))
    (say "ccls r2 first M-. %d ms -> %s (persisted cache, right after start); RSS %d MB"
         (car def) (cdr def) (rss-mb))
    (let ((answered (timed-definition buffer 120 t)))
      (say "ccls r2 first non-empty M-. %d ms after start -> %s" (ms t0) (cdr answered)))
    (let ((indexed (ccls-wait-indexed 1800)))
      (say "ccls r2 idle %d ms after start; peak RSS %d MB; references %s"
           (ms t0) (cdr indexed) (reference-count buffer))))
  (shutdown-all)
  ;; ccls round 3: new process, a header opened first (O-5), then M-. in main.cc.
  (let ((hbuffer (visit header)))
    (say "ccls r3 header opened first: %d errors" (error-count hbuffer))
    (let ((def (timed-definition (visit main))))
      (say "ccls r3 first M-. in main.cc after the header: %d ms -> %s" (car def) (cdr def))))
  (shutdown-all))
