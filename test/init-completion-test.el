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
