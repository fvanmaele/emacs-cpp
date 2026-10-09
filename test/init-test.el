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

(defun init-test--wait-managed (&optional seconds)
  "Wait up to SECONDS (default 10) until eglot manages the current buffer.
Return `eglot-managed-p'.  eglot's connect stops waiting at the first output of
any process, a server's log line on stderr too, so the handshake can still be
under way when the visit returns; the buffer is managed once it ends."
  (let ((deadline (+ (float-time) (or seconds 10))))
    (while (and (not (eglot-managed-p)) (< (float-time) deadline))
      (accept-process-output nil 0.1))
    (eglot-managed-p)))

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
  (dolist (feature '(init-ui init-completion init-project init-cpp init-cmake init-debug
                     init-git init-writing))
    (should (featurep feature)))
  (should-not package-enable-at-startup)
  (should (equal custom-file (expand-file-name "custom.el" init-test--home)))
  (should (memq 'modus-vivendi-tritanopia custom-enabled-themes))
  (should (bound-and-true-p projectile-mode))
  (should (bound-and-true-p which-key-mode))   ; D-034
  (should (bound-and-true-p repeat-mode))      ; D-037
  (should (eq (keymap-lookup projectile-mode-map "C-c p") 'projectile-command-map))
  (should (eq (keymap-lookup global-map "C-x g") 'magit-status))
  (should (eq (assoc-default "notes.md" auto-mode-alist #'string-match) 'markdown-mode))
  ;; D-013: CMake files get the system cmake-mode.
  (let ((file (expand-file-name "CMakeLists.txt" init-test--home)))
    (write-region "project(toy CXX)\n" nil file)
    (with-current-buffer (find-file-noselect file)
      (unwind-protect
          (should (eq major-mode 'cmake-mode))
        (kill-buffer)))
    (should (string-prefix-p (file-name-as-directory emacs-cpp-cmake-mode-directory)
                             (locate-library "cmake-mode"))))
  (should (eq (assoc-default "x/FindFoo.cmake" auto-mode-alist #'string-match) 'cmake-mode))
  (dolist (command '(treemacs treemacs-projectile org-journal-new-entry))
    (should (commandp command)))
  ;; The tree's libraries come from lib/, not from the retired package.el tree.
  (should (string-prefix-p (expand-file-name "lib/" build-packages-root)
                           (locate-library "treemacs"))))

(defun init-test--theme-after-startup (custom)
  "Start the configuration in a child Emacs with CUSTOM as custom.el (nil: none).
Return the themes that give the `default' face its look, as `princ'ed text."
  (let ((home (file-name-as-directory (make-temp-file "emacs-cpp-theme" t))))
    (unwind-protect
        (progn
          (when custom
            (write-region custom nil (expand-file-name "custom.el" home)))
          (with-temp-buffer
            (call-process
             (expand-file-name invocation-name invocation-directory) nil t nil
             "-Q" "--batch" "--eval"
             (format "(progn (setq user-emacs-directory %S)
                       (load %S nil t) (load %S nil t) (run-hooks 'after-init-hook)
                       (princ (format \"THEMES %%S\" (mapcar #'car (get 'default 'theme-face)))))"
                     home
                     (expand-file-name "early-init.el" build-packages-root)
                     (expand-file-name "init.el" build-packages-root)))
            (goto-char (point-min))
            (and (re-search-forward "^THEMES \\(.*\\)" nil t) (match-string 1))))
      (delete-directory home t))))

(defun init-test--defined-names (file)
  "Return the names FILE defines with defconst, defvar or defcustom, sorted."
  (with-temp-buffer
    (insert-file-contents file)
    (let (names form)
      (while (setq form (ignore-error end-of-file (read (current-buffer))))
        (when (memq (car-safe form) '(defconst defvar defcustom))
          (push (symbol-name (cadr form)) names)))
      (sort names #'string<))))

(ert-deftest init-defaults-per-platform ()
  "D-055: one defaults file per platform, the same names in each; an unknown
platform stops startup."
  (init-test--load)
  (should (featurep (emacs-cpp-defaults-feature system-type)))
  (should-error (emacs-cpp-defaults-feature 'windows-nt))
  (let ((names (mapcar (lambda (platform)
                         (init-test--defined-names
                          (locate-library
                           (symbol-name (emacs-cpp-defaults-feature platform)))))
                       '(gnu/linux darwin))))
    (should (car names))
    (should (equal (car names) (cadr names)))))

(ert-deftest init-saved-theme-survives-restart ()
  "D-040: a theme saved with customize-themes is the one in effect after startup;
without one, the default theme is."
  (should (equal (init-test--theme-after-startup
                  "(custom-set-variables '(custom-enabled-themes '(modus-vivendi-tinted)))\n")
                 "(modus-vivendi-tinted)"))
  (should (equal (init-test--theme-after-startup nil) "(modus-vivendi-tritanopia)")))

(ert-deftest init-recent-files-are-kept ()
  "D-041: recentf records visited files, not Emacs's own state files."
  (init-test--load)
  (should (bound-and-true-p recentf-mode))
  (should (= recentf-max-saved-items 200))
  (should (eq (keymap-lookup global-map "C-x C-r") 'consult-recent-file))
  (should (recentf-include-p (expand-file-name "src/main.cc" temporary-file-directory)))
  ;; The test's own home: the predicate needs .cache/ to exist, as it does once
  ;; treemacs has written its state there; the owner's ~/.emacs.d may have none.
  (let ((user-emacs-directory init-test--home))
    (make-directory (expand-file-name ".cache" user-emacs-directory) t)
    (should-not (recentf-include-p (expand-file-name ".cache/treemacs-persist"
                                                     user-emacs-directory)))))

(ert-deftest init-treemacs-magit-loads-with-both ()
  "T-015: treemacs-magit loads once treemacs and magit are loaded."
  (init-test--load)
  (defvar treemacs-persist-file)
  (defvar treemacs-last-error-persist-file)
  (setq treemacs-persist-file (expand-file-name "treemacs-persist" init-test--home)
        treemacs-last-error-persist-file
        (expand-file-name "treemacs-persist-at-last-error" init-test--home))
  (require 'treemacs)
  (require 'magit)
  (should (featurep 'treemacs-magit))
  (should (memq 'treemacs-magit--schedule-update magit-post-stage-hook))
  ;; The same pattern: treemacs-projectile once treemacs and projectile are loaded.
  (should (featurep 'treemacs-projectile)))

(ert-deftest init-info-lists-the-package-manuals ()
  "D-039: C-h i lists the manuals `make packages' built."
  (init-test--load)
  (require 'info)
  (with-temp-buffer
    (Info-mode)
    (Info-find-node "dir" "Top")
    (dolist (entry '("* Magit:" "* Embark:" "* Orderless:" "* Dash:" "* Emacs:"))
      (goto-char (point-min))
      (should (search-forward entry nil t)))))

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
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-tree" t))))
         (file (expand-file-name "a.cc" root)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name ".git" root))
          (write-region "int a;\n" nil file)
          (switch-to-buffer (find-file-noselect file))
          (emacs-cpp-treemacs-toggle)
          (should (treemacs-get-local-window))
          ;; Line numbers in the file, not in the tree (D-063).
          (should (buffer-local-value 'display-line-numbers-mode (get-file-buffer file)))
          (with-current-buffer (window-buffer (treemacs-get-local-window))
            (should-not display-line-numbers-mode))
          (should (equal (mapcar #'treemacs-project->path
                                 (treemacs-workspace->projects
                                  (treemacs-current-workspace)))
                         (list (directory-file-name root))))
          (emacs-cpp-treemacs-toggle)
          (should-not (treemacs-get-local-window)))
      (when-let* ((buffer (get-file-buffer file))) (kill-buffer buffer))
      (delete-directory root t))))

(ert-deftest init-line-numbers-in-editing-buffers-only ()
  "D-063: line numbers in code, text and configuration buffers, not in tool
buffers."
  (init-test--load)
  (dolist (mode '(c++-ts-mode python-ts-mode emacs-lisp-mode markdown-mode
                  text-mode conf-unix-mode))
    (with-temp-buffer
      (funcall mode)
      (should (equal (cons mode display-line-numbers-mode) (cons mode t)))))
  (dolist (mode '(special-mode help-mode compilation-mode))
    (with-temp-buffer
      (funcall mode)
      (should (equal (cons mode display-line-numbers-mode) (cons mode nil)))))
  ;; Not run here, so asked by derivation: magit's buffers are special buffers.
  (require 'magit)
  (should-not (provided-mode-derived-p 'magit-status-mode 'prog-mode 'text-mode
                                       'conf-mode)))

(ert-deftest init-treemacs-opens-only-on-c-c-t ()
  "D-049: visiting a project file does not open the tree; only C-c t does."
  (init-test--load)
  (should-not (memq 'emacs-cpp-treemacs-open-once find-file-hook))
  (should-not (boundp 'emacs-cpp-tree-open-automatically)))

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
