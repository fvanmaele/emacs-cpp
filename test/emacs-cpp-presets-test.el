;;; emacs-cpp-presets-test.el --- Tests for lisp/emacs-cpp-presets.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests on temporary project directories; no cmake or clangd needed.

;;; Code:

(require 'ert)
(require 'emacs-cpp-presets)

(defconst emacs-cpp-presets-test--presets
  "{\"version\": 6, \"configurePresets\": [
     {\"name\": \"base\", \"hidden\": true, \"generator\": \"Ninja\",
      \"binaryDir\": \"${sourceDir}/build/${presetName}\",
      \"environment\": {\"FLAVOUR\": \"base\"}},
     {\"name\": \"debug\", \"inherits\": \"base\"},
     {\"name\": \"release\", \"inherits\": [\"base\"],
      \"binaryDir\": \"out/$env{FLAVOUR}-${generator}\"}]}"
  "A presets file like the reference project's, plus macros and an override.")

(defmacro emacs-cpp-presets-test--with-project (files &rest body)
  "Create FILES, an alist (NAME . CONTENT), in a temporary `root'; run BODY.
`emacs-cpp-presets-state-file' is redirected into the temporary directory."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-presets-test" t)))
          (emacs-cpp-presets-state-file (expand-file-name "state.eld" root)))
     (unwind-protect
         (progn
           (pcase-dolist (`(,name . ,content) ,files)
             (let ((file (expand-file-name name root)))
               (make-directory (file-name-directory file) t)
               (write-region content nil file)))
           ,@body)
       (delete-directory root t))))

(ert-deftest emacs-cpp-presets-visible-names-skip-hidden ()
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets))
    (should (equal (emacs-cpp-presets-visible-names (emacs-cpp-presets-read root))
                   '("debug" "release")))))

(ert-deftest emacs-cpp-presets-binary-dir-follows-inherits-and-macros ()
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets))
    (should (equal (emacs-cpp-presets-binary-dir root "debug")
                   (expand-file-name "build/debug" root)))
    ;; Own binaryDir overrides the parent's; relative to the source directory.
    (should (equal (emacs-cpp-presets-binary-dir root "release")
                   (expand-file-name "out/base-Ninja" root)))))

(ert-deftest emacs-cpp-presets-user-presets-are-read ()
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets)
        ("CMakeUserPresets.json" .
         "{\"version\": 6, \"configurePresets\": [{\"name\": \"mine\", \"inherits\": \"base\"}]}"))
    (should (equal (emacs-cpp-presets-visible-names (emacs-cpp-presets-read root))
                   '("debug" "release" "mine")))
    (should (equal (emacs-cpp-presets-binary-dir root "mine")
                   (expand-file-name "build/mine" root)))))

(ert-deftest emacs-cpp-presets-errors-instead-of-guessing ()
  ;; No presets file at all (D-005).
  (emacs-cpp-presets-test--with-project '(("README" . ""))
    (should-error (emacs-cpp-presets-read root) :type 'user-error))
  ;; `include' is not supported.
  (emacs-cpp-presets-test--with-project
      '(("CMakePresets.json" . "{\"version\": 6, \"include\": [\"x.json\"]}"))
    (should-error (emacs-cpp-presets-read root)))
  ;; Unknown macro, inheritance cycle, duplicate name.
  (emacs-cpp-presets-test--with-project
      '(("CMakePresets.json" .
         "{\"version\": 6, \"configurePresets\": [
            {\"name\": \"v\", \"binaryDir\": \"$vendor{x}/b\"},
            {\"name\": \"a\", \"inherits\": \"b\"}, {\"name\": \"b\", \"inherits\": \"a\"}]}"))
    (should-error (emacs-cpp-presets-binary-dir root "v"))
    (should-error (emacs-cpp-presets-resolve (emacs-cpp-presets-read root) "a")))
  (emacs-cpp-presets-test--with-project
      '(("CMakePresets.json" .
         "{\"version\": 6, \"configurePresets\": [{\"name\": \"d\"}, {\"name\": \"d\"}]}"))
    (should-error (emacs-cpp-presets-read root))))

(ert-deftest emacs-cpp-presets-active-defaults-stores-and-rejects-stale ()
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets))
    (should (equal (emacs-cpp-presets-active root) "debug"))
    (emacs-cpp-presets--store root "release")
    (should (equal (emacs-cpp-presets-active root) "release"))
    ;; A stored preset that disappeared is an error, not a silent default.
    (emacs-cpp-presets--store root "gone")
    (should-error (emacs-cpp-presets-active root) :type 'user-error)))

(ert-deftest emacs-cpp-presets-database-must-carry-std ()
  (emacs-cpp-presets-test--with-project
      '(("ok.json" . "[{\"file\": \"a.cc\", \"command\": \"c++ -std=c++20 -c a.cc\"},
                      {\"file\": \"b.cc\", \"arguments\": [\"c++\", \"-std=gnu++20\", \"b.cc\"]}]")
        ("bad.json" . "[{\"file\": \"a.cc\", \"command\": \"c++ -c a.cc\"}]"))
    (should-not (emacs-cpp-presets-check-database (expand-file-name "ok.json" root)))
    (should-error (emacs-cpp-presets-check-database (expand-file-name "bad.json" root))
                  :type 'user-error)))

(ert-deftest emacs-cpp-presets-clangd-contact ()
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets))
    (let ((project (cons 'transient root))
          (warning-minimum-log-level :emergency))
      ;; Not configured yet: refused with the command to run.
      (should-error (emacs-cpp-presets-clangd-contact nil project) :type 'user-error)
      (make-directory (expand-file-name "build/debug" root) t)
      (write-region "[{\"file\": \"a.cc\", \"command\": \"c++ -std=c++20 -c a.cc\"}]"
                    nil (expand-file-name "build/debug/compile_commands.json" root))
      (should (equal (emacs-cpp-presets-clangd-contact nil project)
                     (list "clangd" (concat "--compile-commands-dir="
                                            (expand-file-name "build/debug" root))))))))

(provide 'emacs-cpp-presets-test)
;;; emacs-cpp-presets-test.el ends here
