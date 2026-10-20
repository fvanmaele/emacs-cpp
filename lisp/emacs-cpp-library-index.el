;;; emacs-cpp-library-index.el --- A library's offline index for clangd  -*- lexical-binding: t; -*-

;;; Commentary:

;; A project names the libraries whose sources it navigates into in its
;; .dir-locals.el (`emacs-cpp-project-libraries', D-130); `make library-index
;; LIBRARY=dealii' builds that library's index offline into indexes/ (D-133), with a
;; stamp: the library's version, where its sources lie, and a probe symbol.  clangd
;; then gets `--index-file=<index>' (D-130).
;;
;; clangd loads such an index only on its first query, in about a second; until then
;; it answers from an empty index, and it lets a file that is not an index pass in
;; silence (it reads it as an empty YAML index).  So (D-131): before clangd starts,
;; an unknown library, a missing index or one that does not start with `RIFF' refuse
;; eglot, and a version other than the installed one is a warning; when clangd
;; connects, the probe symbol is asked for every 0.5 s until a result lies in the
;; library's sources (that also starts the load), at most 10 s; clangd's own
;; "Can't open" or "Bad index file" on its stderr is a warning.  Nothing is
;; swallowed.

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defvar emacs-cpp-root)
(defvar emacs-cpp-default-library-include-dir)

