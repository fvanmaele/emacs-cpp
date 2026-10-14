;;; init-go-to-anything.el --- One prompt for buffers, files and symbols  -*- lexical-binding: t; -*-

;;; Commentary:

;; CLion's "search everywhere" on `M-o' (D-074 .. D-078): one consult prompt over
;; buffers, recent files, bookmarks and the project's files from the first key, the
;; project's clangd symbols from the third (D-082); all symbols (`l'), commands
;; (`x') and known projects (`p') behind narrow keys.  Spike S11 measured it on RMO
;; and the deal.II tree: the settings bound in `emacs-cpp-go-to-anything' keep each
;; key under 25 ms on RMO (0049).
;;
;; Its own module since D-099: it uses the completion stack (init-completion),
;; projectile's files and projects (init-project) and the language servers' symbols
;; (init-lsp), so it loads after all three (DESIGN 5).

;;; Code:

(require 'init-completion)
(require 'init-project)
(require 'init-lsp)

(defun emacs-cpp-go--highlight-first (limit)
  "Return a consult regexp compiler that highlights only LIMIT strings per input.
Highlighting every hit of a one-letter input is most of the filter's time (S11);
with `:sort nil' the first hits are the ones on screen."
  (lambda (input type ignore-case)
    (pcase-let ((`(,regexps . ,highlight)
                 (consult--default-regexp-compiler input type ignore-case))
                (count 0))
      (cons regexps
            (and highlight
                 (lambda (string)
                   (setq count (1+ count))
                   (when (<= count limit)
                     (funcall highlight string))))))))

(defcustom emacs-cpp-go-symbol-limit 10000
  "Most symbols `M-o' asks clangd for per input before keeping the project's.
0: no limit.  clangd ranks without regard to where a symbol is defined, so a
reply that reaches the limit may lack project symbols ranked below library
ones; a message says so (D-083).  On the deal.II project step-1 the largest
reply of 47 three-letter inputs held 6673 symbols (49 ms); 5000 lost project
symbols there, 10000 none."
  :type 'natnum
  :group 'tools)

(defconst emacs-cpp-go--root-ignore-case (eq system-type 'darwin)
  "Non-nil: symbol URIs are compared with the root ignoring case (D-083).
macOS disks ignore case, so a project opened as TOY/ is clangd's toy/.")

(defun emacs-cpp-go--root-uris (root)
  "Return how the URI of a file under project ROOT begins, as (SAFE . FULL) pairs.
FULL is file:// and the root directory, unescaped: ROOT as projectile gives it
and its true name (clangd's URIs follow the compilation database, which may or
may not resolve symlinks).  SAFE is FULL up to its first character other than a
letter, digit or `- _ . /': every language server writes that part alike,
whatever it escapes after it (D-085)."
  (seq-uniq
   (mapcar (lambda (dir)
             (let ((full (concat "file://" (file-name-as-directory dir))))
               (cons (substring full 0 (or (string-match-p "[^A-Za-z0-9._/-]" full
                                                           (length "file://"))
                                           (length full)))
                     full)))
           (list (expand-file-name root) (file-truename root)))))

(defun emacs-cpp-go--under-root-p (symbol root-uris)
  "Non-nil when SYMBOL's file URI lies under one of ROOT-URIS (D-085).
Library URIs fail the cheap test against the safe prefix; only URIs that pass
are percent-decoded and compared with the whole root, so no table of how each
server escapes is needed."
  (let ((uri (plist-get (plist-get symbol :location) :uri))
        (case emacs-cpp-go--root-ignore-case)
        found)
    (dolist (root root-uris found)
      (when (and (not found) (string-prefix-p (car root) uri case))
        (setq found (string-prefix-p
                     (cdr root)
                     (if (string-search "%" uri)
                         (decode-coding-string (url-unhex-string uri) 'utf-8)
                       uri)
                     case))))))

(defun emacs-cpp-go--min-input (min empty)
  "Return an async step passing inputs of MIN characters or more, and with EMPTY
the empty input too, as `C-c l s' asks for it when its prompt opens (D-086).
Shorter inputs cancel: the list shown stays, as in `C-c l s'."
  (lambda (sink)
    (lambda (action)
      (funcall sink (if (and (stringp action)
                             (< (length action) min)
                             (not (and empty (equal action ""))))
                        'cancel
                      action)))))

(defun emacs-cpp-go--symbol-request (servers &optional root-uris empty)
  "Return an async step asking SERVERS for the workspace symbols of each input.
An empty input sends nothing (D-077) unless EMPTY: consult-eglot's own source
asks for \"\" when its prompt opens, which lists clangd's first 100 symbols;
`< l' does so when narrowed to (D-086), hidden it gets no input.  A reply to an input
that has since changed is dropped.  With ROOT-URIS, each request asks for up to
`emacs-cpp-go-symbol-limit' matches (D-083) and only symbols under one of
ROOT-URIS are kept (D-082): within clangd's usual 100, library symbols crowd the
project's out."
  (lambda (sink)
    (let (latest)
      (lambda (action)
        (when (and (stringp action) (or empty (not (equal action ""))))
          (let ((query action) (replies nil))
            (setq latest query)
            (dolist (server servers)
              (jsonrpc-async-request
               server :workspace/symbol
               (if root-uris
                   `(:query ,query :limit ,emacs-cpp-go-symbol-limit)
                 `(:query ,query))
               :success-fn
               (lambda (reply)
                 (when (equal query latest)
                   (when root-uris
                     (when (and (> emacs-cpp-go-symbol-limit 0)
                                (>= (length reply) emacs-cpp-go-symbol-limit))
                       (message "emacs-cpp: %S matched %d symbols or more, \
`emacs-cpp-go-symbol-limit'; project symbols may be missing: type more (D-083)"
                                query emacs-cpp-go-symbol-limit))
                     (setq reply (seq-filter (lambda (symbol)
                                               (emacs-cpp-go--under-root-p symbol root-uris))
                                             reply)))
                   (setq replies (sort (append replies reply nil)
                                       :key (lambda (symbol)
                                              (- (or (plist-get symbol :score) 0)))))
                   (funcall sink 'flush)
                   (funcall sink replies)))
               :error-fn
               (lambda (error)
                 (message "emacs-cpp: workspace/symbol %S failed: %S" query error))
               :timeout-fn
               (lambda ()
                 (message "emacs-cpp: workspace/symbol %S timed out" query))))))
        (funcall sink action)))))

