;;; init-project-test.el --- Textual find references (C-c p ?)  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-081): textual searches run the platform's program,
;; and a missing one stops startup; with patches/projectile/0001 (D-069) `C-c p ?'
;; searches the files projectile lists (tracked and untracked, not git-ignored)
;; with that program.  Without the patch the git-ignored file is found too.  Needs
;; git; ripgrep is tested where it is installed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest init-project-search-program ()
  "D-081: the platform's search program, checked at startup."
  (init-test--load)
  (should (eq xref-search-program emacs-cpp-default-xref-search-program))
  (should (eq (emacs-cpp-search-program-check 'grep) 'grep))
  (should-error (emacs-cpp-search-program-check 'emacs-cpp-no-such-program)))

(ert-deftest init-project-search-keys ()
  "D-135: `C-c p s r' is consult's ripgrep; `C-c p s a' (ag.el, not vendored) is
unbound."
  (init-test--load)
  (should (eq (keymap-lookup projectile-command-map "s r") #'consult-ripgrep))
  (should-not (keymap-lookup projectile-command-map "s a")))

(ert-deftest init-project-find-references-searches-project-files ()
  "patches/projectile/0001: `C-c p ?' finds SYMBOL in the files projectile lists."
  (init-test--load)
  (should (eq (keymap-lookup projectile-command-map "?") #'projectile-find-references))
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-refs" t))))
         (default-directory root))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "sub" root))
          (make-directory (expand-file-name "build" root))
          (write-region "build/\n" nil (expand-file-name ".gitignore" root))
          (write-region "int needle_sym;\n" nil (expand-file-name "a.cc" root))
          (write-region "extern int needle_sym;\n" nil (expand-file-name "sub/b.h" root))
          (write-region "int other;\n" nil (expand-file-name "sub/c.h" root))
          (write-region "int f() { return needle_sym; }\n" nil
                        (expand-file-name "untracked.cc" root))
          (write-region "int needle_sym_copy;\n" nil
                        (expand-file-name "build/generated.cc" root))
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          (should (eql 0 (call-process "git" nil nil nil "add" ".gitignore" "a.cc"
                                       "sub/b.h" "sub/c.h")))
          (let ((buffer (find-file-noselect (expand-file-name "a.cc" root))))
            (unwind-protect
                (with-current-buffer buffer
                  (dolist (program (cons 'grep (and (executable-find "rg") '(ripgrep))))
                    (let ((xref-search-program program)
                          fetcher)
                      (cl-letf (((symbol-function 'xref-show-xrefs)
                                 (lambda (f _display) (setq fetcher f))))
                        (projectile-find-references "needle_sym"))
                      (should (equal (sort (mapcar (lambda (item)
                                                     (file-relative-name
                                                      (xref-location-group
                                                       (xref-item-location item))
                                                      root))
                                                   (funcall fetcher)))
                                     '("a.cc" "sub/b.h" "untracked.cc"))))))
              (kill-buffer buffer))))
      (delete-directory root t))))

(ert-deftest init-project-auto-revert ()
  "D-162 (a): outside project roots unedited buffers follow their files through
auto-revert, notified or polled by platform; a buffer with unsaved edits keeps
them; buffers the reverter covers are left to it.  Batch Emacs delivers no
notifications, so the buffers are polled here, as on the Mac."
  (init-test--load)
  (should global-auto-revert-mode)
  (should (eq auto-revert-use-notify emacs-cpp-default-auto-revert-use-notify))
  (should (eq auto-revert-avoid-polling emacs-cpp-default-auto-revert-use-notify))
  (should (eq (default-value 'global-auto-revert-ignore-buffer)
              #'emacs-cpp-reverter-covers-p))
  (let* ((dir (make-temp-file "emacs-cpp-revert" t))
         (clean-file (expand-file-name "clean.h" dir))
         (edited-file (expand-file-name "edited.h" dir))
         (auto-revert-use-notify nil)
         clean edited)
    (unwind-protect
        (progn
          (write-region "enum class A {};\n" nil clean-file)
          (write-region "enum class B {};\n" nil edited-file)
          (setq clean (find-file-noselect clean-file)
                edited (find-file-noselect edited-file))
          ;; No version control, no .projectile: outside any root (D-163 (a)).
          (should-not (emacs-cpp-reverter-covers-p clean))
          (with-current-buffer edited (goto-char (point-max)) (insert "// mine\n"))
          (write-region "// checkout\nenum class A {};\n" nil clean-file)
          (write-region "// checkout\nenum class B {};\n" nil edited-file)
          (let ((later (time-add nil 10)))
            (set-file-times clean-file later)
            (set-file-times edited-file later))
          (auto-revert-buffers)
          (should (equal (with-current-buffer clean (buffer-string))
                         "// checkout\nenum class A {};\n"))
          (should (equal (with-current-buffer edited (buffer-string))
                         "enum class B {};\n// mine\n")))
      (dolist (buffer (list clean edited))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer)))
      (delete-directory dir t))))

;; D-177 / T-133: a project's file list kept while its directories hold.
(ert-deftest init-project-files-kept ()
  "D-177, S21: `projectile-project-files' lists a project once and serves the kept
list until a directory it depends on changes: files created, removed or renamed
outside Emacs, a new directory with a file, a file in a directory that held none
are each seen by the next call; a file in a git-ignored directory, and Emacs's own
lock and auto-save files during an edit, list nothing anew; `C-c p i' forgets.
D-178: `emacs-cpp-keep-project-files' nil, in the project's .dir-locals.el or
globally, lists on every call; set from Customize it forgets the kept lists."
  (init-test--load)
  (should (advice-member-p #'emacs-cpp-project-files 'projectile-project-files))
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-files" t))))
         (default-directory root)
         (listings 0)
         (count (lambda (&rest _) (cl-incf listings))))
    (cl-flet ((write (rel)
                (let ((file (expand-file-name rel root)))
                  (make-directory (file-name-directory file) t)
                  (write-region (concat rel "\n") nil file nil 'silent)))
              (files () (sort (copy-sequence (projectile-project-files root)) #'string<))
              (listed (thunk) (let ((before listings)) (funcall thunk) (- listings before))))
      (advice-add 'projectile--dir-files-alien-maybe-async :before count)
      (unwind-protect
          (progn
            (write ".gitignore") (write-region "build/\n" nil (expand-file-name ".gitignore" root))
            (write "a.cc") (write "src/b.cc") (write "src/old.cc") (write "build/x.o")
            (make-directory (expand-file-name "empty" root))
            (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
            (clrhash emacs-cpp-project-files--cache)
            (should (= 1 (listed #'files)))
            (should (equal (files) '(".gitignore" "a.cc" "src/b.cc" "src/old.cc")))
            (should (= 0 (listed #'files)))
            (write "src/new.cc")
            (should (= 1 (listed #'files)))
            (should (member "src/new.cc" (files)))
            (delete-file (expand-file-name "src/new.cc" root))
            (should-not (member "src/new.cc" (files)))
            (rename-file (expand-file-name "src/old.cc" root)
                         (expand-file-name "src/renamed.cc" root))
            (should (member "src/renamed.cc" (files)))
            (should-not (member "src/old.cc" (files)))
            (write "newdir/c.cc")
            (should (member "newdir/c.cc" (files)))
            (write "empty/d.cc")
            (should (member "empty/d.cc" (files)))
            ;; A git-ignored directory never counts.
            (write "build/y.o")
            (should (= 0 (listed #'files)))
            ;; An edit: lock file, auto-save file, both removed at save.
            (let ((buffer (find-file-noselect (expand-file-name "a.cc" root)))
                  (create-lockfiles t))
              (unwind-protect
                  (with-current-buffer buffer
                    (auto-save-mode 1)
                    (insert "// edit\n")
                    (should (file-symlink-p (expand-file-name ".#a.cc" root)))
                    (should (= 0 (listed #'files)))
                    (do-auto-save t)
                    (should (file-exists-p buffer-auto-save-file-name))
                    (should (= 0 (listed #'files)))
                    (save-buffer)
                    (should (= 0 (listed #'files))))
                (kill-buffer buffer)))
            (projectile-invalidate-cache nil)
            (should (= 1 (listed #'files)))
            ;; D-178: off for this project in its .dir-locals.el, then globally.
            (write-region "((nil . ((emacs-cpp-keep-project-files . nil))))\n" nil
                          (expand-file-name ".dir-locals.el" root))
            (should (= 1 (listed #'files)))
            (should (= 1 (listed #'files)))
            (delete-file (expand-file-name ".dir-locals.el" root))
            (should (= 1 (listed #'files)))
            (should (= 0 (listed #'files)))
            (let ((emacs-cpp-keep-project-files nil))
              (should (= 1 (listed #'files)))
              (should (= 1 (listed #'files))))
            (customize-set-variable 'emacs-cpp-keep-project-files nil)
            (should (= 0 (hash-table-count emacs-cpp-project-files--cache)))
            (customize-set-variable 'emacs-cpp-keep-project-files t))
        (advice-remove 'projectile--dir-files-alien-maybe-async count)
        (clrhash emacs-cpp-project-files--cache)
        (delete-directory root t)))))

(provide 'init-project-test)
;;; init-project-test.el ends here