(defvar-local emacs-cpp-project-libraries nil
  "Libraries whose offline index clangd gets in this project, as symbols (D-130).
Set in the project's .dir-locals.el, for example
  ((nil . ((emacs-cpp-project-libraries . (dealii)))))
clangd takes one index, so at most one library.")
(put 'emacs-cpp-project-libraries 'safe-local-variable
     (lambda (value) (and (listp value) (cl-every #'symbolp value))))

(defconst emacs-cpp-library-index-libraries
  '((dealii :name "deal.II"
            :version-header "deal.II/base/config.h"
            :version-regexp "^#define DEAL_II_PACKAGE_VERSION \"\\([^\"]+\\)\""))
  "Libraries `make library-index' can index, and how to read the installed version:
the header under `emacs-cpp-default-library-include-dir' and the regexp whose
first group is the version.")

(defcustom emacs-cpp-library-index-probe-interval 0.5
  "Seconds between the probes of a library index after clangd connects (D-131)."
  :type 'number
  :group 'tools)

(defcustom emacs-cpp-library-index-probe-timeout 10
  "Seconds after which a library index that answered no probe is warned about."
  :type 'number
  :group 'tools)

(defun emacs-cpp-library-index-directory ()
  "Return the directory indexes are built into: indexes/ of the repository (D-133)."
  (file-name-as-directory (expand-file-name "indexes" emacs-cpp-root)))

(defun emacs-cpp-library-index-file (library)
  "Return LIBRARY's index file."
  (expand-file-name (format "%s.dex" library) (emacs-cpp-library-index-directory)))

(defun emacs-cpp-library-index--stamp-file (library)
  "Return LIBRARY's stamp file, written next to its index by the build."
  (expand-file-name (format "%s.stamp" library) (emacs-cpp-library-index-directory)))

(defun emacs-cpp-library-index--warn (format &rest args)
  "Show FORMAT with ARGS as a warning of the library index (D-131)."
  (display-warning 'emacs-cpp (apply #'format format args) :warning))

(defun emacs-cpp-library-index--build-command (library)
  "Return the command that builds LIBRARY's index, for messages."
  (format "make library-index LIBRARY=%s" library))

(defun emacs-cpp-library-index--riff-p (file)
  "Non-nil when FILE starts with `RIFF', as clangd's index files do."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file nil 0 4)
    (equal (buffer-string) "RIFF")))

(defun emacs-cpp-library-index-stamp (library)
  "Return LIBRARY's stamp, a plist (:version :sources :probe), or signal why not."
  (let ((file (emacs-cpp-library-index--stamp-file library)))
    (unless (file-readable-p file)
      (user-error "emacs-cpp: no stamp %s for the %s index; run `%s' (D-131)"
                  file library (emacs-cpp-library-index--build-command library)))
    (let ((stamp (with-temp-buffer (insert-file-contents file) (read (current-buffer)))))
      (unless (and (plist-get stamp :version) (plist-get stamp :sources)
                   (plist-get stamp :probe))
        (user-error "emacs-cpp: stamp %s lacks :version, :sources or :probe; run `%s'"
                    file (emacs-cpp-library-index--build-command library)))
      stamp)))

(defun emacs-cpp-library-index-installed-version (library)
  "Return the installed version of LIBRARY, or nil when it cannot be read."
  (let* ((spec (alist-get library emacs-cpp-library-index-libraries))
         (header (and emacs-cpp-default-library-include-dir
                      (expand-file-name (plist-get spec :version-header)
                                        emacs-cpp-default-library-include-dir))))
    (when (and header (file-readable-p header))
      (with-temp-buffer
        (insert-file-contents header)
        (when (re-search-forward (plist-get spec :version-regexp) nil t)
          (match-string 1))))))

(defun emacs-cpp-library-index-check (libraries)
  "Check the index of LIBRARIES before clangd starts; return (LIBRARY . STAMP).
Nil when LIBRARIES is empty.  Signals for an unknown library, more than one, a
missing, unreadable or non-index file (D-131 (a), (b), (b2)); warns when the
index was built for another version than the installed one (d)."
  (when libraries
    (when (cdr libraries)
      (user-error "emacs-cpp: emacs-cpp-project-libraries names %s; clangd takes one \
index (--index-file), so name one library" libraries))
    (let* ((library (car libraries))
           (file (emacs-cpp-library-index-file library)))
      (unless (alist-get library emacs-cpp-library-index-libraries)
        (user-error "emacs-cpp: library %s in emacs-cpp-project-libraries is not in \
emacs-cpp-library-index-libraries (known: %s)"
                    library (mapcar #'car emacs-cpp-library-index-libraries)))
      (unless (file-readable-p file)
        (user-error "emacs-cpp: no index %s for %s; run `%s' (D-130)"
                    file library (emacs-cpp-library-index--build-command library)))
      (unless (emacs-cpp-library-index--riff-p file)
        (user-error "emacs-cpp: %s is not a clangd index (no RIFF header; clangd would \
read it as an empty index); run `%s'" file (emacs-cpp-library-index--build-command library)))
      (let ((stamp (emacs-cpp-library-index-stamp library))
            (installed (emacs-cpp-library-index-installed-version library)))
        (cond
         ((null installed)
          (emacs-cpp-library-index--warn
           "emacs-cpp: the installed %s version cannot be read (no %s under %s); the \
index is for %s"
           library (plist-get (alist-get library emacs-cpp-library-index-libraries)
                              :version-header)
           emacs-cpp-default-library-include-dir (plist-get stamp :version)))
         ((not (equal installed (plist-get stamp :version)))
          (emacs-cpp-library-index--warn
           "emacs-cpp: the %s index is for %s, the installed version is %s; `M-.' may \
land on stale definitions; run `%s'"
           library (plist-get stamp :version) installed
           (emacs-cpp-library-index--build-command library))))
        (cons library stamp)))))

(defun emacs-cpp-library-index-flags (checked)
  "Return clangd's flags for CHECKED, (LIBRARY . STAMP) of the check, or nil."
  (when checked
    (list (concat "--index-file=" (emacs-cpp-library-index-file (car checked))))))

;;;; After clangd connects

(defvar emacs-cpp-library-index--pending (make-hash-table :test #'equal)
  "Project root -> (LIBRARY . STAMP) whose probe runs when that clangd connects.")

(defun emacs-cpp-library-index-expect (root checked)
  "Remember that the clangd starting for ROOT has CHECKED, (LIBRARY . STAMP)."
  (if checked
      (puthash (expand-file-name root) checked emacs-cpp-library-index--pending)
    (remhash (expand-file-name root) emacs-cpp-library-index--pending)))

(defun emacs-cpp-library-index--watch-stderr (server library)
  "Warn once when SERVER's stderr reports that LIBRARY's index failed (D-131 (c))."
  (when-let* ((buffer (jsonrpc-stderr-buffer server)))
    (with-current-buffer buffer
      (let ((warned nil)
            (regexp "\\(Can't open .*\\.dex.*\\|Bad index file.*\\)$"))
        (cl-flet ((scan (beg)
                    (save-excursion
                      (goto-char beg)
                      (when (and (not warned) (re-search-forward regexp nil t))
                        (setq warned t)
                        (emacs-cpp-library-index--warn
                         "emacs-cpp: clangd could not load the %s index: %s; `M-.' gives \
declarations, not %s's definitions; run `%s'"
                         library (match-string 1) library
                         (emacs-cpp-library-index--build-command library))))))
          (scan (point-min))
          (add-hook 'after-change-functions
                    (lambda (beg _end _len) (scan (save-excursion (goto-char beg)
                                                                 (line-beginning-position))))
                    nil t))))))

(defun emacs-cpp-library-index--probe (server library stamp deadline)
  "Ask SERVER for STAMP's probe symbol until a result lies in LIBRARY's sources.
Repeats every `emacs-cpp-library-index-probe-interval' seconds until DEADLINE
\(a `float-time'); warns when it passes or the request fails (D-131 (e))."
  (let ((sources (concat "file://" (file-name-as-directory (plist-get stamp :sources))))
        (fallback "`M-.' gives declarations until clangd loads the index by itself"))
    (jsonrpc-async-request
     server :workspace/symbol (list :query (plist-get stamp :probe))
     :success-fn
     (lambda (symbols)
       (cond
        ((cl-some (lambda (symbol)
                    (string-prefix-p sources (plist-get (plist-get symbol :location) :uri)))
                  symbols))
        ((< (float-time) deadline)
         (run-at-time emacs-cpp-library-index-probe-interval nil
                      #'emacs-cpp-library-index--probe server library stamp deadline))
        (t (emacs-cpp-library-index--warn
            "emacs-cpp: no symbol from the %s index after %s s (asked for %s); %s"
            library emacs-cpp-library-index-probe-timeout (plist-get stamp :probe)
            fallback))))
     :error-fn
     (lambda (error)
       (emacs-cpp-library-index--warn
        "emacs-cpp: the probe of the %s index failed: %S; %s" library error fallback))
     :timeout-fn
     (lambda ()
       (emacs-cpp-library-index--warn
        "emacs-cpp: the probe of the %s index timed out; %s" library fallback)))))

(defun emacs-cpp-library-index-on-connect (server)
  "Start the probe and the stderr watch when SERVER has a library index.
For `eglot-connect-hook'."
  (let* ((root (expand-file-name (project-root (eglot--project server))))
         (checked (gethash root emacs-cpp-library-index--pending)))
    (when checked
      (remhash root emacs-cpp-library-index--pending)
      (emacs-cpp-library-index--watch-stderr server (car checked))
      (emacs-cpp-library-index--probe server (car checked) (cdr checked)
                                      (+ (float-time)
                                         emacs-cpp-library-index-probe-timeout)))))

(declare-function eglot--project "eglot")
(declare-function jsonrpc-async-request "jsonrpc")
(declare-function jsonrpc-stderr-buffer "jsonrpc")
(declare-function project-root "project")

(provide 'emacs-cpp-library-index)
;;; emacs-cpp-library-index.el ends here
