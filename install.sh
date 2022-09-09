#!/usr/bin/env bash
# https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-codespaces-for-your-account#dotfiles

set -eu

# Create missing symlinks within home directory
ensure_symlink() {
  local -r src="${1}"
  local -r dst="${2}"
  local -r dst_dir="$(dirname "${dst}")"
  [[ -d ${dst_dir} ]] || mkdir -p "${dst_dir}"
  if [[ -n ${CODESPACES:-} ]]; then
    echo "Creating ${dst}..."
    ln -fs "${PWD}/${src}" "${dst}"
  elif [[ -f ${dst} ]] || [[ -d ${dst} ]]; then
    echo "Found existing ${dst}"
  else
    echo "Creating ${dst}..."
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
ensure_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
ensure_symlink gtk-3.0 ~/.config/gtk-3.0
ensure_symlink i3 ~/.config/i3
ensure_symlink i3blocks ~/.config/i3blocks
ensure_symlink iftop/.iftoprc ~/.iftoprc
ensure_symlink nano/.nanorc ~/.nanorc
ensure_symlink pylint/.pylintrc ~/.pylintrc
ensure_symlink ripgrep/.rgignore ~/.rgignore
ensure_symlink sublime ~/.config/sublime-text-3/Packages/User
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
      echo "Found matching ${system_path}"
    else
      echo "Found mismatched ${system_path}"
      diff "${repo_path}" "${system_path}"
    fi
  else
    echo "Didn't find ${system_path}"
  fi
done < <(find etc -type f)
