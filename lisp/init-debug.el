;;; init-debug.el --- Debugging with dape and gdb  -*- lexical-binding: t; -*-

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

(defvar emacs-cpp-debug--program-history nil
  "Targets picked for `gdb-preset'.")

(defun emacs-cpp-debug--root ()
  "Return the current project's root, or signal that there is none."
  (let ((project (or (project-current)
                     (user-error "emacs-cpp: %s is in no project; gdb-preset debugs \
a project's CMake preset (D-031)" default-directory))))
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
\(gdb-preset reads its targets, D-033)" ninja))
    (with-temp-buffer
      (insert-file-contents ninja)
      (let (programs)
        ;; build <output>[ | <implicit outputs>]: <LANG>_EXECUTABLE_LINKER__<target>_<config>
        (while (re-search-forward
                (concat "^build \\(\\(?:[^ :$\n]\\|\\$.\\)+\\)"
                        "\\(?:[^:$\n]\\|\\$.\\)*: "
                        "[A-Za-z]+_EXECUTABLE_LINKER__\\([^ \n]+\\)")
                nil t)
          (let* ((output (match-string 1))
                 (rule (match-string 2))
                 ;; The block's CONFIG; none without a build type (rule ends in "_").
                 (config (save-excursion
                           (if (re-search-forward "^  CONFIG = \\(.*\\)$"
                                                  (save-excursion
                                                    (re-search-forward "^$" nil 'move)
                                                    (point))
                                                  t)
                               (match-string 1)
                             "")))
                 (suffix (concat "_" config)))
            (unless (string-suffix-p suffix rule)
              (error "emacs-cpp: link rule %s in %s does not end in %s" rule ninja suffix))
            (push (cons (string-remove-suffix suffix rule)
                        (expand-file-name (emacs-cpp-debug--ninja-unescape output) dir))
                  programs)))
        (nreverse programs)))))

(defun emacs-cpp-debug-read-program ()
  "Ask for an executable target of the active preset; return its program path.
The `:program' of `gdb-preset'; dape calls it in the project root."
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

(defun emacs-cpp-debug--gdb-preset-config ()
  "Return the `gdb-preset' configuration: dape's `gdb' one plus the preset parts."
  (let ((gdb (or (copy-tree (alist-get 'gdb dape-configs))
                 (error "emacs-cpp: dape has no `gdb' configuration (D-002)"))))
    (when (plist-get gdb 'fn)
      (error "emacs-cpp: dape's `gdb' configuration has its own `fn'; review \
emacs-cpp-debug--prepare against it (D-031)"))
    (thread-first
      gdb
      (plist-put 'fn #'emacs-cpp-debug--prepare)
      (plist-put :program #'emacs-cpp-debug-read-program)
      (plist-put :cwd #'dape-cwd))))

(use-package dape
  ;; dape binds its prefix only once loaded; this loads it on the first C-x C-a.
  :bind-keymap ("C-x C-a" . dape-global-map)
  :config
  (setf (alist-get 'gdb-preset dape-configs) (emacs-cpp-debug--gdb-preset-config)))

(provide 'init-debug)
;;; init-debug.el ends here
