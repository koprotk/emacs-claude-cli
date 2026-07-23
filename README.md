# emacs-claude-cli

Launch the [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
inside a [vterm](https://github.com/akermu/emacs-libvterm) terminal buffer,
scoped to the current project's root directory.

## Requirements

- Emacs 28.1+
- [`vterm`](https://github.com/akermu/emacs-libvterm) (builds a native module —
  needs `cmake` and a C compiler on first install)
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
| `M-x claude-cli-send-escape` | Send a raw `ESC` to Claude (useful with evil-mode).      |

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

If you use `evil-mode`, install
[`evil-collection`](https://github.com/emacs-evil/evil-collection) — it
ships a `vterm` module that handles state transitions between evil and
vterm's insert/normal modes for you. Doom Emacs users get this out of the
box with the `:editor evil` module.

Claude Code uses `ESC` for several TUI interactions, which collides with
`evil-mode`'s default binding that leaves insert state. To send a raw
`ESC` to Claude without leaving insert state, bind
`claude-cli-send-escape` to a convenient key — for example:

```elisp
(with-eval-after-load 'vterm
  (evil-define-key '(insert normal) vterm-mode-map
    (kbd "C-<escape>") #'claude-cli-send-escape))
```
