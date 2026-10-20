;;; bench.el --- S17 run 4: lisp/'s hot paths, interpreted, bytecode, native  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-125, O-74).  Run by bench.sh:
;;   emacs -Q --batch -l bench.el STATE TREE DEALII RMO OUT
;; STATE: interp, byte or native; TREE: a copy holding init.el, lib/ and lisp/ (lisp/
;; with .elc for byte and native, .eln in the temporary HOME's cache for native).
;; Loads init.el's prelude and the modules measured, checks the form of
;; `emacs-cpp-match-tier', then times, median and best of 7 after a warm-up, GC
;; included (a prompt pays it too):
;;   B1 `emacs-cpp-match-sort-by-tier' over the set orderless lets through, for M-x's
;;      commands, deal.II's file names and RMO's, beside orderless's own filter time;
;;   B2 `emacs-cpp-go--under-root-p' over 10000 symbol replies (D-083's limit);
;;   B3 `indent-region' of deal.II's tria.cc in `c++-ts-mode' with the config's rules.

(require 'cl-lib)
(require 'benchmark)

(let* ((args command-line-args-left)
       (state (intern (nth 0 args)))
       (tree (file-name-as-directory (expand-file-name (nth 1 args))))
       (dealii (file-name-as-directory (expand-file-name (nth 2 args))))
       (rmo (file-name-as-directory (expand-file-name (nth 3 args))))
       (out (nth 4 args)))
  (setq command-line-args-left nil)
  (defvar emacs-cpp-root)
  (defvar use-package-always-defer)
  (defvar use-package-expand-minimally)
  (setq emacs-cpp-root tree)
  (load (expand-file-name "lib/load-path.el" tree) nil t)
  (load (expand-file-name "lib/autoloads.el" tree) nil t)
  (add-to-list 'load-path (expand-file-name "lisp" tree))
  (require 'use-package)
  (setq use-package-always-defer t use-package-expand-minimally t)
  (require (pcase system-type ('gnu/linux 'defaults-gnu-linux) ('darwin 'defaults-darwin)))
  (require 'init-completion)
  (require 'init-go-to-anything)
  (require 'init-cpp)
  (require 'orderless)
  (let ((say (lambda (fmt &rest a)
               (let ((line (apply #'format fmt a)))
                 (princ (concat line "\n"))
                 (write-region (concat line "\n") nil out t 'silent))))
        (form (lambda (f)
                (let ((d (symbol-function f)))
                  (cond ((native-comp-function-p d) 'native)
                        ((byte-code-function-p d) 'byte)
                        (t 'interpreted)))))
        (time (lambda (thunk)
                ;; Median and best wall ms of 7 runs after one warm-up, GC included.
                (funcall thunk)
                (let ((runs (sort (cl-loop repeat 7
                                           collect (* 1000 (car (benchmark-run 1
                                                                  (funcall thunk)))))
                                  #'<)))
                  (cons (nth 3 runs) (car runs))))))
    (funcall say "state %s: emacs-cpp-match-tier %s, emacs-cpp-go--under-root-p %s, \
emacs-cpp-indent--first-argument-p %s"
             state (funcall form 'emacs-cpp-match-tier)
             (funcall form 'emacs-cpp-go--under-root-p)
             (funcall form 'emacs-cpp-indent--first-argument-p))
    ;; B1: candidates as a prompt sorts them, after orderless's filter.
    (let* ((commands (let (l) (mapatoms (lambda (s) (when (commandp s) (push (symbol-name s) l)))) l))
           (names (lambda (dir) (let ((default-directory dir)) (process-lines "git" "ls-files"))))
           (sets `(("M-x" ,commands ("fin" "buf sw" "eglot" "cons gr"))
                   ("deal.II files" ,(funcall names dealii) ("vec" "tria" "fe q" "dofh"))
                   ("RMO files" ,(funcall names rmo) ("gpe" "main" "lac")))))
      (dolist (set sets)
        (pcase-let ((`(,label ,cands ,inputs) set))
          (dolist (input inputs)
            (let* ((orderless-matching-styles
                    '(orderless-literal orderless-regexp orderless-initialism orderless-flex))
                   (filt (funcall time (lambda () (orderless-filter input cands))))
                   (filtered (orderless-filter input cands))
                   (sort (funcall time (lambda ()
                                         (setq emacs-cpp--match-cache nil)
                                         (emacs-cpp-match-sort-by-tier
                                          input (copy-sequence filtered))))))
              (funcall say "B1 %-13s %-8s %6d of %6d: filter %7.1f ms, tier sort %7.1f ms (best %.1f)"
                       label (format "%S" input) (length filtered) (length cands)
                       (car filt) (car sort) (cdr sort)))))))
    ;; B2: 10000 replies, a third under the root, the rest a library's.
    (let* ((root rmo)
           (uris (emacs-cpp-go--root-uris root))
           (syms (cl-loop for i below 10000
                          collect (list :name (format "sym%d" i)
                                        :location
                                        (list :uri (if (zerop (% i 3))
                                                       (format "file://%ssrc/f%d.cc" root i)
                                                     (format "file:///usr/include/deal.II/x%%2B%d.h" i))))))
           (b2 (funcall time (lambda ()
                               (cl-count-if (lambda (s) (emacs-cpp-go--under-root-p s uris))
                                            syms)))))
      (funcall say "B2 under-root-p, 10000 symbols: %7.1f ms (best %.1f)" (car b2) (cdr b2)))
    ;; B3: indent the whole of tria.cc.
    (let ((file (expand-file-name "source/grid/tria.cc" dealii)))
      (with-temp-buffer
        (insert-file-contents file)
        (setq buffer-file-name nil)
        (c++-ts-mode)
        (emacs-cpp-indent-setup)
        (let* ((lines (count-lines (point-min) (point-max)))
               (b3 (let ((orig (buffer-string)))
                     (funcall time (lambda ()
                                     (erase-buffer) (insert orig)
                                     (indent-region (point-min) (point-max)))))))
          (funcall say "B3 indent-region tria.cc, %d lines: %7.0f ms (best %.0f)"
                   lines (car b3) (cdr b3)))))))
