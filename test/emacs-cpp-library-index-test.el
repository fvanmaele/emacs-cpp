;;; emacs-cpp-library-index-test.el --- Tests for lisp/emacs-cpp-library-index.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; T-118 (D-130, D-131): the library index in clangd's command and every way it can
;; fail told.  Temporary directories stand in for indexes/ and the installed
;; headers; the language server is stubbed, so no clangd or deal.II is needed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'emacs-cpp-presets-test)
(require 'emacs-cpp-library-index)
(require 'jsonrpc)

(defvar emacs-cpp-root)
(defvar emacs-cpp-default-library-include-dir)

(defmacro emacs-cpp-library-index-test--with (spec &rest body)
  "Run BODY with a temporary repository and include directory, from SPEC.
SPEC is a plist: :index (content of indexes/dealii.dex, nil for none), :stamp
\(a plist written to indexes/dealii.stamp), :installed (deal.II version in the
temporary include directory's config.h, nil for none).  Binds `warnings', the
warnings shown, newest first, as (LEVEL MESSAGE)."
  (declare (indent 1))
  `(let* ((top (file-name-as-directory (make-temp-file "emacs-cpp-library-index" t)))
          (emacs-cpp-root (expand-file-name "repo/" top))
          (emacs-cpp-default-library-include-dir (expand-file-name "include/" top))
          (spec (list ,@spec))
          warnings)
     (unwind-protect
         (cl-letf (((symbol-function 'display-warning)
                    (lambda (_type message &optional level _buffer)
                      (push (list level message) warnings))))
           (make-directory (expand-file-name "indexes" emacs-cpp-root) t)
           (when (plist-get spec :index)
             (let ((coding-system-for-write 'no-conversion))
               (write-region (plist-get spec :index) nil
                             (expand-file-name "indexes/dealii.dex" emacs-cpp-root))))
           (when (plist-get spec :stamp)
             (write-region (prin1-to-string (plist-get spec :stamp)) nil
                           (expand-file-name "indexes/dealii.stamp" emacs-cpp-root)))
           (when (plist-get spec :installed)
             (let ((config (expand-file-name "deal.II/base/config.h"
                                             emacs-cpp-default-library-include-dir)))
               (make-directory (file-name-directory config) t)
               (write-region (format "#define DEAL_II_PACKAGE_VERSION \"%s\"\n"
                                     (plist-get spec :installed))
                             nil config)))
           ,@body)
       (delete-directory top t))))

(defconst emacs-cpp-library-index-test--stamp
  '(:library dealii :version "9.8.0" :sources "/src/dealii-9.8.0/" :probe "n_active_cells")
  "A stamp as `make library-index' writes it.")

(defun emacs-cpp-library-index-test--contact (libraries)
  "Return clangd's contact for a configured project naming LIBRARIES."
  (emacs-cpp-presets-test--with-project
      `(("CMakePresets.json" . ,emacs-cpp-presets-test--presets)
        ("build/debug/compile_commands.json"
         . "[{\"file\": \"a.cc\", \"command\": \"c++ -std=c++20 -c a.cc\"}]"))
    (let ((emacs-cpp-project-libraries libraries))
      (emacs-cpp-presets-clangd-contact nil (cons 'transient root)))))

(ert-deftest emacs-cpp-library-index-in-clangd-command ()
  "Item 1: a project naming dealii gets --index-file; one naming none does not."
  (emacs-cpp-library-index-test--with
      (:index "RIFF0000" :stamp emacs-cpp-library-index-test--stamp :installed "9.8.0")
    (should (member (concat "--index-file="
                            (expand-file-name "indexes/dealii.dex" emacs-cpp-root))
                    (emacs-cpp-library-index-test--contact '(dealii))))
    (should-not (cl-some (lambda (arg) (string-prefix-p "--index-file" arg))
                         (emacs-cpp-library-index-test--contact nil)))
    (should-not warnings)))

(ert-deftest emacs-cpp-library-index-refused-before-clangd ()
  "Items 3 (a), (b), (b2): unknown, two, missing or non-index files refuse eglot
with an error naming the problem and what to do."
  (dolist (case `((:libraries (boost) :index "RIFF" :expect "emacs-cpp-library-index-libraries")
                  (:libraries (dealii boost) :index "RIFF" :expect "name one library")
                  (:libraries (dealii) :index nil
                   :expect "make library-index LIBRARY=dealii")
                  (:libraries (dealii) :index "not an index\n" :expect "no RIFF header")))
    (emacs-cpp-library-index-test--with
        (:index (plist-get case :index) :stamp emacs-cpp-library-index-test--stamp
                :installed "9.8.0")
      (should-error (emacs-cpp-library-index-test--contact (plist-get case :libraries))
                    :type 'user-error)
      (should (= 1 (length warnings)))
      (should (eq :error (car (car warnings))))
      (should (string-match-p (regexp-quote (plist-get case :expect))
                              (cadr (car warnings)))))))

(ert-deftest emacs-cpp-library-index-version-warnings ()
  "Item 3 (d): another installed version, or none readable, warns; clangd starts."
  (dolist (case '(("9.7.1" "the dealii index is for 9.8.0, the installed version is 9.7.1")
                  (nil "the installed dealii version cannot be read")))
    (emacs-cpp-library-index-test--with
        (:index "RIFF" :stamp emacs-cpp-library-index-test--stamp :installed (car case))
      (should (emacs-cpp-library-index-test--contact '(dealii)))
      (should (= 1 (length warnings)))
      (should (eq :warning (car (car warnings))))
      (should (string-match-p (regexp-quote (cadr case)) (cadr (car warnings)))))))

(ert-deftest emacs-cpp-library-index-stderr-warns-once ()
  "Item 3 (c): clangd's `Can't open' on its stderr is one warning per server."
  (let ((stderr (generate-new-buffer " *test stderr*"))
        warnings)
    (unwind-protect
        (cl-letf (((symbol-function 'jsonrpc-stderr-buffer) (lambda (_server) stderr))
                  ((symbol-function 'display-warning)
                   (lambda (_type message &optional level _buffer)
                     (push (list level message) warnings))))
          (with-current-buffer stderr (insert "I[00:00:00.000] clangd started\n"))
          (emacs-cpp-library-index--watch-stderr 'server 'dealii)
          (should-not warnings)
          (with-current-buffer stderr
            (goto-char (point-max))
            (insert "E[00:00:01.000] Can't open /x/indexes/dealii.dex: No such file or directory\n")
            (insert "E[00:00:01.000] Bad index file: whatever\n"))
          (should (= 1 (length warnings)))
          (should (string-match-p "Can't open /x/indexes/dealii.dex" (cadr (car warnings)))))
      (kill-buffer stderr))))

(defun emacs-cpp-library-index-test--probe (replies)
  "Run the probe against a stub server answering REPLIES in turn; return warnings.
Each reply is a list of symbols, `empty', `error' or `timeout'; the last repeats."
  (let ((emacs-cpp-library-index-probe-interval 0.01)
        (emacs-cpp-library-index-probe-timeout 0.2)
        (asked 0)
        warnings)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method _params &rest args)
                 (let ((reply (nth (min asked (1- (length replies))) replies)))
                   (cl-incf asked)
                   (pcase reply
                     ('error (funcall (plist-get args :error-fn) '(:code -1 :message "x")))
                     ('timeout (funcall (plist-get args :timeout-fn)))
                     ('empty (funcall (plist-get args :success-fn) []))
                     (_ (funcall (plist-get args :success-fn) (vconcat reply)))))))
              ((symbol-function 'display-warning)
               (lambda (_type message &optional level _buffer)
                 (push (list level message) warnings))))
      (emacs-cpp-library-index--probe 'server 'dealii emacs-cpp-library-index-test--stamp
                                      (+ (float-time) emacs-cpp-library-index-probe-timeout))
      (let ((end (+ (float-time) 0.6)))
        (while (< (float-time) end) (accept-process-output nil 0.02)))
      (list asked warnings))))

(ert-deftest emacs-cpp-library-index-probe ()
  "Items 2, 3 (e): empty replies are repeated until one lies in the sources; never
one, an error or a timeout warn, saying what `M-.' does meanwhile."
  (let ((library '(:name "n_active_cells"
                   :location (:uri "file:///src/dealii-9.8.0/source/grid/tria.cc")))
        (header '(:name "n_active_cells"
                  :location (:uri "file:///usr/include/deal.II/grid/tria.h"))))
    (pcase-let ((`(,asked ,warnings)
                 (emacs-cpp-library-index-test--probe (list 'empty 'empty (list header library)))))
      (should (= asked 3))
      (should-not warnings))
    (pcase-let ((`(,_ ,warnings) (emacs-cpp-library-index-test--probe (list (list header)))))
      (should (= 1 (length warnings)))
      (should (string-match-p "no symbol from the dealii index" (cadr (car warnings))))
      (should (string-match-p "declarations until clangd loads" (cadr (car warnings)))))
    (dolist (failure '(error timeout))
      (pcase-let ((`(,_ ,warnings) (emacs-cpp-library-index-test--probe (list failure))))
        (should (= 1 (length warnings)))
        (should (string-match-p "probe of the dealii index" (cadr (car warnings))))))))

(provide 'emacs-cpp-library-index-test)
;;; emacs-cpp-library-index-test.el ends here
