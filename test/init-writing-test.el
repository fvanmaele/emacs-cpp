;;; init-writing-test.el --- Markdown's PDF export  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (T-135, D-184): the pandoc command line, the errors
;; for a missing pandoc or engine, `C-c C-c x' in Markdown buffers, and a real export
;; through pandoc and `emacs-cpp-markdown-pdf-engine' (skipped where either is missing,
;; or pdf-tools' server is not built): the PDF is written and shown, a second run
;; reverts the same buffer, a LaTeX error leaves pandoc's output and signals.  PDFs in
;; pdf-tools (D-199): every PDF's mode, the server's check, the clamp's choice of windows
;; (D-192); what is drawn on the screen is `make test-gui''s, test/gui/.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defun init-writing-test--write-pdf (file pages)
  "Write FILE, a PDF of PAGES pages, each showing its number in large type."
  (with-temp-file file
    (set-buffer-multibyte nil)
    (let* ((font (+ 3 (* 2 pages)))
           (offsets nil)
           (object (lambda (number body)
                     (push (cons number (1- (point))) offsets)
                     (insert (format "%d 0 obj\n%s\nendobj\n" number body)))))
      (insert "%PDF-1.4\n")
      (funcall object 1 "<< /Type /Catalog /Pages 2 0 R >>")
      (funcall object 2 (format "<< /Type /Pages /Count %d /Kids [%s] >>" pages
                                (mapconcat (lambda (i) (format "%d 0 R" (+ 3 (* 2 i))))
                                           (number-sequence 0 (1- pages)) " ")))
      (dotimes (i pages)
        (funcall object (+ 3 (* 2 i))
                 (format "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] \
/Contents %d 0 R /Resources << /Font << /F1 %d 0 R >> >> >>" (+ 4 (* 2 i)) font))
        (let ((stream (format "BT /F1 96 Tf 150 400 Td (Page %d) Tj ET" (1+ i))))
          (funcall object (+ 4 (* 2 i))
                   (format "<< /Length %d >>\nstream\n%s\nendstream" (length stream) stream))))
      (funcall object font "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
      (let ((xref (1- (point))))
        (insert (format "xref\n0 %d\n0000000000 65535 f \n" (1+ font)))
        (dolist (entry (sort offsets (lambda (a b) (< (car a) (car b)))))
          (insert (format "%010d 00000 n \n" (cdr entry))))
        (insert (format "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
                        (1+ font) xref))))))

(defun init-writing-test--server-p ()
  "Non-nil when pdf-tools' server is built (`make epdfinfo')."
  (file-executable-p (expand-file-name "lib/pdf-tools/server/epdfinfo" emacs-cpp-root)))

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
       (init-writing-test--kill-new-buffers buffers-before)
       (delete-directory root t))))

(defun init-writing-test--kill-new-buffers (before)
  "Kill the buffers not in BEFORE and their processes.
Hidden ones stay: killing pdf-tools' server with its buffer makes the next query ask
whether to restart it, and answered no, every later query fails.  So does native
compilation's log: its processes write there, and without it each one's sentinel
signals \"Selecting deleted buffer\" (graphical Emacs only: batch does not compile)."
  (dolist (buffer (buffer-list))
    (unless (or (memq buffer before)
                (string-prefix-p " " (buffer-name buffer))
                (equal (buffer-name buffer) "*Async-native-compile-log*"))
      (when-let* ((process (get-buffer-process buffer)))
        (delete-process process))
      (with-current-buffer buffer
        (set-buffer-modified-p nil))
      (let ((kill-buffer-query-functions nil))
        (kill-buffer buffer)))))

