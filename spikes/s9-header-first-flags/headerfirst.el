;;; headerfirst.el --- S9: compile command of a header opened first  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S9_ROOT (configured copy), S9_OUT (log), S9_CLANGD (patched clangd),
;; S9_HEADER and S9_SOURCE (relative to S9_ROOT), S9_MODE (index | header-first |
;; source-first), S9_RUN (number, for the log), S9_INDEX_MAX (seconds, index mode).
;; clangd runs with --log=verbose (CLANGD_FLAGS); its stderr shows which command the
;; header got: patch 0005's "Compile command for H ..." and clangd's "building file H
;; ... with command [inferred from X]".
(require 'init-test)
(init-test--load)
(require 'eglot)
(require 'flymake)
(defvar root (file-name-as-directory (getenv "S9_ROOT")))
(defvar out (getenv "S9_OUT"))
(defvar mode (getenv "S9_MODE"))
(defvar header (expand-file-name (getenv "S9_HEADER") root))
(defvar source (expand-file-name (getenv "S9_SOURCE") root))
(setq emacs-cpp-clangd-program (getenv "S9_CLANGD")
      emacs-cpp-presets-state-file (expand-file-name "s9-state.eld" (file-name-directory out)))
(setenv "CLANGD_FLAGS" "--log=verbose")
(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (round (* 1000 (float-time (time-subtract (current-time) t0)))))
(defun wait-for (pred seconds)
  (let ((end (+ (float-time) seconds)) value)
    (while (and (not (setq value (funcall pred))) (< (float-time) end))
      (accept-process-output nil 0.2))
    value))
(defun visit (file)
  "Visit FILE as an interactive visit would; eglot connects from post-command-hook."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer (run-hooks 'post-command-hook))
    buffer))
(defun stderr-text ()
  (let ((server (seq-find #'jsonrpc-running-p (apply #'append (hash-table-values eglot--servers-by-project)))))
    (and server (with-current-buffer (jsonrpc-stderr-buffer server) (buffer-string)))))
(defun log-lines (regexp)
  "Lines of clangd's log matching REGEXP."
  (let ((text (stderr-text)))
    (and text (seq-filter (lambda (line) (string-match-p regexp line))
                          (split-string text "\n" t)))))
(defun building (file)
  "clangd's \"building file FILE\" line, once it is logged."
  (car (log-lines (concat "building file " (regexp-quote file)))))
(defun shards ()
  (let ((dir (expand-file-name ".cache/clangd/index"
                               (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))))
    (if (file-directory-p dir) (length (directory-files dir nil "\\.idx\\'")) 0)))
(defun errors (buffer)
  "flymake errors in BUFFER, once eglot has reported (or 30 s passed)."
  (with-current-buffer buffer
    (wait-for (lambda () (flymake-start) (accept-process-output nil 0.5) (flymake-diagnostics)) 30)
    (seq-count (lambda (d) (memq (flymake-diagnostic-type d) '(:error eglot-error)))
               (flymake-diagnostics))))
(defun short (line)
  (replace-regexp-in-string (regexp-quote root) "" (or line "-")))

(pcase mode
  ("index"
   (visit source)
   (let ((t0 (current-time)) (last -1) (stable 0))
     ;; Done when the shard count has not changed for 15 s.
     (wait-for (lambda ()
                 (let ((n (shards)))
                   (if (= n last) (setq stable (1+ stable)) (setq stable 0 last n))
                   (accept-process-output nil 1)
                   (and (> n 0) (>= stable 15))))
               (string-to-number (or (getenv "S9_INDEX_MAX") "600")))
     (say "index: %d shards after %d ms" (shards) (ms t0))))
  ((or "header-first" "source-first")
   (let ((t0 (current-time)) before)
     (when (equal mode "source-first")
       (visit source)
       (wait-for (lambda () (building source)) 60)
       (setq before (ms t0)))
     (let* ((t1 (current-time))
            (buffer (visit header))
            (built (wait-for (lambda () (building header)) 60))
            (decision (ms t1))
            (count (errors buffer)))
       (say "%s run %s: %s; header command after %d ms; %d errors"
            mode (getenv "S9_RUN")
            (if before (format "source parse started after %d ms" before) "header opened first")
            decision count)
       (say "  patch: %s" (short (car (log-lines (concat "Compile command for "
                                                       (regexp-quote header))))))
       (say "  clangd: %s" (short built))
       ;; When the stored shards were loaded, against the patch's 5 s wait.
       (say "  load start: %s" (short (car (log-lines "Enqueueing [0-9]+ commands"))))
       (say "  load end: %s" (short (car (log-lines "after loading index from disk"))))))))
(dolist (server (apply #'append (hash-table-values eglot--servers-by-project)))
  (ignore-errors (eglot-shutdown server)))
(kill-emacs 0)
