;;; init-test.el --- Load the shipped configuration in batch  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests the profile that ships: the real lib/ packages and init.el, with only
;; `user-emacs-directory' redirected so the owner's history and bookmarks are not
;; touched.  Needs `make packages' first.

;;; Code:

(require 'ert)
(require 'build-packages)

(defun init-test--stale-elc-files ()
  "Return built package files whose .elc is missing or older than the .el."
  (let (stale)
    (dolist (spec (build-packages-read-specs build-packages-root))
      (dolist (file (build-packages-files build-packages-root spec))
        (let ((elc (concat file "c")))
          (when (or (not (file-exists-p elc)) (file-newer-than-file-p file elc))
            (push file stale)))))
    stale))

(ert-deftest init-packages-are-built-and-fresh ()
  "Every package file has a current .elc (else: run `make packages')."
  (should (file-exists-p (expand-file-name "lib/load-path.el" build-packages-root)))
  (should (file-exists-p (expand-file-name "lib/autoloads.el" build-packages-root)))
  (should-not (init-test--stale-elc-files)))

(ert-deftest init-loads-and-matches-retired-dot-emacs ()
  "init.el loads without error and keeps the behaviour of the retired ~/.emacs."
  (let* ((home (file-name-as-directory (make-temp-file "emacs-cpp-init-test" t)))
         (user-emacs-directory home))
    (unwind-protect
        (progn
          (load (expand-file-name "early-init.el" build-packages-root) nil t)
          (load (expand-file-name "init.el" build-packages-root) nil t)
          (run-hooks 'after-init-hook)
          (dolist (feature '(init-ui init-project init-git init-writing))
            (should (featurep feature)))
          (should-not package-enable-at-startup)
          (should (equal custom-file (expand-file-name "custom.el" home)))
          (should (memq 'modus-vivendi-tritanopia custom-enabled-themes))
          (should (bound-and-true-p projectile-mode))
          (should (eq (keymap-lookup projectile-mode-map "C-c p")
                      'projectile-command-map))
          (should (eq (keymap-lookup global-map "C-x g") 'magit-status))
          (should (eq (assoc-default "notes.md" auto-mode-alist #'string-match)
                      'markdown-mode))
          (dolist (command '(treemacs treemacs-projectile org-journal-new-entry))
            (should (commandp command)))
          ;; The tree's libraries come from lib/, not from the retired package.el tree.
          (should (string-prefix-p (expand-file-name "lib/" build-packages-root)
                                   (locate-library "treemacs"))))
      (projectile-mode -1)
      (delete-directory home t))))

(provide 'init-test)
;;; init-test.el ends here
