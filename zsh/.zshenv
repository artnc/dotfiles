# Doing this here instead of in .zshrc so Claude Code can run node etc
if [[ -d "${HOME}/.local/share/mise/shims" ]]; then
  export PATH="${HOME}/.local/share/mise/shims:${PATH}"
fi

# Make mosh-server exit after 1 week without client contact. Otherwise orphans from
# ungraceful disconnects hold their UDP ports forever, and external mosh has only 11
# (60000-60010). Set here because mosh starts the server via non-interactive `zsh -c`
export MOSH_SERVER_NETWORK_TMOUT=604800

# Point SSH at the agent that `ssh-agent.socket` starts on demand, so that
# KeePassXC can load my SSH key into it on unlock. Set here so that Sway apps (via
# `.zprofile`) and mosh sessions inherit it. Keep an existing value, e.g. from macOS
# launchd or a forwarded agent
if [[ -z ${SSH_AUTH_SOCK:-} && -S "${XDG_RUNTIME_DIR:-}/ssh-agent.socket" ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
fi
