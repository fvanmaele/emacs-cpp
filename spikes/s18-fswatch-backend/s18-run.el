;;; s18-run.el --- S18: one measured run  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-127).  Interactive, not batch: batch Emacs does not
;; deliver `file-notify' events (checked 2026-10-20), so run.sh starts
;;   S18_ROOT=... S18_MODE=... S18_SERVER=... S18_N=... S18_OUT=... emacs -nw -Q -l s18-run.el
;; in a private tmux server; the run starts from a timer after startup, waits with
;; `sit-for' (which delivers file-notify events and process output alike), appends
;; one block to S18_OUT and exits.
;; MODE: baseline (Emacs's own `file-notify' watches), eglot or regexp (s18-backend.el
;; with that matcher), fast (regexp, URIs from the root's; run 2), batch (fast, sends
;; batched by a timer; run 2), dedup (fast, a filter call's records merged per path;
;; run 2).  SERVER: fake (fake_server.py, counts every change) or pyright
;; (registration and survival only).  N: files in the burst.

(require 'cl-lib)
(require 'eglot)

(defvar s18-here (file-name-directory load-file-name))
(defvar s18-stats nil)
(defvar s18-run--poll-cpu 0.0 "CPU seconds spent reading the log, subtracted.")

(defun s18-run--cpu ()
  "This Emacs's user + system CPU seconds."
  (let ((a (process-attributes (emacs-pid))))
    (+ (float-time (alist-get 'utime a)) (float-time (alist-get 'stime a)))))

(defun s18-run--wait (pred seconds)
  "Process output until PRED is non-nil or SECONDS pass; return PRED's value."
  (let ((deadline (+ (float-time) seconds)) v)
    (while (and (not (setq v (funcall pred))) (< (float-time) deadline))
      (sit-for 0.05))
    v))

(defun s18-run--log-lines (log)
  (if (file-exists-p log)
      (with-temp-buffer (insert-file-contents log) (split-string (buffer-string) "\n" t))
    nil))

(defun s18-run--count (log regexp)
  "Distinct lines of LOG matching REGEXP."
  (length (delete-dups (cl-remove-if-not (lambda (l) (string-match-p regexp l))
                                         (s18-run--log-lines log)))))

(defun s18-run--count-all (log regexp)
  "Lines of LOG matching REGEXP, repeats included."
  (cl-count-if (lambda (l) (string-match-p regexp l)) (s18-run--log-lines log)))

(defun s18-run--busy (seconds)
  "Keep Emacs busy for SECONDS without reading any process output."
  (let ((end (+ (float-time) seconds)) (x 0))
    (while (< (float-time) end) (setq x (1+ x)))
    x))

(defun s18-run--env (name)
  (or (getenv name) (error "s18: %s is not set" name)))

(defun s18-run--emit (fmt &rest args)
  (write-region (concat (apply #'format fmt args) "\n") nil (s18-run--env "S18_OUT") t 'silent))

(defun s18-run--main ()
(let* ((root (file-name-as-directory (expand-file-name (s18-run--env "S18_ROOT"))))
       (mode (intern (s18-run--env "S18_MODE")))
       (kind (intern (s18-run--env "S18_SERVER")))
       (n (string-to-number (s18-run--env "S18_N")))
       (log (make-temp-file "s18-log"))
       (out #'s18-run--emit)
       (default-directory root)
       (eglot-sync-connect t)
       (eglot-autoreconnect nil)
       (eglot-events-buffer-config '(:size 0 :format full))
       reg-start reg-time server buffer)
  (unless (memq mode '(baseline eglot regexp fast batch dedup)) (error "s18: MODE %s" mode))
  (unless (eq mode 'baseline)
    (load (expand-file-name "s18-backend.el" s18-here) nil t)
    (setq s18-matcher (if (memq mode '(fast batch dedup)) 'regexp mode)
          s18-prefix-uri (memq mode '(fast batch dedup))
          s18-dedup (eq mode 'dedup)
          s18-batch (eq mode 'batch))
    (s18-enable))
  (advice-add 'eglot-register-capability :around
              (lambda (fn &rest args)
                (setq reg-start (float-time))
                (prog1 (apply fn args) (setq reg-time (- (float-time) reg-start)))))
  (pcase kind
    ('fake
     (setq eglot-server-programs
           `((text-mode . ("python3" "-I" ,(expand-file-name "fake_server.py" s18-here)
                           ,log))))
     (write-region "probe\n" nil (expand-file-name "s18-open.txt" root))
     (setq buffer (find-file-noselect (expand-file-name "s18-open.txt" root)))
     (with-current-buffer buffer (text-mode)))
    ('pyright
     (setq eglot-server-programs '((python-mode . ("pyright-langserver" "--stdio"))))
     (write-region "x = 1\n" nil (expand-file-name "s18-open.py" root))
     (setq buffer (find-file-noselect (expand-file-name "s18-open.py" root)))
     (with-current-buffer buffer (python-mode)))
    (_ (error "s18: SERVER %s" kind)))
  (funcall out "S18 run: mode %s, server %s, burst %d, %s, %s" mode kind n system-type
           (car (split-string (emacs-version) "\n")))
  (with-current-buffer buffer
    (let ((t0 (float-time)))
      (eglot-ensure)
      (run-hooks 'post-command-hook)
      (s18-run--wait #'eglot-managed-p 30)
      (setq server (eglot-current-server))
      (unless server (error "s18: no server"))
      (s18-run--wait (lambda () reg-time) 120)
      (funcall out "connect + registration: %.2f s (registration in Emacs: %s)"
               (- (float-time) t0) (if reg-time (format "%.2f s" reg-time) "none seen"))))
  (pcase kind
    ('pyright
     (s18-run--wait (lambda () nil) 30)
     (funcall out "pyright after 30 s: %s; fswatch processes: %d"
              (if (jsonrpc-running-p server) "running" "EXITED")
              (if (fboundp 's18-live-processes) (length (s18-live-processes)) 0)))
    ('fake
     (s18-run--wait (lambda () (s18-run--count log "^registered")) 10)
     (funcall out "registration answer: %s"
              (or (car (cl-remove-if-not (lambda (l) (string-prefix-p "registered" l))
                                         (s18-run--log-lines log)))
                  "none"))
    ;; Ready: a probe file reported back.
    (let* ((probe (expand-file-name "t00/m00/l000/s18-probe.py" root))
           (t0 (float-time))
           (ready (s18-run--wait
                   (lambda ()
                     (write-region "x\n" nil probe nil 'silent)
                     (> (s18-run--count log "s18-probe\\.py") 0))
                   30)))
      (funcall out "ready (a probe change reported): %s"
               (if ready (format "%.2f s" (- (float-time) t0)) "NO, 30 s")))
    ;; The burst, Emacs blocked for its first 5 s.
    (let ((cpu0 nil) (cpu1 nil) (t0 (float-time)) (tag (format "%s%d" mode (random 100000)))
          (want nil)
          (last -1) (got 0) (stalled 0))
      (setq s18-stats nil want (format "burst-%s-.*\\.py$" tag))
      (make-process :name "s18-burst" :noquery t
                    :command (list "python3" "-I" (expand-file-name "burst.py" s18-here)
                                   root (number-to-string n) tag)
                    :buffer nil :stderr (get-buffer-create " *s18-burst*"))
      (s18-run--busy 5)
      (setq cpu0 (s18-run--cpu))
      (while (and (< got n) (< stalled 20))
        (sit-for 0.5)
        (let ((c (s18-run--cpu)))
          (setq got (s18-run--count log (concat "^1 .*" want)))
          (cl-incf s18-run--poll-cpu (- (s18-run--cpu) c)))
        (if (= got last) (setq stalled (1+ stalled)) (setq stalled 0 last got)))
      (setq cpu1 (s18-run--cpu))
      (let ((records (or (plist-get s18-stats :records) 0)))
        (funcall out "burst: %d of %d created files reached the server (%d reports, repeats included), %.1f s after the start"
                 got n (s18-run--count-all log (concat "^1 .*" want)) (- (float-time) t0))
        (funcall out "records read %d, sent %d, skipped %d, overflow %d"
                 records (or (plist-get s18-stats :sent) 0)
                 (or (plist-get s18-stats :skipped) 0) (or (plist-get s18-stats :overflow) 0))
        (when (plist-get s18-stats :handled)
          (funcall out "records after merging per path: %d" (plist-get s18-stats :handled)))
        (funcall out "filter calls %d (%.2f s inside, sends excluded), notifications %d (%.2f s sending)"
                 (or (plist-get s18-stats :calls) 0) (or (plist-get s18-stats :filter-s) 0)
                 (or (plist-get s18-stats :notifies) 0) (or (plist-get s18-stats :notify-s) 0))
        (let ((cpu (- cpu1 cpu0 s18-run--poll-cpu)))
          (funcall out "Emacs CPU after the block: %.2f s (log polling %.2f s taken out), %s per 1000 records"
                   cpu s18-run--poll-cpu
                   (if (> records 0) (format "%.0f ms" (/ (* 1e6 cpu) records)) "-")))))))
  ;; Shutdown.
  (eglot-shutdown server)
  (s18-run--wait (lambda () (not (and (fboundp 's18-live-processes) (s18-live-processes)))) 5)
  (funcall out "after shutdown: fswatch processes alive: %d"
           (if (fboundp 's18-live-processes) (length (s18-live-processes)) 0))
  (when (get-buffer "*Warnings*")
    (with-current-buffer "*Warnings*"
      (funcall out "warnings: %s" (string-trim (buffer-string)))))
  (with-current-buffer "*Messages*"
    (funcall out "messages (last 12 lines):\n%s"
             (string-join (last (split-string (buffer-string) "\n" t) 12) "\n")))
  (delete-file log)))

(run-at-time 0.5 nil
             (lambda ()
               (condition-case err
                   (progn (s18-run--main) (kill-emacs 0))
                 (error (s18-run--emit "s18 ERROR: %S" err)
                        (with-current-buffer "*Messages*"
                          (s18-run--emit "messages:\n%s" (buffer-string)))
                        (kill-emacs 1)))))
