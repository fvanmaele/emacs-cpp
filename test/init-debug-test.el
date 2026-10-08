;;; init-debug-test.el --- dape and gdb on a toy preset project  -*- lexical-binding: t; -*-

;;; Commentary:

;; Unit tests for lisp/init-debug.el on temporary directories, and one session in the
;; shipped profile: `gdb-preset' is evaluated as `C-x C-a d' evaluates it, builds a
;; toy program that was configured but never built (D-033), stops at a breakpoint and
;; is driven like the S2 spike (stack, Locals, watch, step in, out and over, end).
;; Needs cmake, ninja, c++, gdb >= 14.1 and git.

;;; Code:

(require 'ert)
(require 'init-test)

;; Defined by lisp/init-debug.el, loaded by `init-test--load'; declared here so the
;; tests' `let' binds them dynamically.
(defvar emacs-cpp-debug-lazy-symbols)
(defvar emacs-cpp-debug-gdb-scripts)
(defvar emacs-cpp-debug--program-history)

(defconst init-debug-test--presets
  "{\"version\": 6, \"configurePresets\": [
  {\"name\": \"debug\", \"generator\": \"Ninja\",
   \"binaryDir\": \"${sourceDir}/build/${presetName}\",
   \"cacheVariables\": {\"CMAKE_BUILD_TYPE\": \"Debug\"}}]}
"
  "Presets of the toy projects: one debug preset.")

(defconst init-debug-test--files
  `(("CMakeLists.txt" . "cmake_minimum_required(VERSION 3.28)
project(toy CXX)
add_executable(toy src/main.cc)
")
    ("CMakePresets.json" . ,init-debug-test--presets)
    ("src/main.cc" . "int twice(int x) { return 2 * x; }
int main() {
  int value = 21;
  int result = twice(value);
  return result - 42;
}
"))
  "The toy program: a local, and a call to step into.")

(defmacro init-debug-test--with-project (files &rest body)
  "Write FILES into a temporary git project bound to `root', run BODY, clean up.
Buffers visited during BODY and dape sessions it started are killed afterwards."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "emacs-cpp-debug" t)))
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
       (when (and (fboundp 'dape--live-connections) (dape--live-connections))
         (dape-kill (dape--live-connection 'last t))
         (init-debug-test--wait (lambda () (null (dape--live-connections))) 30))
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (let ((kill-buffer-query-functions nil))
             (kill-buffer buffer))))
       (delete-directory root t))))

(defun init-debug-test--wait (predicate seconds)
  "Process events until PREDICATE is non-nil or SECONDS pass; return its value."
  (let ((deadline (+ (float-time) seconds)) value)
    (while (and (not (setq value (funcall predicate))) (< (float-time) deadline))
      (accept-process-output nil 0.1))
    value))

(defconst init-debug-test--ninja
  "# Link the executable main

build main: CXX_EXECUTABLE_LINKER__main_Debug CMakeFiles/main.dir/src/main.cc.o | /usr/lib/libz.so
  CONFIG = Debug
  TARGET_FILE = main

build sub/libs.so: CXX_SHARED_LIBRARY_LINKER__s_Debug sub/CMakeFiles/s.dir/a.cc.o
  CONFIG = Debug

build sub/be$ tool | sub/be.map: CXX_EXECUTABLE_LINKER__b_x_Debug sub/CMakeFiles/b_x.dir/a.cc.o
  CONFIG = Debug

build bin/plain: C_EXECUTABLE_LINKER__plain_ CMakeFiles/plain.dir/p.c.o
  DEP_FILE = CMakeFiles/plain.dir/link.d
"
  "Link blocks as CMake's Ninja generator writes them: a subdirectory target whose
OUTPUT_NAME has a space (Ninja's `$ '), a shared library, a block without CONFIG
\(no build type).")

(ert-deftest init-debug-programs-are-the-executable-targets-of-build-ninja ()
  (init-test--load)
  (init-debug-test--with-project
      `(("CMakePresets.json" . ,init-debug-test--presets)
        ("build/debug/build.ninja" . ,init-debug-test--ninja))
    (let ((dir (expand-file-name "build/debug" root)))
      (should (equal (emacs-cpp-debug-programs dir)
                     `(("main" . ,(expand-file-name "main" dir))
                       ("b_x" . ,(expand-file-name "sub/be tool" dir))
                       ("plain" . ,(expand-file-name "bin/plain" dir)))))
      ;; Offered by target name, the last pick as default; the program path returned.
      (let (offered default)
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt collection &rest args)
                     (setq offered collection default (nth 4 args))
                     "b_x")))
          (let ((emacs-cpp-debug--program-history '("gone" "plain")))
            (should (equal (emacs-cpp-debug-read-program)
                           (expand-file-name "sub/be tool" dir))))
          (should (equal offered '("main" "b_x" "plain")))
          (should (equal default "plain"))))
      ;; The build uses the target name, not the file name.
      (should (equal (emacs-cpp-debug-build-command
                      root (expand-file-name "sub/be tool" dir))
                     (format "cmake --build %s --target b_x"
                             (shell-quote-argument dir)))))))

