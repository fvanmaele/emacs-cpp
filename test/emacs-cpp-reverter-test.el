;;; emacs-cpp-reverter-test.el --- project buffers follow their files  -*- lexical-binding: t; -*-

;;; Commentary:

;; The reverter (T-128, D-153, D-156, D-161 - D-163) in the shipped profile: which
;; roots it watches, the real patched fswatch reverting a checkout's buffers (edited
;; and deleted files' buffers kept and named), one fswatch per root gone with its
;; last buffer, the filter only queuing and timer steps reverting within a budget
;; (D-167), no step inside another, an overflow checking every buffer, and the
;; option, globally and per project; an edited buffer whose file changed asked as
;; CLion asks (D-191).  Needs git and the patched fswatch.

;;; Code:

(require 'ert)
(require 'init-test)

(defvar emacs-cpp-reverter-test--env
  '("GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@t" "GIT_COMMITTER_NAME=t" "GIT_COMMITTER_EMAIL=t@t"))

(defun emacs-cpp-reverter-test--wait (predicate &optional seconds)
  "Wait up to SECONDS (default 5) for PREDICATE; return its value."
  (let ((deadline (+ (float-time) (or seconds 5))) value)
    (while (and (not (setq value (funcall predicate))) (< (float-time) deadline))
      (accept-process-output nil 0.05))
    value))

(defun emacs-cpp-reverter-test--git (root &rest args)
  (let ((process-environment (append emacs-cpp-reverter-test--env process-environment)))
    (with-temp-buffer
      (unless (eql 0 (apply #'call-process "git" nil t nil "-C" root args))
        (error "git %S: %s" args (buffer-string))))))

(defun emacs-cpp-reverter-test--dir (&optional marker)
  "Return a new temporary directory (true name, slash); MARKER: `git', a file name."
  (let ((dir (file-name-as-directory (file-truename (make-temp-file "emacs-cpp-reverter" t)))))
    (pcase marker
      ('git (emacs-cpp-reverter-test--git dir "init" "-q" "-b" "a"))
      ((pred stringp) (write-region "" nil (expand-file-name marker dir))))
    dir))

(defun emacs-cpp-reverter-test--text (buffer)
  (with-current-buffer buffer (buffer-string)))

(defmacro emacs-cpp-reverter-test--cleanup (dirs &rest body)
  "Run BODY; then kill the buffers it visited, stop the reverter, delete DIRS."
  (declare (indent 1))
  `(let ((before (buffer-list)))
     (unwind-protect (progn ,@body)
       (dolist (buffer (buffer-list))
         ;; Killing a root's last buffer stops its fswatch, whose sentinel kills
         ;; its stderr buffer.
         (unless (or (memq buffer before) (not (buffer-live-p buffer)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (let ((kill-buffer-query-functions nil))
             (kill-buffer buffer))))
       (customize-set-variable 'emacs-cpp-revert-project-buffers t)
       (dolist (root (hash-table-keys emacs-cpp-reverter--roots))
         (emacs-cpp-reverter--stop root))
       (dolist (dir ,dirs) (delete-directory dir t)))))

(ert-deftest emacs-cpp-reverter-roots ()
  "D-163 (a): a root under version control or with a .projectile file; a directory
projectile takes for a project by another marker (a Makefile) has none."
  (init-test--load)
  (let ((git (emacs-cpp-reverter-test--dir 'git))
        (projectile (emacs-cpp-reverter-test--dir ".projectile"))
        (makefile (emacs-cpp-reverter-test--dir "Makefile")))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "src" git))
          (should (equal (emacs-cpp-reverter-root (expand-file-name "src" git)) git))
          (should (equal (emacs-cpp-reverter-root projectile) projectile))
          (should-not (emacs-cpp-reverter-root makefile)))
      (dolist (dir (list git projectile makefile)) (delete-directory dir t)))))

(ert-deftest emacs-cpp-reverter-checkout ()
  "D-153, D-151 (2b), D-152: after a checkout the real fswatch reverts the root's
unedited buffers; an edited buffer and a deleted file's buffer are kept and named
in one message; an unchanged file's buffer is left; one fswatch for the root, gone
with its last buffer; auto-revert leaves the root's buffers to the reverter."
  (init-test--load)
  (let* ((root (emacs-cpp-reverter-test--dir 'git))
         (file (lambda (name) (expand-file-name name root)))
         reverted messages
         (record (lambda () (push (current-buffer) reverted))))
    (emacs-cpp-reverter-test--cleanup (list root)
      (dolist (name '("x.h" "y.h" "z.h" "w.h"))
        (write-region (format "// a %s\n" name) nil (funcall file name)))
      (emacs-cpp-reverter-test--git root "add" ".")
      (emacs-cpp-reverter-test--git root "commit" "-qm" "a")
      (emacs-cpp-reverter-test--git root "checkout" "-qb" "b")
      (write-region "// b x.h\n" nil (funcall file "x.h"))
      (write-region "// b y.h\n" nil (funcall file "y.h"))
      (emacs-cpp-reverter-test--git root "rm" "-q" "z.h")
      (emacs-cpp-reverter-test--git root "commit" "-qam" "b")
      (emacs-cpp-reverter-test--git root "checkout" "-q" "a")
      (let ((buffers (mapcar (lambda (name) (find-file-noselect (funcall file name)))
                             '("x.h" "y.h" "z.h" "w.h"))))
        (pcase-let ((`(,x ,y ,z ,w) buffers))
          (dolist (buffer buffers)
            (should (equal (buffer-local-value 'emacs-cpp-reverter--root buffer) root))
            (should (emacs-cpp-reverter-covers-p buffer)))
          (should (= 1 (length (emacs-cpp-reverter-processes))))
          (with-current-buffer y (goto-char (point-max)) (insert "// mine\n"))
          (add-hook 'after-revert-hook record)
          (unwind-protect
              (cl-letf* ((original (symbol-function 'message))
                         ((symbol-function 'message)
                          (lambda (format-string &rest args)
                            (when (stringp format-string)
                              (push (apply #'format format-string args) messages))
                            (apply original format-string args))))
                ;; fswatch sets up its watches after it starts.
                (accept-process-output nil 0.5)
                (emacs-cpp-reverter-test--git root "checkout" "-q" "b")
                (should (emacs-cpp-reverter-test--wait
                         (lambda () (equal (emacs-cpp-reverter-test--text x) "// b x.h\n"))))
                (accept-process-output nil 0.3))
            (remove-hook 'after-revert-hook record))
          (should (equal (emacs-cpp-reverter-test--text y) "// a y.h\n// mine\n"))
          (should (buffer-modified-p y))
          (should (buffer-live-p z))
          (should (equal (emacs-cpp-reverter-test--text z) "// a z.h\n"))
          (should-not (memq w reverted))
          (should-not (memq y reverted))
          ;; One message per filter call; fswatch may hand the two over in two.
          (should (seq-some (lambda (text)
                              (string-match-p "1 buffer with unsaved edits changed on disk: y.h" text))
                            messages))
          (should (seq-some (lambda (text)
                              (string-match-p "1 buffer's file deleted on disk: z.h" text))
                            messages))
          ;; The root's last buffer gone, its fswatch with it.
          (let ((processes (emacs-cpp-reverter-processes)))
            (dolist (buffer buffers)
              (with-current-buffer buffer (set-buffer-modified-p nil))
              (kill-buffer buffer))
            (should-not (emacs-cpp-reverter-processes))
            (should-not (seq-some #'process-live-p processes))))))))

(defun emacs-cpp-reverter-test--armed ()
  "Non-nil if a look for a question is armed; cancel it (the test calls it)."
  (when emacs-cpp-reverter--ask-timer
    (cancel-timer emacs-cpp-reverter--ask-timer)
    (setq emacs-cpp-reverter--ask-timer nil)
    t))

(ert-deftest emacs-cpp-reverter-ask ()
  "D-191: an edited buffer whose file changed is asked load / keep / diff when the
focused frame shows it: after an idle pause, when shown, when the frame regains
focus; never while the minibuffer is active; keep is not asked again until the
file changes again; the message names only buffers not about to be asked."
  (init-test--load)
  (let* ((root (emacs-cpp-reverter-test--dir ".projectile"))
         (file (expand-file-name "a.h" root))
         (other (get-buffer-create "*emacs-cpp-reverter-test other*"))
         (focused t) (minibuffer nil) asked answer diffed messages)
    (emacs-cpp-reverter-test--cleanup (list root)
      (write-region "disk 1\n" nil file)
      (let ((buffer (find-file-noselect file))
            (change (lambda (text)
                      ;; Another program: Emacs's own `write-region' onto a file an
                      ;; edited buffer visits asks about the conflict itself.  A later
                      ;; modification time than the last one Emacs saw.
                      (sleep-for 0.02)
                      (should (eql 0 (call-process "sh" nil nil nil "-c"
                                                   "printf '%s' \"$1\" > \"$2\""
                                                   "sh" text file))))))
        (set-window-buffer (selected-window) buffer)
        (with-current-buffer buffer (goto-char (point-max)) (insert "mine\n"))
        (cl-letf* (((symbol-function 'frame-focus-state) (lambda (&rest _) focused))
                   ((symbol-function 'active-minibuffer-window) (lambda () minibuffer))
                   ((symbol-function 'read-multiple-choice)
                    (lambda (prompt choices &rest _)
                      (push prompt asked)
                      (assq answer choices)))
                   ((symbol-function 'ediff-current-file)
                    (lambda () (setq diffed (current-buffer))))
                   (original (symbol-function 'message))
                   ((symbol-function 'message)
                    (lambda (format-string &rest args)
                      (when (stringp format-string)
                        (push (apply #'format format-string args) messages))
                      (apply original format-string args))))
          (accept-process-output nil 0.5)  ; fswatch's watches
          ;; Shown in the focused frame: a question after an idle pause; no message.
          (funcall change "disk 2\n")
          (should (emacs-cpp-reverter-test--wait
                   (lambda () (memq buffer emacs-cpp-reverter--conflicts))))
          (should (emacs-cpp-reverter-test--armed))
          (accept-process-output nil 0.3)
          (should-not (seq-some (lambda (text) (string-search "a.h" text)) messages))
          ;; The minibuffer active: not asked; its exit arms the look again.
          (setq minibuffer t)
          (emacs-cpp-reverter--ask)
          (should-not asked)
          (setq minibuffer nil)
          (emacs-cpp-reverter--on-minibuffer-exit)
          (should (emacs-cpp-reverter-test--armed))
          ;; Keep: the edits stay, the same change is not asked again.
          (setq answer ?k)
          (emacs-cpp-reverter--ask)
          (should (equal asked '("a.h changed on disk; you have unsaved edits")))
          (should (equal (emacs-cpp-reverter-test--text buffer) "disk 1\nmine\n"))
          (should (buffer-modified-p buffer))
          (should-not emacs-cpp-reverter--conflicts)
          (emacs-cpp-reverter--conflict buffer)
          (should-not emacs-cpp-reverter--conflicts)
          ;; A second change after keep: asked again.  Hidden: no question yet and
          ;; the message names it; shown: asked; load: the disk's text.
          (set-window-buffer (selected-window) other)
          (setq messages nil)
          (funcall change "disk 3\n")
          (should (emacs-cpp-reverter-test--wait
                   (lambda () (memq buffer emacs-cpp-reverter--conflicts))))
          (should-not (emacs-cpp-reverter-test--armed))
          (should (emacs-cpp-reverter-test--wait
                   (lambda ()
                     (seq-some (lambda (text)
                                 (string-search "unsaved edits changed on disk: a.h" text))
                               messages))))
          (set-window-buffer (selected-window) buffer)
          (emacs-cpp-reverter--on-show (selected-frame))
          (should (emacs-cpp-reverter-test--armed))
          (setq answer ?l asked nil)
          (emacs-cpp-reverter--ask)
          (should (= 1 (length asked)))
          (should (equal (emacs-cpp-reverter-test--text buffer) "disk 3\n"))
          (should-not (buffer-modified-p buffer))
          ;; Edited again, changed again while the frame has no focus: asked when
          ;; it regains focus; diff: ediff, not asked again.
          (with-current-buffer buffer (goto-char (point-max)) (insert "mine\n"))
          (setq focused nil)
          (funcall change "disk 4\n")
          (should (emacs-cpp-reverter-test--wait
                   (lambda () (memq buffer emacs-cpp-reverter--conflicts))))
          (should-not (emacs-cpp-reverter-test--armed))
          (setq asked nil)
          (emacs-cpp-reverter--ask)
          (should-not asked)
          (setq focused t)
          (emacs-cpp-reverter--on-focus)
          (should (emacs-cpp-reverter-test--armed))
          (setq answer ?d)
          (emacs-cpp-reverter--ask)
          (should (= 1 (length asked)))
          (should (eq diffed buffer))
          (should (buffer-modified-p buffer))
          (should-not emacs-cpp-reverter--conflicts)
          (with-current-buffer buffer (set-buffer-modified-p nil)))
        (kill-buffer other)))))

(ert-deftest emacs-cpp-reverter-queue ()
  "D-153, D-156 (e): a reverted buffer shown in a window is refreshed from the
queue, whose step waits while another step runs; a hidden one stays stale until
shown."
  (init-test--load)
  (let* ((dir (emacs-cpp-reverter-test--dir))
         (shown-file (expand-file-name "shown.h" dir))
         (hidden-file (expand-file-name "hidden.h" dir))
         refreshed)
    (emacs-cpp-reverter-test--cleanup (list dir)
      (write-region "// 1\n" nil shown-file)
      (write-region "// 1\n" nil hidden-file)
      (let ((shown (find-file-noselect shown-file))
            (hidden (find-file-noselect hidden-file))
            (window (selected-window)))
        (set-window-buffer window shown)
        (advice-add 'vc-refresh-state :before
                    (lambda () (push (current-buffer) refreshed))
                    '((name . emacs-cpp-reverter-test)))
        (unwind-protect
            (progn
              (dolist (buffer (list shown hidden))
                (with-current-buffer buffer (setq emacs-cpp-reverter--root dir)))
              (write-region "// 2\n" nil shown-file)
              (write-region "// 2\n" nil hidden-file)
              (dolist (file (list shown-file hidden-file))
                (set-file-times file (time-add nil 10)))
              (should (eq (emacs-cpp-reverter--revert shown) 'reverted))
              (should (eq (emacs-cpp-reverter--revert hidden) 'reverted))
              (should (memq shown emacs-cpp-reverter--queue))
              (should (buffer-local-value 'emacs-cpp-reverter--stale hidden))
              ;; (e): a step inside a running step refreshes nothing, arms again.
              (let ((emacs-cpp-reverter--busy t))
                (emacs-cpp-reverter--step))
              (should (memq shown emacs-cpp-reverter--queue))
              (should emacs-cpp-reverter--timer)
              (should-not refreshed)
              (should (emacs-cpp-reverter-test--wait
                       (lambda () (null emacs-cpp-reverter--queue))))
              (should (equal refreshed (list shown)))
              ;; The hidden buffer: refreshed once a window shows it.
              (set-window-buffer window hidden)
              (emacs-cpp-reverter--on-show (selected-frame))
              (should-not (buffer-local-value 'emacs-cpp-reverter--stale hidden))
              (should (equal refreshed (list hidden shown))))
          (advice-remove 'vc-refresh-state 'emacs-cpp-reverter-test))))))

(defun emacs-cpp-reverter-test--carrier (root real-root)
  "A process carrying ROOT's filter, as the real fswatch's, but writing nothing."
  (make-process :name "emacs-cpp-reverter-test carrier" :command '("sleep" "30")
                :noquery t :filter (emacs-cpp-reverter--filter root real-root)))

(ert-deftest emacs-cpp-reverter-steps ()
  "D-167: the filter only queues, a shown buffer first; a step reverts until the
budget is spent, one buffer at least, and never refreshes in the same step; the
next step refreshes the shown buffer before the remaining reverts (D-169); the
kept buffers are named once the revert queue is empty; a step inside a running
step reverts nothing (D-161 (p))."
  (init-test--load)
  (let* ((dir (emacs-cpp-reverter-test--dir))
         (files (mapcar (lambda (name) (expand-file-name name dir))
                        '("a.h" "b.h" "shown.h" "edited.h")))
         (carrier (emacs-cpp-reverter-test--carrier dir dir))
         refreshed messages)
    (emacs-cpp-reverter-test--cleanup (list dir)
      (unwind-protect
          (progn
            (dolist (file files) (write-region "// 1\n" nil file))
            (pcase-let* ((buffers (mapcar #'find-file-noselect files))
                         (`(,a ,b ,shown ,edited) buffers))
              (dolist (buffer buffers)
                (with-current-buffer buffer (setq emacs-cpp-reverter--root dir)))
              (set-window-buffer (selected-window) shown)
              (with-current-buffer edited (insert "// mine\n"))
              (dolist (file files)
                (write-region "// 2\n" nil file)
                (set-file-times file (time-add nil 10)))
              (cl-letf (((symbol-function 'emacs-cpp-reverter--refresh)
                         (lambda (buffer) (push buffer refreshed)))
                        ((symbol-function 'emacs-cpp-reverter--message)
                         (lambda (kept) (push kept messages))))
                (funcall (process-filter carrier) carrier
                         (mapconcat (lambda (file) (concat file " Updated,IsFile\0"))
                                    files ""))
                ;; Queued, not reverted; the shown buffer first.
                (should (equal (emacs-cpp-reverter-test--text a) "// 1\n"))
                (should (eq (car emacs-cpp-reverter--reverts) shown))
                (should (= 4 (length emacs-cpp-reverter--reverts)))
                (should emacs-cpp-reverter--timer)
                ;; Inside a running step: nothing reverted.
                (let ((emacs-cpp-reverter--busy t))
                  (emacs-cpp-reverter--step))
                (should (= 4 (length emacs-cpp-reverter--reverts)))
                ;; A spent budget still reverts one buffer per step, and the
                ;; step refreshes nothing though the shown buffer is queued.
                (let ((emacs-cpp-reverter-budget 0))
                  (emacs-cpp-reverter--step))
                (should (equal (emacs-cpp-reverter-test--text shown) "// 2\n"))
                (should (equal emacs-cpp-reverter--queue (list shown)))
                (should (= 3 (length emacs-cpp-reverter--reverts)))
                (should-not refreshed)
                (should-not messages)
                ;; D-169: the next step refreshes the shown buffer and reverts
                ;; nothing, though reverts are queued.
                (emacs-cpp-reverter--step)
                (should (equal refreshed (list shown)))
                (should-not emacs-cpp-reverter--queue)
                (should (= 3 (length emacs-cpp-reverter--reverts)))
                (should (equal (emacs-cpp-reverter-test--text a) "// 1\n"))
                (should emacs-cpp-reverter--timer)
                ;; The rest from the timer: reverts, then one message.
                (should (emacs-cpp-reverter-test--wait
                         (lambda () (and (null emacs-cpp-reverter--reverts)
                                         (null emacs-cpp-reverter--queue)))))
                (should (equal (emacs-cpp-reverter-test--text a) "// 2\n"))
                (should (equal (emacs-cpp-reverter-test--text b) "// 2\n"))
                (should (equal (emacs-cpp-reverter-test--text edited) "// mine\n// 1\n"))
                (should (equal messages (list (list (cons edited 'edited)))))
                (should (equal refreshed (list shown)))
                (should-not emacs-cpp-reverter--kept))))
        (delete-process carrier)))))

(ert-deftest emacs-cpp-reverter-overflow ()
  "An Overflow record warns and checks every buffer of the root against its file:
changes were lost."
  (init-test--load)
  (let* ((dir (emacs-cpp-reverter-test--dir))
         (file (expand-file-name "x.h" dir))
         (carrier (emacs-cpp-reverter-test--carrier dir dir))
         warned)
    (emacs-cpp-reverter-test--cleanup (list dir)
      (unwind-protect
          (cl-letf (((symbol-function 'display-warning)
                     (lambda (type text &rest _)
                       (should (eq type 'emacs-cpp))
                       (push text warned))))
            (write-region "// 1\n" nil file)
            (let ((buffer (find-file-noselect file)))
              (with-current-buffer buffer (setq emacs-cpp-reverter--root dir))
              (write-region "// 2\n" nil file)
              (set-file-times file (time-add nil 10))
              (funcall (process-filter carrier) carrier (concat dir " Overflow\0"))
              (should (emacs-cpp-reverter-test--wait
                       (lambda () (equal (emacs-cpp-reverter-test--text buffer) "// 2\n"))))
              (should (string-match-p "overflowed" (car warned)))))
        (delete-process carrier)))))

(ert-deftest emacs-cpp-reverter-option ()
  "D-163 (b): turned off from Customize, the fswatch stops and auto-revert reverts
the project's buffers; turned on, the fswatch starts again and auto-revert lets
go; a project whose .dir-locals.el turns it off gets no fswatch."
  (init-test--load)
  (let* ((root (emacs-cpp-reverter-test--dir 'git))
         (off (emacs-cpp-reverter-test--dir 'git))
         (file (expand-file-name "x.h" root))
         (off-file (expand-file-name "y.h" off))
         ;; Batch Emacs delivers no notifications: auto-revert polls here.
         (auto-revert-use-notify nil))
    (emacs-cpp-reverter-test--cleanup (list root off)
      (write-region "// 1\n" nil file)
      (let ((buffer (find-file-noselect file)))
        (should (= 1 (length (emacs-cpp-reverter-processes))))
        (customize-set-variable 'emacs-cpp-revert-project-buffers nil)
        (should-not (emacs-cpp-reverter-processes))
        (should-not (buffer-local-value 'emacs-cpp-reverter--root buffer))
        (should-not (emacs-cpp-reverter-covers-p buffer))
        (write-region "// 2\n" nil file)
        (set-file-times file (time-add nil 10))
        (auto-revert-buffers)
        (should (equal (emacs-cpp-reverter-test--text buffer) "// 2\n"))
        (customize-set-variable 'emacs-cpp-revert-project-buffers t)
        (should (= 1 (length (emacs-cpp-reverter-processes))))
        (should (equal (buffer-local-value 'emacs-cpp-reverter--root buffer) root))
        ;; auto-revert let go: a change it would see is left to the reverter.
        (write-region "// 3\n" nil file)
        (set-file-times file (time-add nil 20))
        (let (seen)
          (cl-letf (((symbol-function 'revert-buffer)
                     (lambda (&rest _) (push (current-buffer) seen))))
            (auto-revert-buffers))
          (should-not (memq buffer seen))))
      ;; Per project.
      (write-region "((nil . ((emacs-cpp-revert-project-buffers . nil))))\n" nil
                    (expand-file-name ".dir-locals.el" off))
      (write-region "// 1\n" nil off-file)
      (let ((buffer (find-file-noselect off-file)))
        (should-not (buffer-local-value 'emacs-cpp-reverter--root buffer))
        (should-not (emacs-cpp-reverter-covers-p buffer))
        (should-not (gethash off emacs-cpp-reverter--roots))))))

(ert-deftest emacs-cpp-reverter-diff-hl-hook ()
  "D-153: diff-hl still reverts its marks through `diff-hl-after-revert', the name
the reverter holds back."
  (init-test--load)
  (let ((dir (emacs-cpp-reverter-test--dir 'git)))
    (emacs-cpp-reverter-test--cleanup (list dir)
      (let ((file (expand-file-name "x.h" dir)))
        (write-region "// 1\n" nil file)
        ;; diff-hl turns on for a file under version control.
        (emacs-cpp-reverter-test--git dir "add" "x.h")
        (emacs-cpp-reverter-test--git dir "commit" "-qm" "x")
        (with-current-buffer (find-file-noselect file)
          (should diff-hl-mode)
          (should (memq 'diff-hl-after-revert after-revert-hook)))))))

(provide 'emacs-cpp-reverter-test)
;;; emacs-cpp-reverter-test.el ends here
