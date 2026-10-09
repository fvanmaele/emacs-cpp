;;; init-build-test.el --- Building the active preset with projectile  -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration test in the shipped profile (T-005, D-035): from a header buffer of a
;; toy preset project, `C-c p c o' configures and `C-c p c c' builds the active
;; preset's build directory, and the compiler's error jumps to the source line.
;; Needs cmake, ninja, c++ and git.

;;; Code:

(require 'ert)
(require 'init-test)

(defconst init-build-test--files
  '(("CMakeLists.txt" . "cmake_minimum_required(VERSION 3.28)
project(toy CXX)
add_executable(toy src/main.cc)
target_include_directories(toy PRIVATE include)
")
    ("CMakePresets.json" . "{\"version\": 6, \"configurePresets\": [
  {\"name\": \"debug\", \"generator\": \"Ninja\",
   \"binaryDir\": \"${sourceDir}/build/${presetName}\"}]}
")
    ("include/toy/answer.h" . "#pragma once\nint answer();\n")
    ("src/main.cc" . "#include <toy/answer.h>
int main() {
  return undeclared_name;
}
"))
  "The toy project: an error on line 3 of src/main.cc.")

(defun init-build-test--run (command)
  "Run projectile's COMMAND without its prompt; return the finished buffer."
  (let ((compilation-read-command nil)
        (compilation-ask-about-save nil)
        finished)
    (let ((compilation-finish-functions
           (list (lambda (buffer _status) (setq finished buffer)))))
      (funcall command nil)
      (let ((deadline (+ (float-time) 120)))
        (while (and (not finished) (< (float-time) deadline))
          (accept-process-output nil 0.1))))
    finished))

(ert-deftest init-build-presets-build-from-any-buffer-and-jump-to-errors ()
  (init-test--load)
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-build" t))))
         (default-directory root)
         (emacs-cpp-presets-state-file (expand-file-name "state.eld" root))
         (buffers-before (buffer-list)))
    (unwind-protect
        (progn
          (pcase-dolist (`(,name . ,content) init-build-test--files)
            (let ((file (expand-file-name name root)))
              (make-directory (file-name-directory file) t)
              (write-region content nil file)))
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          ;; From the header: not the file that fails, not the build directory.
          (with-current-buffer (find-file-noselect
                                (expand-file-name "include/toy/answer.h" root))
            (let ((configure (init-build-test--run #'projectile-configure-project)))
              (should configure)
              (with-current-buffer configure
                (should (string-match-p "cmake --preset debug" (buffer-string)))
                (should (string-match-p "finished" (buffer-string)))))
            (let ((build (init-build-test--run #'projectile-compile-project)))
              (should build)
              (with-current-buffer build
                (should (string-match-p "cmake --build build/debug" (buffer-string)))
                (should (string-match-p "undeclared_name" (buffer-string))))
              ;; The first error leads to the source line, shown in the selected window.
              (with-current-buffer build
                (goto-char (point-min))
                (compilation-next-error 1)
                (compile-goto-error))
              (let ((window (selected-window)))
                (should (equal (buffer-file-name (window-buffer window))
                               (expand-file-name "src/main.cc" root)))
                (with-current-buffer (window-buffer window)
                  (should (= (line-number-at-pos (window-point window)) 3)))))))
      (dolist (buffer (buffer-list))
        (unless (memq buffer buffers-before)
          (let ((kill-buffer-query-functions nil))
            (kill-buffer buffer))))
      (delete-directory root t))))

(provide 'init-build-test)
;;; init-build-test.el ends here
