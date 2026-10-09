;;; c_ts_mode_local_style_repro.el --- c-ts-mode-indent-style from local variables is ignored  -*- lexical-binding: t; -*-

;; Usage: emacs -Q --batch -l c_ts_mode_local_style_repro.el
;; Needs the tree-sitter C++ grammar.  Writes a sample to a temporary directory,
;; once with `c-ts-mode-indent-style' bsd in .dir-locals.el and once in the
;; file's -*- line, visits it, re-indents it and prints the result.

(require 'c-ts-mode)

(setq enable-local-variables :all)
(add-to-list 'major-mode-remap-alist '(c++-mode . c++-ts-mode))

(defconst repro-body "int f(int x)\n{\nif (x)\n{\nreturn 1;\n}\nreturn 0;\n}\n"
  "An `if' with its brace on its own line: bsd and gnu indent it differently.")

(defun repro-visit (dir file-name contents)
  "Write CONTENTS to FILE-NAME in DIR, visit it, re-indent it, report."
  (let ((file (expand-file-name file-name dir)))
    (with-temp-file file (insert contents))
    (with-current-buffer (find-file-noselect file)
      (setq-local c-ts-indent-offset 4 indent-tabs-mode nil)
      (indent-region (point-min) (point-max))
      (message "--- %s: c-ts-mode-indent-style is %S (local: %s)\n%s"
               file-name c-ts-mode-indent-style
               (local-variable-p 'c-ts-mode-indent-style) (buffer-string))
      (kill-buffer))))

(message "Emacs %s" emacs-version)
(let ((dir (make-temp-file "c-ts-style" t)))
  (with-temp-file (expand-file-name ".dir-locals.el" dir)
    (insert "((c++-ts-mode . ((c-ts-mode-indent-style . bsd))))\n"))
  (repro-visit dir "dir-local.cc" repro-body)
  (delete-file (expand-file-name ".dir-locals.el" dir))
  (repro-visit dir "file-local.cc"
               (concat "// -*- c-ts-mode-indent-style: bsd -*-\n" repro-body))
  (let ((c-ts-mode-indent-style 'bsd))
    (repro-visit dir "let-bound.cc" repro-body))
  (delete-directory dir t))

;;; c_ts_mode_local_style_repro.el ends here
