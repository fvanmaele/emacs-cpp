;;; init-completion-test.el --- The go-to-anything prompt  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (T-049, D-074 .. D-078): `M-o' runs the command; its
;; sources and narrow keys; D-077's settings hold inside the prompt only and a chosen
;; command runs after it; the symbol request skips an empty input, starts at the
;; third character and drops replies to old input; highlighting stops after the
;; limit; consult's patch 0001 (D-079) drops a source hidden by narrowing from the
;; candidates and brings it back on widening.  `consult--multi' and `jsonrpc-async-request' are replaced by stubs, so no
;; prompt and no clangd are needed.  Snippets (D-095): yasnippet's keys in code and
;; LaTeX buffers, a collection snippet expanding and its fields.  Needs git.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defmacro init-completion-test--with-project (&rest body)
  "Run BODY in a buffer visiting a file of a temporary git project bound to `root'."
  (declare (indent 0))
  `(let* ((root (file-name-as-directory
                (file-truename (make-temp-file "emacs-cpp-go" t))))
          (default-directory root))
     (unwind-protect
         (progn
           (make-directory (expand-file-name "sub" root))
           (write-region "int a;\n" nil (expand-file-name "a.cc" root))
           (write-region "int b;\n" nil (expand-file-name "sub/b.h" root))
           (should (eql 0 (call-process "git" nil nil nil "init" "-q")))
           (let ((buffer (find-file-noselect (expand-file-name "a.cc" root))))
             (unwind-protect
                 (with-current-buffer buffer ,@body)
               (kill-buffer buffer))))
       (delete-directory root t))))

(ert-deftest init-completion-go-key ()
  (init-test--load)
  (should (eq (keymap-lookup global-map "M-o") #'emacs-cpp-go-to-anything)))

(ert-deftest init-completion-go-sources-settings-and-action ()
  (init-test--load)
  (init-completion-test--with-project
    (let ((normal gc-cons-threshold)
          seen ran-with listed-with)
      (defalias 'init-completion-test--command
        (lambda () (interactive) (setq ran-with (list gc-cons-threshold consult-async-split-style))))
      (unwind-protect
          (cl-letf* ((listing (symbol-function 'projectile-project-files))
                     ((symbol-function 'projectile-project-files)
                      (lambda (&rest args)
                        (setq listed-with gc-cons-threshold)
                        (apply listing args)))
                     ((symbol-function 'consult--multi)
                      (lambda (sources &rest options)
                        (setq seen (list :sources sources :options options
                                         :gc gc-cons-threshold
                                         :split consult-async-split-style
                                         :preview consult-preview-key
                                         :delay consult-async-refresh-delay
                                         :directory default-directory))
                        (let ((command (seq-find (lambda (s) (equal (plist-get s :name) "Command"))
                                                 sources)))
                          (cons "init-completion-test--command" command)))))
            (emacs-cpp-go-to-anything))
        (fmakunbound 'init-completion-test--command))
      (let* ((sources (plist-get seen :sources))
             (names (mapcar (lambda (s) (plist-get s :name)) sources))
             (files (plist-get (seq-find (lambda (s) (equal (plist-get s :name) "Project File"))
                                         sources)
                               :items)))
        ;; No eglot server here, so no symbol source.
        (should (equal names '("Buffer" "Recent File" "Bookmark" "Project File" "Command"
                               "Project")))
        (should (equal (mapcar (lambda (s) (plist-get s :narrow)) sources) '(?b ?r ?m ?f ?x ?p)))
        (should (equal (mapcar (lambda (s) (plist-get s :hidden)) sources) '(nil nil nil nil t t)))
        (should (member (cons "sub/b.h" (concat root "sub/b.h")) files))
        (should (member (cons "a.cc" (concat root "a.cc")) files))
        ;; D-077 and D-078 inside the prompt, the file listing included ...
        (should (= listed-with (* 64 1024 1024)))
        (should (= (plist-get seen :gc) (* 64 1024 1024)))
        (should (null (plist-get seen :split)))
        ;; D-088: typing previews after 0.3 s, browsing at once.
        (should (equal (plist-get seen :preview) emacs-cpp-go--preview-key))
        (let ((keys (consult--preview-key-normalize emacs-cpp-go--preview-key)))
          (should (equal (alist-get 'any keys) 0.3))
          (should (equal (cdr (assoc (key-parse "<down>") keys)) 0))
          (should (equal (cdr (assoc (key-parse "<next>") keys)) 0)))
        (should (= (plist-get seen :delay) 0.05))
        (should (equal (plist-get seen :directory) root))
        (should (equal (plist-get (plist-get seen :options) :sort) nil))
        (should (plist-member (plist-get seen :options) :sort))
        ;; ... and the chosen command runs after it, with the usual settings.
        (should (equal ran-with (list normal consult-async-split-style)))
        (should (= normal gc-cons-threshold))))))

(defun init-completion-test--requests (inputs &optional reply-later)
  "Feed INPUTS to the symbol request step; return (QUERIES . SUNK).
Replies come at once with one symbol named after the query, or, with
REPLY-LATER, after all inputs, newest first."
  (let (queries sunk pending)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method params &rest args)
                 (let ((query (plist-get params :query))
                       (success (plist-get args :success-fn)))
                   (push query queries)
                   (let ((reply (lambda () (funcall success (vector (list :name query))))))
                     (if reply-later (push reply pending) (funcall reply)))))))
      (let ((step (funcall (emacs-cpp-go--symbol-request '(server))
                           (lambda (action) (push action sunk) nil))))
        (dolist (input inputs) (funcall step input))
        (mapc #'funcall pending)))
    (cons (nreverse queries) (nreverse sunk))))

(ert-deftest init-completion-go-symbol-request ()
  (init-test--load)
  (require 'consult)
  ;; Nothing for the opening or an empty input; one request per other input.
  (pcase-let ((`(,queries . ,sunk) (init-completion-test--requests '(setup "" "vec"))))
    (should (equal queries '("vec")))
    (should (member '((:name "vec")) sunk)))
  ;; A late reply to an older input is dropped.
  (pcase-let ((`(,queries . ,sunk) (init-completion-test--requests '("vec" "vect") t)))
    (should (equal queries '("vec" "vect")))
    (should (member '((:name "vect")) sunk))
    (should-not (member '((:name "vec")) sunk))))

(ert-deftest init-completion-go-symbols-from-third-character ()
  "D-077: no request before the third character.  consult's timing (D-087) is
checked in a terminal Emacs: in batch the minibuffer never changes, so consult
takes every input for initial input and sends it at once."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  ;; Loaded before the stub below, which loading it would replace.
  (require 'consult-eglot)
  (let (queries)
    (cl-letf (((symbol-function 'consult-eglot--servers) (lambda () '(server)))
              ((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method params &rest _) (push (plist-get params :query) queries))))
      (let* ((source (car (emacs-cpp-go--symbol-sources "/project/")))
             (step (funcall (plist-get source :async) (lambda (_) nil))))
        (should (equal (plist-get source :narrow) ?s))
        (funcall step 'setup)
        (dolist (input '("v" "ve"))
          (funcall step input)
          (accept-process-output nil 0.2))
        (should (null queries))
        (funcall step "vec")
        (let ((deadline (+ (float-time) 1.5)))
          (while (and (null queries) (< (float-time) deadline))
            (accept-process-output nil 0.05)))
        (should (equal queries '("vec")))))))

(ert-deftest init-completion-page-keys ()
  "D-084: PgDn / PgUp page through vertico's candidates, not the history."
  (init-test--load)
  (should (eq (keymap-lookup vertico-map "<next>") #'vertico-scroll-up))
  (should (eq (keymap-lookup vertico-map "<prior>") #'vertico-scroll-down))
  (should (eq (keymap-lookup minibuffer-local-map "M-n") #'next-history-element)))

(ert-deftest init-completion-go-all-symbols-empty-input ()
  "D-086: `l' asks clangd for an empty input, as `C-c l s' does when it opens, and
keeps that list for one or two characters; `s' asks nothing for either."
  (init-test--load)
  (require 'consult)
  (let ((steps (lambda (empty inputs)
                 (let (sunk)
                   (let ((step (funcall (emacs-cpp-go--min-input 3 empty)
                                        (lambda (action) (push action sunk) nil))))
                     (mapc step inputs))
                   (nreverse sunk)))))
    (should (equal (funcall steps t '("" "a" "an" "ans")) '("" cancel cancel "ans")))
    (should (equal (funcall steps nil '("" "a" "an" "ans")) '(cancel cancel cancel "ans"))))
  (let (queries)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method params &rest _) (push params queries))))
      (funcall (funcall (emacs-cpp-go--symbol-request '(server) nil t) #'ignore) "")
      (funcall (funcall (emacs-cpp-go--symbol-request '(server) '(("file:///p/" . "file:///p/")))
                        #'ignore)
               ""))
    (should (equal queries '((:query ""))))))

(ert-deftest init-completion-go-symbol-sources ()
  "D-082: `s' the project's symbols, `l' hidden with every symbol; no root, `s' only."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  (require 'consult-eglot)
  (cl-letf (((symbol-function 'consult-eglot--servers) (lambda () '(server))))
    (let ((sources (emacs-cpp-go--symbol-sources "/project/")))
      (should (equal (mapcar (lambda (s) (plist-get s :name)) sources)
                     '("Symbol" "All Symbols")))
      (should (equal (mapcar (lambda (s) (plist-get s :narrow)) sources) '(?s ?l)))
      (should (equal (mapcar (lambda (s) (plist-get s :hidden)) sources) '(nil t))))
    (should (equal (mapcar (lambda (s) (plist-get s :narrow))
                           (emacs-cpp-go--symbol-sources nil))
                   '(?s)))))

(ert-deftest init-completion-go-project-symbols ()
  "D-082, D-083: with root URIs up to `emacs-cpp-go-symbol-limit' matches are
asked for and only the project's kept, a message when a reply reaches the limit;
without, clangd's usual limit and no filter."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  (let* ((real (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-root" t))))
         (link (concat (directory-file-name real) "-link")))
    (unwind-protect
        (progn
          (make-symbolic-link (directory-file-name real) link)
          (let ((uris (emacs-cpp-go--root-uris (file-name-as-directory link))))
            ;; Both spellings, each ending in a slash, so `root-other/' is no match.
            (should (member (concat "file://" link "/") (mapcar #'cdr uris)))
            (should (member (concat "file://" real) (mapcar #'cdr uris)))
            (let* ((symbol (lambda (name path)
                             (list :name name :location
                                   (list :uri (eglot-path-to-uri path :truenamep t)))))
                   (reply (vector (funcall symbol "mine" (concat real "src/a.cc"))
                                  (funcall symbol "linked" (concat link "/include/a.h"))
                                  (funcall symbol "library" "/usr/include/deal.II/a.h")
                                  (funcall symbol "sibling"
                                           (concat (directory-file-name real) "-other/a.cc"))))
                   (run (lambda (root-uris)
                          (let (params sunk messages)
                            (cl-letf (((symbol-function 'jsonrpc-async-request)
                                       (lambda (_server _method p &rest args)
                                         (setq params p)
                                         (funcall (plist-get args :success-fn) reply)))
                                      ((symbol-function 'message)
                                       (lambda (format &rest args)
                                         (push (apply #'format-message format args) messages))))
                              (funcall (funcall (emacs-cpp-go--symbol-request '(server) root-uris)
                                                (lambda (action) (push action sunk) nil))
                                       "vec"))
                            (list params
                                  (mapcar (lambda (s) (plist-get s :name))
                                          (seq-find #'consp sunk))
                                  (and messages t))))))
              (should (= (default-value 'emacs-cpp-go-symbol-limit) 10000))
              (should (equal (funcall run uris)
                             '((:query "vec" :limit 10000) ("mine" "linked") nil)))
              ;; A reply as long as the limit: maybe more matched; said, not hidden.
              (let ((emacs-cpp-go-symbol-limit 4))
                (should (equal (funcall run uris)
                               '((:query "vec" :limit 4) ("mine" "linked") t))))
              (let ((emacs-cpp-go-symbol-limit 0))
                (should (equal (funcall run uris)
                               '((:query "vec" :limit 0) ("mine" "linked") nil))))
              (should (equal (funcall run nil)
                             '((:query "vec") ("mine" "linked" "library" "sibling") nil))))))
      (delete-file link)
      (delete-directory real t))))

(ert-deftest init-completion-go-root-encoding-and-case ()
  "D-085: a root's URI matches however a server escapes it: the four spellings
seen (eglot, clangd, pyright, R's languageserver; checked 2026-10-13) under three
awkward roots; not a sibling directory or a library; another case on macOS only;
a `%' in the root's name."
  (init-test--load)
  (let* ((parent (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-root" t))))
         (symbol (lambda (uri) (list :name "answer" :location (list :uri uri))))
         (under (lambda (uri root)
                  (and (emacs-cpp-go--under-root-p (funcall symbol (concat "file://" parent uri))
                                                   (emacs-cpp-go--root-uris (concat parent root)))
                       t))))
    (unwind-protect
        (progn
          ;; Root, then its spelling by eglot, clangd, pyright, languageserver.
          (pcase-dolist (`(,root . ,spellings)
                         '(("c++ (x)@y/" "c++%20(x)@y" "c%2B%2B%20%28x%29%40y"
                            "c%2B%2B%20%28x%29%40y" "c++%20(x)@y")
                           ("a:b \u00e4/" "a%3Ab%20%C3%A4" "a:b%20%C3%A4" "a%3Ab%20%C3%A4"
                            "a:b%20%C3%A4")
                           ("py a:b c++/" "py%20a%3Ab%20c++" "py%20a:b%20c%2B%2B"
                            "py%20a%3Ab%20c%2B%2B" "py%20a:b%20c++")))
            (dolist (spelling spellings)
              (should (funcall under (concat spelling "/src/a.cc") root))
              (should-not (funcall under (concat spelling "-other/a.cc") root))
              (should (eq (funcall under (upcase (concat spelling "/src/a.cc")) root)
                          (eq system-type 'darwin)))))
          (should-not (funcall under "c%2B%2B/a.h" "c++ (x)@y/"))
          (should-not (emacs-cpp-go--under-root-p
                       (funcall symbol "file:///usr/include/c%2B%2B/v1/vector")
                       (emacs-cpp-go--root-uris (concat parent "c++ (x)@y/"))))
          (should (funcall under "50%25off/a.R" "50%off/")))
      (delete-directory parent t))))

(ert-deftest init-completion-go-narrowing-drops-hidden-candidates ()
  "consult patch 0001 (D-079): narrowed, a hidden source's candidates leave the list;
widened at the same input, they come back."
  (init-test--load)
  (require 'consult)
  (let* ((shown nil)
         (files (list :name "File" :narrow ?f :items '("vec.h" "vector.cc" "other.cc")))
         (symbols (list :name "Symbol" :narrow ?s
                        :async (consult--async-dynamic
                                (lambda (input) (list (concat "symbol-" input))))))
         (async (funcall (consult--multi-async
                          (consult--multi-enabled-sources (list files symbols)))
                         (lambda (action) (when (consp action) (setq shown action)) nil))))
    (cl-flet ((type (input)
                (funcall async input)
                (accept-process-output nil 0.1)
                (mapcar (lambda (candidate)
                          (substring-no-properties candidate 0 (1- (length candidate))))
                        shown)))
      (with-temp-buffer
        (funcall async 'setup)
        (should (equal (type "vec") '("vec.h" "vector.cc" "symbol-vec")))
        (setq consult--narrow ?s)
        (should (equal (type "vect") '("symbol-vect")))
        (should (equal (type "vec") '("symbol-vec")))
        (setq consult--narrow nil)
        (should (equal (type "vec") '("vec.h" "vector.cc" "symbol-vec")))
        (funcall async 'destroy)))))

(ert-deftest init-completion-go-highlight-limit ()
  (init-test--load)
  (require 'consult)
  (pcase-let ((`(,_ . ,highlight)
               (funcall (emacs-cpp-go--highlight-first 2) "a" 'emacs t)))
    (let ((strings (list (copy-sequence "abc") (copy-sequence "bac") (copy-sequence "cab"))))
      (mapc highlight strings)
      (should (text-property-not-all 0 3 'face nil (nth 0 strings)))
      (should (text-property-not-all 0 3 'face nil (nth 1 strings)))
      (should-not (text-property-not-all 0 3 'face nil (nth 2 strings))))))

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
