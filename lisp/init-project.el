;;; init-project.el --- Projects and the project tree  -*- lexical-binding: t; -*-

;;; Commentary:

;; projectile and treemacs, carried over from the retired ~/.emacs (DESIGN 12).
;; `C-c t' toggles the tree; it shows only the current buffer's project and follows
;; it to other projects (D-029), not into library files outside them (D-070).  It
;; opens only on `C-c t' (D-049).  Two options turn the following off (D-067).
;; Unedited buffers follow their files: a project's through its fswatch
;; (emacs-cpp-reverter, T-128), the others through auto-revert (D-162 (a)).
;; A project's file list (`C-c p f', `M-o') is kept while its directories keep their
;; modification times (D-177, S21): projectile would list it again on every call.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'emacs-cpp-presets)
(require 'emacs-cpp-reverter)

(declare-function projectile-project-vcs "projectile" (&optional project-root))
(declare-function projectile-get-all-sub-projects "projectile" (project))
(defvar projectile-enable-caching)

(defun emacs-cpp-search-program-check (program)
  "Return PROGRAM, a key of `xref-search-program-alist', when its executable is found.
Signal an error naming the executable otherwise (D-081)."
  (let ((executable (if (eq program 'ripgrep) "rg" (symbol-name program))))
    (unless (executable-find executable)
      (error "emacs-cpp: %s is not on exec-path; textual search (C-c p ?) runs it (D-081)"
             executable))
    program))

;; Built in: a buffer without unsaved edits follows its file when a program outside
;; Emacs changes it; eglot gives the server a buffer's text in place of its file, so
;; a stale buffer misleads clangd (D-147).  Here for the buffers the reverter does
;; not cover (outside project roots, or with `emacs-cpp-revert-project-buffers' off):
;; notified or polled by platform (D-055, D-162 (a)).  magit's own auto-revert stays
;; off (init-git, D-153).
(use-package autorevert
  :hook (after-init . global-auto-revert-mode)
  :init
  (setq auto-revert-use-notify emacs-cpp-default-auto-revert-use-notify
        auto-revert-avoid-polling emacs-cpp-default-auto-revert-use-notify)
  (setq-default global-auto-revert-ignore-buffer #'emacs-cpp-reverter-covers-p))

;; Built in: textual searches run the platform's program (D-081, D-055), also
;; `C-c p ?', whose search goes through it with patches/projectile/0001 (D-069).
(use-package xref
  :init
  (setq xref-search-program
        (emacs-cpp-search-program-check emacs-cpp-default-xref-search-program)))

;;;; A project's file list, kept while its directories hold (D-177, T-133)

;; projectile lists a project anew on every call with its `alien' indexing (its own
;; cache only serves `native'): 444 - 493 ms for this repository's 31 submodules
;; (RESEARCH_go_to_anything 22).  A directory's modification time changes when an
;; entry in it is created, removed or renamed, so the list stands while every
;; directory it depends on keeps its time.  Emacs's own lock and auto-save files
;; change those times on every edit (S21): a changed directory's names are read
;; again and the list kept when only such names moved.

(defvar emacs-cpp-project-files--cache (make-hash-table :test #'equal)
  "Project root -> (FILES . DIRS); DIRS maps a directory to (TIME . NAMES).")

(defun emacs-cpp-project-files--time (dir)
  "DIR's modification time, nil when DIR is gone (one `stat')."
  (file-attribute-modification-time (file-attributes dir)))

(defun emacs-cpp-project-files--names (dir)
  "The names in DIR, unsorted, nil when DIR is gone."
  (and (file-directory-p dir)
       (directory-files dir nil directory-files-no-dot-files-regexp t)))

(defun emacs-cpp-project-files--emacs-own-p (name)
  "Non-nil for NAME of Emacs's own lock, auto-save or backup file."
  (or (string-prefix-p ".#" name)
      (auto-save-file-name-p name)
      (backup-file-name-p name)))

(defun emacs-cpp-project-files--git-ignored-in (repo dirs)
  "Those of DIRS (absolute, without a trailing slash) the git repository REPO ignores."
  (with-temp-buffer
    (let ((default-directory repo))
      (insert (string-join dirs "\n") "\n")
      ;; Exit 0: some ignored, 1: none; anything else is an error.
      (let ((status (call-process-region (point-min) (point-max) "git" t t nil
                                         "check-ignore" "--stdin")))
        (unless (memq status '(0 1))
          (error "emacs-cpp: git check-ignore failed in %s: %s" repo (buffer-string)))
        (split-string (buffer-string) "\n" t)))))

(defun emacs-cpp-project-files--git-ignored (root dirs)
  "Those of DIRS (absolute, without a trailing slash) git ignores under ROOT.
Each asked of its innermost repository, ROOT or a submodule: git refuses a path
inside a submodule from the repository above it."
  (let ((repos (sort (cons (file-name-as-directory root)
                           (projectile-get-all-sub-projects root))
                     (lambda (a b) (> (length a) (length b)))))
        (by-repo (make-hash-table :test #'equal)))
    (dolist (dir dirs)
      (let ((repo (seq-find (lambda (repo) (string-prefix-p repo (concat dir "/"))) repos)))
        (push dir (gethash repo by-repo))))
    (let (ignored)
      (maphash (lambda (repo in-repo)
                 (setq ignored (nconc (emacs-cpp-project-files--git-ignored-in repo in-repo)
                                      ignored)))
               by-repo)
      ignored)))

(defun emacs-cpp-project-files--directories (root files)
  "The directories ROOT's list FILES depends on, each with its time and names.
Those holding a file of FILES, their parents up to ROOT, and the subdirectories
of those that hold none (a file may land in an empty directory), but not the
ones git ignores: a build tree never counts.  Each directory is read once, and
only names that are not listed files are tested for being directories.
ROOT and the directories end in a slash, so paths are concatenated, not expanded."
  (let ((root (file-name-as-directory root))
        (listed (make-hash-table :test #'equal :size (length files)))
        (dirs (make-hash-table :test #'equal))
        empty)
    ;; `concat', not `expand-file-name': the root ends in a slash and projectile's
    ;; names are relative and clean; expanding 34556 of them took 400 ms (deal.II).
    (dolist (file files)
      (let ((path (concat root file)))
        (puthash path t listed)
        (let ((dir (file-name-directory path)))
          (while (and dir (not (gethash dir dirs)) (string-prefix-p root dir))
            (puthash dir t dirs)
            (setq dir (file-name-directory (directory-file-name dir)))))))
    (puthash root t dirs)
    ;; Times before names: a change while they are read shows at the next call.
    (maphash (lambda (dir _)
               (let ((time (emacs-cpp-project-files--time dir))
                     (names (emacs-cpp-project-files--names dir)))
                 (puthash dir (cons time names) dirs)
                 (dolist (name names)
                   (let ((path (concat dir name)))
                     (unless (or (gethash path listed) (equal name ".git")
                                 (gethash (file-name-as-directory path) dirs)
                                 (not (file-directory-p path)))
                       (push (file-name-as-directory path) empty))))))
             dirs)
    (let ((ignored (and empty (eq (projectile-project-vcs root) 'git)
                        (emacs-cpp-project-files--git-ignored
                         root (mapcar #'directory-file-name empty)))))
      (dolist (sub empty)
        (unless (member (directory-file-name sub) ignored)
          (puthash sub (cons (emacs-cpp-project-files--time sub)
                             (emacs-cpp-project-files--names sub))
                   dirs))))
    dirs))

(defun emacs-cpp-project-files--current-p (dirs)
  "Non-nil while DIRS still describe the project's files.
A directory whose time changed is read again: when its names differ from those
recorded only by Emacs's own files, its new time is recorded and it stands."
  (catch 'stale
    (maphash
     (lambda (dir entry)
       (let ((time (emacs-cpp-project-files--time dir)))
         (unless (equal time (car entry))
           (if (and time
                    (equal (cl-sort (cl-remove-if #'emacs-cpp-project-files--emacs-own-p
                                                  (emacs-cpp-project-files--names dir))
                                    #'string<)
                           (cl-sort (cl-remove-if #'emacs-cpp-project-files--emacs-own-p
                                                  (copy-sequence (cdr entry)))
                                    #'string<)))
               (setcar entry time)
             (throw 'stale nil)))))
     dirs)
    t))

(defun emacs-cpp-project-files (list-files root)
  "Return ROOT's files as LIST-FILES (`projectile-project-files') does, kept.
`:around' advice: the kept list while ROOT's directories hold, else LIST-FILES
anew, with projectile's own cache off.  The times are read right after the
listing; a change in those few milliseconds shows at that directory's next one,
or after `projectile-invalidate-cache' (`C-c p i').  A remote ROOT is listed
every time, as projectile does: one `stat' per directory would be a round trip
each."
  (if (file-remote-p root)
      (funcall list-files root)
    (let ((entry (gethash root emacs-cpp-project-files--cache))
          ;; Local paths only: the handlers' lookup was most of the cost
          ;; (`file-name-directory', 150 ms over deal.II's 34556 files).
          (file-name-handler-alist nil))
      (if (and entry (emacs-cpp-project-files--current-p (cdr entry)))
          (car entry)
        (let* ((files (let ((projectile-enable-caching nil)
                            (file-name-handler-alist (default-value 'file-name-handler-alist)))
                        (funcall list-files root)))
               (dirs (emacs-cpp-project-files--directories root files)))
          (puthash root (cons files dirs) emacs-cpp-project-files--cache)
          files)))))

(defun emacs-cpp-project-files-forget (&rest _)
  "Forget every kept project file list (after `projectile-invalidate-cache')."
  (clrhash emacs-cpp-project-files--cache))

(use-package projectile
  :hook (after-init . projectile-mode)
  :config
  (advice-add 'projectile-project-files :around #'emacs-cpp-project-files)
  (advice-add 'projectile-invalidate-cache :after #'emacs-cpp-project-files-forget)
  (keymap-set projectile-mode-map "C-c p" #'projectile-command-map)
  ;; `C-c p s r' and `C-c p s a' want rg.el / ag.el, which are not vendored (D-135):
  ;; ripgrep over the project through consult instead (as `M-s r'), ag not at all.
  (keymap-set projectile-command-map "s r" #'consult-ripgrep)
  (keymap-unset projectile-command-map "s a" t)
  ;; C-c p c o / c c / c t configure, build and test the active CMake preset from any
  ;; buffer of the project (D-035); projectile asks again on every run, so a preset
  ;; switch (C-c l P) takes effect at once.
  (projectile-update-project-type
   'cmake
   :configure #'emacs-cpp-presets-configure-command
   :compile #'emacs-cpp-presets-compile-command
   :test #'emacs-cpp-presets-test-command))

(defcustom emacs-cpp-tree-follow-project t
  "Non-nil: the tree switches to the project of the selected buffer (D-029).
nil: it keeps the project `C-c t' opened it with (D-067)."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-tree--set-follow
  :group 'tools)

(defcustom emacs-cpp-tree-follow-file nil
  "Non-nil: the tree expands to and marks the selected buffer's file, as
treemacs does by default.  nil (the default): it stays where you left it (D-067)."
  :type 'boolean
  :initialize #'custom-initialize-default
  :set #'emacs-cpp-tree--set-follow
  :group 'tools)

(defun emacs-cpp-tree--apply-follow ()
  "Turn treemacs's two follow modes on or off as the options say (D-067).
Turning the project follow mode off needs patches/treemacs/0001 (T-041, D-069)."
  (treemacs-project-follow-mode (if emacs-cpp-tree-follow-project 1 -1))
  (treemacs-follow-mode (if emacs-cpp-tree-follow-file 1 -1)))

(defun emacs-cpp-tree--set-follow (symbol value)
  "Set SYMBOL to VALUE; once treemacs is loaded, apply it at once."
  (set-default-toplevel-value symbol value)
  (when (featurep 'treemacs)
    (emacs-cpp-tree--apply-follow)))

(defun emacs-cpp-tree--follow-target-p ()
  "Non-nil if the tree may follow to the current buffer's project (D-070).
Only to a project under version control or with a .projectile file: a library
header reached with `M-.' leaves the tree where it is, also when projectile
takes the library's directory for a project (deal.II's install has a Makefile).
`C-c p' and `C-c t' keep projectile's full rules."
  (let ((dir (if buffer-file-name
                 (file-name-directory buffer-file-name)
               default-directory)))
    ;; The reverter's roots: `projectile-root-bottom-up' alone finds no .projectile.
    (and dir (emacs-cpp-reverter-root dir))))

(defun emacs-cpp-treemacs-toggle ()
  "Close the tree if it is visible, else show the current project in it (D-029).
`treemacs' itself asks for a project root while its workspace is empty."
  (interactive)
  (if-let* ((window (treemacs-get-local-window)))
      (delete-window window)
    (treemacs-add-and-display-current-project-exclusively)))

(use-package treemacs
  :bind ("C-c t" . emacs-cpp-treemacs-toggle)
  :commands treemacs-get-local-window
  :config
  (emacs-cpp-tree--apply-follow)
  (advice-add 'treemacs--do-follow-project :before-while
              #'emacs-cpp-tree--follow-target-p))

;; Lets treemacs add and follow projectile projects; loaded once both are loaded.
;; With `use-package-always-defer' an :after form alone never loads (it did not,
;; T-002 to T-015).
(use-package treemacs-projectile
  :demand t
  :after (treemacs projectile))

(provide 'init-project)
;;; init-project.el ends here
