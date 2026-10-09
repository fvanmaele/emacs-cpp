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
;; CMakeUserPresets.json, `inherits', `condition' (all types but the regular
;; expression ones), and the macros ${sourceDir}, ${sourceParentDir},
;; ${sourceDirName}, ${presetName}, ${generator}, ${hostSystemName}, ${fileDir},
;; ${dollar}, ${pathListSep}, $env{NAME}, $penv{NAME}.  Anything else (`include',
;; $vendor{...}, `matches') is an error rather than a guess.

;;; Code:

(require 'cl-lib)
(require 'project)
(require 'subr-x)
(require 'seq)

(defcustom emacs-cpp-presets-state-file
  (expand-file-name "emacs-cpp-presets.eld" user-emacs-directory)
  "File remembering the active preset per project root."
  :type 'file
  :group 'tools)

(defcustom emacs-cpp-clangd-program nil
  "The patched clangd that answers navigation from its index, or nil (D-026).
Nil starts the system clangd.  A path, normally
/opt/clangd-index-nav/bin/clangd from packaging/clangd-index-nav (D-027), starts
that program with `emacs-cpp-presets--patched-flags'; it must exist and support
them, otherwise eglot is refused rather than started without them."
  :type '(choice (const :tag "System clangd" nil) file)
  :group 'tools)

(defconst emacs-cpp-presets--patched-flags
  '("--navigation-from-index" "--header-flags-from-index")
  "Flags of the patched clangd (D-026, D-028), passed when it is configured.")

(defvar emacs-cpp-presets--navigation-support nil
  "Cache of (PROGRAM MODTIME . MISSING-FLAGS) for `emacs-cpp-clangd-program'.")

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

(defun emacs-cpp-presets-visible-names (root)
  "Return the names of the configure presets of ROOT that `cmake --preset' takes.
That is the presets neither hidden nor disabled by their `condition'
\(inherited as in CMake), in file order."
  (let ((presets (emacs-cpp-presets-read root)))
    (cl-loop for preset in presets
             for name = (alist-get 'name preset)
             unless (or (eq (alist-get 'hidden preset) t)
                        (not (emacs-cpp-presets--enabled-p
                              root (emacs-cpp-presets-resolve presets name))))
             collect name)))

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
      (let ((resolved (emacs-cpp-presets-resolve presets parent (cons name chain))))
        ;; A null `condition' enables its own preset but is not inherited (CMake).
        (when (and (assq 'condition resolved) (null (alist-get 'condition resolved)))
          (setq resolved (assq-delete-all 'condition (copy-alist resolved))))
        (setq merged (emacs-cpp-presets--merge merged resolved))))
    (setq merged (emacs-cpp-presets--merge merged preset))
    (setf (alist-get 'hidden merged) (alist-get 'hidden preset))
    (setf (alist-get 'inherits merged nil 'remove) nil)
    merged))

(defvar emacs-cpp-presets--env-chain nil
  "Names of the preset environment variables being expanded, to stop cycles.")

(defun emacs-cpp-presets--env (name root preset)
  "Return $env{NAME} for PRESET of the project at ROOT, as CMake does.
The preset's `environment' wins over the process environment; its values are
expanded in turn, and a null value means unset."
  (let ((cell (assq (intern name) (alist-get 'environment preset))))
    (cond
     ((null cell) (or (getenv name) ""))
     ((null (cdr cell)) "")
     ((member name emacs-cpp-presets--env-chain)
      (error "emacs-cpp: preset %S: environment cycle through %s"
             (alist-get 'name preset) name))
     (t (let ((emacs-cpp-presets--env-chain (cons name emacs-cpp-presets--env-chain)))
          (emacs-cpp-presets--expand (cdr cell) root preset))))))

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
           ;; CMake's CMAKE_HOST_SYSTEM_NAME (D-050).
           ("hostSystemName"
            (pcase system-type
              ('gnu/linux "Linux")
              ('darwin "Darwin")
              (_ (error "emacs-cpp: ${hostSystemName} unknown for %s" system-type))))
           ("dollar" "$")
           ("pathListSep" path-separator)
           ("env" (emacs-cpp-presets--env arg root preset))
           ("penv" (or (getenv arg) ""))
           (_ (error "emacs-cpp: unsupported preset macro %s in %S" match string)))))
     string t t)))

(defun emacs-cpp-presets--condition-p (condition root preset)
  "Non-nil if the CMake preset CONDITION holds for PRESET of the project at ROOT.
A boolean is itself; an absent or null condition holds.  The regular expression
types (`matches', `notMatches') take ECMAScript syntax, which Emacs's regular
expressions do not match faithfully, so they are an error rather than a guess."
  (let ((expand (lambda (string) (emacs-cpp-presets--expand string root preset)))
        (holds (lambda (sub) (emacs-cpp-presets--condition-p sub root preset)))
        (field (lambda (key) (alist-get key condition))))
    (pcase condition
      ('nil t)
      ('t t)
      (:false nil)
      ((pred consp)
       (pcase (funcall field 'type)
         ("const" (eq (funcall field 'value) t))
         ("equals" (equal (funcall expand (funcall field 'lhs))
                          (funcall expand (funcall field 'rhs))))
         ("notEquals" (not (equal (funcall expand (funcall field 'lhs))
                                  (funcall expand (funcall field 'rhs)))))
         ("inList" (and (member (funcall expand (funcall field 'string))
                                (mapcar expand (funcall field 'list)))
                        t))
         ("notInList" (not (member (funcall expand (funcall field 'string))
                                   (mapcar expand (funcall field 'list)))))
         ("anyOf" (and (cl-some holds (funcall field 'conditions)) t))
         ("allOf" (cl-every holds (funcall field 'conditions)))
         ("not" (not (funcall holds (funcall field 'condition))))
         (type (error "emacs-cpp: preset %S: condition type %S is not supported"
                      (alist-get 'name preset) type))))
      (_ (error "emacs-cpp: preset %S: condition %S is not a boolean, null or object"
                (alist-get 'name preset) condition)))))

(defun emacs-cpp-presets--enabled-p (root preset)
  "Non-nil if the resolved PRESET of the project at ROOT is enabled."
  (emacs-cpp-presets--condition-p (alist-get 'condition preset) root preset))

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
  (let ((visible (emacs-cpp-presets-visible-names root))
        (stored (alist-get (file-name-as-directory root) (emacs-cpp-presets--state)
                           nil nil #'equal)))
    (cond
     ((null visible)
      (user-error "emacs-cpp: %s has no configure preset that is neither hidden nor \
disabled by its condition" root))
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

(defun emacs-cpp-presets--missing-flags (program)
  "Return the `emacs-cpp-presets--patched-flags' PROGRAM's help does not list.
Asked once per program file version."
  (let ((modtime (file-attribute-modification-time (file-attributes program)))
        (cached emacs-cpp-presets--navigation-support))
    (if (and cached (equal (car cached) program) (equal (cadr cached) modtime))
        (cddr cached)
      (let ((missing
             (with-temp-buffer
               (if (eql 0 (call-process program nil t nil "--help-hidden"))
                   (seq-remove (lambda (flag)
                                 (goto-char (point-min))
                                 (search-forward flag nil t))
                               emacs-cpp-presets--patched-flags)
                 emacs-cpp-presets--patched-flags))))
        (setq emacs-cpp-presets--navigation-support
              (cons program (cons modtime missing)))
        missing))))

(defun emacs-cpp-presets--clangd-program ()
  "Return the clangd program and the arguments that come with it (D-026)."
  (let ((program emacs-cpp-clangd-program))
    (cond
     ((null program) (list "clangd"))
     ((not (file-executable-p program))
      (emacs-cpp-presets--refuse
       "emacs-cpp: emacs-cpp-clangd-program %s is not executable; install \
packaging/clangd-index-nav or set it to nil (D-026)" program))
     ((emacs-cpp-presets--missing-flags program)
      (emacs-cpp-presets--refuse
       "emacs-cpp: %s lacks %s; it is not the current patched clangd, rebuild \
packaging/clangd-index-nav (D-026)"
       program (string-join (emacs-cpp-presets--missing-flags program) " ")))
     (t (cons program emacs-cpp-presets--patched-flags)))))

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
    (let ((command (emacs-cpp-presets--clangd-program)))
      `(,(car command) ,(concat "--compile-commands-dir=" dir) ,@(cdr command)))))

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

;;;; Build commands

(defun emacs-cpp-presets--current ()
  "Return (ROOT NAME DIR) for the current project's active preset.
DIR is the build directory relative to ROOT, as the commands below run there."
  (let* ((project (or (project-current)
                      (user-error "emacs-cpp: %s is in no project" default-directory)))
         (root (expand-file-name (project-root project)))
         (name (emacs-cpp-presets-active root)))
    (list root name (file-relative-name (emacs-cpp-presets-binary-dir root name) root))))

(defun emacs-cpp-presets-request-codemodel (dir)
  "Ask CMake for its file API codemodel in build directory DIR (D-056).
Writes the shared query file, an empty `.cmake/api/v1/query/codemodel-v2';
every configure of DIR then writes the reply the debug presets read their
targets from.  Only inside the build directory, which CMake owns (D-016)."
  (let ((file (expand-file-name ".cmake/api/v1/query/codemodel-v2" dir)))
    (unless (file-exists-p file)
      (make-directory (file-name-directory file) t)
      (write-region "" nil file nil 'silent))))

(defun emacs-cpp-presets-configure-command ()
  "Return the command configuring the active preset, for projectile (D-035).
Asks for CMake's file API codemodel first, so the configure writes it (D-056)."
  (pcase-let ((`(,root ,name ,dir) (emacs-cpp-presets--current)))
    (emacs-cpp-presets-request-codemodel (expand-file-name dir root))
    (concat "cmake --preset " (shell-quote-argument name))))

(defun emacs-cpp-presets-compile-command ()
  "Return the command building the active preset, for projectile (D-035).
Any buffer of the project builds the same directory; add `--target X' at the
prompt to build one target."
  (pcase-let ((`(,_root ,_name ,dir) (emacs-cpp-presets--current)))
    (concat "cmake --build " (shell-quote-argument dir))))

(defun emacs-cpp-presets-test-command ()
  "Return the command running the active preset's tests, for projectile (D-035)."
  (pcase-let ((`(,_root ,_name ,dir) (emacs-cpp-presets--current)))
    (concat "ctest --test-dir " (shell-quote-argument dir) " --output-on-failure")))

;;;; Switching

(defun emacs-cpp-presets-select (name)
  "Make preset NAME active for the current project and restart its eglot server."
  (interactive
   (let* ((root (expand-file-name (project-root (project-current t))))
          (visible (emacs-cpp-presets-visible-names root)))
     (list (completing-read "CMake preset: " visible nil t nil nil
                            (emacs-cpp-presets-active root)))))
  (let* ((project (project-current t))
         (root (expand-file-name (project-root project))))
    (unless (member name (emacs-cpp-presets-visible-names root))
      (user-error "emacs-cpp: no enabled, non-hidden configure preset %S in %s" name root))
    (emacs-cpp-presets--store root name)
    (when (fboundp 'eglot-current-server)
      (let ((server (eglot-current-server)))
        (when server
          (eglot-shutdown server)
          (eglot-ensure))))
    (message "emacs-cpp: preset %s active for %s" name root)))

(provide 'emacs-cpp-presets)
;;; emacs-cpp-presets.el ends here
