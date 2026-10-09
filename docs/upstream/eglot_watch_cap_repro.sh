#!/bin/sh
# Reproduction for eglot-watch-cap-partial-watches.md (draft upstream report).
#   sh eglot_watch_cap_repro.sh DIR [DIRS] [CAP]
# Creates a git project of DIRS (default 600) packages in DIR, then runs
# `emacs -Q --batch' with eglot and pyright-langserver, `eglot-max-file-watches'
# set to CAP (default 500) and only project directories watched. Prints whether pyright is still running 20 s after
# connecting, the last JSON-RPC events and pyright's stderr. Needs Emacs 30+ and
# pyright-langserver on PATH.
set -eu
DIR=${1:?usage: sh eglot_watch_cap_repro.sh DIR [DIRS] [CAP]}
DIRS=${2:-600}
CAP=${3:-500}
[ -e "$DIR" ] && { echo "repro: $DIR exists; remove it first" >&2; exit 1; }
mkdir -p "$DIR"
i=1
while [ "$i" -le "$DIRS" ]; do
    mkdir -p "$DIR/pkg$i"
    printf 'def f%d():\n    return %d\n' "$i" "$i" > "$DIR/pkg$i/m.py"
    i=$((i + 1))
done
printf 'from pkg7.m import f7\n\nprint(f7())\n' > "$DIR/main.py"
( cd "$DIR" && git init -q )
emacs -Q --batch --eval "
(progn
  (require 'eglot)
  ;; Project directories only, so the result does not depend on the size of
  ;; the Python installation pyright also asks to watch.
  (setq eglot-max-file-watches $CAP
        eglot-watch-files-outside-project-root nil
        eglot-events-buffer-config '(:size 2000000 :format full))
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . (\"pyright-langserver\" \"--stdio\")))
  (find-file \"$DIR/main.py\")
  (python-mode)
  (eglot-ensure)
  (run-hooks 'post-command-hook)
  (let ((deadline (+ (float-time) 30)))
    (while (and (not (eglot-current-server)) (< (float-time) deadline))
      (accept-process-output nil 0.2)))
  (let* ((server (eglot-current-server))
         (proc (jsonrpc--process server)))
    (let ((deadline (+ (float-time) 20)))
      (while (< (float-time) deadline) (accept-process-output nil 0.5)))
    (require 'find-func)
    (princ (format \"emacs %s, eglot %s, %s; pyright %s after 20 s\n\"
                   emacs-version
                   (with-temp-buffer
                     (insert-file-contents (find-library-name \"eglot\"))
                     (and (re-search-forward \"^;; Version: \\\\(.*\\\\)\" nil t)
                          (match-string 1)))
                   (string-trim (shell-command-to-string \"pyright --version\"))
                   (if (process-live-p proc) \"RUNNING\" \"EXITED\")))
    (princ \"--- last events ---\n\")
    (with-current-buffer (jsonrpc-events-buffer server)
      (princ (buffer-substring (max (point-min) (- (point-max) 1500)) (point-max))))
    (princ \"\n--- pyright stderr (tail) ---\n\")
    (let ((buf (jsonrpc-stderr-buffer server)))
      (when buf
        (with-current-buffer buf
          (princ (buffer-substring (max (point-min) (- (point-max) 1500)) (point-max))))))))" 2>&1
