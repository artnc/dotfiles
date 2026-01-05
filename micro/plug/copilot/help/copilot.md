# Copilot Plugin

GitHub Copilot integration for micro editor.

## Commands

- `copilot.complete` - Request and insert a Copilot completion at cursor
- `copilot.signin` - Sign in to GitHub Copilot (device flow)
- `copilot.signout` - Sign out of GitHub Copilot
- `copilot.status` - Check Copilot status

## Default Keybinding

- `Ctrl-Space` - Request and insert completion

## Usage

1. First time setup: Run `copilot.signin` command
2. Copy the code shown and visit https://github.com/login/device
3. Once authenticated, press `Ctrl-Space` to request completions
4. Completions are inserted directly - use undo (Ctrl-Z) to reject

## Requirements

The Copilot language server must be installed at:
`~/.local/share/copilot-language-server/copilot-language-server`

Download from: https://github.com/github/copilot-language-server-release/releases
