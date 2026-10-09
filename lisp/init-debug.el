;;; init-debug.el --- Debugging with dape, gdb and lldb  -*- lexical-binding: t; -*-

;;; Commentary:

;; dape drives gdb through gdb's own DAP mode (D-002).  The `gdb-preset' entry of
;; `dape-configs' debugs an executable of the active CMake preset (D-031):
;;
;;   C-x C-a d gdb-preset RET
;;
;; asks for one of the preset's executable targets (from CMake's file API, so also
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

(defcustom emacs-cpp-debug-lldb-dap-program "lldb-dap"
  "The lldb-dap program `lldb-preset' starts (D-051).
A file name with a directory is used as it is; a bare name is looked up on
`exec-path'.  Arch: the lldb package.  macOS: the MacPorts lldb-23 port, linked
as /opt/local/bin/lldb-dap by `sudo port select --set lldb mp-lldb-23', or set
this to its own file, /opt/local/bin/lldb-dap-mp-23.  Set it with
\[customize-variable]; Customize saves it in `custom-file' (D-003)."
  :type '(choice (const :tag "lldb-dap on exec-path" "lldb-dap")
                 (file :tag "Program (path or name)"))
  :group 'tools)

(defcustom emacs-cpp-debug-default-configuration emacs-cpp-default-debug-configuration
  "The debug configuration `C-x C-a d' offers first in a C++ buffer (D-055).
Offered only while dape's history holds no `gdb-preset' or `lldb-preset' entry;
after that the last one used comes first, as dape does.  The default comes from
the platform's defaults file: `gdb-preset' on Linux, `lldb-preset' on macOS."
  :type '(choice (const gdb-preset) (const lldb-preset))
  :group 'tools)

(defun emacs-cpp-debug--offer-default ()
  "Put `emacs-cpp-debug-default-configuration' first at `C-x C-a d' (D-055).
For `dape-read-config-hook': in a C++ buffer without a project setting
\(`dape-command') and while dape's history has no preset entry, add the
default to the history, where dape's prompt takes its first input from."
  (when (and (derived-mode-p 'c-ts-base-mode)
             (null dape-command)
             (not (seq-some (lambda (entry)
                              (string-match-p "\\`\\(?:gdb\\|lldb\\)-preset\\_>" entry))
                            dape-history)))
    (push (symbol-name emacs-cpp-debug-default-configuration) dape-history)))

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

(defun emacs-cpp-debug--read-json (file)
  "Return the JSON object in FILE as an alist (arrays as lists)."
  (with-temp-buffer
    (insert-file-contents file)
    (json-parse-buffer :object-type 'alist :array-type 'list
                       :null-object nil :false-object nil)))

(defun emacs-cpp-debug--codemodel (dir)
  "Return the file API codemodel of build directory DIR and its reply directory.
As (CODEMODEL . REPLY-DIR), or nil when CMake wrote no codemodel there.  The
current reply index is the one with the greatest name (CMake's file API
documentation); any client's query produces it, CLion's too."
  (let* ((reply (expand-file-name ".cmake/api/v1/reply" dir))
         (indexes (and (file-directory-p reply)
                       (directory-files reply t "\\`index-.*\\.json\\'")))
         (index (and indexes (emacs-cpp-debug--read-json
                              (car (last (sort indexes #'string<))))))
         (object (seq-find (lambda (object)
                             (and (equal (alist-get 'kind object) "codemodel")
                                  (eql (alist-get 'major (alist-get 'version object)) 2)))
                           (alist-get 'objects index))))
    (when object
      (cons (emacs-cpp-debug--read-json
             (expand-file-name (alist-get 'jsonFile object) reply))
            reply))))

(defun emacs-cpp-debug-programs (dir)
  "Return the executable targets of build directory DIR as (TARGET . PROGRAM).
Read from CMake's file API reply (D-056), so targets never built are listed
too, for any generator; PROGRAM is the absolute path of the target's file.
Without a reply, the query is written and the session refused: one configure
with `C-c p c o' produces it."
  (pcase-let ((`(,codemodel . ,reply) (emacs-cpp-debug--codemodel dir)))
    (unless codemodel
      (emacs-cpp-presets-request-codemodel dir)
      (user-error "emacs-cpp: no CMake file API reply in %s; configure the preset \
once with %s (gdb-preset and lldb-preset read its targets, D-056)"
                  dir (substitute-command-keys "\\[projectile-configure-project]")))
    (let ((configurations (alist-get 'configurations codemodel)))
      (unless (length= configurations 1)
        (user-error "emacs-cpp: %s has %d configurations (a multi-config generator); \
not supported (D-056)" dir (length configurations)))
      (cl-loop for entry in (alist-get 'targets (car configurations))
               for target = (emacs-cpp-debug--read-json
                             (expand-file-name (alist-get 'jsonFile entry) reply))
               when (equal (alist-get 'type target) "EXECUTABLE")
               collect (cons (alist-get 'name target)
                             (expand-file-name
                              (alist-get 'path (car (alist-get 'artifacts target)))
                              dir))))))

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

(defun emacs-cpp-debug--prepare-build (config)
  "Return CONFIG with the build of its program (dape's `fn' for `lldb-preset').
dape calls this again after the build, so it sets the command, never appends."
  (plist-put config 'compile
             (emacs-cpp-debug-build-command (plist-get config 'command-cwd)
                                            (plist-get config :program))))

(defun emacs-cpp-debug--prepare (config)
  "Return CONFIG with gdb's arguments and the build (dape's `fn' for `gdb-preset')."
  (plist-put (emacs-cpp-debug--prepare-build config) 'command-args
             (append (plist-get (alist-get 'gdb dape-configs) 'command-args)
                     (emacs-cpp-debug-gdb-arguments))))

(defun emacs-cpp-debug-lldb-dap ()
  "Return the lldb-dap program to start, or refuse with the fix (D-051).
The `command' of `lldb-preset'."
  (let ((program emacs-cpp-debug-lldb-dap-program))
    (or (if (file-name-absolute-p program)
            (and (file-executable-p program) program)
          (executable-find program))
        (user-error "emacs-cpp: no lldb-dap at %s; %s, or set \
emacs-cpp-debug-lldb-dap-program (D-051)"
                    program (if (eq system-type 'darwin)
                                "install the lldb-23 port and run `sudo port select \
--set lldb mp-lldb-23'"
                              "install the lldb package")))))

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
  (plist-put (emacs-cpp-debug--preset-config 'lldb-dap #'emacs-cpp-debug--prepare-build)
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
  (add-hook 'dape-read-config-hook #'emacs-cpp-debug--offer-default)
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
