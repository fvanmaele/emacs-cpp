;;; emacs-cpp-eglot-fswatch-test.el --- eglot's file watches through fswatch  -*- lexical-binding: t; -*-

;;; Commentary:

;; The fswatch backend (D-127, DESIGN 7.1): globs as regexps, a filter call's records
;; merged per path, and the real patched fswatch on a temporary tree, its changes
;; caught at `jsonrpc-notify' for a stand-in server, so no language server runs.
;; The Python server test in init-lsp-test.el covers a real server.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest emacs-cpp-eglot-fswatch-globs ()
  "LSP globs as anchored regexps over root-relative names; a base is a prefix."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (let ((match (lambda (glob name &optional prefix)
                 (let ((case-fold-search nil))
                   (string-match-p (emacs-cpp-eglot-fswatch-glob-regexp glob prefix)
                                   name)))))
    (should (funcall match "**/*.py" "main.py"))
    (should (funcall match "**/*.py" "a/b/m.py"))
    (should-not (funcall match "**/*.py" "a/b/m.pyc"))
    (should-not (funcall match "*.py" "a/m.py"))
    (should (funcall match "**/*.{c,h}{,pp}" "src/x.hpp"))
    (should (funcall match "**/*.{c,h}{,pp}" "x.c"))
    (should-not (funcall match "**/*.{c,h}{,pp}" "x.cc"))
    (should (funcall match "m?.[!c]" "m1.h"))
    (should-not (funcall match "m?.[!c]" "m1.c"))
    (should (funcall match "**/compile_commands.json" "build/compile_commands.json"))
    (should (funcall match "*.py" "sub/m.py" "sub/"))
    (should-not (funcall match "*.py" "m.py" "sub/"))
    (should-error (emacs-cpp-eglot-fswatch-glob-regexp "{a,b"))))

(ert-deftest emacs-cpp-eglot-fswatch-merge ()
  "Records of one path become one, flags joined, in first-seen order."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (should (equal (emacs-cpp-eglot-fswatch-merge
                  '("/r/a b.py Created" "/r/c.py Updated" "/r/a b.py Updated,IsFile" ""))
                 '(("/r/a b.py" . "Created,Updated,IsFile") ("/r/c.py" . "Updated"))))
  (should-error (emacs-cpp-eglot-fswatch-merge '("noflags"))))

(ert-deftest emacs-cpp-eglot-fswatch-overflow-flag ()
  "`Overflow' counts only as a whole flag after the record's last space."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (should (emacs-cpp-eglot-fswatch--overflow-p "/r Overflow"))
  (should (emacs-cpp-eglot-fswatch--overflow-p "/r/a b.py Created,Overflow"))
  (should (emacs-cpp-eglot-fswatch--overflow-p "/r/a.py Overflow,Updated"))
  (should-not (emacs-cpp-eglot-fswatch--overflow-p "/r/Overflow Created"))
  (should-not (emacs-cpp-eglot-fswatch--overflow-p "/r/a Overflow/b.py Updated"))
  (should-not (emacs-cpp-eglot-fswatch--overflow-p "/r/a.py Overflowed"))
  (should-not (emacs-cpp-eglot-fswatch--overflow-p "/r/a.py overflow")))

