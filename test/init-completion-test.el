;;; init-completion-test.el --- The go-to-anything prompt  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (T-049, D-074 .. D-078): `M-o' runs the command; its
;; sources and narrow keys; D-077's settings hold inside the prompt only and a chosen
;; command runs after it; the symbol request skips an empty input, starts at the
;; third character and drops replies to old input; highlighting stops after the
;; limit; consult's patch 0001 (D-079) drops a source hidden by narrowing from the
;; candidates and brings it back on widening.  `consult--multi' and `jsonrpc-async-request' are replaced by stubs, so no
;; prompt and no clangd are needed.  Needs git.

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
        (accept-process-output nil 0.2)
        (should (equal queries '("vec")))))))

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
  "D-082: with root URIs every match is asked for and only the project's kept;
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
            (should (equal uris (list (concat (eglot-path-to-uri link :truenamep t) "/")
                                      (concat (eglot-path-to-uri (directory-file-name real)
                                                                 :truenamep t)
                                              "/"))))
            (let* ((symbol (lambda (name path)
                             (list :name name :location
                                   (list :uri (eglot-path-to-uri path :truenamep t)))))
                   (reply (vector (funcall symbol "mine" (concat real "src/a.cc"))
                                  (funcall symbol "linked" (concat link "/include/a.h"))
                                  (funcall symbol "library" "/usr/include/deal.II/a.h")
                                  (funcall symbol "sibling"
                                           (concat (directory-file-name real) "-other/a.cc"))))
                   (run (lambda (root-uris)
                          (let (params sunk)
                            (cl-letf (((symbol-function 'jsonrpc-async-request)
                                       (lambda (_server _method p &rest args)
                                         (setq params p)
                                         (funcall (plist-get args :success-fn) reply))))
                              (funcall (funcall (emacs-cpp-go--symbol-request '(server) root-uris)
                                                (lambda (action) (push action sunk) nil))
                                       "vec"))
                            (list params
                                  (mapcar (lambda (s) (plist-get s :name))
                                          (seq-find #'consp sunk)))))))
              (should (equal (funcall run uris)
                             '((:query "vec" :limit 0) ("mine" "linked"))))
              (should (equal (funcall run nil)
                             '((:query "vec") ("mine" "linked" "library" "sibling")))))))
      (delete-file link)
      (delete-directory real t))))

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

(provide 'init-completion-test)
;;; init-completion-test.el ends here
