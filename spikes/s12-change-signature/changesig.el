;;; changesig.el --- S12: change a signature through C-c l a's code action  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S12_ROOT (configured copy of the generated project), S12_OUT (log),
;; S12_CLANGD (the spike's clangd), S12_FILE (relative to S12_ROOT), S12_SEARCH (text
;; before the function's name), S12_NAME (the name), S12_INPUT (the new parameter
;; list), S12_OP (label for the log).
;; Opens S12_FILE as an interactive visit would, waits for clangd's background index,
;; puts point on the name, asks for the code actions as `C-c l a' does
;; (`eglot-code-actions'), runs "Change signature" with S12_INPUT as the answer to
;; prompt.el's prompt, answers eglot's confirmation
;; (`eglot-confirm-server-edits', the shipped default) with yes and logs it, saves
;; every edited buffer.
(require 'init-test)
(init-test--load)
(require 'eglot)
(require 'seq)
(defvar root (file-name-as-directory (getenv "S12_ROOT")))
(defvar out (getenv "S12_OUT"))
(defvar op (getenv "S12_OP"))
(setq emacs-cpp-clangd-program (getenv "S12_CLANGD")
      emacs-cpp-presets-state-file (expand-file-name "s12-state.eld" root))
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

(load (expand-file-name "prompt.el" (file-name-directory load-file-name)) nil t)

(defvar prompts nil "Confirmation prompts eglot showed, answered yes.")
(defvar apply-ms nil "Time eglot spent applying the server's workspace edit.")
(advice-add 'eglot--apply-workspace-edit :around
            (lambda (fn &rest args)
              (let ((t0 (current-time)))
                (prog1 (apply fn args) (setq apply-ms (ms t0))))))
(dolist (fn '(y-or-n-p yes-or-no-p))
  (advice-add fn :override (lambda (prompt &rest _) (push prompt prompts) t)))

(defun visit (file)
  "Visit FILE as an interactive visit would; eglot connects from post-command-hook."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer (run-hooks 'post-command-hook))
    buffer))
(defun server () (seq-find #'jsonrpc-running-p (apply #'append (hash-table-values eglot--servers-by-project))))
(defun stderr-lines (regexp)
  (let ((s (server)))
    (and s (with-current-buffer (jsonrpc-stderr-buffer s)
             (seq-filter (lambda (line) (string-match-p regexp line))
                         (split-string (buffer-string) "\n" t))))))
(defun shards ()
  (let ((dir (expand-file-name ".cache/clangd/index"
                               (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))))
    (if (file-directory-p dir) (length (directory-files dir nil "\\.idx\\'")) 0)))

(let* ((file (expand-file-name (getenv "S12_FILE") root))
       (t0 (current-time))
       (buffer (visit file))
       (last -1) (stable 0))
  ;; The index is done when the shard count has not changed for 5 s.
  (wait-for (lambda ()
              (let ((n (shards)))
                (if (= n last) (setq stable (1+ stable)) (setq stable 0 last n))
                (accept-process-output nil 1)
                (and (> n 0) (>= stable 5))))
            300)
  (say "%s: index %d shards after %d ms" op (shards) (ms t0))
  (with-current-buffer buffer
    (goto-char (point-min))
    (search-forward (getenv "S12_SEARCH"))
    (search-backward (getenv "S12_NAME"))
    (forward-char 1)
    (let* ((t1 (current-time))
           (actions (eglot-code-actions (point) (point) nil nil))
           (list-ms (ms t1))
           (action (seq-find (lambda (a) (equal (plist-get a :title) "Change signature"))
                             actions)))
      (say "%s: %d code actions in %d ms: %s" op (length actions) list-ms
           (mapconcat (lambda (a) (plist-get a :title)) actions ", "))
      (if (not action)
          (say "%s: FAIL no \"Change signature\" action at %s:%d" op
               (getenv "S12_FILE") (line-number-at-pos))
        (let ((t2 (current-time))
              (s12-input (getenv "S12_INPUT"))
              error)
          (condition-case err
              (eglot-execute (eglot--current-server-or-lose) action)
            (error (setq error (error-message-string err))))
          (say "%s: apply %s in %d ms (eglot applying the edit: %s ms)%s" op s12-input
               (ms t2) apply-ms (if error (format "; error: %s" error) ""))
          (dolist (p (reverse prompts)) (say "%s: eglot asked: %s" op (string-trim p)))
          (dolist (line (stderr-lines "S12 \\|workspace/executeCommand\\|workspace/applyEdit\\|<-- reply(")) (say "%s: clangd: %s" op line))
          (let ((edited (seq-filter (lambda (b) (and (buffer-file-name b) (buffer-modified-p b)))
                                    (buffer-list))))
            (say "%s: %d buffers edited" op (length edited))
            (dolist (b edited) (with-current-buffer b (save-buffer)))))))))
(dolist (s (apply #'append (hash-table-values eglot--servers-by-project)))
  (ignore-errors (eglot-shutdown s)))
(kill-emacs 0)
