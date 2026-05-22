;;; copilot-cli.el --- Launch Copilot CLI in an Eat terminal -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniel Munoz

;; Author: Daniel Munoz
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (eat "0.9"))
;; Keywords: tools, terminals
;; URL: https://github.com/danielmunoz/emacs-copilot-cli

;;; Commentary:

;; This package provides a convenient way to launch GitHub Copilot CLI
;; inside an Eat terminal buffer.  Running `M-x copilot-cli' splits the
;; frame vertically (side by side) and opens an Eat terminal running
;; the `copilot-cli' command in the current project's root directory.
;;
;; Usage:
;;
;;   M-x copilot-cli      Start or switch to the Copilot CLI session.
;;   M-x copilot-cli-stop Stop the running session and close its window.
;;
;; Customization:
;;
;;   `copilot-cli-program'     The executable to run (default: "copilot-cli").
;;   `copilot-cli-buffer-name' The buffer name (default: "*copilot-cli*").

;;; Code:

(require 'eat)
(require 'project)

(defgroup copilot-cli nil
  "Launch Copilot CLI in an Eat terminal."
  :group 'tools
  :prefix "copilot-cli-")

(defcustom copilot-cli-program "copilot"
  "The command used to start Copilot CLI."
  :type 'string
  :group 'copilot-cli)

(defcustom copilot-cli-buffer-name "*copilot-cli*"
  "Name of the Copilot CLI terminal buffer."
  :type 'string
  :group 'copilot-cli)

(defun copilot-cli--project-root ()
  "Return the root directory of the current project.
Falls back to `default-directory' if no project is found."
  (or (when-let ((project (project-current)))
        (project-root project))
      default-directory))

(defun copilot-cli--buffer-name ()
  "Return a project-specific buffer name for Copilot CLI.
Includes the project root so each project gets its own session."
  (format "%s<%s>" copilot-cli-buffer-name
          (abbreviate-file-name (copilot-cli--project-root))))

;;;###autoload
(defun copilot-cli ()
  "Start Copilot CLI in an Eat terminal in a vertical split.

The terminal runs in the current project's root directory.  If a
Copilot CLI session is already running for this project, switch to
its buffer instead of starting a new one."
  (interactive)
  (let* ((root (copilot-cli--project-root))
         (default-directory root)
         (buf-name (copilot-cli--buffer-name))
         (buf (get-buffer buf-name)))
    (cond
     ;; Live session exists for this project — switch to it.
     ((and buf (get-buffer-process buf))
      (let ((win (get-buffer-window buf)))
        (if win
            (select-window win)
          (split-window-right)
          (other-window 1)
          (switch-to-buffer buf))))
     ;; Stale or no buffer — start fresh.
     (t
      (when buf (kill-buffer buf))
      (split-window-right)
      (other-window 1)
      (let ((eat-buf (eat copilot-cli-program)))
        (with-current-buffer eat-buf
          (rename-buffer buf-name t)))))))

(defun copilot-cli--find-buffer ()
  "Find the Copilot CLI buffer for the current project.
First tries the exact project-specific name, then falls back to
any buffer whose name starts with the base buffer name."
  (or (get-buffer (copilot-cli--buffer-name))
      (seq-find (lambda (b)
                  (string-prefix-p copilot-cli-buffer-name (buffer-name b)))
                (buffer-list))))

(defun copilot-cli--send-string (text)
  "Send TEXT to the Copilot CLI eat terminal using bracketed paste.
Bracketed paste wrapping ensures multiline content is delivered as
a single paste event rather than line-by-line input."
  (let* ((buf (copilot-cli--find-buffer))
         (proc (and buf (get-buffer-process buf))))
    (unless (and proc (process-live-p proc))
      (user-error "No active Copilot CLI session found"))
    (process-send-string proc
                         (concat "\e[200~" text "\e[201~"))
    (when-let ((win (get-buffer-window buf)))
      (select-window win))))

;;;###autoload
(defun copilot-cli-send-buffer ()
  "Send the entire current buffer content to the Copilot CLI session.
Useful for piping compilation output, test results, or any buffer
into an active chat session."
  (interactive)
  (copilot-cli--send-string
   (buffer-substring-no-properties (point-min) (point-max))))

;;;###autoload
(defun copilot-cli-send-region (beg end)
  "Send the region between BEG and END to the Copilot CLI session."
  (interactive "r")
  (copilot-cli--send-string
   (buffer-substring-no-properties beg end)))

;;;###autoload
(defun copilot-cli-stop ()
  "Stop the running Copilot CLI session and close its window.
Sends SIGINT to gracefully terminate, then force-kills if needed."
  (interactive)
  (if-let ((buf (copilot-cli--find-buffer)))
      (let ((proc (get-buffer-process buf))
            (win (get-buffer-window buf)))
        (when (and proc (process-live-p proc))
          (interrupt-process proc)
          (sit-for 0.5)
          (when (process-live-p proc)
            (delete-process proc)))
        (when (and win (window-deletable-p win))
          (delete-window win))
        (let ((kill-buffer-query-functions nil))
          (kill-buffer buf)))
    (message "No active Copilot CLI session found.")))

(provide 'copilot-cli)
;;; copilot-cli.el ends here