(ert-deftest emacs-cpp-eglot-fswatch-globs-before-the-file-system ()
  "A record no glob matches is dropped without asking whether its file exists; one
whose glob lacks the change's kind is dropped after it."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (let ((matchers (list (cons (emacs-cpp-eglot-fswatch-glob-regexp "**/*.py") 2)))
        asked)
    (puthash "/r/" "file:///r" emacs-cpp-eglot-fswatch--root-uris)
    (unwind-protect
        (cl-letf (((symbol-function 'emacs-cpp-eglot-fswatch--change-type)
                   (lambda (path _flags) (push path asked) 2))
                  ((symbol-function 'emacs-cpp-eglot-fswatch--server-has-text-p) #'ignore))
          (should (equal (emacs-cpp-eglot-fswatch-changes
                          nil '(("/r/build/a.o" . "Created") ("/r/src/a.py" . "Updated"))
                          "/r/" "/r/" matchers)
                         '((:uri "file:///r/src/a.py" :type 2))))
          (should (equal asked '("/r/src/a.py")))
          ;; Kind 2 is Change only: a deletion (type 3) matches the glob, not the kind.
          (cl-letf (((symbol-function 'emacs-cpp-eglot-fswatch--change-type)
                     (lambda (&rest _) 3)))
            (should-not (emacs-cpp-eglot-fswatch-changes
                         nil '(("/r/src/a.py" . "Removed")) "/r/" "/r/" matchers))))
      (remhash "/r/" emacs-cpp-eglot-fswatch--root-uris))))

(ert-deftest emacs-cpp-eglot-fswatch-refusal ()
  "D-127: a missing or unpatched fswatch refuses with the command that builds it."
  (init-test--load)
  (pcase-dolist (`(,program . ,reason)
                 '(("/nonexistent/fswatch" . "no fswatch at")
                   ("/bin/sh" . "not the patched fswatch")))
    (let ((message (cadr (should-error (emacs-cpp-fswatch-program-check program)))))
      (should (string-match-p reason message))
      (should (string-match-p "makepkg -si" message))
      (should (string-match-p "build-macos.sh" message)))))

(defun emacs-cpp-eglot-fswatch-test--wait (predicate &optional seconds)
  "Wait up to SECONDS (default 5) for PREDICATE; return its value."
  (let ((deadline (+ (float-time) (or seconds 5))) value)
    (while (and (not (setq value (funcall predicate))) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    value))

(ert-deftest emacs-cpp-eglot-fswatch-real ()
  "D-127: the real fswatch reports created (1), changed (2) and deleted (3) files
matching the globs, with the root's URIs; other files and git's are left out; a
registration's end and the server's shutdown leave no process."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (let* ((root (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-fswatch" t))))
         (server (make-symbol "server"))
         (root-uri (eglot-path-to-uri (directory-file-name root)))
         ;; Emacs's lock file .#m.py would match **/*.py too.
         (create-lockfiles nil)
         sent)
    (cl-letf (((symbol-function 'eglot--project) (lambda (_) (cons 'transient root)))
              ((symbol-function 'jsonrpc-running-p) (lambda (_) t))
              ((symbol-function 'jsonrpc-notify)
               (lambda (to method params)
                 (should (eq to server))
                 (should (eq method :workspace/didChangeWatchedFiles))
                 (setq sent (append sent (append (plist-get params :changes) nil))))))
      (unwind-protect
          (let ((watchers [(:globPattern "**/*.py")]))
            (make-directory (expand-file-name "sub dir/.git" root) t)
            (should (equal (eglot-register-capability
                            server 'workspace/didChangeWatchedFiles "w1" :watchers watchers)
                           '(t "OK")))
            (should (= 1 (length (emacs-cpp-eglot-fswatch-processes server))))
            ;; fswatch sets up its watches after it starts.
            (accept-process-output nil 0.5)
            (let ((file (expand-file-name "sub dir/m.py" root))
                  (uri (concat root-uri "/sub%20dir/m.py")))
              (write-region "x = 1\n" nil file)
              (write-region "" nil (expand-file-name "sub dir/notes.txt" root))
              (write-region "" nil (expand-file-name "sub dir/.git/index.py" root))
              (should (emacs-cpp-eglot-fswatch-test--wait (lambda () sent)))
              (accept-process-output nil 0.3)
              (should (equal sent `((:uri ,uri :type 1))))
              (setq sent nil)
              (write-region "x = 2\n" nil file)
              (should (emacs-cpp-eglot-fswatch-test--wait (lambda () sent)))
              (should (equal sent `((:uri ,uri :type 2))))
              (setq sent nil)
              (delete-file file)
              (should (emacs-cpp-eglot-fswatch-test--wait (lambda () sent)))
              (should (equal sent `((:uri ,uri :type 3)))))
            ;; The registration ends: its process with it.
            (let ((processes (emacs-cpp-eglot-fswatch-processes server)))
              (should (equal (eglot-unregister-capability
                              server 'workspace/didChangeWatchedFiles "w1")
                             '(t "OK")))
              (should-not (emacs-cpp-eglot-fswatch-processes server))
              (should-not (seq-some #'process-live-p processes)))
            ;; The server shuts down: every process of its registrations ends.
            (eglot-register-capability server 'workspace/didChangeWatchedFiles "w2"
                                       :watchers watchers)
            (eglot-register-capability server 'workspace/didChangeWatchedFiles "w3"
                                       :watchers watchers)
            (let ((processes (emacs-cpp-eglot-fswatch-processes server)))
              (should (= 2 (length processes)))
              (emacs-cpp-eglot-fswatch--on-shutdown server)
              (should-not (emacs-cpp-eglot-fswatch-processes server))
              (should-not (seq-some #'process-live-p processes))))
        (emacs-cpp-eglot-fswatch--stop server)
        (delete-directory root t)))))

(ert-deftest emacs-cpp-eglot-fswatch-dead-server ()
  "A registration handled after its server exited starts no fswatch: jsonrpc runs
requests from a timer, so one can arrive after `eglot--on-shutdown' (ty registers
right after connecting; seen in init-python-eglot-only-in-projects)."
  (init-test--load)
  (require 'emacs-cpp-eglot-fswatch)
  (let ((root (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-fswatch" t))))
        (server (make-symbol "server")))
    (cl-letf (((symbol-function 'eglot--project) (lambda (_) (cons 'transient root)))
              ((symbol-function 'jsonrpc-running-p) (lambda (_) nil)))
      (unwind-protect
          (progn
            (eglot-register-capability server 'workspace/didChangeWatchedFiles "w1"
                                       :watchers [(:globPattern "**")])
            (should-not (emacs-cpp-eglot-fswatch-processes server)))
        (emacs-cpp-eglot-fswatch--stop server)
        (delete-directory root t)))))

(provide 'emacs-cpp-eglot-fswatch-test)
;;; emacs-cpp-eglot-fswatch-test.el ends here
