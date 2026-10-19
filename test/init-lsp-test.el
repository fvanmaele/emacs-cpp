;;; init-lsp-test.el --- Mouse navigation, the right-click menu, vendored eglot  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-093): the navigation clicks on the platform's
;; modifier, the press unbound so the click arrives; the click goes to the definition,
;; or lists references when it is on the definition; right click opens a menu, with
;; the language server's entries in a managed buffer.  xref's backend is a stub, so
;; no server is needed; the clicks in a graphical frame are a hand check.
;;
;; eglot comes from lib/eglot with patch 0001 (D-108, T-090): with the watch limit
;; reached pyright keeps running; and patch 0002 (D-111, T-102): one watch per
;; directory shared by a server's registrations.  Those tests need pyright and git.

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

(ert-deftest init-lsp-eglot-shares-directory-watches ()
  "D-111, patch 0002: one watch per directory for all of a server's registrations.
pyright registers three times, then drops two; with the cap at 500 and 400
directories the watches never exceed 401 and all 401 remain (0001 alone: 0).
A directory whose watch stops (deleted) gets a valid one again when created
anew; a failing handler does not keep the event from the others; the last
registration's removal stops its watches; `eglot-describe-connection' lists them."
  (init-test--load)
  (require 'eglot)
  (let ((eglot-max-file-watches 500)
        (eglot-watch-files-outside-project-root nil)
        (most 0) (sent 0))
    (init-lsp-test--with-pyright 400
      ;; Until pyright keeps one registration, at most 30 s.
      (let ((deadline (+ (float-time) 30)) (registered nil))
        (while (and (< (float-time) deadline)
                    (not (and registered
                              (= 1 (hash-table-count (eglot--file-watches server))))))
          (accept-process-output nil 0.2)
          (setq most (max most (eglot--count-file-watches)))
          (when (< 1 (hash-table-count (eglot--file-watches server)))
            (setq registered t))))
      (should (process-live-p (jsonrpc--process server)))
      (should (= 1 (hash-table-count (eglot--file-watches server))))
      (should (<= most 401))
      (should (= 401 (eglot--count-file-watches)))
      (let* ((table (eglot--directory-watches server))
             (top (directory-file-name root))
             (key (concat top "/d5"))
             (notify (lambda (_server method &rest _)
                       (when (eq method :workspace/didChangeWatchedFiles)
                         (setq sent (1+ sent))))))
        (advice-add 'jsonrpc-notify :before notify)
        (unwind-protect
            (progn
              ;; Deleted: the system ends the watch with `stopped'.
              (eglot--dispatch-directory-event server key
                                               (list (car (gethash key table)) 'stopped key))
              (should-not (gethash key table))
              ;; Created again: the parent's event gives it a valid watch.
              (eglot--dispatch-directory-event server top
                                               (list (car (gethash top table)) 'created key))
              (should (gethash key table))
              (should (file-notify-valid-p (car (gethash key table))))
              ;; A failing handler next to the real one.
              (push (cons "broken" (lambda (_) (error "Broken handler")))
                    (cdr (gethash key table)))
              (setq sent 0)
              (eglot--dispatch-directory-event
               server key (list (car (gethash key table)) 'created (concat key "/new.py")))
              (should (= 1 sent))
              ;; The fake handler belongs to no registration; take it out again.
              (setcdr (gethash key table) (assoc-delete-all "broken" (cdr (gethash key table)))))
          (advice-remove 'jsonrpc-notify notify))
        ;; Watches per registration in the connection buffer.
        (eglot-describe-connection server)
        (with-current-buffer (eglot--server-buffer-name server "connection")
          (should (string-match-p "-> [0-9]+ watchers" (buffer-string))))
        ;; The last registration goes: every watch stops.
        (let ((descriptors (mapcar #'car (hash-table-values table))))
          (eglot-unregister-capability server 'workspace/didChangeWatchedFiles
                                       (car (hash-table-keys (eglot--file-watches server))))
          (should (zerop (hash-table-count table)))
          (should (zerop (eglot--count-file-watches)))
          (should-not (seq-some #'file-notify-valid-p descriptors)))))))

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
