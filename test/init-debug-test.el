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

(defconst init-debug-test--fixtures
  (expand-file-name "fixtures/file-api"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "CMake file API replies of one toy project, written by CMake 3.31 (MacPorts)
and 4.3 (CLion's): a target in a subdirectory whose OUTPUT_NAME has a space, a
shared library, and a C program with its own RUNTIME_OUTPUT_DIRECTORY.")

(defun init-debug-test--install-reply (version dir)
  "Copy the file API reply of CMake VERSION into build directory DIR."
  (let ((reply (expand-file-name ".cmake/api/v1/reply" dir)))
    (make-directory reply t)
    (dolist (file (directory-files (expand-file-name (concat "cmake-" version)
                                                     init-debug-test--fixtures)
                                   t "\\.json\\'"))
      (copy-file file (file-name-as-directory reply)))))

(defun init-debug-test--write-reply (dir configurations)
  "Write a minimal file API reply into build DIR with CONFIGURATIONS (a list)."
  (let ((reply (expand-file-name ".cmake/api/v1/reply" dir)))
    (make-directory reply t)
    (write-region "{\"objects\": [{\"kind\": \"codemodel\", \"version\": {\"major\": 2,
  \"minor\": 7}, \"jsonFile\": \"codemodel-v2-x.json\"}]}" nil
                  (expand-file-name "index-2026-01-01T00-00-00-0000.json" reply))
    (write-region (json-encode `((configurations . ,(vconcat configurations)))) nil
                  (expand-file-name "codemodel-v2-x.json" reply))))

(ert-deftest init-debug-programs-are-the-executable-targets-of-the-file-api ()
  "D-056: executables of the reply, in its order, from CMake 3.31 and 4 alike."
  (init-test--load)
  (init-debug-test--with-project `(("CMakePresets.json" . ,init-debug-test--presets))
    (let ((dir (expand-file-name "build/debug" root)))
      (dolist (version '("3.31" "4.3"))
        (let ((other (expand-file-name (concat "build/v" version) root)))
          (init-debug-test--install-reply version other)
          (should (equal (emacs-cpp-debug-programs other)
                         `(("b_x" . ,(expand-file-name "sub/be tool" other))
                           ("main" . ,(expand-file-name "main" other))
                           ("plain" . ,(expand-file-name "bin/plain" other)))))))
      (init-debug-test--install-reply "4.3" dir)
      ;; Offered by target name, the last pick as default; the program path returned.
      (let (offered default)
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt collection &rest args)
                     (setq offered collection default (nth 4 args))
                     "b_x")))
          (let ((emacs-cpp-debug--program-history '("gone" "plain")))
            (should (equal (emacs-cpp-debug-read-program)
                           (expand-file-name "sub/be tool" dir))))
          (should (equal offered '("b_x" "main" "plain")))
          (should (equal default "plain"))))
      ;; The build uses the target name, not the file name.
      (should (equal (emacs-cpp-debug-build-command
                      root (expand-file-name "sub/be tool" dir))
                     (format "cmake --build %s --target b_x"
                             (shell-quote-argument dir)))))))

(ert-deftest init-debug-errors-instead-of-guessing ()
  (init-test--load)
  (init-debug-test--with-project `(("CMakePresets.json" . ,init-debug-test--presets))
    (let ((dir (expand-file-name "build/debug" root)))
      ;; No reply: refused naming the configure command, and the query is written.
      (should (string-match-p
               "configure the preset once with \\(?:C-c p c o\\|M-x projectile-configure-project\\)"
               (cadr (should-error (emacs-cpp-debug-read-program) :type 'user-error))))
      (should (file-exists-p (expand-file-name ".cmake/api/v1/query/codemodel-v2" dir)))
      ;; A reply without an executable target.
      (init-debug-test--write-reply dir '(((name . "Debug") (targets . []))))
      (should-error (emacs-cpp-debug-read-program) :type 'user-error)
      ;; Two configurations (a multi-config generator): not supported yet.
      (init-debug-test--write-reply dir '(((name . "Debug") (targets . []))
                                          ((name . "Release") (targets . []))))
      (should (string-match-p "2 configurations"
                              (cadr (should-error (emacs-cpp-debug-programs dir)
                                                  :type 'user-error))))
      ;; A program no target links has nothing to build.
      (should-error (emacs-cpp-debug-build-command root "/usr/bin/true") :type 'user-error)))
  ;; Outside any project.
  (let ((default-directory (file-name-as-directory (make-temp-file "emacs-cpp-none" t))))
    (unwind-protect
        (should-error (emacs-cpp-debug-read-program) :type 'user-error)
      (delete-directory default-directory t))))

(ert-deftest init-debug-configure-command-asks-for-the-file-api ()
  "D-056: configured with C-c p c o's command, a preset lists its targets, also
with the Makefiles generator; configured without it, it does not until then."
  (init-test--load)
  (let ((files (cons `("CMakePresets.json" . ,(replace-regexp-in-string
                                               "Ninja" "Unix Makefiles"
                                               init-debug-test--presets))
                     (assoc-delete-all "CMakePresets.json"
                                       (copy-sequence init-debug-test--files)))))
    (init-debug-test--with-project files
      (let ((dir (expand-file-name "build/debug" root)))
        ;; Configured by hand, without the query: refused.
        (should (eql 0 (call-process "cmake" nil nil nil "--preset" "debug")))
        (should-error (emacs-cpp-debug-programs dir) :type 'user-error)
        ;; The configure command (C-c p c o) writes the query; then targets appear.
        (should (eql 0 (call-process-shell-command
                        (emacs-cpp-presets-configure-command))))
        (should (equal (emacs-cpp-debug-programs dir)
                       `(("toy" . ,(expand-file-name "toy" dir)))))))))

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
    ;; As C-c p c o configures: the file API query first (D-056).
    (should (eql 0 (call-process-shell-command (emacs-cpp-presets-configure-command))))
    ;; Configured, never built: the target exists only in CMake's reply.
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

(ert-deftest init-debug-platform-default-at-c-x-c-a-d ()
  "D-055: the platform's preset comes first while dape's history has none."
  (init-test--load)
  (require 'dape)
  (should (eq emacs-cpp-debug-default-configuration
              (if (eq system-type 'darwin) 'lldb-preset 'gdb-preset)))
  (should (memq #'emacs-cpp-debug--offer-default dape-read-config-hook))
  (with-temp-buffer
    (c++-ts-mode)
    (let ((dape-history nil)
          (dape-command nil))
      (emacs-cpp-debug--offer-default)
      (should (equal dape-history
                     (list (symbol-name emacs-cpp-debug-default-configuration))))
      ;; Once a preset was used, the history wins.
      (setq dape-history '("gdb-preset :args [\"5\"]" "debugpy"))
      (emacs-cpp-debug--offer-default)
      (should (equal dape-history '("gdb-preset :args [\"5\"]" "debugpy")))
      ;; A project's own `dape-command' wins too.
      (setq dape-history nil
            dape-command '(lldb-preset))
      (emacs-cpp-debug--offer-default)
      (should-not dape-history)))
  ;; Not outside C and C++ buffers.
  (with-temp-buffer
    (let ((dape-history nil))
      (emacs-cpp-debug--offer-default)
      (should-not dape-history))))

(ert-deftest init-debug-lldb-dap-program-is-configurable ()
  "The option takes a path or a name; a path is used as it is (owner, 2026-10-09)."
  (init-test--load)
  (let* ((dir (file-name-as-directory (file-truename (make-temp-file "lldb-dap" t))))
         (program (expand-file-name "my-lldb-dap" dir)))
    (unwind-protect
        (progn
          (write-region "#!/bin/sh\n" nil program)
          (set-file-modes program #o755)
          (let ((emacs-cpp-debug-lldb-dap-program program))
            (should (equal (emacs-cpp-debug-lldb-dap) program)))
          ;; A bare name is looked up on exec-path.
          (let ((emacs-cpp-debug-lldb-dap-program "my-lldb-dap")
                (exec-path (cons dir exec-path)))
            (should (equal (emacs-cpp-debug-lldb-dap) program))))
      (delete-directory dir t)))
  ;; Customize offers a file chooser for it.
  (should (assq 'file (cdr (get 'emacs-cpp-debug-lldb-dap-program 'custom-type)))))

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
