;;; prompt.el --- S11 run 2: the go-to-anything prompt (D-077), timed  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by prompt.sh in `emacs -nw' under tmux, with the
;; shipped config.  The prompt as D-074 .. D-077 rule it: buffers, recent files,
;; bookmarks, project files from the first key; clangd symbols from the third,
;; without a request for ""; `:sort nil', the first 100 hits highlighted, 0.05 s
;; refresh and symbol throttle, `gc-cons-threshold' 64 MB while open.
;; Environment: S11_PROJECT, S11_FILE, S11_FILES_ROOT (root whose files the prompt
;; lists: the project itself, or the deal.II tree as a stand-in), S11_CLANGD,
;; S11_STATE, S11_EMACS_D (read only), S11_OUT (log), S11_SETTLE (seconds).
(require 'init-test)
(init-test--load)
(require 'consult)
(require 'consult-eglot)
(require 'vertico)
(require 'projectile)

(defvar out (getenv "S11_OUT"))
(defvar files-root (file-name-as-directory (getenv "S11_FILES_ROOT")))
(defvar key-time (current-time))
(defvar gc-at-key (cons 0 0.0))

(defun ms (t0) (* 1000 (float-time (time-subtract (current-time) t0))))
(defun say (fmt &rest args)
  (write-region (concat (apply #'format fmt args) "\n") nil out t 'silent))

;; The owner's recent files and bookmarks, read, never written (temporary home).
(let ((emacs-d (file-name-as-directory (getenv "S11_EMACS_D"))))
  (let ((file (expand-file-name (file-name-nondirectory recentf-save-file) emacs-d)))
    (when (file-exists-p file) (load file nil t)))
  (let ((file (expand-file-name (file-name-nondirectory bookmark-default-file) emacs-d)))
    (when (file-exists-p file) (bookmark-load file t t))))

;;;; Instrumentation

(add-hook 'pre-command-hook
          (lambda ()
            (when (or (minibufferp) (eq this-command 'go-to-anything))
              (setq key-time (current-time)
                    gc-at-key (cons gcs-done gc-elapsed))
              (say "key %s" (key-description (this-command-keys))))))

(advice-add 'vertico--exhibit :around
            (lambda (f &rest args)
              (let ((t0 (current-time)))
                (apply f args)
                (say "  screen %6.1f ms after key (update %5.1f ms): %S %d candidates, %d GCs %.0f ms"
                     (ms key-time) (ms t0) (minibuffer-contents-no-properties) vertico--total
                     (- gcs-done (car gc-at-key))
                     (* 1000 (- gc-elapsed (cdr gc-at-key)))))))

;;;; The prompt

(defun limited-compiler (limit)
  "A regexp compiler whose highlighter marks only the first LIMIT strings per input."
  (lambda (input type ignore-case)
    (pcase-let ((`(,re . ,hl) (consult--default-regexp-compiler input type ignore-case))
                (n 0))
      (cons re (and hl (lambda (s) (when (<= (cl-incf n) limit) (funcall hl s))))))))

(defun symbol-request (servers)
  "Async step: ask SERVERS for symbols matching each non-empty input."
  (lambda (sink)
    (lambda (action)
      (if (not (and (stringp action) (> (length action) 0)))
          (funcall sink action)
        (let ((t0 (current-time)) (replies nil))
          (dolist (server servers)
            (jsonrpc-async-request
             server :workspace/symbol `(:query ,action)
             :success-fn
             (lambda (reply)
               (say "  symbols %S: %d, reply %.1f ms after request, %.1f ms after key"
                    action (length reply) (ms t0) (ms key-time))
               (setq replies (append replies reply nil))
               (funcall sink 'flush)
               (funcall sink replies))
             :error-fn (lambda (err) (say "  symbols %S: error %S" action err))
             :timeout-fn (lambda () (say "  symbols %S: timeout" action))))
          (funcall sink action))))))

(defun file-items ()
  (let* ((t0 (current-time))
         (files (projectile-project-files files-root)))
    (say "  listed %d files in %.1f ms" (length files) (ms t0))
    files))

(defun go-to-anything ()
  (interactive)
  (let* ((servers (consult-eglot--servers))
         (gc-cons-threshold (* 64 1024 1024))
         (consult--regexp-compiler (limited-compiler 100))
         (consult-async-refresh-delay 0.05)
         (default-directory files-root))
    (consult--multi
     (list consult-source-buffer
           consult-source-recent-file
           consult-source-bookmark
           (list :name "Project File" :narrow ?f :category 'file :face 'consult-file
                 :items #'file-items)
           (list :name "Symbol" :narrow ?s :category 'consult-eglot-symbols
                 :async (consult--async-pipeline
                         (consult--async-min-input 3)
                         (consult--async-throttle 0.05 0.05)
                         (symbol-request servers)
                         (consult--async-map #'consult-eglot--transformer))))
     :prompt "Go to: " :sort nil)))

(keymap-global-set "M-o" #'go-to-anything)

;; Open the source once the terminal is up, wait for eglot and the index.
(run-with-timer
 0.5 nil
 (lambda ()
   (let ((emacs-cpp-presets-state-file (getenv "S11_STATE"))
         (emacs-cpp-clangd-program (getenv "S11_CLANGD")))
     (find-file (expand-file-name (getenv "S11_FILE") (getenv "S11_PROJECT")))
     (run-hooks 'post-command-hook)
     (say "# files from %s; managed %s; %s; gc-cons-threshold %d"
          files-root (init-test--wait-managed 60)
          (car (process-command (jsonrpc--process (eglot-current-server))))
          gc-cons-threshold))
   (let ((e (+ (float-time) (string-to-number (or (getenv "S11_SETTLE") "20")))))
     (while (< (float-time) e) (accept-process-output nil 0.2)))
   (say "# ready")))
