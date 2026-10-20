;;; s16.el --- S16: D-120's tiers as a function, against the regexps  -*- lexical-binding: t; -*-

;; Spike code, never promoted (D-124).  Run (run.sh runs all three states):
;;   emacs -Q --batch -l spikes/s16-match-function/s16.el CORPUS-DIR STATE
;; CORPUS-DIR: a source tree whose files' relative names are the candidates (a git
;; checkout: `git ls-files'; otherwise every file).  STATE: interp, byte or native,
;; how both matchers are compiled before every check.  Prints one report.

(require 'cl-lib)
(require 'subr-x)

;;;; The candidate: option C of review 0084 section 3, with its casing fixed.

(defsubst s16-upper-p (c) (/= c (downcase c)))
(defsubst s16-lower-p (c) (/= c (upcase c)))
(defsubst s16-alnum-p (c) (or (<= ?0 c ?9) (/= (upcase c) (downcase c))))

(defun s16-word-start-p (s i)
  "Non-nil if index I of S starts a word, as D-120's regexps define it.
At the start or after a character that is no letter or digit; a capital after a
small letter or digit; a capital ending a run of capitals before a small letter."
  (or (= i 0)
      (let ((prev (aref s (1- i))) (this (aref s i)))
        (or (not (s16-alnum-p prev))
            (and (s16-upper-p this)
                 (or (s16-lower-p prev) (<= ?0 prev ?9)
                     (and (s16-upper-p prev)
                          (< (1+ i) (length s))
                          (s16-lower-p (aref s (1+ i))))))))))

(defun s16-word-tier (word candidate lower)
  "Tier of WORD (lower case) in CANDIDATE, LOWER its lower-case copy: 1, 2 or 3."
  (let ((from 0) hit)
    ;; Tier 1: WORD from a word start.  `string-search' runs in C; word starts are
    ;; tested on CANDIDATE, whose capitals LOWER has lost.
    (while (and (setq hit (string-search word lower from))
                (not (s16-word-start-p candidate hit)))
      (setq from (1+ hit)))
    (cond
     (hit 1)
     ((string-search word lower) 2)
     ;; Tier 2: WORD's letters each start a word, in order (leftmost is enough).
     ((let ((j 0) (n (length word)) (i 0) (m (length lower)))
        (while (and (< j n) (< i m))
          (when (and (= (aref lower i) (aref word j)) (s16-word-start-p candidate i))
            (setq j (1+ j)))
          (setq i (1+ i)))
        (= j n))
      2)
     (t 3))))

(defvar s16--cache nil "The last input and its lower-case words.")

(defun s16-match-tier (input candidate)
  "D-120's tier of CANDIDATE for INPUT; the worst word decides; 1 if none."
  (unless (equal (car s16--cache) input)
    (setq s16--cache (cons input (split-string (downcase input) " " t))))
  (let ((lower (downcase candidate)) (tier 1))
    (if (/= (length lower) (length candidate))
        ;; `downcase' changed the length (rare letters): no index is shared.
        (error "s16: downcase changes the length of %S" candidate)
      (dolist (word (cdr s16--cache) tier)
        (when (< tier 3)
          (setq tier (max tier (s16-word-tier word candidate lower))))))))

(defun s16-sort (input candidates)
  "CANDIDATES sorted stably by tier for INPUT, as `emacs-cpp-match-sort-by-tier'."
  (if (string-blank-p input)
      candidates
    (sort candidates :key (lambda (c) (s16-match-tier input c)))))

;;;; The baseline: the shipped definitions, read from lisp/init-completion.el.

(defconst s16-baseline-names
  '(emacs-cpp--match-class emacs-cpp--match-word-start emacs-cpp--match-compile
    emacs-cpp--match-cache emacs-cpp-match-tier emacs-cpp-match-sort-by-tier))

(defun s16-load-baseline (file)
  "Evaluate the matcher's forms from FILE; return how many."
  (let ((n 0))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (condition-case nil
          (while t
            (let ((form (read (current-buffer))))
              (when (and (memq (car-safe form) '(defun defvar))
                         (memq (cadr form) s16-baseline-names))
                (eval form t)
                (setq n (1+ n)))))
        (end-of-file nil)))
    n))

;;;; The report.

(defconst s16-spec
  ;; test/init-completion-test.el, init-completion-match-tiers (D-120), c031e2b.
  '(("vec" "Vector.cc" 1) ("vec" "src/vector.h" 1) ("ser" "HTTPServer" 1)
    ("tools" "VectorTools.cc" 1) ("ector" "Vector.cc" 2)
    ("vt" "VectorTools.cc" 2) ("VT" "VectorTools.cc" 2)
    ("eto" "Vector.cc" 3) ("vec eto" "Vector.cc" 3) ("" "Vector.cc" 1)
    ("vfoo" "ATVfoo" 1) ("tv" "ATVfoo" 2) ("s" "HTTPServer" 1)
    ("hs" "HTTPServer" 2) ("n" "max_n" 1)))

(defconst s16-sort-example
  '("eto" ("Vector.cc" "fetor.c" "eto.h" "veto.h" "Petrol.cc")
    ("eto.h" "fetor.c" "veto.h" "Vector.cc" "Petrol.cc")))