(defun init-writing-test--tools-p ()
  "Non-nil when pandoc and the configured engine are found and the server is built."
  (and (executable-find "pandoc") (executable-find emacs-cpp-markdown-pdf-engine)
       (init-writing-test--server-p)))

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
  (should (equal (emacs-cpp-markdown--pdf-command "/a/b/doc.md" "lualatex" nil nil)
                 '("pandoc" "doc.md" "-o" "doc.pdf" "--pdf-engine=lualatex")))
  (should (equal (emacs-cpp-markdown--pdf-command "/a/b/doc.md" "xelatex" "Menlo" "2.5cm")
                 '("pandoc" "doc.md" "-o" "doc.pdf" "--pdf-engine=xelatex"
                   "-V" "monofont=Menlo" "-V" "geometry:margin=2.5cm")))
  (should (equal emacs-cpp-markdown-pdf-engine "xelatex"))
  (should (equal emacs-cpp-markdown-pdf-monofont "DejaVuSansMono.ttf"))
  (should (equal emacs-cpp-markdown-pdf-margin "3cm")))

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
  ;; pandoc and the engine found, the server not built: before LaTeX runs (D-199).
  (when (and (executable-find "pandoc") (executable-find "xelatex"))
    (let* ((pdf-info-epdfinfo-program "/nonexistent/epdfinfo")
           (emacs-cpp-pdf--server-checked nil)
           (err (should-error (emacs-cpp-markdown--check-tools "xelatex"))))
      (should (string-search "make epdfinfo" (cadr err))))))

