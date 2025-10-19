#!/usr/bin/env bash
# https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-codespaces-for-your-account#dotfiles

set -eu

# Colored stderr loggers
logE() {
  printf '%s%s%s\n' "$(tput setaf 1)" "${1//${HOME}/~}" "$(tput sgr0)" >&2
}
logI() {
  printf '%s%s%s\n' "$(tput setaf 2)" "${1//${HOME}/~}" "$(tput sgr0)" >&2
}

# Create missing symlinks within home directory
ensure_symlink() {
  local -r src="${1}"
  local -r dst="${2}"
  local -r dst_dir="$(dirname "${dst}")"
  if [[ ! -d ${dst_dir} && -z ${DRY_RUN:-} ]]; then
    mkdir -p "${dst_dir}"
  fi
  if [[ -n ${CODESPACES:-} ]]; then
    logI "Creating ${dst}..."
    if [[ -z ${DRY_RUN:-} ]]; then
      ln -fs "${PWD}/${src}" "${dst}"
    fi
  elif [[ -f ${dst} ]] || [[ -d ${dst} ]]; then
    if [[ -L ${dst} ]]; then
      logI "Found existing ${dst}"
    else
      logE "Found unsymlinked ${dst}"
    fi
  else
    logI "Creating ${dst}..."
    if [[ -z ${DRY_RUN:-} ]]; then
      ln -s "${PWD}/${src}" "${dst}"
    fi
  fi
}
ensure_symlink_if_artnc() {
  local -r dst="${2}"
  if [[ ${GITHUB_USER:-} == artnc ]] || [[ "$(whoami)" == art ]]; then
    ensure_symlink "$@"
  else
    # This repo contains some very personal but not particularly sensitive
    # dotfiles (e.g. ~/.gitignore) that are kept here for illustrative purposes
    # but shouldn't be used by people other than artnc
    logI "Skipping ${dst} since you're not artnc..."
  fi
}

os_name="$(uname)"

# Audit /etc and other files that we can't easily symlink
audit_nonsymlinks() {
  local -r src="${1}"
  local -r dst="${2}"
  local -r dst_contents="${3:-${dst}}"
  if [[ -f ${dst_contents} || -p ${dst_contents} ]]; then
    differences="$(diff "${src}" "${dst_contents}" || true)"
    if [[ -n ${differences} ]]; then
      logE "Found mismatched ${dst}; please resolve conflicts by hand"
      echo "${differences}"
    else
      logI "Found matching ${dst}"
    fi
  else
    logE "Didn't find ${dst}; please copy from this repo"
  fi

  # https://wiki.archlinux.org/title/Pacman/Pacnew_and_Pacsave
  if [[ ${os_name} != Darwin ]]; then
    pacnew_path="${dst}.pacnew"
    if [[ -f ${pacnew_path} ]]; then
      logE "Found ${pacnew_path}; please merge changes into ${dst} and delete"
      diff "${dst}" "${dst}.pacnew" || true
    fi
    pacsave_path="${dst}.pacsave"
    if [[ -f ${pacsave_path} ]]; then
      logE "Found ${pacsave_path}; please delete if obsolete"
    fi
  fi
}

# Audit VSCode extensions, whose manifest isn't portable because it contains
# absolute paths. (We can't just use VSCode Settings Sync either because that
# works with only VSCode, not Cursor)
audit_vscode_extensions() {
  audit_nonsymlinks "${1}" "${2}" <(jq -r '.[].identifier.id' "${2}" | sort)
}

# Process all dotfiles
if [[ ${os_name} == Darwin ]]; then
  vscode_parent_dir="${HOME}/Library/Application Support"
  ensure_symlink aerospace ~/.config/aerospace
  ensure_symlink alacritty/alacritty.mac.toml ~/.config/alacritty/alacritty.toml
  audit_vscode_extensions code/extensions.cursor.txt ~/.cursor/extensions/extensions.json
  audit_vscode_extensions code/extensions.vscode.txt ~/.vscode/extensions/extensions.json
  ensure_symlink hammerspoon ~/.hammerspoon
  ensure_symlink sublime ~/Library/Application\ Support/Sublime\ Text/Packages/User
  ensure_symlink unity/Dvorak.shortcut ~/Library/Preferences/Unity/Editor-5.x/shortcuts/default/Dvorak.shortcut
  audit_nonsymlinks xcode/artnc.idekeybindings ~/Library/Developer/Xcode/UserData/KeyBindings/artnc.idekeybindings
  audit_nonsymlinks xcode/Twilight.xccolortheme ~/Library/Developer/Xcode/UserData/FontAndColorThemes/Twilight.xccolortheme
else
  vscode_parent_dir="${HOME}/.config"
  ensure_symlink alacritty ~/.config/alacritty
  ensure_symlink easystroke ~/.easystroke
  ensure_symlink feh/.fehbg ~/.fehbg
  ensure_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
  ensure_symlink gtk-3.0 ~/.config/gtk-3.0
  ensure_symlink i3 ~/.config/i3
  ensure_symlink i3blocks ~/.config/i3blocks
  ensure_symlink iftop/.iftoprc ~/.iftoprc
  ensure_symlink pylint/.pylintrc ~/.pylintrc
  ensure_symlink sublime ~/.config/sublime-text/Packages/User
  ensure_symlink virtualenvwrapper/postactivate ~/.virtualenvs/postactivate
  ensure_symlink virtualenvwrapper/postmkvirtualenv ~/.virtualenvs/postmkvirtualenv
  ensure_symlink x/.xbindkeysrc ~/.xbindkeysrc
  ensure_symlink x/.xinitrc ~/.xinitrc
  ensure_symlink x/.Xmodmap ~/.Xmodmap
  while read -r src; do
    audit_nonsymlinks "${src}" "/${src}"
  done < <(find etc -type f)
fi
ensure_symlink ag/.agignore ~/.agignore
ensure_symlink claude/CLAUDE.md ~/.claude/CLAUDE.md
ensure_symlink claude/settings.json ~/.claude/settings.json
ensure_symlink code/keybindings.json "${vscode_parent_dir}/Code/User/keybindings.json"
ensure_symlink code/keybindings.json "${vscode_parent_dir}/Cursor/User/keybindings.json"
ensure_symlink code/settings.json "${vscode_parent_dir}/Code/User/settings.json"
ensure_symlink code/settings.json "${vscode_parent_dir}/Cursor/User/settings.json"
ensure_symlink git/.git-template ~/.git-template
ensure_symlink_if_artnc git/.gitconfig ~/.gitconfig
ensure_symlink git/.gitignore ~/.gitignore
ensure_symlink nano/.nanorc ~/.nanorc
ensure_symlink ripgrep/.rgignore ~/.rgignore
ensure_symlink tmux/.tmux.conf ~/.tmux.conf
ensure_symlink zsh/.zshrc ~/.zshrc
