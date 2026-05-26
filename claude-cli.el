;;; claude-cli.el --- Launch Claude CLI in an Eat terminal -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniel Munoz

;; Author: Daniel Munoz
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (eat "0.9"))
;; Keywords: tools, terminals
;; URL: https://github.com/danielmunoz/emacs-claude-cli

;;; Commentary:

;; This package provides a convenient way to launch Claude Code CLI
;; inside an Eat terminal buffer.  Running `M-x claude-cli' splits the
;; frame vertically (side by side) and opens an Eat terminal running
;; the `claude' command in the current project's root directory.
;;
;; Usage:
;;
;;   M-x claude-cli             Start or switch to the Claude CLI session.
;;   M-x claude-cli-stop        Stop the running session and close its window.
;;   M-x claude-cli-clear       Clear the current conversation context.
;;   M-x claude-cli-send-buffer Send the entire current buffer to the session.
;;   M-x claude-cli-send-region Send the active region to the session.
;;   M-x claude-cli-send-escape Send a raw ESC to Claude (also bound to C-<escape>).
;;
;; Customization:
;;
;;   `claude-cli-program'     The executable to run (default: "claude").
;;   `claude-cli-args'        Extra arguments passed to Claude CLI.
;;   `claude-cli-buffer-name' The buffer name (default: "*claude-cli*").

;;; Code:

(require 'eat)
(require 'project)

(defgroup claude-cli nil
  "Launch Claude CLI in an Eat terminal."
  :group 'tools
  :prefix "claude-cli-")

(defcustom claude-cli-program "claude"
  "The command used to start Claude CLI."
  :type 'string
  :group 'claude-cli)

(defcustom claude-cli-args '()
  "Extra arguments passed to the Claude CLI executable.
Example: (setq claude-cli-args \\='(\"--dangerously-skip-permissions\"))"
  :type '(repeat string)
  :group 'claude-cli)

(defcustom claude-cli-buffer-name "*claude-cli*"
  "Name of the Claude CLI terminal buffer."
  :type 'string
  :group 'claude-cli)

(defun claude-cli--project-root ()
  "Return the root directory of the current project.
Falls back to `default-directory' if no project is found."
  (or (when-let ((project (project-current)))
        (project-root project))
      default-directory))

(defun claude-cli--buffer-name ()
  "Return a project-specific buffer name for Claude CLI."
  (format "%s<%s>" claude-cli-buffer-name
          (abbreviate-file-name (claude-cli--project-root))))

(defun claude-cli--evil-to-char-mode ()
  "Switch the eat terminal to char mode (input goes to Claude)."
  (when (and (derived-mode-p 'eat-mode) (fboundp 'eat-char-mode))
    (eat-char-mode)))

(defun claude-cli--evil-to-emacs-mode ()
  "Switch the eat terminal to emacs mode (free buffer navigation)."
  (when (and (derived-mode-p 'eat-mode) (fboundp 'eat-emacs-mode))
    (eat-emacs-mode)))

