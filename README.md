# emacs-claude-cli

Launch the [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
inside an [Eat](https://codeberg.org/akib/emacs-eat) terminal buffer, scoped
to the current project's root directory.

## Requirements

- Emacs 28.1+
- [`eat`](https://codeberg.org/akib/emacs-eat) 0.9+
- The `claude` executable on your `PATH`

## Installation

Drop `claude-cli.el` somewhere on your `load-path` and:

```elisp
(require 'claude-cli)
```

## Commands

| Command                    | Description                                                |
|----------------------------|------------------------------------------------------------|
| `M-x claude-cli`           | Start or switch to the Claude CLI session for the project. |
| `M-x claude-cli-stop`      | Stop the running session and close its window.             |
| `M-x claude-cli-clear`     | Clear the current conversation context (`/clear`).         |
| `M-x claude-cli-send-buffer` | Send the entire current buffer to the session.           |
| `M-x claude-cli-send-region` | Send the active region to the session.                   |
| `M-x claude-cli-send-escape` | Send a raw `ESC` to Claude (see evil-mode note below).   |

## Customization

| Variable                  | Default          | Purpose                                  |
|---------------------------|------------------|------------------------------------------|
| `claude-cli-program`      | `"claude"`       | Executable used to start the CLI.        |
| `claude-cli-args`         | `'()`            | Extra arguments passed to the CLI.       |
| `claude-cli-buffer-name`  | `"*claude-cli*"` | Base name for the terminal buffer.       |

Example:

```elisp
(setq claude-cli-args '("--dangerously-skip-permissions"))
```

## evil-mode compatibility

Claude Code uses `ESC` for several TUI interactions, which collides with
`evil-mode`'s default binding that leaves insert state. To avoid the
conflict, `claude-cli` locally rebinds `<escape>` inside the Claude buffer
so it sends a raw `ESC` to the TUI instead — the override is scoped to that
single buffer, so the rest of your evil bindings (including `C-w` window
navigation) keep working everywhere else.

If `evil` isn't loaded, nothing changes.
