;;; measure.el --- S11: the cost of each source of a go-to-anything prompt  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by run.sh: emacs -Q --batch with the shipped config.
;; Environment: S11_PROJECT (CMake presets project, clangd), S11_FILE (its source to
;; open), S11_TREE (large tree, file listing only), S11_OUT (log), S11_CLANGD
;; (program), S11_STATE (copy of the preset state), S11_EMACS_D (owner's
;; ~/.emacs.d, read for recentf and bookmarks only), S11_SETTLE (seconds).
(require 'init-test)
(init-test--load)
(require 'eglot)
(require 'consult)
(require 'projectile)
(require 'bookmark)
(require 'recentf)

(defvar out (getenv "S11_OUT"))
(defvar project (file-name-as-directory (getenv "S11_PROJECT")))
(defvar tree (file-name-as-directory (getenv "S11_TREE")))
(defvar emacs-d (file-name-as-directory (getenv "S11_EMACS_D")))
(defvar runs 5)

(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (* 1000 (float-time (time-subtract (current-time) t0))))
(defun median (xs) (nth (/ (length xs) 2) (sort (copy-sequence xs) #'<)))
(defun timed (fun)
  "Call FUN `runs' times; return (MEDIAN-MS MIN-MS MAX-MS LAST-RESULT)."
  (let (times result)
    (dotimes (_ runs)
      (garbage-collect)
      (let ((t0 (current-time)))
        (setq result (funcall fun))
        (push (ms t0) times)))
    (list (median times) (apply #'min times) (apply #'max times) result)))
(defun settle (s)
  (let ((e (+ (float-time) s)))
    (while (< (float-time) e) (accept-process-output nil 0.5))))

;;;; Static sources

(defun commands ()
  "Command names as M-x offers them (`read-extended-command-predicate')."
  (let (names)
    (mapatoms (lambda (s)
                (when (and (commandp s)
                           (or (null read-extended-command-predicate)
                               (funcall read-extended-command-predicate s (current-buffer))))
                  (push (symbol-name s) names))))
    names))

;; The owner's recent files and bookmarks, read, never written: the temporary home
;; of `init-test--load' receives any save.  The file names are Emacs's own
;; (`recentf.eld', `bookmarks.eld' in Emacs 31; run 1 looked for `recentf').
(let ((file (expand-file-name (file-name-nondirectory recentf-save-file) emacs-d)))
  (when (file-exists-p file)
    (load file nil t)))
(let ((file (expand-file-name (file-name-nondirectory bookmark-default-file) emacs-d)))
  (when (file-exists-p file)
    (bookmark-load file t t)))

(defun files-of (root label)
  (pcase-let ((`(,med ,lo ,hi ,files) (timed (lambda () (projectile-project-files root)))))
    (say "files %s: %d files, projectile-project-files median %.1f ms (%.1f - %.1f)"
         label (length files) med lo hi)
    files))

(defun filter (items input)
  "What `consult--async-static' does per input: compile, match, highlight."
  (pcase-let ((`(,re . ,hl) (consult--compile-regexp input 'emacs completion-ignore-case)))
    (if re
        (let* ((completion-regexp-list re)
               (all (all-completions "" items)))
          (cl-loop for s in-ref all do (funcall hl (setf s (copy-sequence s))))
          all)
      items)))

(defun measure-static ()
  (let* ((project-files (files-of project "project"))
         (tree-files (files-of tree "tree"))
         (recent (copy-sequence recentf-list))
         (marks (bookmark-all-names))
         (buffers (mapcar #'buffer-name (buffer-list))))
    (pcase-let ((`(,med ,lo ,hi ,names) (timed #'commands)))
      (say "commands: %d, listing median %.1f ms (%.1f - %.1f)" (length names) med lo hi)
      (say "recent files %d, bookmarks %d, buffers %d (batch)"
           (length recent) (length marks) (length buffers))
      (dolist (set (list (cons "project" project-files) (cons "tree" tree-files)))
        (let ((items (append buffers recent marks (cdr set) names)))
          (say "filter over %s files + recent + bookmarks + buffers + commands: %d items"
               (car set) (length items))
          (dolist (input '("m" "ma" "mai" "main" "fe val" "tria h" "assemble"))
            (pcase-let ((`(,med ,lo ,hi ,hits) (timed (lambda () (filter items input)))))
              (say "  %-9S %6d hits  median %.1f ms (%.1f - %.1f)"
                   input (length hits) med lo hi))))))))

;;;; clangd symbols

(defun symbol-round (server label)
  (say "workspace/symbol, %s:" label)
  (let (times)
    (dolist (query '("Tri" "Triangulation" "vec" "main" "assemble" "Sol" "SolutionTransfer"))
      (let* ((t0 (current-time))
             (reply (jsonrpc-request server :workspace/symbol (list :query query)
                                     :timeout 30))
             (d (ms t0)))
        (push d times)
        (say "  %-18S %4d symbols  %.1f ms" query (length reply) d)))
    (say "  median %.1f ms" (median times))))

(defun measure-symbols ()
  (let* ((emacs-cpp-presets-state-file (getenv "S11_STATE"))
         (emacs-cpp-clangd-program (getenv "S11_CLANGD"))
         (t0 (current-time))
         (buffer (find-file-noselect (expand-file-name (getenv "S11_FILE") project))))
    (with-current-buffer buffer
      (run-hooks 'post-command-hook)
      (unless (init-test--wait-managed 60)
        (error "s11: eglot does not manage %s" (buffer-file-name)))
      (say "eglot managed %.0f ms after open (%s)" (ms t0)
           (car (process-command (jsonrpc--process (eglot-current-server)))))
      (let ((server (eglot-current-server)))
        (symbol-round server "at once")
        (settle (string-to-number (or (getenv "S11_SETTLE") "20")))
        (symbol-round server "after the index has loaded")
        (eglot-shutdown server)))
    (kill-buffer buffer)))

(measure-static)
(measure-symbols)
