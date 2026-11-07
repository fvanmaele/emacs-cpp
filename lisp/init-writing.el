;;; init-writing.el --- Markdown and the org journal  -*- lexical-binding: t; -*-

;;; Commentary:

;; The owner's existing packages, carried over (DESIGN 12).  Markdown buffers export to
;; PDF through pandoc and a LaTeX engine on `C-c C-c x', shown in doc-view (D-184,
;; DESIGN 12.1).  Math drawn in the buffer is deferred (T-136).

;;; Code:

(defcustom emacs-cpp-markdown-pdf-engine "xelatex"
  "LaTeX engine pandoc uses for `emacs-cpp-markdown-pdf' (D-184).
Passed as pandoc's --pdf-engine; xelatex reads Unicode text and system fonts."
  :type 'string
  :safe #'stringp
  :group 'tools)

(defconst emacs-cpp-markdown--pdf-output "*emacs-cpp-markdown-pdf*"
  "Buffer holding pandoc's output of the last export.")

(defun emacs-cpp-markdown--pdf-file (file)
  "Return the PDF file `emacs-cpp-markdown-pdf' writes for FILE."
  (concat (file-name-sans-extension file) ".pdf"))

(defun emacs-cpp-markdown--pdf-command (file engine)
  "Return the pandoc command line writing FILE's PDF with ENGINE."
  (list "pandoc" (file-name-nondirectory file)
        "-o" (file-name-nondirectory (emacs-cpp-markdown--pdf-file file))
        (concat "--pdf-engine=" engine)))

(defun emacs-cpp-markdown--check-tools (engine)
  "Signal an error naming the install command when pandoc or ENGINE is missing."
  (dolist (program (list "pandoc" engine))
    (unless (executable-find program)
      (error "emacs-cpp: %s is not on exec-path; install: %s (D-184)"
             program emacs-cpp-default-markdown-pdf-install))))

(defun emacs-cpp-markdown--show-pdf (pdf)
  "Show PDF in another window, reverting its buffer when it has one.  Return it."
  (let ((buffer (find-buffer-visiting pdf)))
    (if buffer
        (with-current-buffer buffer
          (revert-buffer t t))
      (setq buffer (find-file-noselect pdf)))
    (display-buffer buffer '(nil (inhibit-same-window . t)))
    buffer))

(defun emacs-cpp-markdown-pdf ()
  "Write this Markdown file's PDF through pandoc and show it in doc-view (D-184).
The PDF goes beside the file, named as it with .pdf; the engine is
`emacs-cpp-markdown-pdf-engine'.  Return the pandoc process."
  (interactive)
  (let* ((file (or buffer-file-name
                   (user-error "emacs-cpp: this buffer visits no file")))
         (engine emacs-cpp-markdown-pdf-engine)
         (pdf (emacs-cpp-markdown--pdf-file file))
         (output (get-buffer-create emacs-cpp-markdown--pdf-output))
         (default-directory (file-name-directory file)))
    (emacs-cpp-markdown--check-tools engine)
    (save-buffer)
    (with-current-buffer output
      (let ((inhibit-read-only t))
        (erase-buffer)))
    (message "emacs-cpp: pandoc writing %s ..." (file-name-nondirectory pdf))
    (make-process
     :name "emacs-cpp-markdown-pdf"
     :buffer output
     :command (emacs-cpp-markdown--pdf-command file engine)
     :noquery t
     :sentinel (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (emacs-cpp-markdown--pdf-finished
                    (process-exit-status process) file pdf))))))

(defun emacs-cpp-markdown--pdf-finished (status file pdf)
  "Show PDF when pandoc exited with STATUS 0 on FILE; else show its output, signal."
  (if (eql 0 status)
      (prog1 (emacs-cpp-markdown--show-pdf pdf)
        (message "emacs-cpp: wrote %s" pdf))
    (display-buffer (get-buffer-create emacs-cpp-markdown--pdf-output))
    (error "emacs-cpp: pandoc failed (exit %s) on %s; its output is in %s"
           status file emacs-cpp-markdown--pdf-output)))

(use-package markdown-mode
  :config
  (keymap-set markdown-mode-command-map "x" #'emacs-cpp-markdown-pdf))

(use-package org-journal)

(provide 'init-writing)
;;; init-writing.el ends here
