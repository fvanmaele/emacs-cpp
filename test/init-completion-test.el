;;; init-completion-test.el --- The completion stack and snippets  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile: PgDn / PgUp in vertico (D-084); snippets (D-095):
;; yasnippet's keys in code and LaTeX buffers, a collection snippet expanding and its
;; fields.  `M-o' has its own file, init-go-to-anything-test.el (D-099).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(ert-deftest init-completion-page-keys ()
  "D-084: PgDn / PgUp page through vertico's candidates, not the history."
  (init-test--load)
  (should (eq (keymap-lookup vertico-map "<next>") #'vertico-scroll-up))
  (should (eq (keymap-lookup vertico-map "<prior>") #'vertico-scroll-down))
  (should (eq (keymap-lookup minibuffer-local-map "M-n") #'next-history-element)))

;;;; Matching and tiers (D-120)

(ert-deftest init-completion-match-tiers ()
  "D-120: tier 1 unbroken from a word start, 2 unbroken inside a word or initials,
3 letters in order with gaps inside a word; case ignored; the worst word decides."
  (init-test--load)
  (pcase-dolist (`(,input ,candidate ,tier)
                 '(("vec" "Vector.cc" 1) ("vec" "src/vector.h" 1) ("ser" "HTTPServer" 1)
                   ("tools" "VectorTools.cc" 1) ("ector" "Vector.cc" 2)
                   ("vt" "VectorTools.cc" 2) ("VT" "VectorTools.cc" 2)
                   ("eto" "Vector.cc" 3) ("vec eto" "Vector.cc" 3) ("" "Vector.cc" 1)
                   ;; A run of capitals: its last one starts a word before a small one.
                   ("vfoo" "ATVfoo" 1) ("tv" "ATVfoo" 2) ("s" "HTTPServer" 1)
                   ("hs" "HTTPServer" 2) ("n" "max_n" 1)))
    (should (equal (list input candidate (emacs-cpp-match-tier input candidate))
                   (list input candidate tier))))
  ;; Stable within a tier.
  (should (equal (emacs-cpp-match-sort-by-tier
                  "eto" (list "Vector.cc" "fetor.c" "eto.h" "veto.h" "Petrol.cc"))
                 '("eto.h" "fetor.c" "veto.h" "Vector.cc" "Petrol.cc"))))

(ert-deftest init-completion-letters-in-order ()
  "D-120: the prompts match letters in order and initials, ignoring case."
  (init-test--load)
  (let ((files '("Vector.cc" "VectorTools.cc" "eto.h" "README.md")))
    (should (member "Vector.cc" (completion-all-completions "eto" files nil 3)))
    (dolist (input '("vt" "VT"))
      (should (member "VectorTools.cc" (completion-all-completions input files nil 2))))
    (should (member "README.md" (completion-all-completions "readme" files nil 6)))))

(defun init-completion-test--sort (input candidates metadata &optional file-name)
  "Sort CANDIDATES as vertico would for INPUT in a prompt with METADATA."
  (with-temp-buffer
    (insert input)
    (setq-local vertico--metadata metadata)
    (cl-letf (((symbol-function 'minibuffer-prompt-end) #'point-min))
      (let ((minibuffer-completing-file-name file-name)
            (vertico-sort-function nil))
        (emacs-cpp-completion-sort (copy-sequence candidates))))))

(ert-deftest init-completion-sort-by-tier ()
  "D-120: vertico ranks by tier after the prompt's own order; paths typed in
`C-x C-f' and places in a buffer keep their order."
  (init-test--load)
  (should (eq vertico-sort-override-function #'emacs-cpp-completion-sort))
  (let ((files '("Vector.cc" "veto.h" "eto.h")))
    (should (equal (init-completion-test--sort
                    "eto" files '(metadata (category . project-file)))
                   '("eto.h" "veto.h" "Vector.cc")))
    (should (equal (init-completion-test--sort "eto" files '(metadata (category . file)) t)
                   files))
    (should (equal (init-completion-test--sort
                    "eto" files '(metadata (category . consult-location)))
                   files))))

(ert-deftest init-completion-paths-keep-partial-completion ()
  "D-120's exception: `C-x C-f' completes `u/s/e' as before."
  (init-test--load)
  (let ((root (file-name-as-directory (make-temp-file "emacs-cpp-paths" t))))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "usr1/share1/emacs1" root) t)
          (let ((default-directory root))
            (should (equal (car (completion-try-completion
                                 "u/s/e" #'read-file-name-internal nil 5
                                 '(metadata (category . file))))
                           "usr1/share1/emacs1/"))))
      (delete-directory root t))))

;;;; Snippets (D-095)

(defmacro init-completion-test--with-snippet-buffer (name text &rest body)
  "Visit a new file NAME holding TEXT, point at its end, select it and run BODY.
eglot is not started; the buffer and the file go afterwards."
  (declare (indent 2))
  `(let* ((dir (make-temp-file "emacs-cpp-snippets" t))
          (file (expand-file-name ,name dir)))
     (unwind-protect
         (cl-letf (((symbol-function 'eglot-ensure) #'ignore))
           (write-region ,text nil file)
           (let ((buffer (find-file-noselect file)))
             (unwind-protect
                 (save-window-excursion
                   (switch-to-buffer buffer)
                   (goto-char (point-max))
                   ,@body)
               (with-current-buffer buffer (set-buffer-modified-p nil))
               (kill-buffer buffer))))
       (delete-directory dir t))))

(ert-deftest init-completion-snippet-keys ()
  "D-095: yasnippet in code and LaTeX buffers; `C-c y' expands, TAB keeps
indenting and completing (D-020) outside a snippet; choosing a snippet by name
loads the collection too."
  (init-test--load)
  (dolist (case '(("a.cc" . c++-ts-mode) ("a.py" . python-ts-mode) ("a.tex" . LaTeX-mode)))
    (init-completion-test--with-snippet-buffer (car case) ""
      (should (eq major-mode (cdr case)))
      (should yas-minor-mode)
      (should (eq (keymap-lookup nil "C-c y") #'emacs-cpp-snippets-expand))
      (should (eq (keymap-lookup nil "TAB") #'indent-for-tab-command))
      (should (eq (command-remapping #'yas-insert-snippet) #'emacs-cpp-snippets-insert)))))

(ert-deftest init-completion-snippet-collection-on-request ()
  "D-095: patch 0001 keeps the collection out of the autoloads, so loading
yasnippet does not scan it; `C-c y' loads it."
  (should-not (with-temp-buffer
                (insert-file-contents (expand-file-name "lib/autoloads.el" build-packages-root))
                (search-forward "(yasnippet-snippets-initialize)" nil t))))

(ert-deftest init-completion-snippet-expands-and-moves-between-fields ()
  "D-095: a key of the collection expands on `C-c y' in C++, Python and LaTeX;
TAB / S-TAB go to the next / previous field, except while corfu completes."
  (init-test--load)
  ;; AUCTeX picks plain TeX for a file without LaTeX in it, hence the class line.
  (pcase-dolist (`(,name ,text ,expanded ,second-field)
                 '(("a.cc" "for" "for (i = 0; i < N; ++i) {" "i < N")
                   ("a.py" "def" "def methodname(self, arg):" "arg")
                   ("a.tex" "\\documentclass{article}\nbegin" "\\begin{environment}" nil)))
    (init-completion-test--with-snippet-buffer name text
      (execute-kbd-macro (kbd "C-c y"))
      (should (featurep 'yasnippet-snippets))
      (should (save-excursion
                (goto-char (point-min))
                (re-search-forward (concat "^" (regexp-quote expanded) "$") nil t)))
      (should (yas-active-snippets))
      (should (eq (keymap-lookup nil "TAB") #'yas-next-field-or-maybe-expand))
      (should (eq (keymap-lookup nil "<backtab>") #'yas-prev-field))
      (let ((first (point)))
        (when second-field
          (execute-kbd-macro (kbd "TAB"))
          (should (looking-at (regexp-quote second-field)))
          (execute-kbd-macro (kbd "<backtab>"))
          (should (= (point) first))))
      (let ((completion-in-region-mode t))
        (should-not (eq (keymap-lookup nil "TAB") #'yas-next-field-or-maybe-expand))))))

(ert-deftest init-completion-snippet-no-key ()
  "D-095: `C-c y' with no snippet key before point says so and changes nothing."
  (init-test--load)
  (init-completion-test--with-snippet-buffer "a.cc" "xyzzy"
    (should-error (emacs-cpp-snippets-expand) :type 'user-error)
    (should (equal (buffer-string) "xyzzy"))))

(provide 'init-completion-test)
;;; init-completion-test.el ends here
