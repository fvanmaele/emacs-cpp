;;; init-lsp-test.el --- Mouse navigation, the right-click menu, eglot's watches  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-093): the navigation clicks on the platform's
;; modifier, the press unbound so the click arrives; the click goes to the definition,
;; or lists references when it is on the definition; right click opens a menu, with
;; the language server's entries in a managed buffer.  xref's backend is a stub, so
;; no server is needed; the clicks in a graphical frame are a hand check.
;;
;; eglot is Emacs 31's own (D-121), its file watches carried by the patched fswatch
;; (D-127); the pyright test needs pyright, git and that fswatch.  The backend's own
;; tests are in emacs-cpp-eglot-fswatch-test.el.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest init-lsp-mouse-bindings ()
  "D-093: Cmd (Mac) / Super (Arch) clicks; with Opt / Alt implementations, with
Shift the type.  Ctrl's clicks stay Emacs's (buffer menu, rectangle drag).
D-138: buttons 8 / 9 back and forward."
  (init-test--load)
  (should (eq emacs-cpp-default-mouse-modifier 'super))
  (pcase-dolist (`(,keys . ,command)
                 '(("s-<mouse-1>" . emacs-cpp-lsp-mouse-definition-or-references)
                   ("M-s-<mouse-1>" . emacs-cpp-lsp-mouse-implementation)
                   ("S-s-<mouse-1>" . emacs-cpp-lsp-mouse-type-definition)))
    (should (eq (keymap-lookup global-map keys) command))
    (should-not (keymap-lookup global-map
                               (replace-regexp-in-string "<mouse-1>" "<down-mouse-1>" keys))))
  ;; D-138: the side buttons go back and forward.
  (should (eq (keymap-lookup global-map "<mouse-8>") #'xref-go-back))
  (should (eq (keymap-lookup global-map "<mouse-9>") #'xref-go-forward))
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

(ert-deftest init-lsp-eglot-built-in ()
  "D-121, D-127: the shipped profile loads Emacs's own eglot, its file watches
taken over by the fswatch backend."
  (init-test--load)
  (require 'eglot)
  (should (file-in-directory-p (symbol-file 'eglot--watch-globs) lisp-directory))
  (should (featurep 'emacs-cpp-eglot-fswatch))
  (should (advice-member-p #'emacs-cpp-eglot-fswatch--on-shutdown 'eglot--on-shutdown))
  (should (equal (emacs-cpp-fswatch-program-check emacs-cpp-default-fswatch-program)
                 emacs-cpp-default-fswatch-program)))

(defmacro init-lsp-test--with-pyright (dirs &rest body)
  "Run BODY with `server', pyright managing main.py of a git project of DIRS
package directories bound to `root'; shut it down and clean up afterwards."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory
                 (file-truename (make-temp-file "emacs-cpp-watch" t))))
          (default-directory root)
          (buffers-before (buffer-list)))
     (unwind-protect
         (progn
           (dotimes (i ,dirs)
             (make-directory (expand-file-name (format "d%d" i) root))
             (write-region (format "def f%d():\n    return %d\n" i i) nil
                           (expand-file-name (format "d%d/m.py" i) root)))
           (write-region "print(1)\n" nil (expand-file-name "main.py" root))
           (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
           (with-current-buffer (find-file-noselect (expand-file-name "main.py" root))
             (run-hooks 'post-command-hook)
             (should (init-test--wait-managed 20))
             (let ((server (eglot-current-server)))
               ,@body)))
       (dolist (server (apply #'append (hash-table-values eglot--servers-by-project)))
         (ignore-errors (eglot-shutdown server)))
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (let ((kill-buffer-query-functions nil))
             (kill-buffer buffer))))
       (delete-directory root t))))

(ert-deftest init-lsp-eglot-fswatch-pyright ()
  "D-127: pyright's watch registrations get fswatch processes and pyright stays
up with 400 directories (with `file-notify' past the cap it exited); its
shutdown leaves no fswatch running."
  (init-test--load)
  (require 'eglot)
  (let (watching)
    (init-lsp-test--with-pyright 400
      (let ((deadline (+ (float-time) 30)))
        (while (and (not (emacs-cpp-eglot-fswatch-processes server))
                    (< (float-time) deadline))
          (accept-process-output nil 0.2)))
      (setq watching (emacs-cpp-eglot-fswatch-processes server))
      (should watching)
      ;; pyright exits about 80 ms after a failed registration.
      (let ((settle (+ (float-time) 3)))
        (while (< (float-time) settle)
          (accept-process-output nil 0.2)))
      (should (process-live-p (jsonrpc--process server)))
      (should (emacs-cpp-eglot-fswatch-processes server))
      (setq watching (emacs-cpp-eglot-fswatch-processes server))
      (eglot-shutdown server)
      (should-not (emacs-cpp-eglot-fswatch-processes server))
      (should-not (seq-some #'process-live-p watching)))))

(defmacro init-lsp-test--with-servers (&rest body)
  "Run BODY with fake servers: `patched' (clangd announcing both matches),
`stock' (clangd announcing none) and `pyright'; warnings go to `warned'."
  (declare (indent 0))
  `(let ((warned nil)
         (emacs-cpp-lsp--symbol-warned nil))
     (cl-letf (((symbol-function 'eglot--capabilities)
                (lambda (server)
                  (and (eq server 'patched)
                       '(:workspaceSymbolMatchesProvider
                         (:looseScope t :middleMatch t)))))
               ((symbol-function 'eglot--server-info)
                (lambda (server)
                  (list :name (if (eq server 'pyright) "pyright" "clangd"))))
               ((symbol-function 'display-warning)
                (lambda (_type message &rest _) (push message warned))))
       ,@body)))

(ert-deftest init-lsp-symbol-params ()
  "D-113: CLion-style matches asked for only of a server that announces them;
a clangd announcing none gets one warning, other servers none."
  (init-test--load)
  (let ((emacs-cpp-symbol-loose-scope t)
        (emacs-cpp-symbol-middle-match 3))
    (init-lsp-test--with-servers
      (should (equal (emacs-cpp-lsp-symbol-params 'patched)
                     '(:looseScope t :middleMatch 3)))
      (should-not (emacs-cpp-lsp-symbol-params 'pyright))
      (should-not warned)
      (should-not (emacs-cpp-lsp-symbol-params 'stock))
      (should-not (emacs-cpp-lsp-symbol-params 'stock))
      (should (= 1 (length warned)))
      (should (string-match-p "emacs-cpp-clangd-program" (car warned)))))
  ;; Options off: nothing asked for, nothing warned about.
  (let ((emacs-cpp-symbol-loose-scope nil)
        (emacs-cpp-symbol-middle-match nil))
    (init-lsp-test--with-servers
      (should-not (emacs-cpp-lsp-symbol-params 'patched))
      (should-not (emacs-cpp-lsp-symbol-params 'stock))
      (should-not warned)))
  (let ((emacs-cpp-symbol-loose-scope nil)
        (emacs-cpp-symbol-middle-match 4))
    (init-lsp-test--with-servers
      (should (equal (emacs-cpp-lsp-symbol-params 'patched) '(:middleMatch 4))))))

(ert-deftest init-lsp-symbol-params-in-requests ()
  "D-113: `M-o' and `C-c l s' put each server's parameters into its request."
  (init-test--load)
  (require 'consult)
  (require 'consult-eglot)
  (require 'init-go-to-anything)
  (let ((emacs-cpp-symbol-loose-scope t)
        (emacs-cpp-symbol-middle-match 3)
        (sent nil))
    (init-lsp-test--with-servers
      (cl-letf (((symbol-function 'jsonrpc-async-request)
                 (lambda (server _method params &rest _)
                   (push (cons server params) sent))))
        (funcall (funcall (emacs-cpp-go--symbol-request '(patched pyright))
                          #'ignore)
                 "vec")
        (should (equal (alist-get 'patched sent)
                       '(:query "vec" :looseScope t :middleMatch 3)))
        (should (equal (alist-get 'pyright sent) '(:query "vec")))
        (setq sent nil)
        (funcall (funcall (consult-eglot--make-async-source '(patched pyright))
                          #'ignore)
                 "vec")
        (should (equal (alist-get 'patched sent)
                       '(:query "vec" :looseScope t :middleMatch 3)))
        (should (equal (alist-get 'pyright sent) '(:query "vec")))))))

(provide 'init-lsp-test)
;;; init-lsp-test.el ends here
