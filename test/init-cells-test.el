;;; init-cells-test.el --- `# %%' cells in Python  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests in the shipped profile (T-046, D-072): `code-cells-mode' is on
;; in Python buffers with the owner's keys; `C-c C-c' on two cells in turn, with no
;; shell running, starts it and the second cell sees the first one's variable.  R's
;; cells went with ESS (D-145).  Needs python3 and git.

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
  "D-072: cells are on in Python buffers with the owner's keys."
  (init-test--load)
  (init-cells-test--with-dir '(("a.py" . "x = 1\n")) t
    (with-current-buffer (find-file-noselect (expand-file-name "a.py" root))
      (should code-cells-mode)
      (should (eq (keymap-lookup nil "C-c C-c") 'code-cells-eval))
      (should (eq (keymap-lookup nil "M-n") 'code-cells-forward-cell))
      (should (eq (keymap-lookup nil "M-p") 'code-cells-backward-cell))
      (should (eq (keymap-lookup nil "C-c % s") 'code-cells-eval-and-step))
      (should (eq (keymap-lookup nil "C-c % b") 'emacs-cpp-cells-eval-buffer)))))

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

(provide 'init-cells-test)
;;; init-cells-test.el ends here
