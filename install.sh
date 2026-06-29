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

# Process all dotfiles. Symlinks for programs that I'm not currently using but
# might try again in the future are commented out for posterity
if [[ ${os_name} == Darwin ]]; then
  vscode_parent_dir="${HOME}/Library/Application Support"
  ensure_symlink aerospace ~/.config/aerospace
  ensure_symlink ghostty/config-macos ~/.config/ghostty/config
  ensure_symlink hammerspoon ~/.hammerspoon
  ensure_symlink unity/Dvorak.shortcut ~/Library/Preferences/Unity/Editor-5.x/shortcuts/default/Dvorak.shortcut
  audit_nonsymlinks granted/config ~/.granted/config
  audit_nonsymlinks xcode/artnc.idekeybindings ~/Library/Developer/Xcode/UserData/KeyBindings/artnc.idekeybindings
  audit_nonsymlinks xcode/Twilight.xccolortheme ~/Library/Developer/Xcode/UserData/FontAndColorThemes/Twilight.xccolortheme
else
  vscode_parent_dir="${HOME}/.config"
  # ensure_symlink feh/.fehbg ~/.fehbg
  ensure_symlink ghostty/config-linux ~/.config/ghostty/config
  ensure_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
  ensure_symlink gtk-3.0 ~/.config/gtk-3.0
  ensure_symlink i3 ~/.config/i3
  ensure_symlink i3blocks ~/.config/i3blocks
  ensure_symlink iftop/.iftoprc ~/.iftoprc
  ensure_symlink thunar/thunar.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml
  ensure_symlink x/.xbindkeysrc ~/.xbindkeysrc
  ensure_symlink x/.xinitrc ~/.xinitrc
  ensure_symlink x/.Xmodmap ~/.Xmodmap
  while read -r src; do
    audit_nonsymlinks "${src}" "/${src}"
  done < <(find etc -type f)
fi
audit_nonsymlinks code/extensions.vscode.txt \
  ~/.vscode/extensions/extensions.json \
  <(jq -r '.[].identifier.id' ~/.vscode/extensions/extensions.json | sort)
ensure_symlink claude/CLAUDE.md ~/.claude/CLAUDE.md
ensure_symlink claude/settings.json ~/.claude/settings.json
ensure_symlink code/keybindings.json "${vscode_parent_dir}/Code/User/keybindings.json"
ensure_symlink code/settings.json "${vscode_parent_dir}/Code/User/settings.json"
ensure_symlink ghostty/config-base ~/.config/ghostty/config-base
ensure_symlink git/.git-template ~/.git-template
ensure_symlink_if_artnc git/.gitconfig ~/.gitconfig
ensure_symlink git/.gitignore ~/.gitignore
ensure_symlink micro/bindings.json ~/.config/micro/bindings.json
ensure_symlink micro/colorschemes ~/.config/micro/colorschemes
ensure_symlink micro/plug ~/.config/micro/plug
ensure_symlink micro/settings.json ~/.config/micro/settings.json
ensure_symlink mise/global.toml ~/.config/mise/config.toml
ensure_symlink nano/.nanorc ~/.nanorc
ensure_symlink ripgrep/.rgignore ~/.rgignore
ensure_symlink tmux/.tmux.conf ~/.tmux.conf
ensure_symlink zsh/.zshenv ~/.zshenv
ensure_symlink zsh/.zshrc ~/.zshrc

# Install RTK
if command -v rtk > /dev/null; then
  logI "Found existing rtk"
else
  logI "Installing rtk..."
  if [[ -z ${DRY_RUN:-} ]]; then
    if [[ ${os_name} == Darwin ]] && command -v brew > /dev/null; then
      brew install rtk || logE "Failed to install rtk"
    else
      # Install to ~/.local/bin
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh || logE "Failed to install rtk"
    fi
  fi
fi

# micro and vscode don't auto-install plugins/extensions
if command -v code > /dev/null; then
  installed="$(code --list-extensions)"
  # Extensions to keep in the manifest (so the audit tracks them) but never
  # auto-install
  ignored=" github.copilot github.copilot-chat stkb.rewrap "
  while read -r ext_id || [[ -n ${ext_id} ]]; do
    if [[ ${ignored} == *" ${ext_id} "* ]]; then
      logI "Ignoring code ${ext_id} extension"
    elif grep -qixF "${ext_id}" <<< "${installed}"; then
      logI "Found existing code ${ext_id} extension"
    else
      logI "Installing code ${ext_id} extension..."
      if [[ -z ${DRY_RUN:-} ]]; then
        code --install-extension "${ext_id}" || logE "Failed to install code ${ext_id} extension"
      fi
    fi
  done < code/extensions.vscode.txt
fi
if command -v micro > /dev/null; then
  while read -r repo_url; do
    # repo.json is an array for hosted plugins but an object for vendored ones
    plugin_name="$(curl -fsSL "${repo_url}" | jq -r 'if type == "array" then .[].Name else .Name end')"
    if [[ -z ${plugin_name} ]]; then
      logE "Couldn't resolve micro plugin name from ${repo_url}"
      continue
    elif [[ -d ~/.config/micro/plug/${plugin_name} ]]; then
      logI "Found existing micro ${plugin_name} plugin"
    else
      logI "Installing micro ${plugin_name} plugin..."
      if [[ -z ${DRY_RUN:-} ]]; then
        micro -plugin install "${plugin_name}"
      fi
    fi
  done < <(jq -r '.pluginrepos[]?' micro/settings.json)
fi
