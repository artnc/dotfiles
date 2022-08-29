#!/usr/bin/env bash
# https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-codespaces-for-your-account#dotfiles

set -eu

create_symlink() {
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
    echo "${PWD}/${src}" "${dst}"
  fi
}

create_symlink ag/.agignore ~/.agignore
create_symlink alacritty ~/.config/alacritty
create_symlink code/keybindings.json ~/.config/Code/User/keybindings.json
create_symlink code/settings.json ~/.config/Code/User/settings.json
create_symlink easystroke ~/.easystroke
create_symlink feh/.fehbg ~/.fehbg
create_symlink git/.gitconfig ~/.gitconfig
create_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
create_symlink gtk-3.0 ~/.config/gtk-3.0
create_symlink i3 ~/.config/i3
create_symlink i3blocks ~/.config/i3blocks
create_symlink iftop/.iftoprc ~/.iftoprc
create_symlink nano/.nanorc ~/.nanorc
create_symlink pylint/.pylintrc ~/.pylintrc
create_symlink ripgrep/.rgignore ~/.rgignore
create_symlink sublime ~/.config/sublime-text-3/Packages/User
create_symlink tmux/.tmux.conf ~/.tmux.conf
create_symlink virtualenvwrapper/postactivate ~/.virtualenvs/postactivate
create_symlink virtualenvwrapper/postmkvirtualenv ~/.virtualenvs/postmkvirtualenv
create_symlink x/.xbindkeysrc ~/.xbindkeysrc
create_symlink x/.xinitrc ~/.xinitrc
create_symlink x/.Xmodmap ~/.Xmodmap
create_symlink zsh/.zshrc ~/.zshrc
