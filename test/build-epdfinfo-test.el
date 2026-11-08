;;; build-epdfinfo-test.el --- make epdfinfo stops with the fix  -*- lexical-binding: t; -*-

;;; Commentary:

;; scripts/build-epdfinfo.sh (D-199) stops before building when a tool or library is
;; missing, and names the platform's install command.  The build itself runs by hand
;; (`make epdfinfo'); here it never starts.

;;; Code:

(require 'ert)
(require 'build-packages)

(defun build-epdfinfo-test--run (tools)
  "Run build-epdfinfo.sh with only TOOLS and the shell's helpers on PATH.
TOOLS is an alist (NAME . SHELL-BODY).  Return (EXIT . OUTPUT)."
  (let ((stubs (make-temp-file "build-epdfinfo-test" t)))
    (unwind-protect
        (progn
          (dolist (helper '("dirname" "uname"))
            (make-symbolic-link (executable-find helper) (expand-file-name helper stubs)))
          (pcase-dolist (`(,name . ,body) tools)
            (let ((file (expand-file-name name stubs)))
              (write-region (concat "#!/bin/sh\n" body "\n") nil file nil 'no-message)
              (set-file-modes file #o755)))
          (with-temp-buffer
            (let* ((shell (executable-find "sh"))
                   (process-environment (cons (concat "PATH=" stubs) process-environment))
                   (exit (call-process shell nil t nil
                                       (expand-file-name "scripts/build-epdfinfo.sh"
                                                         build-packages-root))))
              (cons exit (buffer-string)))))
      (delete-directory stubs t))))

(defun build-epdfinfo-test--install-command ()
  "Return the install command the script names on this platform."
  (if (eq system-type 'darwin)
      "sudo port install poppler autoconf automake pkgconfig"
    "sudo pacman -S --needed base-devel libpng zlib poppler-glib"))

(ert-deftest build-epdfinfo-names-a-missing-tool ()
  "A build tool not on PATH stops the script, naming the tool and the install command."
  (let ((result (build-epdfinfo-test--run nil)))
    (should-not (eql 0 (car result)))
    (should (string-search "autoreconf is not on PATH" (cdr result)))
    (should (string-search (build-epdfinfo-test--install-command) (cdr result)))))

(ert-deftest build-epdfinfo-names-a-missing-library ()
  "poppler-glib not found stops the script before anything builds."
  (let ((result (build-epdfinfo-test--run
                 '(("autoreconf" . "exit 0")
                   ("automake" . "exit 0")
                   ("make" . "echo make called; exit 3")
                   ("cc" . "exit 0")
                   ("pkg-config" . "exit 1")))))
    (should-not (eql 0 (car result)))
    (should (string-search "finds no poppler-glib" (cdr result)))
    (should (string-search (build-epdfinfo-test--install-command) (cdr result)))
    (should-not (string-search "make called" (cdr result)))))

(provide 'build-epdfinfo-test)
;;; build-epdfinfo-test.el ends here
