;;; emacs-cpp-refactor-test.el --- clang's refactoring tools from Emacs  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-094): `C-c l T' and `C-c l M' build their command
;; lines from the active preset's database and the platform's tool directory; a
;; missing tool is refused by name; clang-move runs where the old source's #include
;; of the old header starts.  The process is a stub; real runs on a generated
;; project are in journal 0063.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defmacro emacs-cpp-refactor-test--with-project (&rest body)
  "Run BODY in a temporary preset project bound to `root', with stubbed tools.
`ran' holds (DIRECTORY ARGUMENTS) of each `compilation-start', the command line
split back into its arguments."
  (declare (indent 0))
  `(let* ((root (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-ref" t))))
          (tools (file-name-as-directory (make-temp-file "emacs-cpp-tools" t)))
          (default-directory root)
          (emacs-cpp-presets-state-file (expand-file-name "state.eld" root))
          (emacs-cpp-default-llvm-tools-dir tools)
          ran)
     (unwind-protect
         (progn
           (dolist (tool '("run-clang-tidy" "clang-tidy" "clang-apply-replacements"
                           "clang-move"))
             (let ((file (expand-file-name tool tools)))
               (write-region "#!/bin/sh\n" nil file)
               (set-file-modes file #o755)))
           (make-directory (expand-file-name "build/debug" root) t)
           (make-directory (expand-file-name "include/geom" root) t)
           (make-directory (expand-file-name "src" root) t)
           (write-region "{\"version\": 6, \"configurePresets\": [{\"name\": \"debug\",
  \"binaryDir\": \"${sourceDir}/build/${presetName}\"}]}" nil
                         (expand-file-name "CMakePresets.json" root))
           (write-region (format "[{\"directory\": %S, \"file\": \"src/a.cc\",
  \"command\": \"c++ -std=c++20 -c src/a.cc\"}]" root)
                         nil (expand-file-name "build/debug/compile_commands.json" root))
           (write-region "class Foo {};\n" nil (expand-file-name "include/geom/a.h" root))
           (write-region "#include \"geom/a.h\"\n" nil (expand-file-name "src/a.cc" root))
           (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
           (cl-letf (((symbol-function 'compilation-start)
                      (lambda (command &rest _)
                        (push (list default-directory (split-string-shell-command command))
                              ran)
                        (get-buffer-create " *emacs-cpp-refactor-test*")))
                     ((symbol-function 'save-some-buffers) #'ignore))
             ,@body))
       (delete-directory root t)
       (delete-directory tools t))))

(ert-deftest emacs-cpp-refactor-tidy-fix-command ()
  "D-094: run-clang-tidy -fix on the preset's database; checks as one argument."
  (init-test--load)
  (emacs-cpp-refactor-test--with-project
    (emacs-cpp-refactor-tidy-fix "-*,modernize-use-nullptr")
    (pcase-let ((`(,dir ,args) (car ran)))
      (should (equal dir root))
      (should (equal (file-name-nondirectory (car args)) "run-clang-tidy"))
      (should (equal (cdr args)
                     (list "-p" (concat root "build/debug") "-fix" "-quiet"
                           "-clang-tidy-binary" (concat emacs-cpp-default-llvm-tools-dir "clang-tidy")
                           "-clang-apply-replacements-binary"
                           (concat emacs-cpp-default-llvm-tools-dir "clang-apply-replacements")
                           "-checks=-*,modernize-use-nullptr"))))
    ;; Empty checks: the project's .clang-tidy.
    (emacs-cpp-refactor-tidy-fix "")
    (should-not (seq-find (lambda (a) (string-prefix-p "-checks" a)) (cadr (car ran))))))

(ert-deftest emacs-cpp-refactor-move-command ()
  "D-094: clang-move from the include root, new header relative to it, the old
header including the new one."
  (init-test--load)
  (emacs-cpp-refactor-test--with-project
    (emacs-cpp-refactor-move "Foo" (concat root "include/geom/a.h") (concat root "src/a.cc")
                             (concat root "include/geom/b.h") (concat root "src/b.cc"))
    (pcase-let ((`(,dir ,args) (car ran)))
      (should (equal dir (concat root "include/")))
      (should (member "-names=Foo" args))
      (should (member "-new_header=geom/b.h" args))
      (should (member (concat "-old_cc=" root "src/a.cc") args))
      (should (member "-old_depend_on_new" args)))
    ;; A source that does not include the header is refused.
    (write-region "int x;\n" nil (expand-file-name "src/a.cc" root))
    (should-error (emacs-cpp-refactor-move "Foo" (concat root "include/geom/a.h")
                                           (concat root "src/a.cc")
                                           (concat root "include/geom/b.h")
                                           (concat root "src/b.cc"))
                  :type 'user-error)))

(ert-deftest emacs-cpp-refactor-missing-tool ()
  "D-094: a tool not in the platform's directory is refused by name."
  (init-test--load)
  (emacs-cpp-refactor-test--with-project
    (delete-file (expand-file-name "clang-move" emacs-cpp-default-llvm-tools-dir))
    (should-error (emacs-cpp-refactor-move "Foo" (concat root "include/geom/a.h")
                                           (concat root "src/a.cc")
                                           (concat root "include/geom/b.h")
                                           (concat root "src/b.cc"))
                  :type 'user-error)))

(ert-deftest emacs-cpp-refactor-keys ()
  "D-094: `C-c l T' and `C-c l M'."
  (init-test--load)
  (should (eq (keymap-lookup emacs-cpp-code-map "T") #'emacs-cpp-refactor-tidy-fix))
  (should (eq (keymap-lookup emacs-cpp-code-map "M") #'emacs-cpp-refactor-move)))

(provide 'emacs-cpp-refactor-test)
;;; emacs-cpp-refactor-test.el ends here
