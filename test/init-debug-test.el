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
  `(let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-debug" t))))
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

(defun init-debug-test--skip-without-gdb ()
  "Skip the test when gdb is not installed: there is none for Apple silicon."
  (unless (executable-find "gdb")
    (ert-skip "gdb not installed (none for Apple silicon; lldb-preset, D-051)")))

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
  "Link blocks as CMake 4's Ninja generator writes them: a subdirectory target whose
OUTPUT_NAME has a space (Ninja's `$ '), a shared library, a block without CONFIG
\(no build type).")

(defconst init-debug-test--ninja-3-31
  "# Set configuration variable for custom commands.

CONFIGURATION = Debug

# Link the executable toy

build toy: CXX_EXECUTABLE_LINKER__my_tool_Debug CMakeFiles/my_tool.dir/src/main.cc.o
  FLAGS = -g
  TARGET_FILE = toy
"
  "A link block as CMake 3.31 (MacPorts) writes it: no CONFIG in the block, the build
type only as the file's CONFIGURATION.")

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
      (let ((dir-3-31 (expand-file-name "build/old" root)))
        (make-directory dir-3-31 t)
        (write-region init-debug-test--ninja-3-31 nil
                      (expand-file-name "build.ninja" dir-3-31))
        (should (equal (emacs-cpp-debug-programs dir-3-31)
                       `(("my_tool" . ,(expand-file-name "toy" dir-3-31))))))
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

(ert-deftest init-debug-gud-leaves-c-x-c-a-to-dape ()
  "D-044: loading gud (M-x gdb, pdb, perldb) binds its map on C-x M-a, not C-x C-a."
  (init-test--load)
  (require 'dape)
  (require 'gud)
  (should (eq (keymap-lookup global-map "C-x C-a d") 'dape))
  (should (eq (keymap-lookup global-map "C-x M-a") gud-global-map)))

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
          (when (executable-find "gdb")
            (write-region "echo emacs-cpp-script-read\\n\n" nil script)
            (with-temp-buffer
              (apply #'call-process "gdb" nil t nil "-batch" "-nx"
                     (emacs-cpp-debug-gdb-arguments))
              (should (string-match-p "emacs-cpp-script-read" (buffer-string))))))
      (delete-file script)))
  (let ((emacs-cpp-debug-gdb-scripts '("/nonexistent/printers.py")))
    (should-error (emacs-cpp-debug-gdb-arguments) :type 'user-error))
  ;; The arguments are checked above; only gdb reading the script was left out.
  (init-debug-test--skip-without-gdb))

(ert-deftest init-debug-dape-gets-gdb-preset-on-c-x-c-a ()
  (init-test--load)
  ;; Before dape is loaded C-x C-a is use-package's loader; dape then binds its map.
  (require 'dape)
  (should (eq (keymap-lookup global-map "C-x C-a d") 'dape))
  (should (eq (keymap-lookup global-map "C-x C-a n") 'dape-next))
  ;; D-036: gutter clicks in C/C++ buffers, red breakpoints, highlighted stop line.
  (should (memq 'dape-breakpoint-mode c-ts-base-mode-hook))
  (should (eq (face-attribute 'dape-breakpoint-face :inherit) 'error))
  (should (eq (face-attribute 'dape-source-line-face :inherit) 'hl-line))
  (with-temp-buffer
    (c++-ts-mode)
    (should dape-breakpoint-mode))
  ;; D-037: stepping repeats, the rest does not.
  (dolist (command '(dape-next dape-step-in dape-step-out dape-continue dape-until))
    (should (eq (get command 'repeat-map) 'dape-global-map)))
  (dolist (command '(dape dape-breakpoint-toggle dape-watch-dwim dape-info))
    (should-not (get command 'repeat-map)))
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

(defun init-debug-test--session (name)
  "Debug the toy program with dape's configuration NAME as `C-x C-a d' does:
pick the target, build it, stop at a breakpoint, show locals and a watch, step
into a call, out of it and over a line, then end the session."
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
        ;; As `C-x C-a d NAME RET' evaluates it, the prompt answered.
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt collection &rest _)
                     (setq offered collection)
                     "toy")))
          (setq config (let ((default-directory root))
                         (dape--config-eval name nil))))
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
      ;; Into the call (gdb names it "twice", lldb "twice(int)"), out of it, then
      ;; over the rest of line 4.
      (should (string-prefix-p "twice" (plist-get (init-debug-test--step #'dape-step-in)
                                                  :name)))
      (should (equal (plist-get (init-debug-test--step #'dape-step-out) :name) "main"))
      (let ((frame (init-debug-test--step #'dape-next)))
        (should (equal (list (plist-get frame :name) (plist-get frame :line))
                       '("main" 5))))
      (let ((process (jsonrpc--process (init-debug-test--connection))))
        (dape-kill (init-debug-test--connection))
        (should (init-debug-test--wait (lambda () (null (dape--live-connections))) 30))
        (should (init-debug-test--wait (lambda () (not (process-live-p process))) 10))))))

(ert-deftest init-debug-gdb-preset-builds-stops-and-steps ()
  (init-test--load)
  (init-debug-test--skip-without-gdb)
  (require 'dape)
  (init-debug-test--session 'gdb-preset))

;;;; lldb (D-051)

(ert-deftest init-debug-dape-gets-lldb-preset ()
  (init-test--load)
  (require 'dape)
  (let ((config (alist-get 'lldb-preset dape-configs)))
    (should (eq (plist-get config 'fn) #'emacs-cpp-debug--prepare-build))
    (should (eq (plist-get config :program) #'emacs-cpp-debug-read-program))
    (should (eq (plist-get config 'command) #'emacs-cpp-debug-lldb-dap))
    (should (equal (plist-get config :type)
                   (plist-get (alist-get 'lldb-dap dape-configs) :type)))))

(ert-deftest init-debug-lldb-preset-refuses-without-lldb-dap ()
  (init-test--load)
  (require 'dape)
  (dolist (program '("/nonexistent/lldb-dap" "emacs-cpp-no-such-lldb-dap"))
    (let ((emacs-cpp-debug-lldb-dap-program program))
      ;; The message names the fix.
      (should (string-match-p
               "emacs-cpp-debug-lldb-dap-program"
               (cadr (should-error (emacs-cpp-debug-lldb-dap) :type 'user-error))))
      (init-debug-test--with-project `(("CMakePresets.json" . ,init-debug-test--presets))
        ;; `C-x C-a d lldb-preset RET': `command' is evaluated before the target
        ;; prompt, so no target is asked for.
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _) (error "Target asked for"))))
          (should-error (dape--config-eval 'lldb-preset nil) :type 'user-error))
        ;; dape's `ensure' (also what keeps it out of the suggestions).
        (should-error (dape--config-ensure (alist-get 'lldb-preset dape-configs) t)
                      :type 'user-error)))))

(ert-deftest init-debug-lldb-preset-builds-stops-and-steps ()
  (init-test--load)
  (unless (ignore-errors (emacs-cpp-debug-lldb-dap))
    (ert-skip (format "no lldb-dap at %s (D-051)" emacs-cpp-debug-lldb-dap-program)))
  (require 'dape)
  (init-debug-test--session 'lldb-preset))

(provide 'init-debug-test)
;;; init-debug-test.el ends here