(defconst s16-inputs '("vec" "tria" "fe" "vt" "dofh" "fe q" "grid in" "sparsematrix"))

(defun s16-names (dir)
  "The relative names of DIR's files: `git ls-files' in a checkout."
  (let ((default-directory (file-name-as-directory (expand-file-name dir))))
    (if (file-directory-p ".git")
        (process-lines "git" "ls-files")
      (mapcar (lambda (f) (file-relative-name f default-directory))
              (directory-files-recursively default-directory "")))))

(defun s16-filter (input names)
  "NAMES with every word of INPUT's letters in order, ignoring case (orderless flex)."
  (let ((case-fold-search t)
        (regexps (mapcar (lambda (w) (mapconcat (lambda (c) (regexp-quote (string c)))
                                                w ".*"))
                         (split-string input " " t))))
    (cl-remove-if-not (lambda (n) (cl-every (lambda (r) (string-match-p r n)) regexps))
                      names)))

(defun s16-best-of (n thunk)
  "Best wall time in milliseconds of N runs of THUNK, after one warm-up."
  (funcall thunk)
  (let ((best most-positive-fixnum))
    (dotimes (_ n best)
      (garbage-collect)
      (setq best (min best (* 1000 (car (benchmark-run 1 (funcall thunk)))))))))

(defun s16-time-row (state names filtered)
  "Print one timing line per input for STATE."
  (dolist (input s16-inputs)
    (let ((all (gethash input names)) (some (gethash input filtered)))
      (princ (format "   %-9s %-13s %8.1f %8.1f %8.1f %8.1f  (%d filtered)\n"
                     state input
                     (s16-best-of 5 (lambda () (emacs-cpp-match-sort-by-tier input (copy-sequence all))))
                     (s16-best-of 5 (lambda () (s16-sort input (copy-sequence all))))
                     (s16-best-of 5 (lambda () (emacs-cpp-match-sort-by-tier input (copy-sequence some))))
                     (s16-best-of 5 (lambda () (s16-sort input (copy-sequence some))))
                     (length some))))))

(defun s16-compile (how)
  "Compile the baseline's and the candidate's functions by HOW, `byte' or `native'."
  (dolist (f (append '(emacs-cpp--match-class emacs-cpp--match-word-start
                       emacs-cpp--match-compile emacs-cpp-match-tier
                       emacs-cpp-match-sort-by-tier)
                     '(s16-upper-p s16-lower-p s16-alnum-p s16-word-start-p s16-word-tier
                       s16-match-tier s16-sort)))
    (if (eq how 'native) (native-compile f) (byte-compile f))))

(let* ((root (expand-file-name "../.." (file-name-directory load-file-name)))
       (corpus (or (pop command-line-args-left) (error "s16: name a corpus directory")))
       (state (or (pop command-line-args-left) "interp"))
       (n (s16-load-baseline (expand-file-name "lisp/init-completion.el" root)))
       (names (s16-names corpus))
       (failures 0) (disagree 0) (compared 0))
  (pcase state
    ("interp")
    ("byte" (s16-compile 'byte))
    ("native" (unless (native-comp-available-p) (error "s16: no native compiler"))
     (s16-compile 'native))
    (_ (error "s16: STATE is interp, byte or native, not %s" state)))
  (princ (format "S16 (%s): %s; %s; baseline: %d forms from lisp/init-completion.el\n"
                 state (car (split-string (emacs-version) "\n")) system-type n))
  (princ (format "corpus: %s, %d names\n" (file-name-nondirectory (directory-file-name corpus))
                 (length names)))
  ;; 1. The spec.
  (pcase-dolist (`(,input ,candidate ,tier) s16-spec)
    (let ((got (s16-match-tier input candidate)))
      (unless (eql got tier)
        (setq failures (1+ failures))
        (princ (format "  SPEC FAIL %S %S: want %d, got %S\n" input candidate tier got)))))
  (pcase-let* ((`(,input ,given ,want) s16-sort-example)
               (got (s16-sort input (copy-sequence given))))
    (unless (equal got want)
      (setq failures (1+ failures))
      (princ (format "  SORT FAIL: want %S, got %S\n" want got))))
  (princ (format "1. spec: %d rows and the sort example, %d failures\n"
                 (length s16-spec) failures))
  ;; 2. Agreement with the regexps on every name, filtered or not.
  (let ((by-tier (make-vector 4 0)))
    (dolist (input s16-inputs)
      (dolist (c names)
        (let ((a (emacs-cpp-match-tier input c)) (b (s16-match-tier input c)))
          (setq compared (1+ compared))
          (aset by-tier a (1+ (aref by-tier a)))
          (unless (eql a b)
            (setq disagree (1+ disagree))
            (when (<= disagree 20)
              (princ (format "  DISAGREE %S %S: regexps %d, function %d\n" input c a b)))))))
    (princ (format "2. agreement: %d pairs (%d inputs x %d names), %d disagree; regexp tiers 1/2/3: %d/%d/%d\n"
                   compared (length s16-inputs) (length names) disagree
                   (aref by-tier 1) (aref by-tier 2) (aref by-tier 3))))
  ;; 3. Speed: all names (review 0084's method) and the filtered ones (a prompt's).
  (let ((all (make-hash-table :test #'equal)) (filtered (make-hash-table :test #'equal)))
    (dolist (input s16-inputs)
      (puthash input names all)
      (puthash input (s16-filter input names) filtered))
    (princ "3. sort time, best of 5, ms: regexps / function on all names, then on the filtered\n")
    (princ (format "   %-9s %-13s %8s %8s %8s %8s\n" "state" "input" "rx-all" "fn-all" "rx-filt" "fn-filt"))
    (s16-time-row state all filtered)))
