;;; init-cells.el --- `# %%' cells in Python and R scripts  -*- lexical-binding: t; -*-

;;; Commentary:

;; A line `# %%' (optionally with a title) starts a cell, as in jupytext, VS Code and
;; Spyder (D-072).  code-cells sends the cell at point to the buffer's REPL: the
;; Python shell (`run-python') or ESS's R process, started when none runs.  Keys
;; (owner's choice): `C-c C-c' runs the cell, `M-n' / `M-p' move to the next /
;; previous one, `C-c % s' runs it and moves on, `C-c % b' runs the whole buffer;
;; the other `C-c %' keys are code-cells' own.

;;; Code:

(defun emacs-cpp-cells--python-eval (start end)
  "Send START..END to the buffer's Python shell, starting `run-python' if needed.
The shell must have printed its first prompt before code is sent, or the code
is lost; this waits for it (up to 10 s, then an error)."
  (unless (python-shell-get-process)
    (save-selected-window (run-python nil nil t))
    (let ((process (python-shell-get-process))
          (deadline (+ (float-time) 10)))
      (while (not (with-current-buffer (process-buffer process)
                    python-shell--first-prompt-received))
        (when (> (float-time) deadline)
          (error "emacs-cpp: Python shell gave no prompt within 10 s"))
        (accept-process-output process 0.1))))
  (python-shell-send-region start end))

(defun emacs-cpp-cells--r-eval (start end)
  "Send START..END to the buffer's R process (ESS starts one if needed)."
  (ess-eval-region start end nil))

(defun emacs-cpp-cells-eval-buffer ()
  "Run the whole buffer in its REPL, as the cells do."
  (interactive)
  (code-cells-eval (point-min) (point-max)))

(use-package code-cells
  :hook ((python-base-mode ess-r-mode) . code-cells-mode)
  :config
  ;; Ahead of code-cells' own Python entries, which need a running shell.
  (add-to-list 'code-cells-eval-region-commands
               (cons 'python-base-mode #'emacs-cpp-cells--python-eval))
  (add-to-list 'code-cells-eval-region-commands
               (cons 'ess-r-mode #'emacs-cpp-cells--r-eval))
  (keymap-set code-cells-mode-map "C-c C-c" #'code-cells-eval)
  (keymap-set code-cells-mode-map "M-n" #'code-cells-forward-cell)
  (keymap-set code-cells-mode-map "M-p" #'code-cells-backward-cell)
  (keymap-set code-cells-mode-map "C-c % b" #'emacs-cpp-cells-eval-buffer))

(provide 'init-cells)
;;; init-cells.el ends here
