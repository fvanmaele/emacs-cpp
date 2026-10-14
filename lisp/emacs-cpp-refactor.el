;;; emacs-cpp-refactor.el --- C++ refactorings by clang's command-line tools  -*- lexical-binding: t; -*-

;;; Commentary:

;; Refactorings clangd does not offer, by the command-line tools that come with
;; clang (D-094, O-43 (c)): clang-tidy's fixes over the whole project
;; (run-clang-tidy -fix) and moving classes to other files (clang-move).  Each
;; runs on the active preset's compilation database (lisp/emacs-cpp-presets.el) in a
;; compilation buffer from the project root, and afterwards reverts the unmodified
;; buffers whose files it changed.  The tools come from the platform's directory
;; (`emacs-cpp-default-llvm-tools-dir', D-055).
;;
;; Renaming a namespace (D-097) takes clang-change-namespace with a crash fix, built
;; by packaging/clang-change-namespace/build.sh (LLVM 23's own crashes on two
;; sources, D-094).  The tool moves the namespace's code and re-qualifies the
;; references inside it, never the uses outside; those (`old::') are then replaced
;; through an editable list of every line, as MANUAL 8's route by hand.

;;; Code:

(require 'emacs-cpp-presets)
(require 'compile)
(require 'cl-lib)
(require 'grep)
(require 'xref)

(defcustom emacs-cpp-refactor-change-namespace-program
  "~/opt/clang-change-namespace/bin/clang-change-namespace"
  "Patched clang-change-namespace from packaging/clang-change-namespace (D-097).
`C-c l N' refuses to run when it is missing; LLVM 23's own crashes on two or
more sources (D-094)."
  :type 'file
  :group 'tools)

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

(defun emacs-cpp-refactor--run (root arguments &optional directory note then)
  "Run the shell-quoted ARGUMENTS in a compilation buffer, from DIRECTORY or ROOT.
Modified buffers are saved first, asking as `compile' does; when the tool is
done, the buffers under ROOT it changed are reverted and NOTE, if any, shown.
THEN, if non-nil, is called without arguments after a run that succeeded."
  (save-some-buffers (not compilation-ask-about-save))
  (let* ((default-directory (or directory root))
         (buffer (compilation-start (mapconcat #'shell-quote-argument arguments " "))))
    (with-current-buffer buffer
      (add-hook 'compilation-finish-functions
                (lambda (_buffer status)
                  (emacs-cpp-refactor--revert root)
                  (when note (message "%s" note))
                  (when (and then (string-prefix-p "finished" status))
                    (funcall then)))
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

;;;; Renaming a namespace (D-097)

(defconst emacs-cpp-refactor--namespace-regexp
  "\\`[A-Za-z_][A-Za-z0-9_]*\\(?:::[A-Za-z_][A-Za-z0-9_]*\\)*\\'"
  "A namespace name as the tool takes it: `a' or `a::b', without a leading `::'.")

(defun emacs-cpp-refactor--change-namespace-program ()
  "Return the patched clang-change-namespace, or signal an error when missing."
  (let ((file (expand-file-name emacs-cpp-refactor-change-namespace-program)))
    (unless (file-executable-p file)
      (user-error "emacs-cpp: %s not found; build it with \
packaging/clang-change-namespace/build.sh, or set \
`emacs-cpp-refactor-change-namespace-program' (D-097)" file))
    file))

(defun emacs-cpp-refactor--ere-quote (string)
  "Quote STRING for a POSIX extended regular expression (the tool's -file_pattern)."
  (replace-regexp-in-string "[][.*+?^$(){}|\\]" "\\\\\\&" string))

(defun emacs-cpp-refactor--qualified-use (old)
  "Return a regexp matching `OLD::' as a qualifier, its group 1 being `OLD::'.
Not when OLD is the end of a longer name (`xOLD::') or nested in another
namespace (`outer::OLD::'); `::OLD::', the global one, is."
  (concat "\\(?:^\\|[^[:alnum:]_:]\\|\\(?:^\\|[^[:alnum:]_:]\\)::\\)\\("
          (regexp-quote old) "::\\)"))

(defun emacs-cpp-refactor--namespace-uses (root old new)
  "Replace the uses `OLD::' with `NEW::' in ROOT's project files, through a list.
The list is a grep buffer in Emacs 31's grep-edit mode, one line per changed
line, already edited: each edit is in its file's buffer, not saved.  Return the
list buffer, or nil (and a message) when no use is left."
  (let* ((files (project-files (project-current nil root)))
         (use (emacs-cpp-refactor--qualified-use old))
         (default-directory root)
         (case-fold-search nil)
         hits lines)
    ;; xref finds the lines; their text is read from the files, as xref splits a
    ;; line with several matches into pieces.
    (dolist (item (xref-matches-in-files (regexp-quote (concat old "::")) files))
      (let ((location (xref-item-location item)))
        (cl-pushnew (xref-file-location-line location)
                    (alist-get (xref-file-location-file location) hits nil nil #'equal))))
    (pcase-dolist (`(,file . ,numbers) (nreverse hits))
      (with-temp-buffer
        (insert-file-contents file)
        (dolist (line (sort numbers #'<))
          (goto-char (point-min))
          (forward-line (1- line))
          (let ((text (buffer-substring-no-properties (point) (line-end-position))))
            (when (string-match-p use text)
              (push (list (file-relative-name file root) line text
                          (replace-regexp-in-string use (concat new "::") text t t 1))
                    lines))))))
    (if (null lines)
        (progn (message "emacs-cpp: no uses of %s:: left in the project" old) nil)
      (setq lines (nreverse lines))
      (let ((buffer (get-buffer-create (format "*namespace %s -> %s*" old new))))
        (with-current-buffer buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (grep-mode)
            (setq default-directory root)
            (insert (format "Uses of %s:: replaced with %s:: (in the files' buffers):\n\n"
                            old new))
            (pcase-dolist (`(,file ,line ,text ,_) lines)
              (insert (format "%s:%d:%s\n" file line text))))
          ;; grep-edit needs the lines parsed as matches, which font-lock does.
          (font-lock-ensure)
          (grep-change-to-grep-edit-mode)
          (goto-char (point-min))
          (forward-line 2)
          (pcase-dolist (`(,file ,line ,_ ,replaced) lines)
            (forward-char (length (format "%s:%d:" file line)))
            (delete-region (point) (line-end-position))
            (insert replaced)
            (forward-line 1))
          (goto-char (point-min)))
        (pop-to-buffer buffer)
        (message "emacs-cpp: %s:: -> %s:: on %d lines of %d files, not saved: check \
the list (C-/ there takes a change back), C-c C-c ends editing, C-x s saves"
                 old new (length lines)
                 (length (delete-dups (mapcar #'car lines))))
        buffer))))

(defun emacs-cpp-refactor-change-namespace (old new)
  "Rename the namespace OLD to NEW in the whole project (D-097).
clang-change-namespace moves the namespace's code in every source of the
active preset's database and the headers they include, and re-qualifies the
references inside it; then the uses outside, `OLD::', become `NEW::' through
an editable list (`emacs-cpp-refactor--namespace-uses')."
  (interactive
   (let ((old (read-string "Namespace to rename (a or a::b): " (thing-at-point 'symbol t))))
     (list old (read-string (format "Rename %s to: " old)))))
  (dolist (name (list old new))
    (unless (string-match-p emacs-cpp-refactor--namespace-regexp name)
      (user-error "emacs-cpp: %S is not a namespace name (a or a::b)" name)))
  (pcase-let* ((program (emacs-cpp-refactor--change-namespace-program))
               (`(,root ,build ,sources) (emacs-cpp-refactor--project))
               (roots (delete-dups (list (directory-file-name root)
                                         (directory-file-name (file-truename root))))))
    (emacs-cpp-refactor--run
     root
     `(,program ,(concat "-old_namespace=" old) ,(concat "-new_namespace=" new)
       ;; Only the project's files, never a library header that has the namespace.
       ,(concat "-file_pattern=^("
                (mapconcat #'emacs-cpp-refactor--ere-quote roots "|") ")/")
       ;; No -style: the tool takes it as its fallback style too, where `file' is
       ;; refused and the clean-up skipped; it formats its edits in LLVM style.
       "-i" "-p" ,build ,@sources)
     nil nil
     (lambda () (emacs-cpp-refactor--namespace-uses root old new)))))

(provide 'emacs-cpp-refactor)
;;; emacs-cpp-refactor.el ends here
