# Doing this here instead of in .zshrc so Claude Code can run node etc
if [[ -d "${HOME}/.local/share/mise/shims" ]]; then
  export PATH="${HOME}/.local/share/mise/shims:${PATH}"
fi
