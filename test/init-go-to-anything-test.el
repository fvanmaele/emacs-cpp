;;; init-go-to-anything-test.el --- The go-to-anything prompt  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (T-049, D-074 .. D-078): `M-o' runs the command; its
;; sources and narrow keys; D-077's settings hold inside the prompt only and a chosen
;; command runs after it; the symbol request skips an empty input, starts at the
;; third character and drops replies to old input; highlighting stops after the
;; limit; consult's patch 0001 (D-079) drops a source hidden by narrowing from the
;; candidates and brings it back on widening.  `consult--multi' and
;; `jsonrpc-async-request' are replaced by stubs, so no prompt and no clangd are
;; needed; with them `emacs-cpp-lsp-symbol-params', since the fake servers have no
;; capabilities (D-113 is tested in init-lsp-test.el).  Needs git.  Moved from init-completion-test.el with the module (D-099).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defmacro init-go-to-anything-test--with-project (&rest body)
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

(ert-deftest init-go-to-anything-key ()
  (init-test--load)
  (should (eq (keymap-lookup global-map "M-o") #'emacs-cpp-go-to-anything)))

(ert-deftest init-go-to-anything-sources-settings-and-action ()
  (init-test--load)
  (init-go-to-anything-test--with-project
    (let ((normal gc-cons-threshold)
          seen ran-with listed-with)
      (defalias 'init-go-to-anything-test--command
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
                          (cons "init-go-to-anything-test--command" command)))))
            (emacs-cpp-go-to-anything))
        (fmakunbound 'init-go-to-anything-test--command))
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

(defun init-go-to-anything-test--requests (inputs &optional reply-later)
  "Feed INPUTS to the symbol request step; return (QUERIES . SUNK).
Replies come at once with one symbol named after the query, or, with
REPLY-LATER, after all inputs, newest first."
  (let (queries sunk pending)
    (cl-letf (((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
              ((symbol-function 'jsonrpc-async-request)
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

(ert-deftest init-go-to-anything-symbol-request ()
  (init-test--load)
  (require 'consult)
  ;; Nothing for the opening or an empty input; one request per other input.
  (pcase-let ((`(,queries . ,sunk) (init-go-to-anything-test--requests '(setup "" "vec"))))
    (should (equal queries '("vec")))
    (should (member '((:name "vec")) sunk)))
  ;; A late reply to an older input is dropped.
  (pcase-let ((`(,queries . ,sunk) (init-go-to-anything-test--requests '("vec" "vect") t)))
    (should (equal queries '("vec" "vect")))
    (should (member '((:name "vect")) sunk))
    (should-not (member '((:name "vec")) sunk))))

(ert-deftest init-go-to-anything-symbols-from-third-character ()
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
              ((symbol-function 'eglot-current-server) #'ignore)
              ((symbol-function 'emacs-cpp-go--server-name) #'symbol-name)
              ((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
              ((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method params &rest _) (push (plist-get params :query) queries))))
      (let* ((source (car (emacs-cpp-go--symbol-sources "/project/")))
             (step (funcall (plist-get source :async) (lambda (_) nil))))
        (should (equal (plist-get source :narrow) '(?s . "Project Symbol")))
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

(ert-deftest init-go-to-anything-all-symbols-empty-input ()
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
    (cl-letf (((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
              ((symbol-function 'jsonrpc-async-request)
               (lambda (_server _method params &rest _) (push params queries))))
      (funcall (funcall (emacs-cpp-go--symbol-request '(server) nil t) #'ignore) "")
      (funcall (funcall (emacs-cpp-go--symbol-request '(server) '(("file:///p/" . "file:///p/")))
                        #'ignore)
               ""))
    (should (equal queries '((:query ""))))))

(ert-deftest init-go-to-anything-symbol-sources ()
  "D-082, D-106, D-118: per server an `s' source with the project's symbols, as
Project Symbol, and a hidden `l' source with all, under the server's heading, the
current buffer's server first; the narrow keys shared, one entry each; no root,
`s' only, as Symbol."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  (require 'consult-eglot)
  (cl-letf (((symbol-function 'consult-eglot--servers) (lambda () (list 'pyright 'clangd)))
            ((symbol-function 'eglot-current-server) (lambda () 'clangd))
            ((symbol-function 'emacs-cpp-go--server-name) #'symbol-name))
    (let ((sources (emacs-cpp-go--symbol-sources "/project/")))
      (should (equal (mapcar (lambda (s) (plist-get s :name)) sources)
                     '("Project Symbol (clangd)" "Project Symbol (pyright)"
                       "All Symbols (clangd)" "All Symbols (pyright)")))
      (should (equal (mapcar (lambda (s) (plist-get s :hidden)) sources) '(nil nil t t)))
      (should (equal (consult--multi-narrow sources)
                     '((?s . "Project Symbol") (?l . "All Symbols"))))
      (let ((consult--narrow ?s))
        (should (equal (mapcar #'consult--multi-visible-p sources) '(t t nil nil))))
      (let ((consult--narrow ?l))
        (should (equal (mapcar #'consult--multi-visible-p sources) '(nil nil t t))))
      (let ((consult--narrow nil))
        (should (equal (mapcar #'consult--multi-visible-p sources) '(t t nil nil)))))
    ;; Called from a buffer no server manages: eglot's order.
    (cl-letf (((symbol-function 'eglot-current-server) #'ignore))
      (should (equal (mapcar (lambda (s) (plist-get s :name))
                             (emacs-cpp-go--symbol-sources nil))
                     '("Symbol (pyright)" "Symbol (clangd)"))))))

(ert-deftest init-go-to-anything-symbol-source-asks-its-server ()
  "D-106: each server's source asks that server alone."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  (require 'consult-eglot)
  (let (asked)
    (cl-letf (((symbol-function 'consult-eglot--servers) (lambda () (list 'clangd 'pyright)))
              ((symbol-function 'eglot-current-server) #'ignore)
              ((symbol-function 'emacs-cpp-go--server-name) #'symbol-name)
              ((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
              ((symbol-function 'jsonrpc-async-request)
               (lambda (server &rest _) (push server asked))))
      (pcase-dolist (`(,source . ,server)
                     (cl-mapcar #'cons (emacs-cpp-go--symbol-sources nil) '(clangd pyright)))
        (setq asked nil)
        (let ((step (funcall (plist-get source :async) (lambda (_) nil)))
              (deadline (+ (float-time) 1.5)))
          (funcall step 'setup)
          (funcall step "vec")
          (while (and (null asked) (< (float-time) deadline))
            (accept-process-output nil 0.05))
          (funcall step 'destroy))
        (should (equal asked (list server)))))))

(ert-deftest init-go-to-anything-project-symbols ()
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
                            (cl-letf (((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
                                      ((symbol-function 'jsonrpc-async-request)
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

(ert-deftest init-go-to-anything-root-encoding-and-case ()
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

(ert-deftest init-go-to-anything-narrowing-drops-hidden-candidates ()
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

(ert-deftest init-go-to-anything-highlight-limit ()
  (init-test--load)
  (require 'consult)
  (pcase-let ((`(,_ . ,highlight)
               (funcall (emacs-cpp-go--highlight-first 2) "a" 'emacs t)))
    (let ((strings (list (copy-sequence "abc") (copy-sequence "bac") (copy-sequence "cab"))))
      (mapc highlight strings)
      (should (text-property-not-all 0 3 'face nil (nth 0 strings)))
      (should (text-property-not-all 0 3 'face nil (nth 1 strings)))
      (should-not (text-property-not-all 0 3 'face nil (nth 2 strings))))))

(defun init-go-to-anything-test--replies (make-step order)
  "Run the step MAKE-STEP returns for SINK on input \"vector\"; reply in ORDER.
Server `clangd' sends dealii::Vector (exact name, `score' 0.275) before
vector_n_rows_1d (0.55), as clangd 21.1.8 did on a toy (D-105); server `pyright'
sends one symbol without a `score'.  ORDER lists the servers in the order their
replies arrive.  Return the names of the last list the step sank."
  (let ((replies `((clangd . [(:name "Vector" :score 0.275) (:name "vector_n_rows_1d" :score 0.55)])
                   (pyright . [(:name "vector_norm")])))
        pending shown)
    (cl-letf (((symbol-function 'emacs-cpp-lsp-symbol-params) #'ignore)
              ((symbol-function 'jsonrpc-async-request)
               (lambda (server _method _params &rest args)
                 (push (cons server (plist-get args :success-fn)) pending))))
      (funcall (funcall make-step (lambda (action) (when (consp action) (setq shown action)) nil))
               "vector")
      (dolist (server order)
        (funcall (alist-get server pending) (alist-get server replies))))
    (mapcar (lambda (symbol) (plist-get symbol :name)) shown)))

(ert-deftest init-go-to-anything-symbols-in-server-order ()
  "D-105: each server's reply in the order it was sent, not re-sorted by its
`score'; a second server's reply follows the first one's."
  (init-test--load)
  (require 'consult)
  (let ((step (lambda (sink)
                (funcall (emacs-cpp-go--symbol-request '(clangd pyright)) sink))))
    (should (equal (init-go-to-anything-test--replies step '(clangd pyright))
                   '("Vector" "vector_n_rows_1d" "vector_norm")))
    (should (equal (init-go-to-anything-test--replies step '(pyright clangd))
                   '("vector_norm" "Vector" "vector_n_rows_1d")))))

(ert-deftest init-go-to-anything-consult-eglot-server-order ()
  "consult-eglot patch 0001 (D-105): `C-c l s' keeps each reply's order too."
  (init-test--load)
  (require 'consult)
  (require 'eglot)
  (require 'consult-eglot)
  (should consult-eglot-sort-results)   ; so its prompt passes `:sort' nil
  (let ((step (lambda (sink)
                (funcall (consult-eglot--make-async-source '(clangd pyright)) sink))))
    (should (equal (init-go-to-anything-test--replies step '(clangd pyright))
                   '("Vector" "vector_n_rows_1d" "vector_norm")))))

(ert-deftest init-go-to-anything-ignores-case ()
  "D-105, D-120: inside the prompt, `readme' finds README.md through consult's
filter of the static sources; outside it too, since D-120 ignores case everywhere."
  (init-test--load)
  (require 'consult)
  (let ((filter (lambda ()
                  (let (shown)
                    (funcall (funcall (consult--async-static '("README.md" "src/a.cc"))
                                      (lambda (action) (when (consp action) (setq shown action)) nil))
                             "readme")
                    (mapcar #'substring-no-properties shown))))
        inside)
    (init-go-to-anything-test--with-project
      (cl-letf (((symbol-function 'consult--multi)
                 (lambda (&rest _) (setq inside (funcall filter)) nil)))
        (emacs-cpp-go-to-anything)))
    (should (equal inside '("README.md")))
    (should (equal (funcall filter) '("README.md")))))

(ert-deftest init-go-to-anything-letters-in-order ()
  "D-120: the static sources match as every prompt does: `eto' finds Vector.cc,
`vt' VectorTools.cc."
  (init-test--load)
  (require 'consult)
  (let ((filter (lambda (input)
                  (let (shown)
                    (funcall (funcall (consult--async-static
                                       '("Vector.cc" "VectorTools.cc" "README.md"))
                                      (lambda (action)
                                        (when (consp action) (setq shown action))
                                        nil))
                             input)
                    (mapcar #'substring-no-properties shown))))
        inside)
    (init-go-to-anything-test--with-project
      (cl-letf (((symbol-function 'consult--multi)
                 (lambda (&rest _)
                   (setq inside (list (funcall filter "eto") (funcall filter "vt")))
                   nil)))
        (emacs-cpp-go-to-anything)))
    (should (member "Vector.cc" (nth 0 inside)))
    (should (member "VectorTools.cc" (nth 1 inside)))))

(ert-deftest init-go-to-anything-file-names ()
  "D-141: inside `M-o' a word matches the file name, as CLion's Go to File, and
gaps stay inside a word; a word with `/' searches the directories too.  The
owner's report: `ect' matched ~/sourc_e_/repos/.../in_c_lude/rmo/gpe/me_t_ric.h."
  (init-test--load)
  (require 'consult)
  (let* ((path "~/source/repos/RMO-gross-pitaevskii/include/rmo/gpe/metric.h")
         (candidates (list path "include/rmo/gpe/metric.h" "src/vector.cc" "*scratch*"))
         (filter (lambda (input)
                   (let (shown)
                     (funcall (funcall (consult--async-static candidates)
                                       (lambda (action)
                                         (when (consp action) (setq shown action))
                                         nil))
                              input)
                     (mapcar #'substring-no-properties shown))))
         inside)
    (init-go-to-anything-test--with-project
      (cl-letf (((symbol-function 'consult--multi)
                 (lambda (&rest _)
                   (setq inside (mapcar (lambda (input) (cons input (funcall filter input)))
                                        '("ect" "metric" "met" "gpe" "gpe/met" "rmo/gpe/"
                                          "include/" "vec" "scr")))
                   nil)))
        (emacs-cpp-go-to-anything)))
    ;; vector.cc has `ect' unbroken; the paths have it only spread over words.
    (should (equal (alist-get "ect" inside nil nil #'equal) '("src/vector.cc")))
    (should-not (alist-get "gpe" inside nil nil #'equal))
    (dolist (input '("metric" "met" "gpe/met" "rmo/gpe/" "include/"))
      (should (equal (list input (alist-get input inside nil nil #'equal))
                     (list input (list path "include/rmo/gpe/metric.h")))))
    (should (equal (alist-get "vec" inside nil nil #'equal) '("src/vector.cc")))
    (should (equal (alist-get "scr" inside nil nil #'equal) '("*scratch*")))
    ;; The name's letters are highlighted, not the directories'.
    (pcase-let ((`(,_ . ,highlight) (funcall (emacs-cpp-go--highlight-first 10) "met" 'emacs t)))
      (let ((shown (funcall highlight (copy-sequence path))))
        (should-not (text-property-not-all 0 (string-search "metric" shown) 'face nil shown))
        (should (get-text-property (string-search "metric" shown) 'face shown))))))

(ert-deftest init-go-to-anything-gaps-inside-a-word ()
  "D-141: every orderless prompt (`C-x b', `M-x', `C-c p f') keeps a match's gaps
inside a word: `ect' no longer spans the path's words, `eto' still finds Vector.cc."
  (init-test--load)
  (let ((files '("~/source/repos/RMO-gross-pitaevskii/include/rmo/gpe/metric.h"
                 "Vector.cc" "selector.h")))
    (let ((found (completion-all-completions "ect" files nil 3)))
      (setcdr (last found) nil)          ; drop the base size ending the list
      (should (equal (sort (mapcar #'substring-no-properties found) #'string<)
                     '("Vector.cc" "selector.h"))))
    (should (member "Vector.cc" (completion-all-completions "eto" files nil 3)))))

(ert-deftest init-go-to-anything-sort-by-source-and-tier ()
  "D-120: `M-o' sorts by tier within each source, the sources in their order;
symbols keep their server's order."
  (init-test--load)
  (require 'consult)
  (let* ((file (lambda (name) (let ((c (consult--tofu-append name 0)))
                                (put-text-property 0 1 'multi-category (cons 'file name) c)
                                c)))
         (symbol (lambda (name) (let ((c (consult--tofu-append name 1)))
                                  (put-text-property 0 1 'multi-category
                                                     (cons 'consult-eglot-symbols name) c)
                                  c)))
         (candidates (list (funcall symbol "TangentVector") (funcall file "Vector.cc")
                           (funcall symbol "eto") (funcall file "eto.h")
                           (funcall file "veto.h"))))
    (with-temp-buffer
      (insert "eto")
      (cl-letf (((symbol-function 'minibuffer-prompt-end) #'point-min))
        (should (equal (mapcar #'consult--tofu-strip (emacs-cpp-go--sort candidates))
                       '("eto.h" "veto.h" "Vector.cc" "TangentVector" "eto")))))))

(provide 'init-go-to-anything-test)
;;; init-go-to-anything-test.el ends here
