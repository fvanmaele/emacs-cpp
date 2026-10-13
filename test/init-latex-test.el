;;; init-latex-test.el --- LaTeX with AUCTeX and texlab  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-090): `.tex' opens in AUCTeX's `LaTeX-mode', `.bib'
;; in `bibtex-mode', both start eglot in a project, and eglot's program for them is
;; texlab; texlab's settings send the line to the platform's PDF viewer after a build;
;; `C-c l b' sends texlab's build request and reports its result.  The request is a
;; stub here; the real build with texlab and Skim is a hand check (0061).  Needs git.

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

(provide 'init-latex-test)
;;; init-latex-test.el ends here
