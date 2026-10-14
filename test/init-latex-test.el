;;; init-latex-test.el --- LaTeX with AUCTeX and texlab  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-090): `.tex' opens in AUCTeX's `LaTeX-mode', `.bib'
;; in `bibtex-mode', both start eglot in a project, and eglot's program for them is
;; texlab; texlab's settings send the line to the platform's PDF viewer after a build;
;; `C-c l b' sends texlab's build request and reports its result.  The request is a
;; stub here; the real build with texlab and Skim is a hand check (0061).  `C-c l f'
;; formats a buffer or a region with latexindent, the real one when installed.
;; Needs git.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest init-latex-modes-and-server ()
  "D-090: AUCTeX's mode for .tex, eglot's texlab for it and for .bib."
  (init-test--load)
  (let* ((root (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-tex" t))))
         (default-directory root))
    (unwind-protect
        (progn
          (write-region "\\documentclass{article}\n" nil (expand-file-name "main.tex" root))
          (write-region "@book{k,title={T}}\n" nil (expand-file-name "refs.bib" root))
          (cl-letf (((symbol-function 'eglot-ensure) #'ignore))
            (dolist (case '(("main.tex" . LaTeX-mode) ("refs.bib" . bibtex-mode)))
              (let ((buffer (find-file-noselect (expand-file-name (car case) root))))
                (unwind-protect
                    (with-current-buffer buffer
                      (should (eq major-mode (cdr case)))
                      (require 'eglot)
                      ;; (MODES PROJECT CLASS CONTACT LANGUAGE-IDS)
                      (should (equal (nth 3 (eglot--guess-contact)) '("texlab")))
                      (should (memq #'emacs-cpp-latex-eglot-ensure
                                    (symbol-value (intern (format "%s-hook" major-mode))))))
                  (kill-buffer buffer))))))
      (delete-directory root t))))

(ert-deftest init-latex-viewer-after-build ()
  "D-090: texlab shows the line in the platform's viewer after a build."
  (init-test--load)
  (require 'eglot)
  (let ((texlab (plist-get (default-value 'eglot-workspace-configuration) :texlab)))
    (should (eq (plist-get (plist-get texlab :build) :forwardSearchAfter) t))
    (should (equal (plist-get (plist-get texlab :forwardSearch) :executable)
                   (car emacs-cpp-default-pdf-viewer)))
    (should (equal (plist-get (plist-get texlab :forwardSearch) :args)
                   (vconcat (cdr emacs-cpp-default-pdf-viewer))))))

(ert-deftest init-latex-build-command ()
  "D-090: `C-c l b' sends texlab's build request with the buffer and the line,
