;;; init-debug.el --- Debugging with dape, gdb and lldb  -*- lexical-binding: t; -*-

;;; Commentary:

;; dape drives gdb through gdb's own DAP mode (D-002).  The `gdb-preset' entry of
;; `dape-configs' debugs an executable of the active CMake preset (D-031):
;;
;;   C-x C-a d gdb-preset RET
;;
;; asks for one of the preset's executable targets (read from build.ninja, so also
;; one never built, D-033), builds it with `cmake --build', and on success starts gdb
;; in the project root.  A failed build
;; starts no session.  gdb never downloads symbols (D-014); it reads every shared
;; library's symbols at start unless `emacs-cpp-debug-lazy-symbols' is set (D-030),
;; and sources `emacs-cpp-debug-gdb-scripts', such as deal.II's printers (D-032).
;; Breakpoints are kept with dape's own `dape-breakpoint-save' and `-load'.
;;
;; `lldb-preset' does the same with lldb-dap (D-051): the debugger on macOS, where
;; Apple silicon has no gdb, and an alternative on Arch.  It takes the same targets
;; and builds them the same way; the gdb options (symbols, scripts) are gdb's only.
;;
;;   C-x C-a d lldb-preset RET
;;
;; In source buffers the fringe (the margin in a terminal) toggles breakpoints with a
;; click, as CLion's gutter does; breakpoints are drawn in the theme's error colour
;; and the line the program stopped at is highlighted (D-036).

;;; Code:

(require 'emacs-cpp-presets)

(defcustom emacs-cpp-debug-lazy-symbols nil
  "Non-nil: gdb loads shared-library symbols on demand (D-030).
The first stop is then much faster (RMO: 2.3 s instead of 17 s), but frames in
deal.II have no symbols until gdb's `sharedlibrary' command loads them."
  :type 'boolean
  :group 'tools)

