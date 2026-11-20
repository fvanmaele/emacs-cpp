;;; init-toolbar-test.el --- The icon tool bar  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests in the shipped profile (D-210, T-150): after startup the tool bar is on and
;; shows the configuration's buttons only; every button has its icon file, a command
;; that exists and a tooltip naming the key that runs it; the debugger's buttons
;; follow its state, read through a stub of dape's `dape--live-connection' (no debug
;; session in batch) and without loading dape; the icons take the theme's foreground
;; or the colour set; a missing icon stops with an error.  Batch Emacs draws no bar:
;; how it looks is the owner's check (H-39).

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'init-test)

(defun init-toolbar-test--item (id)
  "Return the tool bar's menu item ID as (LABEL COMMAND . PROPERTIES)."
  (let ((binding (cdr (assq id (cdr (default-value 'tool-bar-map))))))
    (should (eq (car binding) 'menu-item))
    (cdr binding)))

(defun init-toolbar-test--shown (session stopped)
  "Return (ID . ENABLED) of the buttons shown for a debugger state.
SESSION and STOPPED are what `dape--live-connection' answers for `parent' and
`stopped'."
  (cl-letf (((symbol-function 'dape--live-connection)
             (lambda (type &rest _) (pcase type ('parent session) ('stopped stopped)))))
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
  (pcase-dolist (`(,id ,label ,command ,key ,icon ,_when) emacs-cpp-toolbar-items)
    (ert-info ((symbol-name id))
      (pcase-let ((`(,item-label ,item-command . ,properties)
                   (init-toolbar-test--item id)))
        (should (equal item-label label))
        (should (eq item-command command))
        (should (commandp command))
        (should (equal (plist-get properties :help) (format "%s (%s)" label key)))
        (should (eq (keymap-lookup nil key) command))
        (let ((image (plist-get properties :image)))
          (should (eq (plist-get (cdr image) :type) 'svg))
          (should (= (plist-get (cdr image) :width) emacs-cpp-toolbar-icon-size))
          (should-not (string-search "currentColor" (plist-get (cdr image) :data))))
        (should (file-readable-p (expand-file-name (concat icon ".svg")
                                                   emacs-cpp-toolbar-icon-directory)))))))

(ert-deftest init-toolbar-debug-buttons-follow-the-session ()
  "D-210: Debug shows while no session runs; in a session the steps and Stop show,
the steps greyed out unless the program is stopped."
  (init-test--load)
  (let ((always '((sidebar . t) (go-to . t) (text . t) (git . t) (build . t))))
    (should (equal (init-toolbar-test--shown nil nil)
                   (append always '((debug . t)))))
    (should (equal (init-toolbar-test--shown t nil)
                   (append always '((continue . nil) (step-over . nil) (step-in . nil)
                                    (step-out . nil) (stop . t)))))
    (should (equal (init-toolbar-test--shown t t)
                   (append always '((continue . t) (step-over . t) (step-in . t)
                                    (step-out . t) (stop . t)))))))

(ert-deftest init-toolbar-state-without-dape ()
  "D-210: the bar's state checks answer nil while dape's function is undefined,
as before dape loads, and do not load it."
  (init-test--load)
  (cl-letf (((symbol-function 'dape--live-connection) nil))
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
            (should (string-search
                     "#123456"
                     (plist-get (cdr (plist-get (cddr (init-toolbar-test--item 'git))
                                                :image))
                                :data))))
          (cl-letf (((symbol-function 'face-foreground) (lambda (&rest _) "#abcdef")))
            (should (equal (emacs-cpp-toolbar--color) "#abcdef"))))
      (emacs-cpp-toolbar-refresh))))

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
