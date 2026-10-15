;;; init-lsp-test.el --- Mouse navigation, the right-click menu, vendored eglot  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-093): the navigation clicks on the platform's
;; modifier, the press unbound so the click arrives; the click goes to the definition,
;; or lists references when it is on the definition; right click opens a menu, with
;; the language server's entries in a managed buffer.  xref's backend is a stub, so
;; no server is needed; the clicks in a graphical frame are a hand check.
;;
;; eglot comes from lib/eglot with patch 0001 (D-108, T-090): with the watch limit
;; reached pyright keeps running.  That test needs pyright and git.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest init-lsp-mouse-bindings ()
  "D-093: Cmd (Mac) / Super (Arch) clicks; with Opt / Alt implementations, with
Shift the type.  Ctrl's clicks stay Emacs's (buffer menu, rectangle drag)."
  (init-test--load)
  (should (eq emacs-cpp-default-mouse-modifier 'super))
  (pcase-dolist (`(,keys . ,command)
                 '(("s-<mouse-1>" . emacs-cpp-lsp-mouse-definition-or-references)
                   ("M-s-<mouse-1>" . emacs-cpp-lsp-mouse-implementation)
                   ("S-s-<mouse-1>" . emacs-cpp-lsp-mouse-type-definition)))
    (should (eq (keymap-lookup global-map keys) command))
    (should-not (keymap-lookup global-map
                               (replace-regexp-in-string "<mouse-1>" "<down-mouse-1>" keys))))
  (should (eq (keymap-lookup global-map "C-<down-mouse-1>") #'mouse-buffer-menu))
  (should (eq (keymap-lookup global-map "C-M-<down-mouse-1>") #'mouse-drag-region-rectangle)))

(ert-deftest init-lsp-mouse-definition-or-references ()
  "D-093: a click on a use goes to the definition, on the definition itself it
lists the references."
  (init-test--load)
  (require 'xref)
  (let ((file (make-temp-file "emacs-cpp-click" nil ".cc" "int answer();\nint x = answer();\n"))
        called)
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (cl-letf (((symbol-function 'mouse-set-point) #'ignore)
                    ((symbol-function 'xref-find-backend) (lambda () 'stub))
                    ((symbol-function 'xref-backend-identifier-at-point)
                     (lambda (_backend) "answer"))
                    ((symbol-function 'xref-backend-definitions)
                     (lambda (_backend _id)
                       (list (xref-make "answer" (xref-make-file-location file 1 4)))))
                    ((symbol-function 'xref-find-definitions)
                     (lambda (id) (setq called (list 'definitions id))))
                    ((symbol-function 'xref-find-references)
                     (lambda (id) (setq called (list 'references id)))))
            (goto-char (point-min))
            (forward-line 1)
            (emacs-cpp-lsp-mouse-definition-or-references nil)
            (should (equal called '(definitions "answer")))
            (goto-char (point-min))
            (emacs-cpp-lsp-mouse-definition-or-references nil)
            (should (equal called '(references "answer"))))
          (kill-buffer))
      (delete-file file))))

(ert-deftest init-lsp-context-menu ()
  "D-093: right click opens a menu; in a managed buffer it has the server's
entries, elsewhere not."
  (init-test--load)
  (should (bound-and-true-p context-menu-mode))
  (should (memq #'emacs-cpp-lsp-context-menu (default-value 'context-menu-functions)))
  (require 'eglot)
  (let ((entries (lambda (managed)
                   (cl-letf (((symbol-function 'eglot-managed-p) (lambda () managed)))
                     (let ((menu (emacs-cpp-lsp-context-menu (make-sparse-keymap) nil)))
                       (delq nil (mapcar (lambda (k) (and (consp k) (car k))) (cdr menu))))))))
    (should (equal (funcall entries t)
                   '(emacs-cpp-lsp-separator emacs-cpp-lsp-rename emacs-cpp-lsp-actions
                     emacs-cpp-lsp-implementation emacs-cpp-lsp-format)))
    (should-not (funcall entries nil))))

(ert-deftest init-lsp-eglot-vendored ()
  "D-108: the shipped profile loads eglot from lib/eglot, not Emacs's own."
  (init-test--load)
  (require 'eglot)
  (should (file-in-directory-p (symbol-file 'eglot--watch-globs)
                               (expand-file-name "lib/eglot" build-packages-root))))

(ert-deftest init-lsp-eglot-keeps-partial-watches ()
  "D-108, patch 0001: a watch registration past `eglot-max-file-watches' keeps
the watches it got and succeeds, so pyright stays up (without the patch it exits)."
  (init-test--load)
  (require 'eglot)
  (let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-watch" t))))
         (default-directory root)
         (buffers-before (buffer-list))
         (eglot-max-file-watches 5)
         (eglot-watch-files-outside-project-root nil))
    (unwind-protect
        (progn
          (dotimes (i 20)
            (make-directory (expand-file-name (format "pkg%d" i) root))
            (write-region (format "def f%d():\n    return %d\n" i i) nil
                          (expand-file-name (format "pkg%d/m.py" i) root)))
          (write-region "from pkg7.m import f7\n\nprint(f7())\n" nil
                        (expand-file-name "main.py" root))
          (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
          (let ((buffer (find-file-noselect (expand-file-name "main.py" root))))
            (with-current-buffer buffer
              (run-hooks 'post-command-hook)
              (should (init-test--wait-managed 20))
              (let ((server (eglot-current-server))
                    (deadline (+ (float-time) 20)))
                ;; Wait for pyright's registrations, then a few seconds more: it
                ;; exits about 80 ms after a failed one.
                (while (and (zerop (hash-table-count (eglot--file-watches server)))
                            (< (float-time) deadline))
                  (accept-process-output nil 0.2))
                (should (< 0 (hash-table-count (eglot--file-watches server))))
                (let ((settle (+ (float-time) 3)))
                  (while (< (float-time) settle)
                    (accept-process-output nil 0.2)))
                (should (process-live-p (jsonrpc--process server)))
                (should (<= (eglot--count-file-watches) 5))))))
      (dolist (server (apply #'append (hash-table-values eglot--servers-by-project)))
        (ignore-errors (eglot-shutdown server)))
      (dolist (buffer (buffer-list))
        (unless (memq buffer buffers-before)
          (let ((kill-buffer-query-functions nil))
            (kill-buffer buffer))))
      (delete-directory root t))))

(provide 'init-lsp-test)
;;; init-lsp-test.el ends here
