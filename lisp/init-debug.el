;;; init-debug.el --- Debugging with dape and gdb  -*- lexical-binding: t; -*-

;;; Commentary:

;; dape drives gdb through gdb's own DAP mode (D-002).  The `gdb-preset' entry of
;; `dape-configs' debugs an executable of the active CMake preset (D-031):
;;
;;   C-x C-a d gdb-preset RET
;;
;; asks for an executable in the preset's build directory, builds its target with
;; `cmake --build', and on success starts gdb in the project root.  A failed build
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
  "Executables picked for `gdb-preset', relative to the build directory.")

(defun emacs-cpp-debug--root ()
  "Return the current project's root, or signal that there is none."
  (let ((project (or (project-current)
                     (user-error "emacs-cpp: %s is in no project; gdb-preset debugs \
a project's CMake preset (D-031)" default-directory))))
    (expand-file-name (project-root project))))

(defun emacs-cpp-debug--build-dir (root)
  "Return the build directory of the active preset of the project at ROOT."
  (emacs-cpp-presets-binary-dir root (emacs-cpp-presets-active root)))

(defun emacs-cpp-debug--executable-p (file)
  "Non-nil if FILE is an ELF program: executable, not a shared library."
  (and (file-regular-p file)
       (file-executable-p file)
       (not (string-match-p "\\.so\\(?:\\.[0-9]+\\)*\\'" file))
       (with-temp-buffer
         (set-buffer-multibyte nil)
         (insert-file-contents-literally file nil 0 4)
         (equal (buffer-string) "\177ELF"))))

(defun emacs-cpp-debug-executables (dir)
  "Return the programs under build directory DIR, absolute and sorted.
CMake's own directories (CMakeFiles, hidden ones like .cmake) are skipped."
  (unless (file-directory-p dir)
    (user-error "emacs-cpp: no build directory %s; configure and build the preset \
first" dir))
  (seq-filter #'emacs-cpp-debug--executable-p
              (sort (directory-files-recursively
                     dir "" nil
                     (lambda (subdir)
                       (let ((name (file-name-nondirectory subdir)))
                         (not (or (equal name "CMakeFiles")
                                  (string-prefix-p "." name))))))
                    #'string<)))

(defun emacs-cpp-debug-read-program ()
  "Ask for a program of the active preset's build directory; return its path.
The `:program' of `gdb-preset'; dape calls it in the project root."
  (let* ((root (emacs-cpp-debug--root))
         (dir (emacs-cpp-debug--build-dir root))
         (programs (mapcar (lambda (file) (file-relative-name file dir))
                           (emacs-cpp-debug-executables dir))))
    (unless programs
      (user-error "emacs-cpp: no program in %s; build the preset first" dir))
    (expand-file-name
     (completing-read (format "Program in %s: " (abbreviate-file-name dir))
                      programs nil t nil 'emacs-cpp-debug--program-history
                      (or (seq-find (lambda (old) (member old programs))
                                    emacs-cpp-debug--program-history)
                          (and (length= programs 1) (car programs))))
     dir)))

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
  "Return the command that builds PROGRAM's target in ROOT's active preset.
The target is the program's file name, CMake's default for an executable."
  (let ((dir (emacs-cpp-debug--build-dir root)))
    (unless (and (file-name-absolute-p program)
                 (file-in-directory-p program dir))
      (user-error "emacs-cpp: program %s is not in the build directory %s (D-031)"
                  program dir))
    (format "cmake --build %s --target %s" (shell-quote-argument dir)
            (shell-quote-argument (file-name-nondirectory program)))))

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
