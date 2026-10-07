;;; warmup.el --- S5: does opening the project's sources ahead of time help?  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S5_ROOT (configured copy), S5_REPO (emacs-cpp), S5_OUT (log file).
(require 'init-test)
(init-test--load)
(require 'eglot)
(setq eglot-confirm-server-edits nil)
(defvar root (file-name-as-directory (getenv "S5_ROOT")))
(defvar out (getenv "S5_OUT"))
(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (round (* 1000 (float-time (time-subtract (current-time) t0)))))
(defun settle (secs) (let ((end (+ (float-time) secs))) (while (< (float-time) end) (accept-process-output nil 0.2))))
(defun visit (file)
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer (run-hooks 'post-command-hook))
    buffer))
(defun clangd-rss-mb ()
  (let ((server (car (apply #'append (hash-table-values eglot--servers-by-project)))))
    (/ (string-to-number (shell-command-to-string
                          (format "ps -o rss= -p %d" (process-id (jsonrpc--process server)))))
       1024)))
(defun first-library-definition-ms (buffer)
  "Time M-. on the first `dealii::' (else `std::') name in BUFFER."
  (with-current-buffer buffer
    (goto-char (point-min))
    (unless (re-search-forward "\\_<\\(dealii\\|std\\)::\\([A-Za-z_]+\\)" nil t)
      (error "no dealii:: or std:: name in %s" (buffer-name)))
    (goto-char (match-beginning 2))
    (let ((t0 (current-time)))
      (xref-backend-definitions 'eglot (xref-backend-identifier-at-point 'eglot))
      (ms t0))))
(defun not-found-count (buffer)
  (with-current-buffer buffer
    (flymake-start)
    (settle 8)
    (cl-count-if (lambda (d) (string-match-p "not found" (flymake-diagnostic-text d)))
                 (flymake-diagnostics))))
(defun shutdown-all ()
  (dolist (server (apply #'append (hash-table-values eglot--servers-by-project)))
    (eglot-shutdown server))
  (dolist (b (buffer-list))
    (when (and (buffer-live-p b) (buffer-file-name b)) (kill-buffer b))))

(let* ((emacs-cpp-presets-state-file (expand-file-name "s5-state.eld" (file-name-directory out)))
       (dir (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))
       (sources (cl-remove-if
                 (lambda (f) (or (string-match-p "/fmt/" f) (not (file-in-directory-p f root))))
                 (mapcar (lambda (e) (expand-file-name (alist-get 'file e) (alist-get 'directory e)))
                         (with-temp-buffer
                           (insert-file-contents (expand-file-name "compile_commands.json" dir))
                           (json-parse-buffer :object-type 'alist :array-type 'list)))))
       (main (or (seq-find (lambda (f) (string-suffix-p "src/main.cc" f)) sources) (car sources)))
       (header (car (directory-files-recursively (expand-file-name "include" root) "\\.h\\'"))))
  (say "sources: %d (fmt excluded); main: %s; header: %s" (length sources)
       (file-relative-name main root) (and header (file-relative-name header root)))
  ;; A: today's behaviour, only main.cc open.
  (let ((buffer (visit main)))
    (say "A cold   first M-. in main.cc: %d ms, clangd %d MB" (first-library-definition-ms buffer) (clangd-rss-mb)))
  (when header
    (say "A        header opened after main.cc: %d 'not found'" (not-found-count (visit header))))
  (shutdown-all)
  ;; B: warm-up, every project source opened in the background first.
  (let ((t0 (current-time)) (buffers (mapcar #'visit sources)))
    ;; documentSymbol answers once the file is parsed; clangd parses them in parallel.
    (dolist (b buffers)
      (with-current-buffer b
        (eglot--request (eglot-current-server) :textDocument/documentSymbol
                        `(:textDocument ,(eglot--TextDocumentIdentifier)) :timeout 600)))
    (say "B warm-up of %d sources: %d ms, clangd %d MB" (length buffers) (ms t0) (clangd-rss-mb))
    (say "B warm   first M-. in main.cc: %d ms" (first-library-definition-ms (find-buffer-visiting main))))
  (when header
    (say "B        header opened after warm-up: %d 'not found'" (not-found-count (visit header))))
  (shutdown-all))
