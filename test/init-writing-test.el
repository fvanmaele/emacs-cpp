;;; init-writing-test.el --- Markdown's PDF export  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (T-135, D-184): the pandoc command line, the errors
;; for a missing pandoc or engine, `C-c C-c x' in Markdown buffers, and a real export
;; through pandoc and `emacs-cpp-markdown-pdf-engine' (skipped where either is
;; missing): the PDF is written and shown fitted to the window's width (D-187), a
;; second run reverts the same buffer, a LaTeX error leaves pandoc's output and
;; signals.

;;; Code:

(require 'ert)
(require 'init-test)

(defmacro init-writing-test--with-file (content &rest body)
  "Visit a temporary doc.md holding CONTENT, run BODY in its buffer, clean up."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory
                 (file-truename (make-temp-file "emacs-cpp-writing" t))))
          (file (expand-file-name "doc.md" root))
          (buffers-before (buffer-list)))
     (unwind-protect
         (progn
           (write-region ,content nil file)
           (with-current-buffer (find-file-noselect file)
             ,@body))
       (dolist (buffer (buffer-list))
         (unless (memq buffer buffers-before)
           (when-let* ((process (get-buffer-process buffer)))
             (delete-process process))
           (let ((kill-buffer-query-functions nil))
             (set-buffer-modified-p nil)
             (kill-buffer buffer))))
       (delete-directory root t))))

(defun init-writing-test--tools-p ()
  "Non-nil when pandoc, the configured engine and mutool are on `exec-path'."
  (and (executable-find "pandoc") (executable-find emacs-cpp-markdown-pdf-engine)
       (executable-find "mutool")))

(defun init-writing-test--wait (process)
  "Wait up to 120 s for PROCESS to finish; return its exit status."
  (let ((deadline (+ (float-time) 120)))
    (while (and (process-live-p process) (< (float-time) deadline))
      (accept-process-output process 0.1))
    ;; Let the sentinel run.
    (accept-process-output nil 0.1)
    (should-not (process-live-p process))
    (process-exit-status process)))

