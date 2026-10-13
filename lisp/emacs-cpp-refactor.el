;;; emacs-cpp-refactor.el --- C++ refactorings by clang's command-line tools  -*- lexical-binding: t; -*-

;;; Commentary:

;; Refactorings clangd does not offer, by the command-line tools that come with
;; clang (D-094, O-43 (c)): clang-tidy's fixes over the whole project
;; (run-clang-tidy -fix) and moving classes to other files (clang-move).
;; clang-change-namespace is not offered: LLVM 23.1.3's crashes on two sources and
;; half-edits a project one source at a time (D-094).  Each
;; runs on the active preset's compilation database (lisp/emacs-cpp-presets.el) in a
;; compilation buffer from the project root, and afterwards reverts the unmodified
;; buffers whose files it changed.  The tools come from the platform's directory
;; (`emacs-cpp-default-llvm-tools-dir', D-055).

;;; Code:

(require 'emacs-cpp-presets)
(require 'compile)

(defun emacs-cpp-refactor--tool (name)
  "Return the absolute file name of the clang tool NAME, or signal an error."
  (let ((file (if emacs-cpp-default-llvm-tools-dir
                  (expand-file-name name emacs-cpp-default-llvm-tools-dir)
                (executable-find name))))
    (unless (and file (file-executable-p file))
      (user-error "emacs-cpp: %s not found%s; it comes with clang (D-094)" name
                  (if emacs-cpp-default-llvm-tools-dir
                      (format " in %s" emacs-cpp-default-llvm-tools-dir)
                    " on exec-path")))
    file))

(defun emacs-cpp-refactor--project ()
  "Return (ROOT DATABASE-DIR SOURCES) of the current project's active preset.
SOURCES are the files its compilation database lists."
  (pcase-let* ((`(,root ,_name ,dir) (emacs-cpp-presets--current))
               (build (expand-file-name dir root))
               (database (expand-file-name "compile_commands.json" build)))
    (unless (file-exists-p database)
      (user-error "emacs-cpp: no %s; configure the preset first (C-c p c o)" database))
    (emacs-cpp-presets-check-database database)
    (list root build
          (mapcar (lambda (entry)
                    (expand-file-name (alist-get 'file entry)
                                      (alist-get 'directory entry)))
                  (emacs-cpp-presets--read-json database :object-type 'alist
                                                :array-type 'list)))))

(defun emacs-cpp-refactor--revert (root)
  "Revert the buffers of files under ROOT changed on disk and not modified here."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and buffer-file-name
                 (string-prefix-p root buffer-file-name)
                 (not (buffer-modified-p))
                 (not (verify-visited-file-modtime buffer)))
        (revert-buffer t t t)))))

(defun emacs-cpp-refactor--run (root arguments &optional directory note)
  "Run the shell-quoted ARGUMENTS in a compilation buffer, from DIRECTORY or ROOT.
Modified buffers are saved first, asking as `compile' does; when the tool is
done, the buffers under ROOT it changed are reverted and NOTE, if any, shown."
  (save-some-buffers (not compilation-ask-about-save))
  (let* ((default-directory (or directory root))
         (buffer (compilation-start (mapconcat #'shell-quote-argument arguments " "))))
    (with-current-buffer buffer
      (add-hook 'compilation-finish-functions
                (lambda (_buffer _status)
                  (emacs-cpp-refactor--revert root)
                  (when note (message "%s" note)))
                nil t))
    buffer))

(defun emacs-cpp-refactor--include-root (header source)
  "Return the directory HEADER is included from in SOURCE.
clang-move writes the new header's #include as its path relative to the
directory it runs in, so it runs where SOURCE's #include of HEADER starts."
  (let ((spelled
         (with-temp-buffer
           (insert-file-contents source)
           (when (re-search-forward
                  (concat "^[ \t]*#[ \t]*include[ \t]*[\"<]\\([^\">]*"
                          (regexp-quote (file-name-nondirectory header))
                          "\\)[\">]")
                          nil t)
             (match-string 1)))))
    (unless (and spelled (string-suffix-p spelled header))
      (user-error "emacs-cpp: %s does not #include %s; clang-move needs it to"
                  source header))
    (substring header 0 (- (length header) (length spelled)))))

(defun emacs-cpp-refactor-tidy-fix (checks)
  "Apply clang-tidy's fixes for CHECKS to every file of the project (D-094).
An empty CHECKS uses the project's .clang-tidy, as clangd's diagnostics do."
  (interactive (list (read-string "clang-tidy checks to fix (empty: .clang-tidy): ")))
  (pcase-let ((`(,root ,build ,_sources) (emacs-cpp-refactor--project)))
    (emacs-cpp-refactor--run
     root
     `(,(emacs-cpp-refactor--tool "run-clang-tidy") "-p" ,build "-fix" "-quiet"
       "-clang-tidy-binary" ,(emacs-cpp-refactor--tool "clang-tidy")
       "-clang-apply-replacements-binary"
       ,(emacs-cpp-refactor--tool "clang-apply-replacements")
       ;; One argument: a value starting with `-' would be read as an option.
       ,@(unless (string-empty-p checks) (list (concat "-checks=" checks)))))))

(defun emacs-cpp-refactor-move (names old-header old-cc new-header new-cc)
  "Move the classes NAMES from OLD-HEADER / OLD-CC to NEW-HEADER / NEW-CC.
NAMES is comma-separated, qualified as needed (\"Foo,ns::Bar\"); the new files
are created when missing (clang-move, D-094).  The new header is #included like
the old one (relative to the same directory), and the old header #includes the
new one, so the code using the classes keeps compiling.  The new source must
still be added to the build (CMakeLists.txt); a message says so."
  (interactive
   (let* ((names (read-string "Classes to move (Foo,ns::Bar): " (thing-at-point 'symbol t)))
          (old-header (read-file-name "From header: " nil nil t))
          (old-cc (read-file-name "From source: " nil nil t))
          (new-header (read-file-name "To header: "))
          (new-cc (read-file-name "To source: ")))
     (list names old-header old-cc new-header new-cc)))
  (pcase-let* ((`(,root ,build ,_sources) (emacs-cpp-refactor--project))
               (old-header (expand-file-name old-header))
               (old-cc (expand-file-name old-cc))
               (include-root (emacs-cpp-refactor--include-root old-header old-cc)))
    (emacs-cpp-refactor--run
     root
     `(,(emacs-cpp-refactor--tool "clang-move") ,(concat "-names=" names)
       ,(concat "-old_header=" old-header) ,(concat "-old_cc=" old-cc)
       ,(concat "-new_header=" (file-relative-name (expand-file-name new-header)
                                                   include-root))
       ,(concat "-new_cc=" (expand-file-name new-cc))
       "-old_depend_on_new" "-p" ,build ,old-cc)
     include-root
     (format "Moved %s; add %s to its target in CMakeLists.txt" names
             (file-relative-name (expand-file-name new-cc) root)))))

(provide 'emacs-cpp-refactor)
;;; emacs-cpp-refactor.el ends here
