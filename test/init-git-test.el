;;; init-git-test.el --- diff-hl marks in a git project  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration test in the shipped profile (T-016, D-042): a changed line of a
;; committed file is marked when the file is visited, on the right side, and the
;; marks go once magit commits the change.  Needs git.

;;; Code:

(require 'ert)
(require 'init-test)

(defun init-git-test--marks ()
  "Return diff-hl's overlays in the current buffer."
  (seq-filter (lambda (overlay) (overlay-get overlay 'diff-hl))
              (overlays-in (point-min) (point-max))))

(ert-deftest init-git-diff-hl-marks-changes-and-follows-magit ()
  (init-test--load)
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-git" t))))
         (default-directory root)
         (file (expand-file-name "a.cc" root))
         (process-environment (append '("GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@t"
                                        "GIT_COMMITTER_NAME=t" "GIT_COMMITTER_EMAIL=t@t")
                                      process-environment))
         (buffers-before (buffer-list)))
    (unwind-protect
        (progn
          (write-region "int a() { return 1; }\n" nil file)
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          (should (eql 0 (call-process "git" nil nil nil "add" "a.cc")))
          (should (eql 0 (call-process "git" nil nil nil "commit" "-qm" "one")))
          (write-region "int a() { return 2; }\nint b() { return 3; }\n" nil file)
          (with-current-buffer (find-file-noselect file)
            (should diff-hl-mode)
            (should (eq diff-hl-side 'right))
            (should (init-git-test--marks))
            ;; Batch has no fringe: the marks go to the right margin.
            (should diff-hl-margin-local-mode)
            (let ((drawn (seq-find (lambda (overlay)
                                     (let ((mark (overlay-get overlay 'before-string)))
                                       (and mark (not (string-empty-p mark)))))
                                   (init-git-test--marks))))
              (should drawn)
              (should (equal (car (get-text-property 0 'display
                                                     (overlay-get drawn 'before-string)))
                             '(margin right-margin))))
            ;; magit commits behind the buffer's back; its refresh clears the marks.
            (require 'magit)
            (magit-run-git "commit" "-qam" "two")
            (should-not (init-git-test--marks))))
      (dolist (buffer (buffer-list))
        (unless (memq buffer buffers-before)
          (let ((kill-buffer-query-functions nil))
            (kill-buffer buffer))))
      (delete-directory root t))))

(provide 'init-git-test)
;;; init-git-test.el ends here
