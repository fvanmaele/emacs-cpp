;;; init-cpp-test.el --- eglot and clangd on a toy preset project  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration test in the shipped profile: a throw-away CMake project with presets is
;; configured, a C++ file is opened, eglot starts clangd through
;; `emacs-cpp-presets-clangd-contact', and go-to-definition must reach another file.
;; Without the compile database (the failure the owner saw before T-004) the include
;; directory is unknown and the definition is not found.  Needs cmake, ninja, c++,
;; clangd and git.

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
    ("src/main.cc" . "#include <toy/answer.h>\nint main() {\n  int* unused = 0;\n  return answer() + (unused == 0);\n}\n")
    (".clang-tidy" . "Checks: 'modernize-use-nullptr'\n"))
  "The toy project: the definition lives in another file, behind an include path,
and main.cc has one clang-tidy finding (`0' for a null pointer).")

(defun init-cpp-test--tidy-diagnostic ()
  "Return the first flymake diagnostic of the current buffer from clang-tidy."
  (cl-find-if (lambda (diagnostic)
                (string-match-p "modernize-use-nullptr" (flymake-diagnostic-text diagnostic)))
              (flymake-diagnostics)))

(ert-deftest init-cpp-eglot-navigates-and-reports-clang-tidy ()
  (init-test--load)
  (let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-toy" t)))
         (default-directory root)
         (emacs-cpp-presets-state-file (expand-file-name "state.eld" root))
         buffer)
    (unwind-protect
        (progn
          (pcase-dolist (`(,name . ,content) init-cpp-test--files)
            (let ((file (expand-file-name name root)))
              (make-directory (file-name-directory file) t)
              (write-region content nil file)))
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          (should (eql 0 (call-process "cmake" nil nil nil "--preset" "debug")))
          (setq buffer (find-file-noselect (expand-file-name "src/main.cc" root)))
          (with-current-buffer buffer
            (should (eq major-mode 'c++-ts-mode))
            ;; eglot-ensure waits for a command loop; batch has none, so connect the
            ;; way it would (eglot's own contact guess, which reaches our function).
            (apply #'eglot (eglot--guess-contact))
            (should (equal (process-command
                            (jsonrpc--process (eglot-current-server)))
                           (list "clangd" (concat "--compile-commands-dir="
                                                  (expand-file-name "build/debug" root)))))
            (goto-char (point-min))
            (search-forward "return answer")
            (backward-char 2)
            (let* ((identifier (xref-backend-identifier-at-point 'eglot))
                   (items (xref-backend-definitions 'eglot identifier))
                   (files (mapcar (lambda (item)
                                    (xref-location-group (xref-item-location item)))
                                  items)))
              (should items)
              (should (cl-every (lambda (file)
                                  (member (file-name-nondirectory file)
                                          '("answer.h" "answer.cc")))
                                files)))
            ;; clangd runs clang-tidy by default; the project's .clang-tidy selects
            ;; the checks.  Batch has no idle timers, so start flymake by hand.
            (flymake-start)
            (let ((deadline (+ (float-time) 30)))
              (while (and (not (init-cpp-test--tidy-diagnostic))
                          (< (float-time) deadline))
                (accept-process-output nil 0.2)))
            (should (init-cpp-test--tidy-diagnostic))))
      (when (and buffer (buffer-live-p buffer))
        (with-current-buffer buffer
          (when (eglot-current-server)
            (eglot-shutdown (eglot-current-server))))
        (kill-buffer buffer))
      (delete-directory root t))))

(provide 'init-cpp-test)
;;; init-cpp-test.el ends here