(define-minor-mode claude-cli-evil-sync-mode
  "Mirror evil state into the eat terminal input mode.
Insert state switches to `eat-char-mode' so keys are sent to Claude
with a terminal-managed cursor.  Normal, visual, and motion states
switch to `eat-emacs-mode' so the cursor moves freely with the shape
configured via `evil-normal-state-cursor' and friends."
  :lighter nil
  (if claude-cli-evil-sync-mode
      (progn
        (add-hook 'evil-insert-state-entry-hook
                  #'claude-cli--evil-to-char-mode nil t)
        (add-hook 'evil-normal-state-entry-hook
                  #'claude-cli--evil-to-emacs-mode nil t)
        (add-hook 'evil-visual-state-entry-hook
                  #'claude-cli--evil-to-emacs-mode nil t)
        (add-hook 'evil-motion-state-entry-hook
                  #'claude-cli--evil-to-emacs-mode nil t))
    (remove-hook 'evil-insert-state-entry-hook
                 #'claude-cli--evil-to-char-mode t)
    (remove-hook 'evil-normal-state-entry-hook
                 #'claude-cli--evil-to-emacs-mode t)
    (remove-hook 'evil-visual-state-entry-hook
                 #'claude-cli--evil-to-emacs-mode t)
    (remove-hook 'evil-motion-state-entry-hook
                 #'claude-cli--evil-to-emacs-mode t)))

;;;###autoload
(defun claude-cli ()
  "Start Claude CLI in an Eat terminal in a vertical split.

The terminal runs in the current project's root directory.  If a
Claude CLI session is already running for this project, switch to
its buffer instead of starting a new one."
  (interactive)
  (let* ((root (claude-cli--project-root))
         (default-directory root)
         (buf-name (claude-cli--buffer-name))
         (buf (get-buffer buf-name)))
    (cond
     ((and buf (get-buffer-process buf))
      (let ((win (get-buffer-window buf)))
        (if win
            (select-window win)
          (split-window-right)
          (other-window 1)
          (switch-to-buffer buf))))
     (t
      (when buf (kill-buffer buf))
      (split-window-right)
      (other-window 1)
      (let ((eat-buf (apply #'eat claude-cli-program claude-cli-args)))
        (with-current-buffer eat-buf
          ;; Inside Emacs, Claude Code's mouse tracking buys nothing —
          ;; all TUI interactions have keyboard equivalents.  Disabling it
          ;; lets click-drag text selection work normally for copying paths.
          (setq-local eat-enable-mouse nil)
          ;; Keep ESC for evil-mode (leave insert state) and bind
          ;; C-<escape> to send a raw ESC to Claude when needed.
          (when (and (featurep 'evil) (fboundp 'evil-local-set-key))
            (dolist (state '(insert normal visual motion))
              (evil-local-set-key state (kbd "C-<escape>")
                                  #'claude-cli-send-escape))
            (claude-cli-evil-sync-mode 1)
            (when (fboundp 'evil-insert-state)
              (evil-insert-state)))
          (rename-buffer buf-name t)))))))

(defun claude-cli--find-buffer ()
  "Find the Claude CLI buffer for the current project."
  (or (get-buffer (claude-cli--buffer-name))
      (seq-find (lambda (b)
                  (string-prefix-p claude-cli-buffer-name (buffer-name b)))
                (buffer-list))))

(defun claude-cli--send-string (text)
  "Send TEXT to the Claude CLI eat terminal using bracketed paste."
  (let* ((buf (claude-cli--find-buffer))
         (proc (and buf (get-buffer-process buf))))
    (unless (and proc (process-live-p proc))
      (user-error "No active Claude CLI session found"))
    (process-send-string proc (concat "\e[200~" text "\e[201~"))
    (when-let ((win (get-buffer-window buf)))
      (select-window win))))

;;;###autoload
(defun claude-cli-send-buffer ()
  "Send the entire current buffer content to the Claude CLI session."
  (interactive)
  (claude-cli--send-string
   (buffer-substring-no-properties (point-min) (point-max))))

;;;###autoload
(defun claude-cli-send-region (beg end)
  "Send the region between BEG and END to the Claude CLI session."
  (interactive "r")
  (claude-cli--send-string
   (buffer-substring-no-properties beg end)))

;;;###autoload
(defun claude-cli-send-escape ()
  "Send a raw ESC to the Claude CLI session.
Bound to C-<escape> in the Claude buffer so ESC can stay
reserved for `evil-mode' (leaving insert state)."
  (interactive)
  (let* ((buf (claude-cli--find-buffer))
         (proc (and buf (get-buffer-process buf))))
    (unless (and proc (process-live-p proc))
      (user-error "No active Claude CLI session found"))
    (process-send-string proc "\e")))

;;;###autoload
(defun claude-cli-clear ()
  "Clear the current Claude CLI conversation context."
  (interactive)
  (let* ((buf (claude-cli--find-buffer))
         (proc (and buf (get-buffer-process buf))))
    (unless (and proc (process-live-p proc))
      (user-error "No active Claude CLI session found"))
    (process-send-string proc "/clear\n")
    (when-let ((win (get-buffer-window buf)))
      (select-window win))))

;;;###autoload
(defun claude-cli-stop ()
  "Stop the running Claude CLI session and close its window.
Sends /exit to gracefully terminate the TUI, then falls back to
SIGINT and force-kill if needed."
  (interactive)
  (if-let ((buf (claude-cli--find-buffer)))
      (let ((proc (get-buffer-process buf))
            (win  (get-buffer-window buf)))
        (when (and proc (process-live-p proc))
          (process-send-string proc "/exit\n")
          (sit-for 1)
          (when (process-live-p proc)
            (interrupt-process proc)
            (sit-for 0.5)
            (when (process-live-p proc)
              (delete-process proc))))
        (when (and win (window-deletable-p win))
          (delete-window win))
        (let ((kill-buffer-query-functions nil))
          (kill-buffer buf)))
    (message "No active Claude CLI session found.")))

(provide 'claude-cli)
;;; claude-cli.el ends here
