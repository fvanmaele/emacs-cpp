;;; init-toolbar-test.el --- The icon tool bar  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-210, D-211, T-150, T-151): after startup the tool
;; bar is on and shows the configuration's buttons only; every button has its icon
;; file, a command that exists and a tooltip naming the key that runs it; the
;; debugger's buttons follow its state, read through `dape-active-mode' and a stub of
;; dape's `dape--live-connection' (no debug session in batch) without loading dape;
;; the icons take the theme's foreground or the colour set, also in the bar
;; tool-bar.el builds and caches, after Customize and on a daemon's first graphical
;; frame; Git status refuses outside a repository; a missing icon stops with an
;; error.  Batch Emacs draws no bar: how it looks is the owner's check (H-39).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defun init-toolbar-test--item (id)
  "Return the tool bar's menu item ID as (LABEL COMMAND . PROPERTIES)."
  (let ((binding (cdr (assq id (cdr (default-value 'tool-bar-map))))))
    (should (eq (car binding) 'menu-item))
    (cdr binding)))

(defvar dape-active-mode)

(defun init-toolbar-test--shown (session stopped)
  "Return (ID . ENABLED) of the buttons shown for a debugger state.
SESSION is `dape-active-mode', STOPPED what `dape--live-connection' answers for
`stopped'."
  (cl-letf (((symbol-function 'dape--live-connection)
             (lambda (type &rest _) (pcase type ('stopped stopped))))
            (dape-active-mode session))
    (cl-loop for (id) in emacs-cpp-toolbar-items
             for properties = (cddr (init-toolbar-test--item id))
             when (or (not (plist-member properties :visible))
                      (eval (plist-get properties :visible) t))
             collect (cons id (or (not (plist-member properties :enable))
                                  (and (eval (plist-get properties :enable) t) t))))))

(ert-deftest init-toolbar-on-after-startup ()
  "D-210: the tool bar is on after startup, with the configuration's buttons only,
in every buffer."
  (init-test--load)
  (should tool-bar-mode)
  (should tool-bar-always-show-default)
  (should (equal (cl-loop for binding in (cdr (default-value 'tool-bar-map))
                          collect (car binding))
                 (mapcar #'car emacs-cpp-toolbar-items)))
  (should (memq #'emacs-cpp-toolbar-refresh enable-theme-functions))
  (should (memq #'emacs-cpp-toolbar-refresh disable-theme-functions)))

(ert-deftest init-toolbar-items-have-icon-command-and-key ()
  "D-210: each button has its SVG, an existing command, and a tooltip naming the
key that runs the command."
  (init-test--load)
  (require 'dape)
  (should (file-readable-p (expand-file-name "LICENSE" emacs-cpp-toolbar-icon-directory)))
  (pcase-dolist (`(,id ,label ,command ,key ,icon ,_when ,note) emacs-cpp-toolbar-items)
    (ert-info ((symbol-name id))
      (pcase-let ((`(,item-label ,item-command . ,properties)
                   (init-toolbar-test--item id)))
        (should (equal item-label label))
        (should (eq item-command command))
        (should (commandp command))
        (should (equal (plist-get properties :help)
                       (format "%s (%s)%s" label key (if note (concat ": " note) ""))))
        ;; The button may wrap the key's command (D-211).
        (should (eq (keymap-lookup nil key)
                    (alist-get command '((emacs-cpp-toolbar-git-status . magit-status))
                               command)))
        (let ((image (plist-get properties :image)))
          (should (eq (plist-get (cdr image) :type) 'svg))
          (should (= (plist-get (cdr image) :width) emacs-cpp-toolbar-icon-size))
          (should (stringp (plist-get (cdr image) :foreground)))
          (should (file-equal-p (plist-get (cdr image) :file)
                                (expand-file-name (concat icon ".svg")
                                                  emacs-cpp-toolbar-icon-directory))))
        (should (file-readable-p (expand-file-name (concat icon ".svg")
                                                   emacs-cpp-toolbar-icon-directory)))))))

(ert-deftest init-toolbar-debug-buttons-follow-the-session ()
  "D-210, D-211: Debug shows while no session runs; in a session the steps and Stop
show, the steps greyed out unless the program is stopped, and Pause takes
Continue's place while it runs."
  (init-test--load)
  (let ((always '((sidebar . t) (go-to . t) (text . t) (git . t) (build . t))))
    (should (equal (init-toolbar-test--shown nil nil)
                   (append always '((debug . t)))))
    (should (equal (init-toolbar-test--shown t nil)
                   (append always '((pause . t) (step-over . nil) (step-in . nil)
                                    (step-out . nil) (stop . t)))))
    (should (equal (init-toolbar-test--shown t t)
                   (append always '((continue . t) (step-over . t) (step-in . t)
                                    (step-out . t) (stop . t)))))))

(ert-deftest init-toolbar-state-without-dape ()
  "D-210: the bar's state checks answer nil before dape loads, and do not load it."
  (init-test--load)
  (cl-letf (((symbol-function 'dape--live-connection) nil)
            (dape-active-mode nil))
    (should-not (emacs-cpp-toolbar--session-p))
    (should-not (emacs-cpp-toolbar--stopped-p))))

(ert-deftest init-toolbar-icon-colour ()
  "D-210: icons are drawn in `emacs-cpp-toolbar-icon-color' when set, else in the
theme's foreground; a refresh makes a new map with the new colour."
  (init-test--load)
  (let ((before (default-value 'tool-bar-map)))
    (unwind-protect
        (progn
          (let ((emacs-cpp-toolbar-icon-color "#123456"))
            (emacs-cpp-toolbar-refresh)
            (should-not (eq (default-value 'tool-bar-map) before))
            (should (equal (plist-get (cdr (plist-get (cddr (init-toolbar-test--item 'git))
                                                      :image))
                                      :foreground)
                           "#123456")))
          (cl-letf (((symbol-function 'face-foreground) (lambda (&rest _) "#abcdef")))
            (should (equal (emacs-cpp-toolbar--color (selected-frame)) "#abcdef"))
            ;; No graphical frame: a placeholder that Emacs can resolve, not the
            ;; terminal's "unspecified-fg".
            (should (equal (emacs-cpp-toolbar--color nil) "gray50"))))
      (emacs-cpp-toolbar-refresh))))

(defun init-toolbar-test--built-colour ()
  "Return the Git button's icon colour in the bar tool-bar.el builds and caches."
  (let ((item (cdr (assq 'git (cdr (tool-bar-make-keymap))))))
    (plist-get (cdr (plist-get (cdddr item) :image)) :foreground)))

(ert-deftest init-toolbar-built-bar-follows-refresh ()
  "D-211: after every refresh the bar tool-bar.el builds has the new colour, also
when a new map takes a collected map's address (its cache is keyed by address)."
  (init-test--load)
  (unwind-protect
      (dolist (colour '("#111111" "#222222" "#333333" "#444444" "#555555"))
        (let ((emacs-cpp-toolbar-icon-color colour))
          (emacs-cpp-toolbar-refresh)
          (should (equal (init-toolbar-test--built-colour) colour))
          (garbage-collect)))
    (emacs-cpp-toolbar-refresh)))

(ert-deftest init-toolbar-customize-redraws ()
  "D-211: setting the icon colour through Customize draws the bar again."
  (init-test--load)
  (let ((before emacs-cpp-toolbar-icon-color))
    (unwind-protect
        (progn
          (customize-set-variable 'emacs-cpp-toolbar-icon-color "#654321")
          (should (equal (init-toolbar-test--built-colour) "#654321")))
      (customize-set-variable 'emacs-cpp-toolbar-icon-color before))))

(ert-deftest init-toolbar-first-graphical-frame ()
  "D-211: without a graphical frame (a daemon) the macOS title area is left alone;
the first graphical frame draws the bar again in its theme's colour, later ones
do not."
  (init-test--load)
  (let ((default-frame-alist (assq-delete-all 'ns-appearance
                                              (copy-alist default-frame-alist)))
        (refreshes 0))
    (unwind-protect
        (progn
          (emacs-cpp-toolbar-refresh)
          (should-not emacs-cpp-toolbar--drawn-on-graphic)
          (should-not (assq 'ns-appearance default-frame-alist))
          (cl-letf* (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                     ((symbol-function 'face-foreground) (lambda (&rest _) "#abcdef"))
                     (refresh (symbol-function 'emacs-cpp-toolbar-refresh))
                     ((symbol-function 'emacs-cpp-toolbar-refresh)
                      (lambda (&rest args) (cl-incf refreshes) (apply refresh args))))
            (emacs-cpp-toolbar--frame-made (selected-frame))
            (should (equal (init-toolbar-test--built-colour) "#abcdef"))
            (emacs-cpp-toolbar--frame-made (selected-frame))
            (should (= refreshes 1))))
      (emacs-cpp-toolbar-refresh))))

(ert-deftest init-toolbar-title-follows-theme-opt-out ()
  "D-211: `emacs-cpp-toolbar-title-follows-theme' nil leaves `ns-appearance' alone."
  (init-test--load)
  (let ((default-frame-alist (assq-delete-all 'ns-appearance
                                              (copy-alist default-frame-alist))))
    (cl-letf (((symbol-function 'framep) (lambda (&rest _) 'ns))
              ((symbol-function 'set-frame-parameter) #'ignore)
              ((symbol-function 'face-background) (lambda (&rest _) "#000000")))
      (let ((emacs-cpp-toolbar-title-follows-theme nil))
        (emacs-cpp-toolbar--chrome-follows-theme (selected-frame))
        (should-not (assq 'ns-appearance default-frame-alist)))
      (emacs-cpp-toolbar--chrome-follows-theme (selected-frame))
      (should (eq (alist-get 'ns-appearance default-frame-alist) 'dark)))))

(ert-deftest init-toolbar-git-status-outside-repository ()
  "D-211: Git status outside a repository says so and never offers to create one;
inside one it runs `magit-status'."
  (init-test--load)
  ;; Loaded first: loading it later would put the real `magit-status' over the stub.
  (require 'magit)
  (let ((called nil))
    (cl-letf (((symbol-function 'magit-status)
               (lambda () (interactive) (setq called t))))
      (let ((default-directory (file-name-as-directory (make-temp-file "toolbar" t))))
        (unwind-protect
            (should (string-match-p "Not inside a git repository"
                                    (cadr (should-error (emacs-cpp-toolbar-git-status)
                                                        :type 'user-error))))
          (delete-directory default-directory t)))
      (should-not called)
      (let ((default-directory emacs-cpp-root))
        (emacs-cpp-toolbar-git-status))
      (should called))))

(ert-deftest init-toolbar-dape-stopped-type ()
  "D-211: dape's `dape--live-connection' still knows the TYPE `stopped' the bar
asks for; a renamed TYPE would answer nil and grey the steps out silently."
  (init-test--load)
  (require 'dape)
  (pcase-let ((`(,buffer . ,position) (find-function-noselect 'dape--live-connection)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char position)
        (let ((end (save-excursion (end-of-defun) (point))))
          (should (search-forward "('stopped " end t)))))))

(ert-deftest init-toolbar-setup-runs-last ()
  "D-211: the bar is set up last on `after-init-hook', after the theme."
  (init-test--load)
  (should (equal (car (last (default-value 'after-init-hook)))
                 #'emacs-cpp-toolbar-setup)))

(ert-deftest init-toolbar-dark-theme ()
  "D-210: the theme's background decides dark or light; unknown is not dark."
  (init-test--load)
  (cl-letf (((symbol-function 'face-background) (lambda (&rest _) "#000000")))
    (should (emacs-cpp-toolbar--dark-p)))
  (cl-letf (((symbol-function 'face-background) (lambda (&rest _) "#ffffff")))
    (should-not (emacs-cpp-toolbar--dark-p)))
  (cl-letf (((symbol-function 'face-background) (lambda (&rest _) "unspecified-bg")))
    (should-not (emacs-cpp-toolbar--dark-p))))

(ert-deftest init-toolbar-missing-icon-stops ()
  "D-210: an icon file that is missing stops with an error naming it."
  (init-test--load)
  (should (string-match-p
           "no-such-icon\\.svg is missing"
           (cadr (should-error (emacs-cpp-toolbar--image "no-such-icon" "#000000"))))))

(provide 'init-toolbar-test)
;;; init-toolbar-test.el ends here
