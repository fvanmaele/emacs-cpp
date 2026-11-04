;;; s21.el --- S21: projectile's lists checked by directory times  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-177, T-133).  Batch Emacs with the pinned
;; projectile (lib/projectile) and an `:around' advice on `projectile-project-files'.
;;   REPO=... S21_MODE=m1|m2|m3 S21_TEST=correct|edit|time S21_ROOT=... S21_OUT=... \
;;     emacs -Q --batch -l s21.el
;; m1: any changed directory time lists anew.  m2: a changed directory's names are
;; read again; a difference of Emacs's own lock, auto-save and backup names only
;; keeps the list.  m3: m1, with Emacs's lock, auto-save and backup files written
;; outside project directories.
;; Directories checked: those holding a listed file, their ancestors up to the
;; root, and their subdirectories that hold no listed file and are not ignored
;; (`git check-ignore', for git roots), so a file added to an empty directory is
;; seen; ignored directories (build trees) never count.
;; correct: a temporary git repository and its outside changes, each followed by a
;; served list compared with a fresh uncached listing.  edit: modifies and saves 20
;; files of S21_ROOT in turn, a listing after each step, with backups and
;; auto-saves on as in an interactive session.  time: medians of 7 of a call with
;; the list current, on S21_ROOT.

(require 'cl-lib)
(require 'subr-x)
(add-to-list 'load-path (expand-file-name "lib/projectile" (getenv "REPO")))
(require 'projectile)

(defvar s21-mode (or (getenv "S21_MODE") "m2"))
(defvar s21-out (getenv "S21_OUT"))
(defvar s21-listings 0 "Uncached listings the advice made.")
(defvar s21-cache (make-hash-table :test #'equal)
  "ROOT -> (FILES . DIRS); DIRS: hash DIR -> (MTIME . NAMES).")

(defun s21-emit (fmt &rest args)
  (let ((line (apply #'format fmt args)))
    (if s21-out
        (write-region (concat line "\n") nil s21-out t 'silent)
      (message "%s" line))))

;;;; The cache

(defun s21--mtime (dir)
  (file-attribute-modification-time (file-attributes dir)))

(defun s21--names (dir)
  (directory-files dir nil directory-files-no-dot-files-regexp t))

(defun s21--emacs-own-p (name)
  "Non-nil for Emacs's own lock, auto-save and backup file NAME."
  (or (string-prefix-p ".#" name)
      (auto-save-file-name-p name)
      (backup-file-name-p name)))

(defun s21--ignored (root dirs)
  "The subset of DIRS (absolute) git ignores under ROOT, or nil without git."
  (when (eq (projectile-project-vcs root) 'git)
    (with-temp-buffer
      (let ((default-directory root))
        (insert (mapconcat #'identity dirs "\n") "\n")
        (call-process-region (point-min) (point-max) "git" t t nil
                             "check-ignore" "--stdin")
        (split-string (buffer-string) "\n" t)))))

(defun s21--dirs (root files)
  "Directories to check for ROOT's FILES, each with its time and names."
  (let ((dirs (make-hash-table :test #'equal))
        (extra nil))
    (puthash (file-name-as-directory root) t dirs)
    (dolist (file files)
      (let ((dir (file-name-directory (expand-file-name file root))))
        (while (and dir (not (gethash dir dirs))
                    (string-prefix-p (file-name-as-directory root) dir))
          (puthash dir t dirs)
          (setq dir (file-name-directory (directory-file-name dir))))))
    ;; Subdirectories holding no listed file (an empty directory a file may land in).
    (maphash (lambda (dir _)
               (dolist (name (s21--names dir))
                 (let ((sub (file-name-as-directory (expand-file-name name dir))))
                   (when (and (not (gethash sub dirs))
                              (not (member name '(".git")))
                              (file-directory-p sub))
                     (push sub extra)))))
             dirs)
    (let ((ignored (s21--ignored root (mapcar #'directory-file-name extra))))
      (dolist (sub extra)
        (unless (member (directory-file-name sub) ignored)
          (puthash sub t dirs))))
    ;; Times and names, read before the listing they guard.
    (let ((out (make-hash-table :test #'equal)))
      (maphash (lambda (dir _) (puthash dir (cons (s21--mtime dir) (s21--names dir)) out))
               dirs)
      out)))

(defun s21--current-p (dirs)
  "Non-nil while every directory in DIRS keeps its time (m2: or only Emacs's names moved)."
  (catch 'stale
    (maphash
     (lambda (dir entry)
       ;; One stat per directory: `file-attributes' is nil for a missing one.
       (let ((now (s21--mtime dir)))
         (unless (equal now (car entry))
           (if (and now (equal s21-mode "m2")
                    (equal (cl-remove-if #'s21--emacs-own-p (s21--names dir))
                           (cl-remove-if #'s21--emacs-own-p (cdr entry))))
               (setcar entry now)   ; only Emacs's own files: keep the list
             (throw 'stale nil)))))
     dirs)
    t))

(defun s21-project-files (orig root)
  (let ((entry (gethash root s21-cache)))
    (if (and entry (s21--current-p (cdr entry)))
        (car entry)
      (let* ((projectile-enable-caching nil)
             (files (funcall orig root))
             ;; Times right after the listing: a change in between (a few ms) is
             ;; missed until the next change of structure (RESULTS: a limit).
             (dirs (s21--dirs root files)))
        (cl-incf s21-listings)
        (puthash root (cons files dirs) s21-cache)
        files))))

(advice-add 'projectile-project-files :around #'s21-project-files)

(when (equal s21-mode "m3")
  (let ((away (make-temp-file "s21-away" t)))
    ;; As Emacs's own default for remote files: the name made unique, no directories.
    (setq lock-file-name-transforms `((".*" ,(file-name-as-directory away) t))
          auto-save-file-name-transforms `((".*" ,(file-name-as-directory away) t))
          backup-directory-alist `(("." . ,away)))))

;;;; Tests

(defun s21--fresh (root)
  (let ((projectile-enable-caching nil))
    (advice-remove 'projectile-project-files #'s21-project-files)
    (unwind-protect (projectile-project-files root)
      (advice-add 'projectile-project-files :around #'s21-project-files))))

(defun s21--git (dir &rest args)
  (let ((default-directory dir))
    (unless (eql 0 (apply #'call-process "git" nil nil nil args))
      (error "s21: git %S failed" args))))

(defun s21--check (root label)
  (let* ((before s21-listings)
         (served (projectile-project-files root))
         (fresh (s21--fresh root))
         (same (and (null (cl-set-difference served fresh :test #'equal))
                    (null (cl-set-difference fresh served :test #'equal)))))
    (s21-emit "  %-46s %s, listed anew %s (%d files)"
              label (if same "same" "DIFFERS") (if (> s21-listings before) "yes" "no")
              (length fresh))
    same))

(defun s21-test-correct ()
  (let* ((root (file-name-as-directory (make-temp-file "s21-repo" t)))
         (ok t))
    (cl-flet ((write (rel text) (let ((f (expand-file-name rel root)))
                                  (make-directory (file-name-directory f) t)
                                  (write-region text nil f nil 'silent))))
      (write "a.cc" "a\n") (write "src/b.cc" "b\n") (write "src/old.cc" "o\n")
      (write ".gitignore" "build/\n")
      (make-directory (expand-file-name "empty" root))
      (s21--git root "init" "-q")
      (s21--git root "add" ".")
      (s21--git root "-c" "user.name=s21" "-c" "user.email=s21@invalid" "commit" "-qm" "a")
      (s21--git root "checkout" "-qb" "other")
      (write "only-other.cc" "x\n") (delete-file (expand-file-name "a.cc" root))
      (s21--git root "add" "-A")
      (s21--git root "-c" "user.name=s21" "-c" "user.email=s21@invalid" "commit" "-qm" "b")
      (s21--git root "checkout" "-q" "master")
      (s21-emit "correct, mode %s, %s" s21-mode root)
      (setq ok (and (s21--check root "first call") ok))
      (setq ok (and (s21--check root "second call, nothing changed") ok))
      (write "src/new.cc" "n\n")
      (setq ok (and (s21--check root "file created outside Emacs") ok))
      (delete-file (expand-file-name "src/new.cc" root))
      (setq ok (and (s21--check root "file removed outside Emacs") ok))
      (rename-file (expand-file-name "src/old.cc" root) (expand-file-name "src/renamed.cc" root))
      (setq ok (and (s21--check root "file renamed outside Emacs") ok))
      (write "newdir/c.cc" "c\n")
      (setq ok (and (s21--check root "new directory with a file") ok))
      (write "empty/d.cc" "d\n")
      (setq ok (and (s21--check root "file added to a directory with none") ok))
      (write "build/out.o" "o\n")
      (setq ok (and (s21--check root "ignored directory created (build/)") ok))
      (write "build/more.o" "m\n")
      (setq ok (and (s21--check root "file written into ignored build/") ok))
      (s21--git root "add" "-A")
      (s21--git root "-c" "user.name=s21" "-c" "user.email=s21@invalid" "commit" "-qm" "c")
      (s21--git root "checkout" "-q" "other")
      (setq ok (and (s21--check root "git checkout adding and removing files") ok))
      (s21-emit "correct: %s" (if ok "all same" "SOME DIFFER")))))

(defun s21-test-edit (root)
  (let* ((root (file-name-as-directory root))
         (files (cl-remove-if-not
                 (lambda (f) (string-match-p "\\.\\(el\\|md\\|sh\\|py\\)\\'" f))
                 (s21--fresh root)))
         (picked (seq-take (cl-remove-if (lambda (f) (string-prefix-p "lib/" f)) files) 20))
         (backup-enable-predicate (lambda (_) t)) ; batch under /tmp makes none otherwise
         (auto-save-default t))
    (s21-emit "edit, mode %s, %s: %d files" s21-mode root (length picked))
    (projectile-project-files root)
    (let ((start s21-listings))
      (dolist (rel picked)
        (with-current-buffer (find-file-noselect (expand-file-name rel root))
          (auto-save-mode 1)
          (goto-char (point-max))
          (insert "\n;; s21\n")             ; first modification: lock file
          (projectile-project-files root)
          (do-auto-save t)                  ; auto-save file
          (projectile-project-files root)
          (save-buffer)                     ; backup, lock removed
          (projectile-project-files root)
          (kill-buffer)))
      (s21-emit "edit: %d listings anew over %d files (3 calls each), served list %s"
                (- s21-listings start) (length picked)
                (if (s21--check root "after editing") "same" "DIFFERS")))))

(defun s21-test-time (root)
  (let* ((root (file-name-as-directory root))
         (n (length (projectile-project-files root)))
         (dirs (hash-table-count (cdr (gethash root s21-cache))))
         (ms (cl-loop repeat 7 collect
                      (let ((s (float-time)))
                        (projectile-project-files root)
                        (* 1000 (- (float-time) s))))))
    (s21-emit "time, mode %s, %s: %d files, %d directories checked; current call median %.2f ms (max %.2f), listings %d"
              s21-mode root n dirs (nth 3 (sort ms #'<)) (apply #'max ms) s21-listings)))

(pcase (getenv "S21_TEST")
  ("correct" (s21-test-correct))
  ("edit" (s21-test-edit (getenv "S21_ROOT")))
  ("time" (s21-test-time (getenv "S21_ROOT")))
  (other (error "s21: unknown S21_TEST %S" other)))

;;; s21.el ends here