(defcustom emacs-cpp-debug-gdb-scripts nil
  "gdb command scripts sourced at the start of every `gdb-preset' session (D-032).
They are read as gdb command scripts whatever their extension, so deal.II's
contrib/utilities/dotgdbinit.py (gdb commands despite its name) can be listed
directly.  A listed file that does not exist refuses the session."
  :type '(repeat file)
  :group 'tools)

(defcustom emacs-cpp-debug-lldb-dap-program
  (if (eq system-type 'darwin) "/opt/local/libexec/llvm-23/bin/lldb-dap" "lldb-dap")
  "The lldb-dap program `lldb-preset' starts (D-051).
A name is looked up on `exec-path' (Arch: the lldb package).  On macOS the
default is the MacPorts lldb-23 port's, which is not on PATH (D-053)."
  :type 'string
  :group 'tools)

(defvar emacs-cpp-debug--program-history nil
  "Targets picked for `gdb-preset' and `lldb-preset'.")

(defun emacs-cpp-debug--root ()
  "Return the current project's root, or signal that there is none."
  (let ((project (or (project-current)
                     (user-error "emacs-cpp: %s is in no project; gdb-preset and \
lldb-preset debug a project's CMake preset (D-031, D-051)" default-directory))))
    (expand-file-name (project-root project))))

(defun emacs-cpp-debug--build-dir (root)
  "Return the build directory of the active preset of the project at ROOT."
  (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))

(defun emacs-cpp-debug--ninja-unescape (path)
  "Return PATH from build.ninja with Ninja's `$' escapes removed."
  (replace-regexp-in-string "\\$\\(.\\)" "\\1" path t))

(defun emacs-cpp-debug-programs (dir)
  "Return the executable targets of build directory DIR as (TARGET . PROGRAM).
Read from DIR's build.ninja, so targets never built are listed too (D-033);
PROGRAM is the absolute path CMake links the target to.  File order."
  (let ((ninja (expand-file-name "build.ninja" dir)))
    (unless (file-readable-p ninja)
      (user-error "emacs-cpp: no %s; configure the preset, with the Ninja generator \
\(gdb-preset and lldb-preset read its targets, D-033)" ninja))
    (with-temp-buffer
      (insert-file-contents ninja)
      ;; The build type: CMake 4 repeats it as CONFIG in each link block, CMake 3.31
      ;; (MacPorts, D-053) only states it once, as the file's CONFIGURATION.
      (let ((file-config (if (re-search-forward "^CONFIGURATION = \\(.*\\)$" nil t)
                             (match-string 1)
                           ""))
            programs)
        (goto-char (point-min))
        ;; build <output>[ | <implicit outputs>]: <LANG>_EXECUTABLE_LINKER__<target>_<config>
        (while (re-search-forward
                (concat "^build \\(\\(?:[^ :$\n]\\|\\$.\\)+\\)"
                        "\\(?:[^:$\n]\\|\\$.\\)*: "
                        "[A-Za-z]+_EXECUTABLE_LINKER__\\([^ \n]+\\)")
                nil t)
          (let* ((output (match-string 1))
                 (rule (match-string 2))
                 ;; The block's CONFIG, else the file's; none without a build type
                 ;; (rule ends in "_").
                 (config (save-excursion
                           (if (re-search-forward "^  CONFIG = \\(.*\\)$"
                                                  (save-excursion
                                                    (re-search-forward "^$" nil 'move)
                                                    (point))
                                                  t)
                               (match-string 1)
                             file-config)))
                 (suffix (concat "_" config)))
            (unless (string-suffix-p suffix rule)
              (error "emacs-cpp: link rule %s in %s does not end in %s" rule ninja suffix))
            (push (cons (string-remove-suffix suffix rule)
                        (expand-file-name (emacs-cpp-debug--ninja-unescape output) dir))
                  programs)))
        (nreverse programs)))))

(defun emacs-cpp-debug-read-program ()
  "Ask for an executable target of the active preset; return its program path.
The `:program' of `gdb-preset' and `lldb-preset'; dape calls it in the project
root."
  (let* ((root (emacs-cpp-debug--root))
         (dir (emacs-cpp-debug--build-dir root))
         (programs (emacs-cpp-debug-programs dir))
         (targets (mapcar #'car programs)))
    (unless programs
      (user-error "emacs-cpp: %s has no executable target" dir))
    (cdr (assoc (completing-read
                 (format "Target in %s: " (abbreviate-file-name dir))
                 targets nil t nil 'emacs-cpp-debug--program-history
                 (or (seq-find (lambda (old) (member old targets))
                               emacs-cpp-debug--program-history)
                     (and (length= targets 1) (car targets))))
                programs))))

(defun emacs-cpp-debug-gdb-arguments ()
  "Return gdb's arguments after `--interpreter=dap', from the options above."
  (dolist (script emacs-cpp-debug-gdb-scripts)
    (unless (file-readable-p script)
      (user-error "emacs-cpp: gdb script %s in emacs-cpp-debug-gdb-scripts does not \
exist (D-032)" script)))
  (append
   '("-iex" "set debuginfod enabled off")
   (when emacs-cpp-debug-gdb-scripts
     ;; "off": every sourced file is read as gdb commands, not by its extension.
     `("-iex" "set script-extension off"
       ,@(mapcan (lambda (script)
                   (list "-iex" (concat "source " (expand-file-name script))))
                 emacs-cpp-debug-gdb-scripts)
       "-iex" "set script-extension soft"))
   (when emacs-cpp-debug-lazy-symbols
     '("-iex" "set auto-solib-add off"))))

(defun emacs-cpp-debug-build-command (root program)
  "Return the command building the target that links PROGRAM in ROOT's preset."
  (let* ((dir (emacs-cpp-debug--build-dir root))
         (target (car (rassoc (expand-file-name program dir)
                              (emacs-cpp-debug-programs dir)))))
    (unless target
      (user-error "emacs-cpp: %s is no executable target's program in %s (D-033)"
                  program dir))
    (format "cmake --build %s --target %s" (shell-quote-argument dir)
            (shell-quote-argument target))))

(defun emacs-cpp-debug--prepare (config)
  "Return CONFIG with gdb's arguments and the build of its program (dape's `fn').
dape calls this again after the build, so it sets these, never appends."
  (let ((root (plist-get config 'command-cwd)))
    (thread-first
      config
      (plist-put 'command-args
                 (append (plist-get (alist-get 'gdb dape-configs) 'command-args)
                         (emacs-cpp-debug-gdb-arguments)))
      (plist-put 'compile
                 (emacs-cpp-debug-build-command root (plist-get config :program))))))

(defun emacs-cpp-debug--prepare-lldb (config)
  "Return CONFIG with the build of its program (dape's `fn' for `lldb-preset')."
  (plist-put config 'compile
             (emacs-cpp-debug-build-command (plist-get config 'command-cwd)
                                            (plist-get config :program))))

(defun emacs-cpp-debug-lldb-dap ()
  "Return the lldb-dap program to start, or refuse with the fix (D-051).
The `command' of `lldb-preset'."
  (let ((program emacs-cpp-debug-lldb-dap-program))
    (or (if (file-name-absolute-p program)
            (and (file-executable-p program) program)
          (executable-find program))
        (user-error "emacs-cpp: no lldb-dap at %s; install %s, or set \
emacs-cpp-debug-lldb-dap-program (D-051)"
                    program (if (eq system-type 'darwin)
                                "the lldb-23 port"
                              "the lldb package")))))

(defun emacs-cpp-debug--preset-config (name prepare)
  "Return dape's configuration NAME with the preset parts and PREPARE as `fn'."
  (let ((config (or (copy-tree (alist-get name dape-configs))
                    (error "emacs-cpp: dape has no `%s' configuration (D-002)" name))))
    (when (plist-get config 'fn)
      (error "emacs-cpp: dape's `%s' configuration has its own `fn'; review \
%s against it (D-031)" name prepare))
    (thread-first
      config
      (plist-put 'fn prepare)
      (plist-put :program #'emacs-cpp-debug-read-program)
      (plist-put :cwd #'dape-cwd))))

(defun emacs-cpp-debug--gdb-preset-config ()
  "Return the `gdb-preset' configuration: dape's `gdb' one plus the preset parts."
  (emacs-cpp-debug--preset-config 'gdb #'emacs-cpp-debug--prepare))

(defun emacs-cpp-debug--lldb-preset-config ()
  "Return the `lldb-preset' configuration: dape's `lldb-dap' one plus the preset
parts, started with `emacs-cpp-debug-lldb-dap' (D-051)."
  (plist-put (emacs-cpp-debug--preset-config 'lldb-dap #'emacs-cpp-debug--prepare-lldb)
             'command #'emacs-cpp-debug-lldb-dap))

;; gud (M-x gdb, pdb, perldb) binds its map on `gud-key-prefix' globally when it
;; loads; on the default C-x C-a that would take dape's keys for the session (D-044).
(use-package gud
  :init
  (setq gud-key-prefix (kbd "C-x M-a")))

(use-package dape
  ;; dape binds its prefix only once loaded; this loads it on the first C-x C-a.
  :bind-keymap ("C-x C-a" . dape-global-map)
  ;; Gutter clicks in C and C++ buffers; dape (135 ms) loads with the first one.  Not
  ;; `prog-mode': *scratch* is one, and would load dape at every startup.
  :hook (c-ts-base-mode . dape-breakpoint-mode)
  :config
  (setf (alist-get 'gdb-preset dape-configs) (emacs-cpp-debug--gdb-preset-config))
  (setf (alist-get 'lldb-preset dape-configs) (emacs-cpp-debug--lldb-preset-config))
  ;; The theme styles neither face; inheriting keeps them in the theme's colours.
  (require 'hl-line)
  (face-spec-set 'dape-breakpoint-face '((t :inherit error)))
  (face-spec-set 'dape-source-line-face '((t :inherit hl-line :extend t)))
  ;; dape's debugpy (Python, D-045) listens on 0.0.0.0, every network interface;
  ;; keep the debugger to this machine.  dape connects to `host' (default
  ;; "localhost", which may resolve to IPv6 ::1 first), so name the address too.
  ;; Remote files (TRAMP) are not covered: the adapter then listens on the remote
  ;; machine's loopback, which dape cannot reach (DESIGN 2, one workstation).
  (dolist (name '(debugpy debugpy-module))
    (let* ((config (alist-get name dape-configs))
           (args (plist-get config 'command-args)))
      (unless (and config (or (member "0.0.0.0" args) (member "127.0.0.1" args)))
        (error "emacs-cpp: dape's `%s' configuration changed (command-args %S); \
review its listening address in lisp/init-debug.el (D-045)" name args))
      (plist-put config 'command-args
                 (cl-substitute "127.0.0.1" "0.0.0.0" args :test #'equal))
      (plist-put config 'host "127.0.0.1")))
  ;; dape puts every command on its repeat map; only stepping should repeat (D-037),
  ;; so that after `C-x C-a b' or `w' the next letter is text again.
  (dolist (command '(dape dape-breakpoint-log dape-breakpoint-expression
                     dape-breakpoint-hits dape-breakpoint-function
                     dape-breakpoint-toggle dape-breakpoint-remove-all
                     dape-select-stack dape-select-thread dape-select-session
                     dape-watch-dwim dape-evaluate-expression dape-info))
    (put command 'repeat-map nil)))

(provide 'init-debug)
;;; init-debug.el ends here