(ert-deftest init-writing-pdf-server-check ()
  "A server not built or not running: an error naming the fix; a pass holds (D-199)."
  (init-test--load)
  (let ((emacs-cpp-pdf--server-checked nil)
        (dir (make-temp-file "emacs-cpp-writing-bin" t)))
    (unwind-protect
        (let ((failing (expand-file-name "epdfinfo" dir)))
          ;; Not built.
          (let* ((pdf-info-epdfinfo-program (expand-file-name "missing" dir))
                 (err (should-error (emacs-cpp-pdf--check-server))))
            (should (string-search "make epdfinfo" (cadr err)))
            (should (string-search emacs-cpp-root (cadr err)))
            (should-not emacs-cpp-pdf--server-checked))
          ;; Built, but it does not run: a poppler library replaced since the build.
          (write-region "#!/bin/sh\necho no such library\nexit 1\n" nil failing nil 'no-message)
          (set-file-modes failing #o755)
          (let* ((pdf-info-epdfinfo-program failing)
                 (err (should-error (emacs-cpp-pdf--check-server))))
            (should (string-search "make epdfinfo" (cadr err)))
            (should (string-search "no such library" (cadr err)))
            (should-not emacs-cpp-pdf--server-checked))
          ;; A pass is not checked again; another program is.
          (let ((calls 0)
                (pdf-info-epdfinfo-program failing))
            (cl-letf (((symbol-function 'pdf-info-check-epdfinfo)
                       (lambda (&rest _) (cl-incf calls))))
              (emacs-cpp-pdf--check-server)
              (emacs-cpp-pdf--check-server)
              (should (= calls 1))
              (let ((pdf-info-epdfinfo-program (concat failing "2")))
                (emacs-cpp-pdf--check-server))
              (should (= calls 2)))))
      (delete-directory dir t))))

(ert-deftest init-writing-pdf-every-pdf ()
  "Every PDF, by name or by content, gets pdf-tools' mode through the check (D-199)."
  (init-test--load)
  (dolist (name '("a.pdf" "b.PDF" "/x/c.Pdf"))
    (should (eq (assoc-default name auto-mode-alist #'string-match-p)
                #'emacs-cpp-pdf-view-mode)))
  (should (eq (cdr (assoc "%PDF" magic-mode-alist)) #'emacs-cpp-pdf-view-mode))
  (should (equal pdf-info-epdfinfo-program
                 (expand-file-name "lib/pdf-tools/server/epdfinfo" emacs-cpp-root)))
  (should (eq (default-value 'pdf-view-display-size) 'fit-width))
  (should (memq #'emacs-cpp-pdf--setup pdf-view-mode-hook))
  (dolist (mode '(pdf-view-roll-minor-mode pdf-links-minor-mode pdf-isearch-minor-mode))
    (should (memq mode pdf-tools-enabled-modes))))

(ert-deftest init-writing-pdf-without-server ()
  "A PDF visited without a server stays raw, and the message names the fix (D-199)."
  (init-test--load)
  (let* ((file (make-temp-file "emacs-cpp-writing" nil ".pdf"))
         (emacs-cpp-pdf--server-checked nil)
         (pdf-info-epdfinfo-program "/nonexistent/epdfinfo")
         (messages nil)
         (inhibit-message t))
    (unwind-protect
        (progn
          (init-writing-test--write-pdf file 1)
          (cl-letf (((symbol-function 'message)
                     (lambda (format-string &rest args)
                       (push (apply #'format format-string args) messages))))
            (with-current-buffer (find-file-noselect file)
              (unwind-protect
                  (should-not (derived-mode-p 'pdf-view-mode))
                (kill-buffer))))
          (should (cl-some (lambda (line) (string-search "make epdfinfo" line)) messages)))
      (delete-file file))))

(ert-deftest init-writing-pdf-clamp ()
  "The clamp moves every live window past the new end, and only those (D-192)."
  (init-test--load)
  (require 'pdf-tools)
  (let ((moved nil)
        (window (selected-window))
        (dead (let ((new (split-window))) (delete-window new) new)))
    (with-temp-buffer
      (cl-letf (((symbol-function 'pdf-info-number-of-pages) (lambda (&rest _) 5))
                ((symbol-function 'pdf-roll-goto-page)
                 (lambda (page win) (push (list 'roll page win) moved)))
                ((symbol-function 'pdf-view-goto-page)
                 (lambda (page win) (push (list 'view page win) moved)))
                ((symbol-function 'image-mode-window-get)
                 (lambda (prop win) (and (eq prop 'page) (cdr (assq win pages)))))
                ((symbol-function 'image-mode-window-put) #'ignore))
        (let ((pages nil))
          (ignore pages))
        (setq-local image-mode-winprops-alist `((,window) (,dead) (t)))
        (dlet ((pages `((,window . 6) (,dead . 9))))
          (setq-local pdf-view-roll-minor-mode t)
          (emacs-cpp-pdf--clamp-page)
          (should (equal moved `((roll 5 ,window))))
          ;; Roll mode turned off by hand.
          (setq moved nil)
          (setq-local pdf-view-roll-minor-mode nil)
          (emacs-cpp-pdf--clamp-page)
          (should (equal moved `((view 5 ,window)))))
        ;; A page that still exists stays.
        (dlet ((pages `((,window . 5))))
          (setq moved nil)
          (setq-local pdf-view-roll-minor-mode t)
          (emacs-cpp-pdf--clamp-page)
          (should-not moved))))))

(ert-deftest init-writing-pdf-defaults ()
  "The Mac finds MacTeX's engines (D-184); each platform names its install command."
  (init-test--load)
  (pcase system-type
    ('darwin
     (should (member "/Library/TeX/texbin" emacs-cpp-default-exec-path-prepend))
     (should (member "/Library/TeX/texbin" exec-path))
     (should (string-match-p "port install pandoc;"
                             emacs-cpp-default-markdown-pdf-install)))
    ('gnu/linux
     (should (equal emacs-cpp-default-markdown-pdf-install
                    "sudo pacman -S pandoc-cli texlive-xetex")))))

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
        ;; pdf-tools' modes hold after the revert too (D-199).
        (with-current-buffer shown
          (should (eq major-mode 'pdf-view-mode))
          (should pdf-view-roll-minor-mode)
          (should (memq #'emacs-cpp-pdf--clamp-page after-revert-hook)))
        ;; The margin goes to pandoc, and LaTeX accepts it (D-189).
        (let ((process (emacs-cpp-markdown-pdf)))
          (should (member "geometry:margin=3cm" (process-command process)))
          (should (eql 0 (init-writing-test--wait process))))))))

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