(ert-deftest init-debug-errors-instead-of-guessing ()
  (init-test--load)
  (init-debug-test--with-project `(("CMakePresets.json" . ,init-debug-test--presets))
    ;; Not configured (or not with Ninja): no build.ninja.
    (should-error (emacs-cpp-debug-read-program) :type 'user-error)
    ;; Configured, but no executable target.
    (make-directory (expand-file-name "build/debug" root) t)
    (write-region "build sub/libs.so: CXX_SHARED_LIBRARY_LINKER__s_ a.o\n" nil
                  (expand-file-name "build/debug/build.ninja" root))
    (should-error (emacs-cpp-debug-read-program) :type 'user-error)
    ;; A program no target links has nothing to build.
    (should-error (emacs-cpp-debug-build-command root "/usr/bin/true") :type 'user-error))
  ;; Outside any project.
  (let ((default-directory (file-name-as-directory (make-temp-file "emacs-cpp-none" t))))
    (unwind-protect
        (should-error (emacs-cpp-debug-read-program) :type 'user-error)
      (delete-directory default-directory t))))

(ert-deftest init-debug-gdb-arguments-follow-the-options ()
  (init-test--load)
  (let ((emacs-cpp-debug-lazy-symbols nil)
        (emacs-cpp-debug-gdb-scripts nil))
    (should (equal (emacs-cpp-debug-gdb-arguments)
                   '("-iex" "set debuginfod enabled off"))))
  (let* ((script (make-temp-file "printers" nil ".py"))
         (emacs-cpp-debug-lazy-symbols t)
         (emacs-cpp-debug-gdb-scripts (list script)))
    (unwind-protect
        (progn
          (should (equal (emacs-cpp-debug-gdb-arguments)
                         `("-iex" "set debuginfod enabled off"
                           "-iex" "set script-extension off"
                           "-iex" ,(concat "source " script)
                           "-iex" "set script-extension soft"
                           "-iex" "set auto-solib-add off")))
          ;; gdb reads a .py script listed here as gdb commands.
          (write-region "echo emacs-cpp-script-read\\n\n" nil script)
          (with-temp-buffer
            (apply #'call-process "gdb" nil t nil "-batch" "-nx"
                   (emacs-cpp-debug-gdb-arguments))
            (should (string-match-p "emacs-cpp-script-read" (buffer-string)))))
      (delete-file script)))
  (let ((emacs-cpp-debug-gdb-scripts '("/nonexistent/printers.py")))
    (should-error (emacs-cpp-debug-gdb-arguments) :type 'user-error)))

(ert-deftest init-debug-dape-gets-gdb-preset-on-c-x-c-a ()
  (init-test--load)
  ;; Before dape is loaded C-x C-a is use-package's loader; dape then binds its map.
  (require 'dape)
  (should (eq (keymap-lookup global-map "C-x C-a d") 'dape))
  (should (eq (keymap-lookup global-map "C-x C-a n") 'dape-next))
  (let ((config (alist-get 'gdb-preset dape-configs)))
    (should (eq (plist-get config 'fn) #'emacs-cpp-debug--prepare))
    (should (eq (plist-get config :program) #'emacs-cpp-debug-read-program))
    (should (equal (plist-get config 'command-args)
                   (plist-get (alist-get 'gdb dape-configs) 'command-args)))))

;;;; A session

(defvar init-debug-test--stops 0
  "Stops reported by dape during the session test.")

(defun init-debug-test--connection ()
  "The stopped dape connection, or nil."
  (dape--live-connection 'stopped t))

(defun init-debug-test--call (function &rest args)
  "Call dape's FUNCTION with ARGS and a callback; wait until it is called."
  (let (done)
    (apply function (append args (list (lambda (&rest _) (setq done t)))))
    (init-debug-test--wait (lambda () done) 30)))

(defun init-debug-test--top-frame ()
  "Return the top stack frame of the stopped thread."
  (let ((connection (init-debug-test--connection)))
    (init-debug-test--call #'dape--stack-trace connection
                           (dape--current-thread connection) 20)
    (car (plist-get (dape--current-thread connection) :stackFrames))))

(defun init-debug-test--step (command)
  "Run dape's step COMMAND; return the top frame after the next stop."
  (let ((before init-debug-test--stops))
    (funcall command (init-debug-test--connection))
    (should (init-debug-test--wait (lambda () (and (> init-debug-test--stops before)
                                                   (init-debug-test--connection)))
                                   60))
    (init-debug-test--top-frame)))

(ert-deftest init-debug-gdb-preset-builds-stops-and-steps ()
  (init-test--load)
  (require 'dape)
  (init-debug-test--with-project init-debug-test--files
    (should (eql 0 (call-process "cmake" nil nil nil "--preset" "debug")))
    ;; Configured, never built: the target exists only in build.ninja.
    (should-not (file-exists-p (expand-file-name "build/debug/toy" root)))
    (let ((source (find-file-noselect (expand-file-name "src/main.cc" root)))
          (init-debug-test--stops 0)
          ;; Batch has no windows to arrange; count stops instead.
          (dape-start-hook nil)
          (dape-update-ui-hook nil)
          (dape-display-source-hook nil)
          (dape-stopped-hook (list (lambda () (cl-incf init-debug-test--stops))))
          (compilation-ask-about-save nil)
          (emacs-cpp-debug--program-history nil)
          offered config)
      (with-current-buffer source
        (goto-char (point-min))
        (search-forward "int result")
        (dape-breakpoint-toggle)
        ;; As `C-x C-a d gdb-preset RET' evaluates it, the prompt answered.
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt collection &rest _)
                     (setq offered collection)
                     "toy")))
          (setq config (let ((default-directory root))
                         (dape--config-eval 'gdb-preset nil))))
        (should (equal offered '("toy")))
        (should (equal (plist-get config :program)
                       (expand-file-name "build/debug/toy" root)))
        (dape config))
      (should (init-debug-test--wait (lambda () (and (> init-debug-test--stops 0)
                                                     (init-debug-test--connection)))
                                     120))
      (let* ((connection (init-debug-test--connection))
             (frame (init-debug-test--top-frame)))
        (should (equal (plist-get frame :name) "main"))
        (should (equal (plist-get frame :line) 4))
        ;; Locals, as the info buffer shows them.
        (init-debug-test--call #'dape--scopes connection frame)
        (let ((locals (seq-find (lambda (scope) (equal (plist-get scope :name) "Locals"))
                                (plist-get frame :scopes))))
          (should locals)
          (init-debug-test--call #'dape--variables connection locals)
          (should (equal (plist-get (seq-find (lambda (variable)
                                                (equal (plist-get variable :name) "value"))
                                              (plist-get locals :variables))
                                    :value)
                         "21")))
        ;; A watch expression, evaluated as the watch window does.
        (let (result)
          (dape-request connection :evaluate
                        (list :expression "value * 2" :frameId (plist-get frame :id)
                              :context "watch")
                        (lambda (body error) (setq result (or error body))))
          (should (equal (plist-get (init-debug-test--wait (lambda () result) 30) :result)
                         "42"))))
      ;; Into the call, out of it, then over the rest of line 4.
      (should (equal (plist-get (init-debug-test--step #'dape-step-in) :name) "twice"))
      (should (equal (plist-get (init-debug-test--step #'dape-step-out) :name) "main"))
      (let ((frame (init-debug-test--step #'dape-next)))
        (should (equal (list (plist-get frame :name) (plist-get frame :line))
                       '("main" 5))))
      (let ((process (jsonrpc--process (init-debug-test--connection))))
        (dape-kill (init-debug-test--connection))
        (should (init-debug-test--wait (lambda () (null (dape--live-connections))) 30))
        (should (init-debug-test--wait (lambda () (not (process-live-p process))) 10))))))

(provide 'init-debug-test)
;;; init-debug-test.el ends here
