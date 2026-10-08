;;; init-test.el --- Load the shipped configuration in batch  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests the profile that ships: the real lib/ packages and init.el, with only
;; `user-emacs-directory' redirected so the owner's history and bookmarks are not
;; touched.  The configuration is loaded once and shared by the tests below.
;; Needs `make packages' first.

;;; Code:

(require 'ert)
(require 'build-packages)

(defvar init-test--home nil
  "Temporary `user-emacs-directory' of the loaded configuration, or nil.")

(defun init-test--load ()
  "Load early-init.el and init.el once, then run `after-init-hook'.
The temporary home is deleted when Emacs exits."
  (unless init-test--home
    (setq init-test--home (file-name-as-directory
                           (make-temp-file "emacs-cpp-init-test" t)))
    (add-hook 'kill-emacs-hook
              (lambda ()
                (when (bound-and-true-p projectile-mode)
                  (projectile-mode -1))
                (delete-directory init-test--home t)))
    (let ((user-emacs-directory init-test--home))
      (load (expand-file-name "early-init.el" build-packages-root) nil t)
      (load (expand-file-name "init.el" build-packages-root) nil t)
      (run-hooks 'after-init-hook))))

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
  (init-test--load)
  (dolist (feature '(init-ui init-completion init-project init-cpp init-debug init-git
                     init-writing))
    (should (featurep feature)))
  (should-not package-enable-at-startup)
  (should (equal custom-file (expand-file-name "custom.el" init-test--home)))
  (should (memq 'modus-vivendi-tritanopia custom-enabled-themes))
  (should (bound-and-true-p projectile-mode))
  (should (eq (keymap-lookup projectile-mode-map "C-c p") 'projectile-command-map))
  (should (eq (keymap-lookup global-map "C-x g") 'magit-status))
  (should (eq (assoc-default "notes.md" auto-mode-alist #'string-match) 'markdown-mode))
  (dolist (command '(treemacs treemacs-projectile org-journal-new-entry))
    (should (commandp command)))
  ;; The tree's libraries come from lib/, not from the retired package.el tree.
  (should (string-prefix-p (expand-file-name "lib/" build-packages-root)
                           (locate-library "treemacs"))))

(ert-deftest init-treemacs-follows-the-project ()
  "D-029: `C-c t' toggles the tree, which follows the current buffer's project."
  (init-test--load)
  (should (eq (keymap-lookup global-map "C-c t") 'emacs-cpp-treemacs-toggle))
  ;; Keep treemacs's workspace files in the temporary home, not ~/.emacs.d.
  (defvar treemacs-persist-file)
  (defvar treemacs-last-error-persist-file)
  (setq treemacs-persist-file (expand-file-name "treemacs-persist" init-test--home)
        treemacs-last-error-persist-file
        (expand-file-name "treemacs-persist-at-last-error" init-test--home))
  (require 'treemacs)
  (should (bound-and-true-p treemacs-project-follow-mode))
  ;; In a project: the first C-c t shows exactly that project (no prompt for a
  ;; root, as `treemacs' gives with an empty workspace), the second closes it.
  (let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-tree" t)))
         (file (expand-file-name "a.cc" root)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name ".git" root))
          (write-region "int a;\n" nil file)
          (switch-to-buffer (find-file-noselect file))
          (emacs-cpp-treemacs-toggle)
          (should (treemacs-get-local-window))
          (should (equal (mapcar #'treemacs-project->path
                                 (treemacs-workspace->projects
                                  (treemacs-current-workspace)))
                         (list (directory-file-name root))))
          (emacs-cpp-treemacs-toggle)
          (should-not (treemacs-get-local-window)))
      (when-let* ((buffer (get-file-buffer file))) (kill-buffer buffer))
      (delete-directory root t))))

(ert-deftest init-completion-stack-is-active ()
  "T-003: vertico, orderless, marginalia, consult, embark, corfu, cape are wired."
  (init-test--load)
  (dolist (mode '(vertico-mode marginalia-mode savehist-mode global-corfu-mode
                  corfu-popupinfo-mode corfu-history-mode))
    (should (symbol-value mode)))
  (should (equal completion-styles '(orderless basic)))
  (should-not corfu-auto)                ; on request only (TAB, C-M-i)
  (should (memq 'cape-file (default-value 'completion-at-point-functions)))
  (should (eq xref-show-xrefs-function #'consult-xref))
  (should (eq xref-show-definitions-function #'consult-xref))
  (pcase-dolist (`(,key . ,command)
                 '(("C-x b" . consult-buffer) ("M-s r" . consult-ripgrep)
                   ("M-s l" . consult-line) ("M-g i" . consult-imenu)
                   ("M-g f" . consult-flymake) ("C-." . embark-act)))
    (should (eq (keymap-lookup global-map key) command)))
  ;; projectile's consult bridge is built again now that consult is vendored.
  (should (locate-library "projectile-consult")))

(ert-deftest init-orderless-matches-parts-in-any-order ()
  "Space-separated parts match in any order, as `C-c p f' will use them."
  (init-test--load)
  (let ((files '("include/rmo/gpe/model.h" "include/rmo/fe/assemble.h" "src/main.cc")))
    (should (equal (completion-all-completions "mod gpe" files nil 7)
                   ;; completion-all-completions ends the list with the base size.
                   (append '("include/rmo/gpe/model.h") 0)))))

(provide 'init-test)
;;; init-test.el ends here