(ert-deftest init-writing-pdf-command ()
  "pandoc gets the file and its PDF by name, run in the file's directory."
  (init-test--load)
  (should (equal (emacs-cpp-markdown--pdf-command "/a/b/doc.md" "lualatex" nil)
                 '("pandoc" "doc.md" "-o" "doc.pdf" "--pdf-engine=lualatex")))
  (should (equal (emacs-cpp-markdown--pdf-command "/a/b/doc.md" "xelatex" "Menlo")
                 '("pandoc" "doc.md" "-o" "doc.pdf" "--pdf-engine=xelatex"
                   "-V" "monofont=Menlo")))
  (should (equal emacs-cpp-markdown-pdf-engine "xelatex"))
  (should (equal emacs-cpp-markdown-pdf-monofont "DejaVuSansMono.ttf")))

(ert-deftest init-writing-pdf-missing-characters ()
  "LaTeX's missing-glyph lines give each character once, in order (D-185)."
  (init-test--load)
  (should (equal (emacs-cpp-markdown--missing-characters
                  (concat "[WARNING] Missing character: There is no \u03c1 (U+03C1) "
                          "in font [lmmono10-regular]:!\n"
                          "[WARNING] Missing character: There is no \u2202 (U+2202) "
                          "in font [lmmono10-regular]:!\n"
                          "[WARNING] Missing character: There is no \u03c1 (U+03C1) "
                          "(U+03C1) in font [lmmono10-regular]:!\n"))
                 '("\u03c1" "\u2202")))
  (should-not (emacs-cpp-markdown--missing-characters "Output written.\n")))

(ert-deftest init-writing-pdf-missing-tools ()
  "A missing pandoc or engine signals with the platform's install command."
  (init-test--load)
  (let ((err (let ((exec-path nil))
               (should-error (emacs-cpp-markdown--check-tools "xelatex")))))
    (should (string-match-p "pandoc is not on exec-path" (cadr err)))
    (should (string-search emacs-cpp-default-markdown-pdf-install (cadr err))))
  (when (executable-find "pandoc")
    (let ((err (should-error
                (emacs-cpp-markdown--check-tools "emacs-cpp-no-such-engine"))))
      (should (string-match-p "emacs-cpp-no-such-engine is not on exec-path"
                              (cadr err)))))
  ;; pandoc and the engine found, mutool not (D-186).
  (when (and (executable-find "pandoc") (executable-find "xelatex"))
    (let ((dir (make-temp-file "emacs-cpp-writing-bin" t)))
      (unwind-protect
          (progn
            (dolist (program '("pandoc" "xelatex"))
              (make-symbolic-link (executable-find program)
                                  (expand-file-name program dir)))
            (let* ((exec-path (list dir))
                   (err (should-error (emacs-cpp-markdown--check-tools "xelatex"))))
              (should (string-match-p "mutool is not on exec-path" (cadr err)))))
        (delete-directory dir t)))))

(ert-deftest init-writing-pdf-defaults ()
  "The Mac finds MacTeX's engines (D-184); each platform names its install command."
  (init-test--load)
  (pcase system-type
    ('darwin
     (should (member "/Library/TeX/texbin" emacs-cpp-default-exec-path-prepend))
     (should (member "/Library/TeX/texbin" exec-path))
     (should (string-match-p "port install pandoc mupdf"
                             emacs-cpp-default-markdown-pdf-install)))
    ('gnu/linux
     (should (equal emacs-cpp-default-markdown-pdf-install
                    "sudo pacman -S pandoc-cli texlive-xetex mupdf-tools")))))

(ert-deftest init-writing-pdf-key ()
  "`C-c C-c x' exports in Markdown buffers; markdown-mode's own keys stay."
  (init-test--load)
  (init-writing-test--with-file "# Title\n"
    (should (derived-mode-p 'markdown-mode))
    (should (eq (key-binding (kbd "C-c C-c x")) #'emacs-cpp-markdown-pdf))
    (should (eq (key-binding (kbd "C-c C-c e")) #'markdown-export))))

(ert-deftest init-writing-pdf-export ()
  "The PDF is written beside the file and shown; a second run reverts that buffer."
  (init-test--load)
  (skip-unless (init-writing-test--tools-p))
  (init-writing-test--with-file "# Title\n\nArea $x^2$.\n"
    (let ((pdf (expand-file-name "doc.pdf" default-directory)))
      (insert "Edited.\n")
      (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf))))
      (should-not (buffer-modified-p))
      (should (file-exists-p pdf))
      (should (equal (with-temp-buffer
                       (insert-file-contents-literally pdf nil 0 5)
                       (buffer-string))
                     "%PDF-"))
      (let ((shown (find-buffer-visiting pdf)))
        (should shown)
        (should (get-buffer-window shown))
        (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf))))
        (should (eq (find-buffer-visiting pdf) shown))
        (should (buffer-live-p shown))
        ;; Pages fit the window's width, after the revert too (D-187).
        (with-current-buffer shown
          (when (derived-mode-p 'doc-view-mode)
            (should (eql doc-view-image-width
                         (with-selected-window (get-buffer-window shown)
                           (floor (window-body-width nil t)
                                  (image-compute-scaling-factor))))))
          (should (memq #'emacs-cpp-markdown--fit-width
                        window-size-change-functions)))))))

(ert-deftest init-writing-pdf-fit-width ()
  "A resized window refits the shown PDF's pages to its body width (D-187)."
  (init-test--load)
  (with-temp-buffer
    (require 'doc-view)
    (let ((window (selected-window)))
      (set-window-buffer window (current-buffer))
      (setq-local doc-view-image-width 1)
      ;; Shown as text: left alone.
      (emacs-cpp-markdown--fit-width window)
      (should (eql doc-view-image-width 1))
      ;; DocView with no page drawn yet: the width alone.
      (setq-local major-mode 'doc-view-mode)
      (setq-local image-mode-winprops-alist nil)
      (let ((image-scaling-factor 2))
        (emacs-cpp-markdown--fit-width window))
      (should (eql doc-view-image-width (floor (window-body-width window t) 2))))))

(defun init-writing-test--warnings ()
  "Return the text of the *Warnings* buffer, or the empty string."
  (if-let* ((buffer (get-buffer "*Warnings*")))
      (with-current-buffer buffer (buffer-string))
    ""))

(ert-deftest init-writing-pdf-code-span-glyphs ()
  "Greek and math symbols in code spans reach the PDF with the default monofont;
with pandoc's own font they are dropped, and the export warns naming them."
  (init-test--load)
  (skip-unless (init-writing-test--tools-p))
  (init-writing-test--with-file "Restriction `\u03c1_I = \u03a3 p_i`, `\u2202f \u2265 0`.\n"
    (when (get-buffer "*Warnings*")
      (kill-buffer "*Warnings*"))
    (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf))))
    (should-not (string-search "lacks" (init-writing-test--warnings)))
    (let ((emacs-cpp-markdown-pdf-monofont nil))
      (should (eql 0 (init-writing-test--wait (emacs-cpp-markdown-pdf)))))
    (let ((warnings (init-writing-test--warnings)))
      (should (string-match-p "lacks [0-9]+ characters" warnings))
      (should (string-search "\u03c1" warnings))
      (should (string-search "\u2265" warnings)))))

(ert-deftest init-writing-pdf-failure ()
  "A LaTeX error: pandoc exits non-zero, its output is kept, the finish signals."
  (init-test--load)
  (skip-unless (init-writing-test--tools-p))
  (init-writing-test--with-file "Broken $\\emacscppundefined$.\n"
    (let* ((file buffer-file-name)
           (pdf (expand-file-name "doc.pdf" default-directory))
           (status (cl-letf (((symbol-function 'emacs-cpp-markdown--pdf-finished)
                              #'ignore))
                     (init-writing-test--wait (emacs-cpp-markdown-pdf)))))
      (should-not (eql 0 status))
      (should-not (file-exists-p pdf))
      (should (string-match-p "emacscppundefined"
                              (with-current-buffer emacs-cpp-markdown--pdf-output
                                (buffer-string))))
      (let ((err (should-error
                  (emacs-cpp-markdown--pdf-finished status file pdf))))
        (should (string-match-p "pandoc failed (exit [0-9]+)" (cadr err)))))))

(provide 'init-writing-test)
;;; init-writing-test.el ends here
