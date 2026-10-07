;;; emacs-cpp-presets.el --- Active CMake preset per project, clangd's database  -*- lexical-binding: t; -*-

;;; Commentary:

;; CMakePresets.json is the build profile mechanism (D-005).  This library answers
;; "which preset is active for this project, and where is its build directory?"
;; (D-017), and computes the clangd command for eglot from it (D-016):
;;
;;   clangd --compile-commands-dir=<binaryDir of the active preset>
;;
;; The default preset is the first non-hidden configure preset; `emacs-cpp-presets-select'
;; switches it and remembers the choice per project in `emacs-cpp-presets-state-file'
;; (outside the project).  eglot is refused, loudly, when the database is missing or a
;; compile command lacks -std (D-011, D-018): clangd would otherwise fall back to
;; default flags and report false errors.
;;
;; Supported preset features: configurePresets in CMakePresets.json and
;; CMakeUserPresets.json, `inherits', and the macros ${sourceDir}, ${sourceParentDir},
;; ${sourceDirName}, ${presetName}, ${generator}, ${hostSystemName}, ${fileDir},
;; ${dollar}, ${pathListSep}, $env{NAME}, $penv{NAME}.  Anything else (`include',
;; $vendor{...}) is an error rather than a guess.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'subr-x)

(defcustom emacs-cpp-presets-state-file
  (expand-file-name "emacs-cpp-presets.eld" user-emacs-directory)
  "File remembering the active preset per project root."
  :type 'file
  :group 'tools)

(defconst emacs-cpp-presets--files '("CMakePresets.json" "CMakeUserPresets.json")
  "Preset files read from a project root, in CMake's order.")

;;;; Reading presets

(defun emacs-cpp-presets--read-file (file)
  "Return the configure presets of FILE as a list of alists, or nil if absent."
  (when (file-exists-p file)
    (let ((json (with-temp-buffer
                  (insert-file-contents file)
                  (json-parse-buffer :object-type 'alist :array-type 'list
                                     :null-object nil :false-object :false))))
      (when (alist-get 'include json)
        (error "emacs-cpp: %s uses `include', which is not supported yet" file))
      (alist-get 'configurePresets json))))

(defun emacs-cpp-presets-read (root)
  "Return all configure presets of the project at ROOT.
Signal an error if the project has no CMakePresets.json (D-005) or a preset
name appears twice."
  (unless (file-exists-p (expand-file-name "CMakePresets.json" root))
    (user-error "emacs-cpp: no CMakePresets.json in %s (presets are required, D-005)"
                root))
  (let ((presets (cl-loop for name in emacs-cpp-presets--files
                          append (emacs-cpp-presets--read-file
                                  (expand-file-name name root))))
        seen)
    (dolist (preset presets)
      (let ((name (alist-get 'name preset)))
        (when (member name seen)
          (error "emacs-cpp: configure preset %S is defined twice in %s" name root))
        (push name seen)))
    presets))

(defun emacs-cpp-presets-visible-names (presets)
  "Return the names of the non-hidden PRESETS, in file order."
  (cl-loop for preset in presets
           unless (eq (alist-get 'hidden preset) t)
           collect (alist-get 'name preset)))

;;;; Inheritance and macros

(defun emacs-cpp-presets--merge (base override)
  "Return alist BASE with the fields of OVERRIDE taking precedence.
The `environment' and `cacheVariables' objects are merged field by field."
  (let ((result (copy-alist base)))
    (pcase-dolist (`(,key . ,value) override)
      (setf (alist-get key result)
            (if (memq key '(environment cacheVariables))
                (emacs-cpp-presets--merge (alist-get key result) value)
              value)))
    result))

(defun emacs-cpp-presets-resolve (presets name &optional chain)
  "Return preset NAME from PRESETS with its `inherits' applied.
As in CMake, an earlier parent wins over a later one, the preset's own fields
win over all parents, and `hidden' is not inherited.  CHAIN detects cycles."
  (when (member name chain)
    (error "emacs-cpp: preset inheritance cycle: %s"
           (string-join (reverse (cons name chain)) " -> ")))
  (let* ((preset (or (cl-find name presets :key (lambda (p) (alist-get 'name p))
                              :test #'equal)
                     (error "emacs-cpp: no configure preset named %S" name)))
         (parents (let ((inherits (alist-get 'inherits preset)))
                    (if (stringp inherits) (list inherits) inherits)))
         (merged nil))
    (dolist (parent (reverse parents))
      (setq merged (emacs-cpp-presets--merge
                    merged (emacs-cpp-presets-resolve presets parent (cons name chain)))))
    (setq merged (emacs-cpp-presets--merge merged preset))
    (setf (alist-get 'hidden merged) (alist-get 'hidden preset))
    (setf (alist-get 'inherits merged nil 'remove) nil)
    merged))

(defun emacs-cpp-presets--expand (string root preset)
  "Expand the CMake preset macros in STRING for PRESET of the project at ROOT."
  (let ((source (directory-file-name (expand-file-name root))))
    (replace-regexp-in-string
     "\\$\\(?:{\\([A-Za-z]+\\)}\\|\\(p?env\\|vendor\\){\\([^}]*\\)}\\)"
     (lambda (match)
       (let ((macro (match-string 1 match))
             (kind (match-string 2 match))
             (arg (match-string 3 match)))
         (pcase (or macro kind)
           ("sourceDir" source)
           ("sourceParentDir" (directory-file-name (file-name-directory source)))
           ("sourceDirName" (file-name-nondirectory source))
           ("fileDir" source)
           ("presetName" (alist-get 'name preset))
           ("generator" (or (alist-get 'generator preset)
                            (error "emacs-cpp: ${generator} used but preset %S has none"
                                   (alist-get 'name preset))))
           ("hostSystemName"
            (if (eq system-type 'gnu/linux) "Linux"
              (error "emacs-cpp: ${hostSystemName} only supported on GNU/Linux")))
           ("dollar" "$")
           ("pathListSep" path-separator)
           ("env" (or (cdr (assq (intern arg) (alist-get 'environment preset)))
                      (getenv arg) ""))
           ("penv" (or (getenv arg) ""))
           (_ (error "emacs-cpp: unsupported preset macro %s in %S" match string)))))
     string t t)))

(defun emacs-cpp-presets-binary-dir (root name)
  "Return the absolute build directory of preset NAME of the project at ROOT."
  (let* ((preset (emacs-cpp-presets-resolve (emacs-cpp-presets-read root) name))
         (binary-dir (or (alist-get 'binaryDir preset)
                         (user-error "emacs-cpp: preset %S has no binaryDir" name))))
    (directory-file-name
     (expand-file-name (emacs-cpp-presets--expand binary-dir root preset) root))))

;;;; Active preset

(defun emacs-cpp-presets--state ()
  "Return the stored alist of (ROOT . PRESET-NAME)."
  (when (file-exists-p emacs-cpp-presets-state-file)
    (with-temp-buffer
      (insert-file-contents emacs-cpp-presets-state-file)
      (read (current-buffer)))))

(defun emacs-cpp-presets--store (root name)
  "Remember NAME as the active preset of ROOT."
  (let ((state (emacs-cpp-presets--state)))
    (setf (alist-get (file-name-as-directory root) state nil nil #'equal) name)
    (with-temp-file emacs-cpp-presets-state-file
      (insert ";; Active CMake preset per project; written by emacs-cpp-presets.el\n")
      (prin1 state (current-buffer))
      (insert "\n"))))

(defun emacs-cpp-presets-active (root)
  "Return the active preset name of the project at ROOT.
That is the stored choice, else the first non-hidden configure preset.  A
stored choice that no longer exists is an error, not a silent fallback."
  (let ((visible (emacs-cpp-presets-visible-names (emacs-cpp-presets-read root)))
        (stored (alist-get (file-name-as-directory root) (emacs-cpp-presets--state)
                           nil nil #'equal)))
    (cond
     ((null visible)
      (user-error "emacs-cpp: %s has no non-hidden configure preset" root))
     ((null stored) (car visible))
     ((member stored visible) stored)
     (t (user-error "emacs-cpp: stored preset %S is no longer in %s; choose one with %s"
                    stored root
                    (substitute-command-keys "\\[emacs-cpp-presets-select]"))))))

;;;; clangd

(defun emacs-cpp-presets-check-database (file)
  "Signal an error unless every compile command in FILE carries -std= (D-011)."
  (let* ((entries (with-temp-buffer
                    (insert-file-contents file)
                    (json-parse-buffer :object-type 'alist :array-type 'list)))
         (missing (cl-remove-if
                   (lambda (entry)
                     (let ((command (alist-get 'command entry))
                           (arguments (alist-get 'arguments entry)))
                       (if command
                           (string-match-p "\\(?:^\\|[ \t]\\)-std=" command)
                         (cl-some (lambda (arg) (string-prefix-p "-std=" arg))
                                  arguments))))
                   entries)))
    (when missing
      (user-error "emacs-cpp: %d of %d compile commands in %s lack -std= (e.g. %s); \
set CMAKE_CXX_EXTENSIONS OFF and reconfigure (D-011)"
                  (length missing) (length entries) file
                  (alist-get 'file (car missing))))))

(defun emacs-cpp-presets--refuse (format &rest args)
  "Show FORMAT with ARGS as an error-level warning, then signal it.
eglot only logs errors from a contact function, so the warning makes the
refusal visible (D-018)."
  (let ((message (apply #'format format args)))
    (display-warning 'emacs-cpp message :error)
    (user-error "%s" message)))

(defun emacs-cpp-presets-clangd-contact (_interactive project)
  "Return the clangd command for PROJECT, for `eglot-server-programs'."
  (let* ((root (expand-file-name (project-root project)))
         (name (emacs-cpp-presets-active root))
         (dir (emacs-cpp-presets-binary-dir root name))
         (database (expand-file-name "compile_commands.json" dir)))
    (unless (file-exists-p database)
      (emacs-cpp-presets--refuse
       "emacs-cpp: no %s for preset %S; run `cmake --preset %s' in %s, then M-x eglot"
       database name name root))
    (condition-case err
        (emacs-cpp-presets-check-database database)
      (user-error (emacs-cpp-presets--refuse "%s" (error-message-string err))))
    (list "clangd" (concat "--compile-commands-dir=" dir))))

;;;; Starting eglot

(defun emacs-cpp-presets-eglot-ensure ()
  "Start eglot for the current C++ buffer if its project has CMake presets.
For `c++-ts-mode-hook'.  A file in a project without CMakePresets.json gets
an echo-area note instead (D-005).  A file in no project, such as a library
header opened directly, gets no language server and no note; library headers
reached with `M-.' join the project's server through `eglot-extend-to-xref'."
  (when-let* ((project (project-current)))
    (let ((root (expand-file-name (project-root project))))
      (if (file-exists-p (expand-file-name "CMakePresets.json" root))
          (eglot-ensure)
        (message "emacs-cpp: no CMakePresets.json in %s; eglot not started (D-005)"
                 root)))))

;;;; Switching

(defun emacs-cpp-presets-select (name)
  "Make preset NAME active for the current project and restart its eglot server."
  (interactive
   (let* ((root (expand-file-name (project-root (project-current t))))
          (visible (emacs-cpp-presets-visible-names (emacs-cpp-presets-read root))))
     (list (completing-read "CMake preset: " visible nil t nil nil
                            (emacs-cpp-presets-active root)))))
  (let* ((project (project-current t))
         (root (expand-file-name (project-root project))))
    (unless (member name (emacs-cpp-presets-visible-names (emacs-cpp-presets-read root)))
      (user-error "emacs-cpp: no non-hidden configure preset %S in %s" name root))
    (emacs-cpp-presets--store root name)
    (when (fboundp 'eglot-current-server)
      (let ((server (eglot-current-server)))
        (when server
          (eglot-shutdown server)
          (eglot-ensure))))
    (message "emacs-cpp: preset %s active for %s" name root)))

(provide 'emacs-cpp-presets)
;;; emacs-cpp-presets.el ends here
