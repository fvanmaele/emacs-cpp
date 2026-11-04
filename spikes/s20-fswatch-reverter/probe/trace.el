;;; trace.el --- loaded before s20-run.el: per-revert and filter-part times  -*- lexical-binding: t; -*-
;; Spike code, never promoted (S20, 0120).
(require 'cl-lib)
(defvar tr-out (getenv "TR_OUT"))
(defun tr-emit (fmt &rest args)
  (write-region (concat (apply #'format fmt args) "\n") nil tr-out t 'silent))
(defvar tr-reverts nil "(MS NAME RESULT) newest first.")
(defvar tr-sums (make-hash-table :test #'eq))
(defvar tr-counts (make-hash-table :test #'eq))
(defvar tr-in-handle nil)
(defun tr-add (key ms) (cl-incf (gethash key tr-sums 0.0) ms) (cl-incf (gethash key tr-counts 0)))
(defmacro tr-timed (key &rest body)
  `(let ((s (float-time))) (prog1 (progn ,@body) (tr-add ,key (* 1000 (- (float-time) s))))))
(advice-add 'emacs-cpp-reverter--revert :around
            (lambda (fn buffer)
              (let* ((g gcs-done) (ge gc-elapsed) (s (float-time)) (r (funcall fn buffer)))
                (push (list (* 1000 (- (float-time) s)) (buffer-name buffer) r
                            (format "gc %d, %.1f ms; shown %s" (- gcs-done g) (* 1000 (- gc-elapsed ge))
                                    (if (get-buffer-window buffer t) "yes" "no")))
                      tr-reverts)
                r)))
(advice-add 'emacs-cpp-reverter--handle :around
            (lambda (fn &rest args)
              (let ((tr-in-handle t)) (tr-timed 'handle (apply fn args)))))
(advice-add 'emacs-cpp-reverter--path :around
            (lambda (fn &rest args) (tr-timed 'path (apply fn args))))
(advice-add 'emacs-cpp-reverter--overflow-p :around
            (lambda (fn &rest args) (tr-timed 'overflow-p (apply fn args))))
(advice-add 'emacs-cpp-reverter--enqueue-revert :around
            (lambda (fn &rest args) (tr-timed 'enqueue-revert (apply fn args))))
(advice-add 'get-file-buffer :around
            (lambda (fn &rest args)
              (if tr-in-handle (tr-timed 'get-file-buffer (apply fn args)) (apply fn args))))
(advice-add 's20--checkout :around
            (lambda (fn branch &rest args)
              (setq tr-reverts nil) (clrhash tr-sums) (clrhash tr-counts)
              (prog1 (apply fn branch args)
                (tr-emit "checkout %s:" branch)
                (maphash (lambda (k v) (tr-emit "  %-15s %4d calls %7.2f ms" k (gethash k tr-counts) v)) tr-sums)
                (let ((sorted (sort (copy-sequence tr-reverts) (lambda (a b) (> (car a) (car b))))))
                  (tr-emit "  reverts %d, sum %.1f ms, median %.2f ms" (length sorted)
                           (apply #'+ (mapcar #'car sorted)) (car (nth (/ (length sorted) 2) sorted)))
                  (dolist (r (seq-take sorted 4)) (tr-emit "  slow: %6.2f ms %s %s %s" (nth 0 r) (nth 1 r) (nth 2 r) (nth 3 r)))))))
