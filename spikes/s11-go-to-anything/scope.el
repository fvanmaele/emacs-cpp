;;; scope.el --- S11 run 5: project symbols among clangd's workspace symbols  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Run by scope.sh: emacs -Q --batch with the shipped
;; config.  Question (owner 2026-10-13, O-37): if the prompt kept only symbols defined
;; under the project root, how many would a request with `limit' 100 / 1000 lose
;; against no limit (0), and what does a larger limit cost?
;; Environment: S11_PROJECT, S11_FILE, S11_CLANGD, S11_STATE, S11_OUT, S11_SETTLE
;; (as measure.el); S11_SEEDS (space-separated seed queries, default: the project's
;; source file base names).
(require 'init-test)
(init-test--load)
(require 'eglot)
(require 'projectile)

(defvar out (getenv "S11_OUT"))
(defvar project (file-name-as-directory (getenv "S11_PROJECT")))
(defvar limits '(100 1000 0))
(defvar max-queries 40)

(defun say (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (princ (concat line "\n"))
    (write-region (concat line "\n") nil out t)))
(defun ms (t0) (* 1000 (float-time (time-subtract (current-time) t0))))
(defun median (xs) (if xs (nth (/ (length xs) 2) (sort (copy-sequence xs) #'<)) 0))
(defun settle (s)
  (let ((e (+ (float-time) s)))
    (while (< (float-time) e) (accept-process-output nil 0.5))))

(defun under-project-p (symbol)
  "Non-nil when SYMBOL's location is a file under the project root."
  (let ((file (eglot-uri-to-path
               (plist-get (plist-get symbol :location) :uri))))
    (string-prefix-p project (file-truename file))))

(defun ask (server query limit)
  "Return (MS ALL MINE) for QUERY with LIMIT: time, the reply, those under root."
  (let* ((t0 (current-time))
         (reply (append (jsonrpc-request server :workspace/symbol
                                         (list :query query :limit limit)
                                         :timeout 120)
                        nil))
         (d (ms t0)))
    (list d reply (seq-filter #'under-project-p reply))))

(defun seeds ()
  "The seed queries: S11_SEEDS, or the base names of the project's C++ files."
  (if-let* ((env (getenv "S11_SEEDS")))
      (split-string env)
    (seq-uniq
     (mapcar #'file-name-base
             (seq-filter (lambda (f) (string-match-p "\\.\\(cc\\|cpp\\|h\\|hpp\\)\\'" f))
                         (projectile-project-files project))))))

(defun queries (server)
  "Seeds, then 3- and 5-letter prefixes and full names of project symbols they find."
  (let (names)
    (dolist (seed (seeds))
      (pcase-let ((`(,_ ,_ ,mine) (ask server seed 0)))
        (dolist (symbol mine)
          (let ((name (plist-get symbol :name)))
            (when (string-match-p "\\`[A-Za-z_][A-Za-z0-9_]+\\'" name)
              (push name names))))))
    (setq names (seq-uniq (nreverse names)))
    (say "seeds: %d, project symbol names found: %d" (length (seeds)) (length names))
    (let (qs)
      (dolist (name names)
        (dolist (q (list (substring name 0 (min 3 (length name)))
                         (substring name 0 (min 5 (length name)))
                         name))
          (unless (member q qs) (push q qs))))
      (seq-take (nreverse qs) max-queries))))

(defun measure (server)
  (let ((stats (mapcar (lambda (limit) (list limit nil nil)) limits)) ; limit times lost
        (qs (queries server)))
    (say "%-24s %s" "query" (mapconcat (lambda (l) (format "limit %-4d: ms all mine" l))
                                       limits " | "))
    (dolist (q qs)
      (let ((row (mapcar (lambda (limit) (cons limit (ask server q limit))) limits)))
        (let ((truth (length (nth 3 (assq 0 row)))))
          (dolist (entry row)
            (pcase-let ((`(,limit ,d ,all ,mine) entry))
              (let ((stat (assq limit stats)))
                (push d (nth 1 stat))
                (push (- truth (length mine)) (nth 2 stat)))
              (ignore all)))
          (say "%-24S %s" q
               (mapconcat (lambda (entry)
                            (pcase-let ((`(,_ ,d ,all ,mine) entry))
                              (format "%7.1f %6d %4d" d (length all) (length mine))))
                          row " | ")))))
    (dolist (stat stats)
      (pcase-let ((`(,limit ,times ,lost) stat))
        (say "limit %d: median %.1f ms, max %.1f ms; queries losing project symbols %d of %d, lost %d"
             limit (median times) (apply #'max times)
             (seq-count #'cl-plusp lost) (length lost) (apply #'+ lost))))))

(let* ((emacs-cpp-presets-state-file (getenv "S11_STATE"))
       (emacs-cpp-clangd-program (getenv "S11_CLANGD"))
       (buffer (find-file-noselect (expand-file-name (getenv "S11_FILE") project))))
  (with-current-buffer buffer
    (run-hooks 'post-command-hook)
    (unless (init-test--wait-managed 60)
      (error "s11: eglot does not manage %s" (buffer-file-name)))
    (let ((server (eglot-current-server)))
      (settle (string-to-number (or (getenv "S11_SETTLE") "20")))
      (measure server)
      (eglot-shutdown server)))
  (kill-buffer buffer))
