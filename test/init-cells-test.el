;;; init-cells-test.el --- `# %%' cells in Python and R, ESS for R  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests in the shipped profile (T-046, D-072): `.R' files open in
;; `ess-r-mode' without eglot or lintr's flymake; `code-cells-mode' is on in Python and
;; R buffers with the owner's keys; `C-c C-c' on two cells in turn, with no REPL
;; running, starts it and the second cell sees the first one's variable; R starts in
;; the project root.  Needs python3, git, and R (the R test skips without it).

;;; Code:

(require 'ert)
(require 'init-test)

(defmacro init-cells-test--with-dir (files git &rest body)
  "Write FILES (alist NAME . CONTENT) into a temporary `root', `git init' if GIT,
run BODY, then kill the buffers and processes it started."
  (declare (indent 2))
  `(let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-cells" t))))
          (default-directory root)
          (buffers-before (buffer-list)))
     (unwind-protect
         (progn
           (pcase-dolist (`(,name . ,content) ,files)
             (let ((file (expand-file-name name root)))
               (make-directory (file-name-directory file) t)
               (write-region content nil file)))
           (when ,git
             (should (eql 0 (call-process "git" nil nil nil "init" "-q"))))
           ,@body)
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (when-let* ((process (get-buffer-process buffer)))
             (set-process-query-on-exit-flag process nil)
             (delete-process process))
           (let ((kill-buffer-query-functions nil))
             (kill-buffer buffer))))
       (delete-directory root t))))

(defun init-cells-test--run-two-cells ()
  "In the current buffer, press `C-c C-c', `M-n', `C-c C-c' from the top."
  (goto-char (point-min))
  (call-interactively (keymap-lookup nil "C-c C-c"))
  (call-interactively (keymap-lookup nil "M-n"))
  (call-interactively (keymap-lookup nil "C-c C-c")))

(defun init-cells-test--wait-for (buffer regexp)
  "Wait up to 20 s for REGEXP in BUFFER; return the match or nil."
  (let ((deadline (+ (float-time) 20)) found)
    (while (and (not (setq found (with-current-buffer buffer
                                   (save-excursion
                                     (goto-char (point-min))
                                     (and (re-search-forward regexp nil t)
                                          (match-string 0))))))
                (< (float-time) deadline))
      (accept-process-output nil 0.2))
    found))

(ert-deftest init-cells-modes-and-keys ()
  "D-072: R files open in `ess-r-mode', cells are on in Python and R buffers with
the owner's keys, and R gets neither eglot nor lintr's flymake."
  (init-test--load)
  (init-cells-test--with-dir '(("a.py" . "x = 1\n") ("a.R" . "x <- 1\n")) t
    (dolist (file '("a.py" "a.R"))
      (with-current-buffer (find-file-noselect (expand-file-name file root))
        (should code-cells-mode)
        (should (eq (keymap-lookup nil "C-c C-c") 'code-cells-eval))
        (should (eq (keymap-lookup nil "M-n") 'code-cells-forward-cell))
        (should (eq (keymap-lookup nil "M-p") 'code-cells-backward-cell))
        (should (eq (keymap-lookup nil "C-c % s") 'code-cells-eval-and-step))
        (should (eq (keymap-lookup nil "C-c % b") 'emacs-cpp-cells-eval-buffer))))
    (with-current-buffer (get-file-buffer (expand-file-name "a.R" root))
      (should (eq major-mode 'ess-r-mode))
      (should-not (bound-and-true-p eglot--managed-mode))
      (should-not (bound-and-true-p flymake-mode))
      ;; ESS found its own directory, not lib/ (lisp/init-r.el).
      (should (file-directory-p ess-etc-directory)))))

(ert-deftest init-cells-python-cells-share-state ()
  "D-072: with no shell running, `C-c C-c' starts `run-python'; the second cell
uses the first one's variable."
  (init-test--load)
  (init-cells-test--with-dir
      '(("demo.py" . "# %% setup\nimport math\nx = 2\n\n# %% compute\nprint(\"cell2\", round(math.sqrt(x) * 10, 3))\n"))
      nil
    (with-current-buffer (find-file-noselect (expand-file-name "demo.py" root))
      (should-not (python-shell-get-process))
      (init-cells-test--run-two-cells)
      (should (equal (init-cells-test--wait-for (python-shell-get-buffer) "cell2 14\\.142")
                     "cell2 14.142")))))

(ert-deftest init-cells-r-cells-share-state-in-the-project-root ()
  "D-072: with no R running, `C-c C-c' starts R in the project root (the file is in
a subdirectory); the second cell uses the first one's variable."
  (init-test--load)
  (unless (executable-find "R")
    (ert-skip "R not installed (pacman r, MacPorts R)"))
  (init-cells-test--with-dir
      '(("R/demo.R" . "# %% setup\nx <- 2\n\n# %% compute\ncat(\"cell2\", round(sqrt(x) * 10, 3), getwd(), \"\\n\")\n"))
      t
    (with-current-buffer (find-file-noselect (expand-file-name "R/demo.R" root))
      (init-cells-test--run-two-cells)
      (should (equal (init-cells-test--wait-for
                      (process-buffer (ess-get-process ess-local-process-name))
                      (concat "cell2 14\\.142 " (regexp-quote (directory-file-name root))))
                     (concat "cell2 14.142 " (directory-file-name root)))))))

(provide 'init-cells-test)
;;; init-cells-test.el ends here