(defun emacs-cpp-go--symbol-sources (root)
  "Return the clangd symbol sources for project ROOT, nil when no server has one.
`s': symbols defined under ROOT (D-082).  `l', hidden until narrowed: every
symbol of clangd's index, deal.II's and the standard library's too, clangd's
best 100 as `C-c l s' shows them, its first 100 for an empty input (D-086).
Without ROOT, `s' is the latter but asks nothing for an empty input."
  (when (featurep 'eglot)
    (require 'consult-eglot)
    (when-let* ((servers (consult-eglot--servers)))
      (if root
          (list (emacs-cpp-go--symbol-source "Symbol" ?s nil servers
                                             (emacs-cpp-go--root-uris root) nil)
                (emacs-cpp-go--symbol-source "All Symbols" ?l t servers nil t))
        (list (emacs-cpp-go--symbol-source "Symbol" ?s nil servers nil nil))))))

(defun emacs-cpp-go--symbol-source (name narrow hidden servers root-uris empty)
  "Return a symbol source NAME on key NARROW, HIDDEN or not, asking SERVERS.
ROOT-URIS and EMPTY as in `emacs-cpp-go--symbol-request'.  The candidates and
their preview come from consult-eglot."
  (list :name name :narrow narrow :hidden hidden :category 'consult-eglot-symbols
        :state (lambda ()
                 (let ((state (consult-eglot--state)))
                   (lambda (action candidate)
                     (funcall state action
                              (and candidate
                                   (get-text-property 0 'consult--candidate
                                                      candidate))))))
        :emacs-cpp-action (lambda (_) (run-hooks 'consult-after-jump-hook))
        :async (consult--async-pipeline
                (emacs-cpp-go--min-input 3 empty)
                ;; consult's own timing, as `C-c l s' (D-087): a request at most every
                ;; 0.5 s, once typing has paused for 0.2 s.
                (consult--async-throttle)
                (emacs-cpp-go--symbol-request servers root-uris empty)
                (consult--async-map #'consult-eglot--transformer))))

(defun emacs-cpp-go--file-source (root)
  "Return the source of ROOT's files, listed now, or nil when ROOT is nil.
Listed before the prompt opens: inside it consult computes a static source
under `while-no-input' and lists again when interrupted (S11 run 2)."
  (when root
    (list :name "Project File" :narrow ?f :category 'file :face 'consult-file
          :history 'file-name-history :state #'consult--file-state
          :items (mapcar (lambda (file) (cons file (concat root file)))
                         (projectile-project-files root)))))

(defun emacs-cpp-go--commands (buffer)
  "Return the names of the commands `M-x' offers in BUFFER."
  (let (names)
    (mapatoms (lambda (symbol)
                (when (and (commandp symbol)
                           (or (null read-extended-command-predicate)
                               (funcall read-extended-command-predicate symbol buffer)))
                  (push (symbol-name symbol) names))))
    names))

(defun emacs-cpp-go--sources (buffer root)
  "Return the sources of the go-to-anything prompt for BUFFER in project ROOT."
  (delq nil
        (append
         (list consult-source-buffer
               ;; consult's recent files narrow with `f', taken here by the project's.
               (append '(:name "Recent File" :narrow ?r) consult-source-recent-file)
               consult-source-bookmark
               (emacs-cpp-go--file-source root))
         (with-current-buffer buffer (emacs-cpp-go--symbol-sources root))
         (list (list :name "Command" :narrow ?x :hidden t :category 'command
                     :history 'extended-command-history
                     :items (lambda () (emacs-cpp-go--commands buffer))
                     :emacs-cpp-action (lambda (name) (command-execute (intern name) 'record)))
               (list :name "Project" :narrow ?p :hidden t :category 'file
                     :items #'projectile-relevant-known-projects
                     :emacs-cpp-action #'projectile-switch-project-by-name)))))

(defconst emacs-cpp-go--preview-key
  '(:debounce 0.3 any
    :debounce 0 "<up>" "<down>" "C-n" "C-p" "<next>" "<prior>" "C-v" "M-v")
  "When `M-o' previews the selected candidate (D-088).
After a typed key, once no other came for 0.3 s: the first preview of a file
type loads its mode (Org about 1.3 s on the Mac, O-41) and would hold the keys
typed meanwhile.  After a key moving through the list, at once.")

(defun emacs-cpp-go-to-anything ()
  "Go to a buffer, recent file, bookmark, project file or clangd symbol.
Symbols are the project's (D-082); every symbol, deal.II's and the standard
library's too (narrow with `l'), commands (`x') and known projects (`p') are
hidden until narrowed.  Narrow with `<' and the letter (b r m f s l x p), or the
letter and SPC; `<' first does not filter the files by the letter (D-079).
`< <' widens again.  Symbols need three characters and a running eglot server.  The settings of
D-077 hold only while the prompt is open; the command or project chosen runs
after it, with the usual ones."
  (interactive)
  (require 'consult)
  (let* ((buffer (current-buffer))
         (root (projectile-project-root))
         (selected
          ;; No collection while the files are listed or while typing (S11: 69 %
          ;; of a key's time; 6 collections at opening on 34583 files).
          (let ((gc-cons-threshold (* 64 1024 1024)))
            (let ((sources (emacs-cpp-go--sources buffer root))
                  (default-directory (or root default-directory))
                  (consult--regexp-compiler (emacs-cpp-go--highlight-first 100))
                  ;; clangd answers in under 25 ms; consult's 0.2 s was the wait.
                  (consult-async-refresh-delay 0.05)
                  ;; No `#' in front of the input (D-078).
                  (consult-async-split-style nil)
                  ;; Preview after a pause in typing, at once when browsing (D-088).
                  (consult-preview-key emacs-cpp-go--preview-key))
              (consult--multi sources :prompt "Go to: " :require-match t :sort nil)))))
    (when-let* ((action (plist-get (cdr selected) :emacs-cpp-action)))
      (funcall action (car selected)))))

(keymap-global-set "M-o" #'emacs-cpp-go-to-anything)

(provide 'init-go-to-anything)
;;; init-go-to-anything.el ends here
