# copilot-cli.el

Launch [GitHub Copilot CLI](https://github.com/github/copilot-cli) inside Emacs using an [Eat](https://codeberg.org/akib/emacs-eat) terminal buffer.

Running `M-x copilot-cli` splits your frame vertically (side by side) and opens a full terminal session rooted at your project directory — no context-switching required.

## Requirements

- Emacs 28.1+
- [eat](https://codeberg.org/akib/emacs-eat) 0.9+
- [copilot-cli](https://github.com/github/copilot-cli) installed and available in your `PATH`

## Installation

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/emacs-copilot-cli")
(require 'copilot-cli)
```

### use-package (with straight.el)

```elisp
(use-package copilot-cli
  :straight (:host github :repo "koprotk/emacs-copilot-cli")
  :commands (copilot-cli copilot-cli-stop copilot-cli-send-buffer copilot-cli-send-region))
```

### Doom Emacs

In `packages.el`:

```elisp
(package! copilot-cli
  :recipe (:host github :repo "koprotk/emacs-copilot-cli"))
```

In `config.el`:

```elisp
(use-package! copilot-cli
  :commands (copilot-cli copilot-cli-stop copilot-cli-send-buffer copilot-cli-send-region))
```

## Usage

| Command                    | Description                                      |
|----------------------------|--------------------------------------------------|
| `M-x copilot-cli`         | Start or switch to the Copilot CLI session       |
| `M-x copilot-cli-stop`    | Stop the session and close its window            |
| `M-x copilot-cli-send-buffer` | Send the entire current buffer to the CLI    |
| `M-x copilot-cli-send-region` | Send the selected region to the CLI          |

If a session is already running, `copilot-cli` switches to the existing buffer instead of starting a new one.

`copilot-cli-stop` works regardless of which buffer or project you call it from — it will find the active session even if the current project context differs from where the session was started.

### Sending buffer content

You can send any buffer's content directly to the Copilot CLI session — no manual copy-paste needed. This is especially useful for piping compilation output, test results, or error logs:

```elisp
;; From a *compilation* buffer, send everything:
M-x copilot-cli-send-buffer

;; Or select a region first, then:
M-x copilot-cli-send-region
```

Content is sent using [bracketed paste](https://en.wikipedia.org/wiki/Bracketed-paste) so multiline text is delivered as a single paste event. After sending, focus moves to the Copilot CLI window so you can immediately type your question.

### Keybinding examples

Bind it to whatever feels natural:

```elisp
;; Vanilla Emacs
(global-set-key (kbd "C-c c") #'copilot-cli)

;; Evil / Doom / Spacemacs leader key
(map! :leader :desc "Copilot CLI" "o c" #'copilot-cli)
```

## Customization

All options live under `M-x customize-group RET copilot-cli`:

| Variable                  | Default           | Description                    |
|---------------------------|-------------------|--------------------------------|
| `copilot-cli-program`     | `"copilot"`       | The executable to run          |
| `copilot-cli-buffer-name` | `"*copilot-cli*"` | Name of the terminal buffer    |

Example — use a different CLI command:

```elisp
(setq copilot-cli-program "gh copilot")
```

## How it works

1. Detects the project root via Emacs's built-in `project.el`.
2. Splits the frame vertically (`split-window-right`).
3. Launches an Eat terminal running `copilot-cli` in that root.
4. Reuses the existing session if one is already alive.

## License

GPL-3.0-or-later
