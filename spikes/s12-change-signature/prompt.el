;;; prompt.el --- S12: ask for the new parameter list of "Change signature"  -*- lexical-binding: t; -*-
;; Spike code, never promoted.  Loaded by changesig.el; for the owner's hand check:
;;   M-x load-file RET spikes/s12-change-signature/prompt.el RET
;; then `C-c l a' on a function's name with the spike's clangd as
;; `emacs-cpp-clangd-program' (see RUN.md).
(require 'eglot)
(defvar s12-input nil "The answer to the new-parameter-list prompt, in batch.")

;; What a fresh patch's Emacs side would do: ask for the new list when the server's
;; command is the change-signature tweak, and send it as the command's "input".
(cl-defmethod eglot-execute :around (server action)
  (let ((args (plist-get action :arguments)))
    (if (and (equal (plist-get action :command) "clangd.applyTweak")
             (vectorp args) (> (length args) 0)
             (equal (plist-get (aref args 0) :tweakID) "ChangeSignature"))
        (let ((input (or s12-input (read-string "New parameter list: " "()"))))
          (cl-call-next-method
           server
           (plist-put (copy-sequence action) :arguments
                      (vector (plist-put (copy-sequence (aref args 0)) :input input)))))
      (cl-call-next-method))))

