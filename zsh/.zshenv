# Doing this here instead of in .zshrc so Claude Code can run node etc
if [[ -d "${HOME}/.local/share/mise/shims" ]]; then
  export PATH="${HOME}/.local/share/mise/shims:${PATH}"
fi

# Make mosh-server exit after 1 week without client contact. Otherwise orphans from
# ungraceful disconnects hold their UDP ports forever, and external mosh has only 11
# (60000-60010). Set here because mosh starts the server via non-interactive `zsh -c`
export MOSH_SERVER_NETWORK_TMOUT=604800
