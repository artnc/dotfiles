#!/usr/bin/env bash
# https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-codespaces-for-your-account#dotfiles

set -eu

# Colored stderr loggers
logE() {
  printf '%s%s%s\n' "$(tput setaf 1)" "${1:-}" "$(tput sgr0)" >&2
}
logI() {
  printf '%s%s%s\n' "$(tput setaf 2)" "${1:-}" "$(tput sgr0)" >&2
}

# Create missing symlinks within home directory
ensure_symlink() {
  local -r src="${1}"
  local -r dst="${2}"
  local -r dst_dir="$(dirname "${dst}")"
  [[ -d ${dst_dir} ]] || mkdir -p "${dst_dir}"
  if [[ -n ${CODESPACES:-} ]]; then
    logI "Creating ${dst}..."
    ln -fs "${PWD}/${src}" "${dst}"
  elif [[ -f ${dst} ]] || [[ -d ${dst} ]]; then
    logI "Found existing ${dst}"
  else
    logI "Creating ${dst}..."
    ln -s "${PWD}/${src}" "${dst}"
  fi
}
ensure_symlink ag/.agignore ~/.agignore
ensure_symlink alacritty ~/.config/alacritty
ensure_symlink code/keybindings.json ~/.config/Code/User/keybindings.json
ensure_symlink code/settings.json ~/.config/Code/User/settings.json
ensure_symlink easystroke ~/.easystroke
ensure_symlink feh/.fehbg ~/.fehbg
ensure_symlink git/.git-template ~/.git-template
ensure_symlink git/.gitconfig ~/.gitconfig
ensure_symlink git/.gitignore ~/.gitignore
ensure_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
ensure_symlink gtk-3.0 ~/.config/gtk-3.0
ensure_symlink i3 ~/.config/i3
ensure_symlink i3blocks ~/.config/i3blocks
ensure_symlink iftop/.iftoprc ~/.iftoprc
ensure_symlink nano/.nanorc ~/.nanorc
ensure_symlink pylint/.pylintrc ~/.pylintrc
ensure_symlink ripgrep/.rgignore ~/.rgignore
ensure_symlink sublime ~/.config/sublime-text/Packages/User
ensure_symlink tmux/.tmux.conf ~/.tmux.conf
ensure_symlink virtualenvwrapper/postactivate ~/.virtualenvs/postactivate
ensure_symlink virtualenvwrapper/postmkvirtualenv ~/.virtualenvs/postmkvirtualenv
ensure_symlink x/.xbindkeysrc ~/.xbindkeysrc
ensure_symlink x/.xinitrc ~/.xinitrc
ensure_symlink x/.Xmodmap ~/.Xmodmap
ensure_symlink zsh/.zshrc ~/.zshrc

# Audit /etc and other files outside home directory
while read -r repo_path; do
  system_path="/${repo_path}"
  if [[ -f ${system_path} ]]; then
    repo_hash="$(md5sum "${repo_path}" | awk '{print $1}')"
    system_hash="$(md5sum "${system_path}" | awk '{print $1}')"
    if [[ ${repo_hash} == "${system_hash}" ]]; then
      logI "Found matching ${system_path}"
    else
      logE "Found mismatched ${system_path}; please resolve conflicts by hand"
      diff "${repo_path}" "${system_path}" || true
    fi
  else
    logE "Didn't find ${system_path}; please copy from this repo"
  fi

  # https://wiki.archlinux.org/title/Pacman/Pacnew_and_Pacsave
  pacnew_path="${system_path}.pacnew"
  if [[ -f ${pacnew_path} ]]; then
    logE "Found ${pacnew_path}; please merge changes into ${system_path} and delete"
    diff "${system_path}" "${system_path}.pacnew" || true
  fi
  pacsave_path="${system_path}.pacsave"
  if [[ -f ${pacsave_path} ]]; then
    logE "Found ${pacsave_path}; please delete if obsolete"
  fi
done < <(find etc -type f)
