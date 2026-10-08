;;; build-packages.el --- Build the pinned packages in lib/  -*- lexical-binding: t; -*-

;;; Commentary:

;; Run by `make packages' (DESIGN 12, D-006).  Every package is a git submodule under
;; lib/.  This script reads the submodules from .gitmodules, byte-compiles their files,
;; and writes the two generated files that init.el loads:
;;
;;   lib/load-path.el   adds every package directory to `load-path'
;;   lib/autoloads.el   the autoloads of all packages, in one file
;;   lib/info/          the packages' Info manuals and their `dir' index (D-039)
;;
;; Extra keys a submodule section in .gitmodules may carry:
;;
;;   load-path = DIR        directory with the package's Lisp, relative to the
;;                          submodule; repeatable; default "."
;;   build-exclude = FILE   file not compiled and not scanned for autoloads (needs a
;;                          package that is not vendored); repeatable
;;   info = FILE            Texinfo manual built with makeinfo into lib/info/,
;;                          relative to the submodule; repeatable
;;
;; Anything wrong (unknown key, missing directory or manual, stale exclude, compile
;; error, makeinfo missing or failing) stops the build with an error (DESIGN 4,
;; principle 1).

;;; Code:

(require 'bytecomp)
(require 'cl-lib)
(require 'loaddefs-gen)

(defconst build-packages-root
  (file-name-directory
   (directory-file-name (file-name-directory (or load-file-name buffer-file-name))))
  "Root of the emacs-cpp repository (the parent of scripts/).")

(defconst build-packages-known-keys
  '("path" "url" "branch" "ignore" "load-path" "build-exclude" "info")
  "Keys allowed in a .gitmodules submodule section.")

(defconst build-packages-default-excludes
  '("\\`\\.dir-locals\\.el\\'" "-pkg\\.el\\'" "-autoloads\\.el\\'" "-tests?\\.el\\'")
  "Regexps for file names that are never compiled or scanned for autoloads.")

;;;; Reading .gitmodules

(defun build-packages-parse-config-lines (lines)
  "Parse LINES of `git config --get-regexp ^submodule\\.' output into specs.
Each spec is a plist (:name :path :load-path :build-exclude :info), in .gitmodules
order.  Signal an error for an unknown key or a submodule without a path."
  (let (specs)
    (dolist (line lines)
      (unless (string-match "\\`submodule\\.\\(.+\\)\\.\\([^.]+\\) \\(.*\\)\\'" line)
        (error "build-packages: cannot parse .gitmodules line: %S" line))
      (let* ((name (match-string 1 line))
             (key (match-string 2 line))
             (value (match-string 3 line))
             (spec (or (assoc name specs)
                       (car (push (list name) specs)))))
        (unless (member key build-packages-known-keys)
          (error "build-packages: unknown key %S in submodule %S" key name))
        (push value (alist-get key (cdr spec) nil nil #'equal))))
    (mapcar
     (lambda (spec)
       (let* ((name (car spec))
              (keys (cdr spec))
              (path (alist-get "path" keys nil nil #'equal)))
         (unless path
           (error "build-packages: submodule %S has no path" name))
         (list :name name
               :path (car path)
               :load-path (or (reverse (alist-get "load-path" keys nil nil #'equal))
                              '("."))
               :build-exclude (reverse
                               (alist-get "build-exclude" keys nil nil #'equal))
               :info (reverse (alist-get "info" keys nil nil #'equal)))))
     (reverse specs))))

(defun build-packages-read-specs (root)
  "Return the package specs of the .gitmodules file in ROOT."
  (with-temp-buffer
    (let ((status (call-process "git" nil t nil "config" "-f"
                                (expand-file-name ".gitmodules" root)
                                "--get-regexp" "^submodule\\.")))
      (unless (eql status 0)
        (error "build-packages: git config on %s/.gitmodules failed (%s): %s"
               root status (buffer-string)))
      (build-packages-parse-config-lines
       (split-string (buffer-string) "\n" t)))))

;;;; Directories and files

(defun build-packages-load-path-dirs (root spec)
  "Return the absolute load-path directories of SPEC under ROOT.
Signal an error if one is missing (submodule not checked out)."
  (mapcar
   (lambda (dir)
     (let ((abs (directory-file-name
                 (expand-file-name dir (expand-file-name (plist-get spec :path) root)))))
       (unless (file-directory-p abs)
         (error "build-packages: %s missing; run `git submodule update --init'" abs))
       abs))
   (plist-get spec :load-path)))

(defun build-packages-excluded-files (root spec)
  "Return the absolute files SPEC excludes under ROOT.
Signal an error for an exclude naming a file that does not exist, since a
stale exclude would silently start compiling the file once it is renamed back."
  (mapcar
   (lambda (file)
     (let ((abs (expand-file-name file (expand-file-name (plist-get spec :path) root))))
       (unless (file-exists-p abs)
         (error "build-packages: build-exclude %s of %s does not exist"
                file (plist-get spec :name)))
       abs))
   (plist-get spec :build-exclude)))

(defun build-packages-default-excluded-p (file)
  "Return non-nil if FILE matches `build-packages-default-excludes'."
  (let ((name (file-name-nondirectory file)))
    (cl-some (lambda (regexp) (string-match-p regexp name))
             build-packages-default-excludes)))

(defun build-packages-files (root spec)
  "Return the absolute .el files of SPEC under ROOT that are built.
Only the load-path directories themselves are searched, not subdirectories."
  (let ((excluded (build-packages-excluded-files root spec)))
    (cl-loop for dir in (build-packages-load-path-dirs root spec)
             append (cl-loop for file in (directory-files dir t "\\.el\\'")
                             unless (or (build-packages-default-excluded-p file)
                                        (member file excluded))
                             collect file))))

;;;; Generated files

(defun build-packages-write-load-path (root specs file)
  "Write FILE, which adds the load-path directories of SPECS under ROOT.
The directories are stored relative to FILE's directory, so the repository
can move without a rebuild."
  (let* ((base (file-name-directory file))
         (dirs (cl-loop for spec in specs
                        append (mapcar (lambda (dir) (file-relative-name dir base))
                                       (build-packages-load-path-dirs root spec)))))
    (with-temp-file file
      (insert ";;; load-path.el --- Generated by scripts/build-packages.el; "
              "do not edit  -*- lexical-binding: t; -*-\n\n"
              "(let ((base (file-name-directory (file-truename load-file-name))))\n"
              "  (setq load-path\n"
              "        (append (mapcar (lambda (dir) (expand-file-name dir base))\n"
              "                        '" (prin1-to-string dirs) ")\n"
              "                load-path)))\n"))))

;; Built with `concat' so Emacs does not mistake this file's own text for a
;; file-local variables block.
(defconst build-packages--local-variables-line (concat ";; Local " "Variables:")
  "First line of the file-local variables block of a generated file.")

(defun build-packages--directory-autoloads (dir excluded)
  "Return the autoload forms of the .el files in DIR, without EXCLUDED files.
They are generated next to the files, so each names its file by bare library
name (\"projectile\", not \"projectile/projectile\") and resolves through
`load-path' like a package.el autoloads file."
  (let ((tmp (expand-file-name ".build-packages-loaddefs" dir)))
    (unwind-protect
        (progn
          (loaddefs-generate dir tmp excluded)
          (with-temp-buffer
            (insert-file-contents tmp)
            ;; Keep only the forms: drop the header line and the trailing
            ;; file-local variables, which the combined file supplies once.
            (goto-char (point-min))
            (forward-line 1)
            (delete-region (point-min) (point))
            (goto-char (point-max))
            (when (re-search-backward build-packages--local-variables-line nil t)
              (delete-region (point) (point-max)))
            (buffer-string)))
      (when (file-exists-p tmp)
        (delete-file tmp)))))

(defun build-packages-write-autoloads (root specs file)
  "Write FILE with the autoloads of all SPECS under ROOT."
  (let ((pieces
         (cl-loop
          for spec in specs
          for excluded = (build-packages-excluded-files root spec)
          append (cl-loop
                  for dir in (build-packages-load-path-dirs root spec)
                  collect (build-packages--directory-autoloads
                           dir
                           (append excluded
                                   (cl-remove-if-not
                                    #'build-packages-default-excluded-p
                                    (directory-files dir t "\\.el\\'"))))))))
    (with-temp-file file
      (insert ";;; autoloads.el --- Generated by scripts/build-packages.el; "
              "do not edit  -*- lexical-binding: t; -*-\n")
      (dolist (piece pieces)
        (insert piece))
      (insert "\n" build-packages--local-variables-line "\n"
              ";; no-byte-compile: t\n;; no-update-autoloads: t\n;; End:\n"))))

;;;; Info manuals

(defun build-packages-info-files (root spec)
  "Return the absolute Texinfo files SPEC lists under ROOT.
Signal an error for one that does not exist."
  (mapcar
   (lambda (file)
     (let ((abs (expand-file-name file (expand-file-name (plist-get spec :path) root))))
       (unless (file-exists-p abs)
         (error "build-packages: info %s of %s does not exist" file (plist-get spec :name)))
       abs))
   (plist-get spec :info)))

(defun build-packages--run (program &rest args)
  "Run PROGRAM with ARGS; return its output, or signal an error naming the cause."
  (with-temp-buffer
    (let ((status (condition-case nil
                      (apply #'call-process program nil t nil args)
                    (file-missing
                     (error "build-packages: %s not found; install texinfo (D-039)"
                            program)))))
      (unless (eql status 0)
        (error "build-packages: %s %s failed (%s):
%s"
               program (string-join args " ") status (buffer-string)))
      (buffer-string))))

(defun build-packages-write-info (root specs dir)
  "Build the Texinfo manuals of SPECS under ROOT into DIR, with its `dir' index.
DIR is emptied first, so a manual dropped from .gitmodules disappears.
Return the number of manuals."
  (let ((files (cl-loop for spec in specs append (build-packages-info-files root spec))))
    (when (file-directory-p dir)
      (delete-directory dir t))
    (make-directory dir t)
    (dolist (texi files)
      (let ((info (expand-file-name (concat (file-name-base texi) ".info") dir)))
        ;; Warnings (upstream style) pass; only a failure stops the build.
        (build-packages--run "makeinfo" "--no-split" "-o" info texi)
        (build-packages--run "install-info" (concat "--info-dir=" dir) info)))
    (length files)))

;;;; Compilation

(defun build-packages-compile (root specs)
  "Byte-compile every built file of SPECS under ROOT.
Old .elc files are deleted first so no stale code is loaded while compiling.
Signal an error listing every file that failed."
  (let ((files (cl-loop for spec in specs append (build-packages-files root spec)))
        (byte-compile-warnings nil)     ; third-party warnings are not actionable here
        failed)
    (dolist (file files)
      (let ((elc (concat file "c")))
        (when (file-exists-p elc)
          (delete-file elc))))
    (dolist (file files)
      (unless (byte-compile-file file)
        (push file failed)))
    (when failed
      (error "build-packages: %d file(s) failed to compile:\n  %s"
             (length failed) (string-join (nreverse failed) "\n  ")))
    (length files)))

(defun build-packages-build (root)
  "Build all packages of the repository at ROOT."
  (let* ((specs (build-packages-read-specs root))
         (lib (expand-file-name "lib" root)))
    ;; Dependencies must be loadable while their dependents compile.
    (setq load-path (append (cl-loop for spec in specs
                                     append (build-packages-load-path-dirs root spec))
                            load-path))
    (let ((count (build-packages-compile root specs)))
      (build-packages-write-load-path root specs (expand-file-name "load-path.el" lib))
      (build-packages-write-autoloads root specs (expand-file-name "autoloads.el" lib))
      (message "build-packages: %d packages, %d files compiled, %d manuals"
               (length specs) count
               (build-packages-write-info root specs (expand-file-name "info" lib))))))

(defun build-packages-batch ()
  "Entry point for `make packages'."
  (build-packages-build build-packages-root))

(provide 'build-packages)
;;; build-packages.el ends here
