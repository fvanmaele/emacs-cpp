;;; init-cpp-test.el --- eglot and clangd on a toy preset project  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests in the shipped profile.  A throw-away CMake project with presets
;; is configured and a C++ file opened; eglot must start through the real hook path
;; (`c++-ts-mode-hook' -> `emacs-cpp-presets-eglot-ensure' -> `eglot-ensure', which
;; connects after the next command), with clangd given the preset's build directory.
;; Go-to-definition must reach another file, a library header reached that way must
;; join the same server (D-019), and a clang-tidy finding must reach flymake.
;; Needs cmake, ninja, c++, clangd and git.

;;; Code:

(require 'ert)
(require 'init-test)

(defconst init-cpp-test--files
  '(("CMakeLists.txt" . "cmake_minimum_required(VERSION 3.28)
project(toy CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)
add_executable(toy src/main.cc src/answer.cc)
target_include_directories(toy PRIVATE include)
")
    ("CMakePresets.json" . "{\"version\": 6, \"configurePresets\": [
  {\"name\": \"debug\", \"generator\": \"Ninja\",
   \"binaryDir\": \"${sourceDir}/build/${presetName}\",
   \"cacheVariables\": {\"CMAKE_EXPORT_COMPILE_COMMANDS\": \"ON\"}}]}
")
    ("include/toy/answer.h" . "#pragma once\nint answer();\n")
    ("src/answer.cc" . "#include <toy/answer.h>\nint answer() { return 42; }\n")
    ("src/main.cc" . "#include <toy/answer.h>
#include <vector>
int main() {
  int* unused = 0;
  std::vector<int> values;
  return answer() + (unused == 0) + static_cast<int>(values.size());
}
")
    (".clang-tidy" . "Checks: 'modernize-use-nullptr'\n"))
  "The toy project: one definition in another file behind an include path, one
library type, and one clang-tidy finding (`0' for a null pointer).")

(defmacro init-cpp-test--with-project (files &rest body)
  "Write FILES into a temporary git project bound to `root', run BODY, clean up.
Every buffer visited under ROOT or reached from it is killed afterwards, and
any eglot server shut down."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-toy" t)))
          (default-directory root)
          (emacs-cpp-presets-state-file (expand-file-name "state.eld" root))
          (buffers-before (buffer-list)))
     (unwind-protect
         (progn
           (pcase-dolist (`(,name . ,content) ,files)
             (let ((file (expand-file-name name root)))
               (make-directory (file-name-directory file) t)
               (write-region content nil file)))
           (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
           ,@body)
       (dolist (server (and (boundp 'eglot--servers-by-project)
                            (apply #'append (hash-table-values eglot--servers-by-project))))
         (eglot-shutdown server))
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (kill-buffer buffer)))
       (delete-directory root t))))

(defun init-cpp-test--visit (file)
  "Visit FILE and run one command loop step, as an interactive visit would.
`eglot-ensure' connects from `post-command-hook'."
  (let ((buffer (find-file-noselect file)))
    (with-current-buffer buffer
      (run-hooks 'post-command-hook))
    buffer))

(defun init-cpp-test--definition-file (buffer text)
  "Return the file of the first definition of the identifier TEXT in BUFFER."
  (with-current-buffer buffer
    (goto-char (point-min))
    (search-forward text)
    (goto-char (1+ (match-beginning 0)))
    (let ((items (xref-backend-definitions 'eglot (xref-backend-identifier-at-point 'eglot))))
      (and items (xref-location-group (xref-item-location (car items)))))))

(defun init-cpp-test--tidy-diagnostic ()
  "Return the first flymake diagnostic of the current buffer from clang-tidy."
  (cl-find-if (lambda (diagnostic)
                (string-match-p "modernize-use-nullptr" (flymake-diagnostic-text diagnostic)))
              (flymake-diagnostics)))

(ert-deftest init-cpp-eglot-starts-navigates-and-reports-clang-tidy ()
  (init-test--load)
  (init-cpp-test--with-project init-cpp-test--files
    (should (eql 0 (call-process "cmake" nil nil nil "--preset" "debug")))
    (let ((main (init-cpp-test--visit (expand-file-name "src/main.cc" root))))
      (with-current-buffer main
        (should (eq major-mode 'c++-ts-mode))
        ;; Started by the hook, with the preset's build directory (D-016).
        (should (eglot-managed-p))
        (should (equal (process-command (jsonrpc--process (eglot-current-server)))
                       (list "clangd" (concat "--compile-commands-dir="
                                              (expand-file-name "build/debug" root))))))
      ;; M-. crosses files inside the project ...
      (should (member (file-name-nondirectory
                       (init-cpp-test--definition-file main "answer()"))
                      '("answer.h" "answer.cc")))
      ;; ... and into a library header, which joins the same server (D-019).
      (let* ((library-file (init-cpp-test--definition-file main "vector<int>"))
             (library (init-cpp-test--visit library-file)))
        (should (string-prefix-p "/usr/" library-file))
        (with-current-buffer library
          (should (eglot-managed-p))
          (should (eq (eglot-current-server)
                      (with-current-buffer main (eglot-current-server))))))
      ;; clangd runs clang-tidy by default; the project's .clang-tidy picks checks.
      ;; Batch has no idle timers, so flymake is started by hand.
      (with-current-buffer main
        (flymake-start)
        (let ((deadline (+ (float-time) 30)))
          (while (and (not (init-cpp-test--tidy-diagnostic)) (< (float-time) deadline))
            (accept-process-output nil 0.2)))
        (should (init-cpp-test--tidy-diagnostic))))))

(ert-deftest init-cpp-code-map-on-c-c-l ()
  "T-007, D-004: every proposed letter under `C-c l' runs its command, and
which-key lists all of them."
  (init-test--load)
  (let ((expected '(("r" . eglot-rename) ("a" . eglot-code-actions)
                    ("f" . eglot-format) ("i" . eglot-find-implementation)
                    ("d" . eglot-find-declaration) ("h" . eglot-show-call-hierarchy)
                    ("t" . eglot-show-type-hierarchy) ("o" . projectile-find-other-file)
                    ("s" . consult-eglot-symbols) ("e" . flymake-show-project-diagnostics)
                    ("I" . eglot-inlay-hints-mode) ("P" . emacs-cpp-presets-select))))
    (pcase-dolist (`(,key . ,command) expected)
      (should (eq (keymap-lookup global-map (concat "C-c l " key)) command))
      (should (commandp command)))
    (require 'which-key)
    (let ((listed (mapcar #'car (which-key--get-bindings (kbd "C-c l")))))
      (should (equal (sort (copy-sequence listed) #'string<)
                     (sort (mapcar #'car expected) #'string<))))))

(ert-deftest init-cpp-breadcrumb-shows-path-and-function ()
  "T-017, D-043: the header line of a C++ buffer names the project-relative path
and the function at point."
  (init-test--load)
  (init-cpp-test--with-project init-cpp-test--files
    (with-current-buffer (find-file-noselect (expand-file-name "src/answer.cc" root))
      (should breadcrumb-local-mode)
      (should (member '(:eval (breadcrumb--header-line)) header-line-format))
      (goto-char (point-min))
      (search-forward "return 42")
      ;; breadcrumb rescans on an idle timer; batch has none, so scan here.
      (imenu--make-index-alist t)
      (let ((header (substring-no-properties (breadcrumb--header-line))))
        (should (string-match-p "src/answer\\.cc" header))
        (should (string-match-p "answer\\'" header))))))

(defun init-cpp-test--patched-clangd ()
  "The patched clangd to test (D-026), or nil when it is not installed."
  (let ((program (or (getenv "EMACS_CPP_PATCHED_CLANGD")
                     "/opt/clangd-index-nav/bin/clangd")))
    (and (file-executable-p program) program)))

(ert-deftest init-cpp-patched-clangd-navigates ()
  "D-026: with `emacs-cpp-clangd-program' set, eglot runs it with the index flags."
  (init-test--load)
  (let ((program (init-cpp-test--patched-clangd)))
    (unless program
      (ert-skip "patched clangd not installed (packaging/clangd-index-nav)"))
    (init-cpp-test--with-project init-cpp-test--files
      (should (eql 0 (call-process "cmake" nil nil nil "--preset" "debug")))
      (let* ((emacs-cpp-clangd-program program)
             (main (init-cpp-test--visit (expand-file-name "src/main.cc" root))))
        (with-current-buffer main
          (should (eglot-managed-p))
          (should (equal (process-command (jsonrpc--process (eglot-current-server)))
                         (list program
                               (concat "--compile-commands-dir="
                                       (expand-file-name "build/debug" root))
                               "--navigation-from-index"
                               "--header-flags-from-index"))))
        (should (member (file-name-nondirectory
                         (init-cpp-test--definition-file main "answer()"))
                        '("answer.h" "answer.cc")))
        (with-current-buffer main
          (goto-char (point-min))
          (search-forward "answer()")
          (goto-char (1+ (match-beginning 0)))
          ;; In a first session clangd knows other files' references only once
          ;; it has indexed them; the system clangd also returns just the call
          ;; here (measured 2026-10-08), so only that one is required.
          (should (xref-backend-references
                   'eglot (xref-backend-identifier-at-point 'eglot))))))))

(ert-deftest init-cpp-eglot-only-for-preset-projects ()
  (init-test--load)
  ;; A project without presets: no server, an echo-area note instead (D-005).
  (init-cpp-test--with-project '(("src/main.cc" . "int main() { return 0; }\n"))
    (let ((warning-minimum-log-level :emergency))
      (with-current-buffer (init-cpp-test--visit (expand-file-name "src/main.cc" root))
        (should (eq major-mode 'c++-ts-mode))
        ;; eglot may not even be loaded yet, so ask its mode variable.
        (should-not (bound-and-true-p eglot--managed-mode)))))
  ;; A file in no project at all (like a library header opened directly).
  (let* ((dir (file-name-as-directory (make-temp-file "emacs-cpp-loose" t)))
         (file (expand-file-name "loose.h" dir)))
    (unwind-protect
        (progn
          (write-region "int loose();\n" nil file)
          (let ((buffer (init-cpp-test--visit file)))
            (with-current-buffer buffer
              (should-not (project-current))
              (should-not (bound-and-true-p eglot--managed-mode)))
            (kill-buffer buffer)))
      (delete-directory dir t))))

(provide 'init-cpp-test)
;;; init-cpp-test.el ends here
