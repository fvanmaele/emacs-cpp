;;; init-lsp-test.el --- Mouse navigation and the right-click menu  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-093): the navigation clicks on the platform's
;; modifier, the press unbound so the click arrives; the click goes to the definition,
;; or lists references when it is on the definition; right click opens a menu, with
;; the language server's entries in a managed buffer.  xref's backend is a stub, so
;; no server is needed; the clicks in a graphical frame are a hand check.

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

(provide 'init-lsp-test)
;;; init-lsp-test.el ends here