and reports texlab's result; without texlab it says so."
  (init-test--load)
  (require 'eglot)
  (should (eq (keymap-lookup emacs-cpp-code-map "b") #'emacs-cpp-latex-build))
  (with-temp-buffer
    (should-error (emacs-cpp-latex-build) :type 'user-error))
  (let ((file (make-temp-file "emacs-cpp-tex" nil ".tex" "\\documentclass{article}\nx\n"))
        sent messages)
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (forward-line 1)
          (setq-local eglot--managed-mode t)
          (cl-letf (((symbol-function 'eglot-current-server) (lambda () 'server))
                    ((symbol-function 'eglot--capabilities)
                     (lambda (_) '(:experimental (:textDocumentBuild t))))
                    ((symbol-function 'jsonrpc-async-request)
                     (lambda (_server method params &rest args)
                       (setq sent (list method params))
                       (funcall (plist-get args :success-fn) '(:status 1))))
                    ((symbol-function 'message)
                     (lambda (format &rest args)
                       (push (apply #'format-message format args) messages))))
            (emacs-cpp-latex-build))
          (should (eq (car sent) :textDocument/build))
          (should (equal (plist-get (plist-get (cadr sent) :position) :line) 1))
          (should (string-suffix-p (file-name-nondirectory file)
                                   (plist-get (plist-get (cadr sent) :textDocument) :uri)))
          (should (string-match-p "with errors" (car messages)))
          (set-buffer-modified-p nil)
          (kill-buffer))
      (delete-file file))))

(defconst init-latex-test--unformatted
  "\\documentclass{article}\n\\begin{document}\n\\begin{itemize}\n\\item one
\\item two\n\\end{itemize}\n\\begin{enumerate}\n\\item three\n\\end{enumerate}
\\end{document}\n"
  "A document latexindent indents in two places: both lists' items.")

(defun init-latex-test--formatted (indent &optional first last)
  "`init-latex-test--unformatted' with the items indented by INDENT.
With FIRST and LAST (line numbers), only the items on those lines."
  (let ((line 0))
    (mapconcat (lambda (text)
                 (setq line (1+ line))
                 (if (and (string-prefix-p "\\item" text)
                          (or (not first) (<= first line last)))
                     (concat indent text)
                   text))
               (split-string init-latex-test--unformatted "\n")
               "\n")))

(defmacro init-latex-test--with-document (&rest body)
  "Run BODY in a LaTeX buffer of `init-latex-test--unformatted', eglot off.
No user settings of latexindent's are read, whatever the machine has."
  (declare (indent 0))
  `(let ((file (make-temp-file "emacs-cpp-tex" nil ".tex" init-latex-test--unformatted))
         (emacs-cpp-latex--user-settings nil))
     (unwind-protect
         (cl-letf (((symbol-function 'eglot-ensure) #'ignore))
           (with-current-buffer (find-file-noselect file)
             (unwind-protect
                 (progn ,@body)
               (set-buffer-modified-p nil)
               (kill-buffer))))
       (delete-file file))))

(defun init-latex-test--select-lines (first last)
  "Make the region the lines FIRST to LAST, active, as a user marks them."
  ;; Off in batch Emacs; without it no region counts as active.
  (setq-local transient-mark-mode t)
  (goto-char (point-min))
  (forward-line (1- first))
  (push-mark (point) t t)
  (forward-line (1+ (- last first))))

(ert-deftest init-latex-format-region ()
  "D-101: `C-c l f' with a region indents only its lines, as the buffer format
would, in one undo step; point stays."
  (skip-unless (executable-find emacs-cpp-latex-indent-program))
  (init-test--load)
  (init-latex-test--with-document
    (should (eq (key-binding (kbd "C-c l f")) #'emacs-cpp-latex-format))
    (buffer-enable-undo)
    ;; The itemize list, lines 3 - 6; the enumerate list stays as it is.
    (init-latex-test--select-lines 3 6)
    (call-interactively (key-binding (kbd "C-c l f")))
    (should (equal (buffer-string) (init-latex-test--formatted "  " 3 6)))
    (should (equal (line-number-at-pos) 7))
    ;; One undo record set, no boundary inside: one step brings it all back.
    (should-not (memq nil buffer-undo-list))
    (primitive-undo 1 buffer-undo-list)
    (should (equal (buffer-string) init-latex-test--unformatted))))

(ert-deftest init-latex-format-buffer ()
  "D-101, D-103: without a region `C-c l f' formats the whole buffer with
latexindent, not texlab, indenting as AUCTeX's `TAB' (`LaTeX-indent-level'
spaces, a tab with `indent-tabs-mode'); the menu's Format Buffer formats the
whole buffer also with a region."
  (skip-unless (executable-find emacs-cpp-latex-indent-program))
  (init-test--load)
  (init-latex-test--with-document
    (cl-letf (((symbol-function 'eglot-format)
               (lambda (&rest _) (interactive) (error "texlab asked"))))
      (should (equal LaTeX-indent-level 2))
      (deactivate-mark)
      (call-interactively (key-binding (kbd "C-c l f")))
      (should (equal (buffer-string) (init-latex-test--formatted "  ")))
      (erase-buffer)
      (insert init-latex-test--unformatted)
      (should (eq (key-binding [remap eglot-format-buffer])
                  #'emacs-cpp-latex-format-buffer))
      (init-latex-test--select-lines 3 6)
      (call-interactively #'emacs-cpp-latex-format-buffer)
      (should (equal (buffer-string) (init-latex-test--formatted "  ")))
      (erase-buffer)
      (insert init-latex-test--unformatted)
      (setq-local indent-tabs-mode t)
      (emacs-cpp-latex-format-buffer)
      (should (equal (buffer-string) (init-latex-test--formatted "\t"))))))

(ert-deftest init-latex-format-project-settings ()
  "D-103: a project's `.latexindent.yaml' wins, read where texlab reads it: the
nearest directory upward with `.latexmkrc' (or texlabroot), else the file's."
  (skip-unless (executable-find emacs-cpp-latex-indent-program))
  (init-test--load)
  (let* ((root (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-tex" t))))
         (default-directory root)
         (emacs-cpp-latex--user-settings nil))
    (unwind-protect
        (cl-letf (((symbol-function 'eglot-ensure) #'ignore))
          (call-process "git" nil nil nil "init" "-q")
          (make-directory (expand-file-name "chapters" root))
          (write-region "defaultIndent: \"    \"\n" nil (expand-file-name ".latexindent.yaml" root))
          (dolist (case '(("main.tex" nil . "    ")             ; the file's own directory
                          ("chapters/one.tex" nil . "  ")     ; not read from below
                          ("chapters/one.tex" t . "    ")))   ; .latexmkrc at the root
            (when (cadr case)
              (write-region "" nil (expand-file-name ".latexmkrc" root)))
            (let ((file (expand-file-name (car case) root)))
              (write-region init-latex-test--unformatted nil file)
              (with-current-buffer (find-file-noselect file)
                (unwind-protect
                    (progn
                      (emacs-cpp-latex-format-buffer)
                      (should (equal (cons (car case) (buffer-string))
                                     (cons (car case)
                                           (init-latex-test--formatted (cddr case))))))
                  (set-buffer-modified-p nil)
                  (kill-buffer))))))
      (delete-directory root t))))

(ert-deftest init-latex-format-refusals ()
  "D-101: a missing or failing latexindent stops with the reason and leaves the
buffer as it was."
  (init-test--load)
  (init-latex-test--with-document
    (let ((original (buffer-string)))
      (init-latex-test--select-lines 3 6)
      (let ((emacs-cpp-latex-indent-program "emacs-cpp-no-such-latexindent"))
        (should (string-match-p
                 "not found"
                 (cadr (should-error (call-interactively #'emacs-cpp-latex-format)
                                     :type 'user-error))))
        (should-error (emacs-cpp-latex-format-buffer) :type 'user-error))
      (cl-letf (((symbol-function 'executable-find) (lambda (_) "/bin/latexindent"))
                ((symbol-function 'call-process)
                 (lambda (_program _infile destination &rest _)
                   (insert "half a document")
                   (with-temp-file (cadr destination) (insert "Cannot read file\n"))
                   2)))
        (should (string-match-p
                 "latexindent failed (2): Cannot read file"
                 (cadr (should-error (call-interactively #'emacs-cpp-latex-format)
                                     :type 'user-error)))))
      (should (equal (buffer-string) original)))))

(provide 'init-latex-test)
;;; init-latex-test.el ends here
