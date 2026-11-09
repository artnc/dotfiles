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

# Merge tracked keys into a JSON file that we can't symlink because its owner
# rewrites it via temp file + rename(), which replaces a symlink with a regular
# file on the first write. Values in src win; untracked keys in dst are kept
merge_json() {
  local -r src="${1}"
  local -r dst="${2}"
  if [[ ! -f ${dst} ]]; then
    logE "Didn't find ${dst}; please run its app once and rerun this script"
    return
  fi
  if jq -es '.[0] * .[1] == .[0]' "${dst}" "${src}" > /dev/null; then
    logI "Found matching ${dst}"
    return
  fi
  logI "Updating ${dst}..."
  if [[ -z ${DRY_RUN:-} ]]; then
    jq -s '.[0] * .[1]' "${dst}" "${src}" > "${dst}.tmp"
    mv "${dst}.tmp" "${dst}"
  fi
}

# Install Arch packages and enable their services. Commented-out packages are
# ones that I've used before but don't currently need
if command -v pacman > /dev/null && [[ -z ${CODESPACES:-} ]]; then
  # Install yay, which installs both official and AUR packages. Every Arch
  # machine needs it since this script and `.zshrc` use it instead of pacman
  # https://github.com/Jguer/yay#binary
  if command -v yay > /dev/null; then
    logI 'Found existing yay'
  else
    logI 'Installing yay...'
    if [[ -z ${DRY_RUN:-} ]]; then
      yay_dir="$(mktemp -d)"
      { sudo pacman -Syu --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git "${yay_dir}" && (cd "${yay_dir}" && makepkg -si); } || {
        logE 'Failed to install yay'
        exit 1
      }
      rm -rf "${yay_dir}"
    fi
  fi

  # List packages for all machines
  pkgs=(
    base-devel
    # bc
    # cronie
    curl
    # direnv
    fzf
    git
    go-yq
    htop
    # iftop
    jq
    man-db
    micro
    # mise
    mosh
    ncdu
    # opencode-bin
    openssh
    pacman-contrib
    prek
    rclone
    ripgrep
    # rsync
    syncthing
    tailscale
    tmux
    unzip
    wget
    # yazi
    zip
    zsh
    zsh-syntax-highlighting
  )
  # Arch Linux ARM lacks these. Its mirrorlist uses a GeoIP redirector instead
  # of reflector, and claude-code has no `armv7h` build
  if [[ "$(uname -m)" == x86_64 ]]; then
    pkgs+=(claude-code reflector)
  fi
  # pi isn't packaged: `npm install -g @mariozechner/pi-coding-agent`

  # List packages for graphical machines. Detect them by `xorg-server` rather
  # than `DISPLAY`, which is unset over SSH/mosh and set by X forwarding. Set
  # `GRAPHICAL=1` to install these on a new machine
  if [[ -n ${GRAPHICAL:-} ]] || yay -Qq xorg-server &> /dev/null; then
    pkgs+=(
      # adwaita-qt5-git
      # adwaita-qt6-git
      acpi
      alsa-utils
      dex
      dmenu
      docker
      docker-compose
      dunst
      # ffmpeg
      firefox
      ghostty
      # gimp
      # gnome-themes-extra
      # gnome-themes-extra-gtk2
      gvfs
      i3-wm
      i3blocks
      # i3blocks-contrib-git
      # i3status
      # imagemagick
      keepassxc
      # mpv
      network-manager-applet
      # numlockx
      # pacgraph
      picom
      pipewire
      pipewire-alsa
      pipewire-pulse
      ristretto
      sysstat
      thunar
      # thunar-archive-plugin
      ttf-dejavu
      ttf-liberation
      # visual-studio-code-bin
      vocalinux
      wireplumber
      # xarchiver
      xclip
      xdotool
      xfce-polkit
      xfce4-clipman-plugin
      xfce4-power-manager
      xfce4-screenshooter
      xorg-server
      xorg-xinit
      xorg-xset
      # xpra
      xsecurelock
      xss-lock
    )
  fi

  # Install missing packages in a single transaction. Sync and upgrade first
  # since partial upgrades are unsupported and a stale sync DB 404s on download
  # https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
  missing_pkgs=()
  for pkg in "${pkgs[@]}"; do
    if yay -Qq "${pkg}" &> /dev/null; then
      logI "Found existing ${pkg}"
    else
      missing_pkgs+=("${pkg}")
    fi
  done
  if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    logI "Installing ${missing_pkgs[*]}..."
    if [[ -z ${DRY_RUN:-} ]]; then
      yay -Syu --needed "${missing_pkgs[@]}" || logE 'Failed to install packages'
    fi
  fi

  # Enable services of installed packages
  while read -r scope svc; do
    if systemctl "${scope}" is-enabled "${svc}" &> /dev/null; then
      logI "Found enabled ${svc}"
    elif ! systemctl "${scope}" cat "${svc}" &> /dev/null; then
      logI "Skipping ${svc} since it isn't installed"
    else
      logI "Enabling ${svc}..."
      if [[ -z ${DRY_RUN:-} ]]; then
        # System units need root, but `sudo` would make user units target root's
        # service manager instead of mine
        $([[ ${scope} == --system ]] && echo sudo) systemctl "${scope}" enable --now "${svc}" || logE "Failed to enable ${svc}"
      fi
    fi
  done << 'EOF'
--system docker.service
--system tailscaled.service
--user syncthing.service
EOF

  # Let me run docker without sudo. Query the group DB rather than this
  # session's groups, which lag `usermod` until I log in again
  if ! getent group docker > /dev/null; then
    logI "Skipping docker group since docker isn't installed"
  elif [[ " $(id -nG "$(whoami)") " == *' docker '* ]]; then
    logI 'Found existing docker group membership'
  else
    logI "Adding $(whoami) to docker group..."
    if [[ -z ${DRY_RUN:-} ]]; then
      sudo usermod -aG docker "$(whoami)" || logE "Failed to add $(whoami) to docker group"
    fi
  fi

  # Make libadwaita apps (e.g. Ghostty) dark. libadwaita doesn't support
  # `GTK_THEME`, and setting it strips the background from Ghostty's toasts
  if ! command -v gsettings > /dev/null; then
    logI "Skipping dark color scheme since gsettings isn't installed"
  elif [[ $(gsettings get org.gnome.desktop.interface color-scheme) == "'prefer-dark'" ]]; then
    logI 'Found existing dark color scheme'
  else
    logI 'Setting dark color scheme...'
    if [[ -z ${DRY_RUN:-} ]]; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark || logE 'Failed to set dark color scheme'
    fi
  fi
fi

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
  logI "Applying macOS settings..."
  if [[ -z ${DRY_RUN:-} ]]; then
    macos/settings.sh
  fi
else
  vscode_parent_dir="${HOME}/.config"
  # ensure_symlink feh/.fehbg ~/.fehbg
  ensure_symlink dunst ~/.config/dunst
  ensure_symlink ghostty/config-linux ~/.config/ghostty/config
  ensure_symlink gtk-2.0/.gtkrc-2.0 ~/.gtkrc-2.0
  ensure_symlink gtk-3.0 ~/.config/gtk-3.0
  ensure_symlink i3 ~/.config/i3
  ensure_symlink i3blocks ~/.config/i3blocks
  ensure_symlink iftop/.iftoprc ~/.iftoprc
  ensure_symlink picom ~/.config/picom
  ensure_symlink thunar/thunar.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml
  ensure_symlink x/.xinitrc ~/.xinitrc
  ensure_symlink x/.Xmodmap ~/.Xmodmap
  ensure_symlink xdg-autostart ~/.config/autostart
  while read -r src; do
    # Only x13 has the swap file that suspend-then-hibernate needs. Elsewhere,
    # logind would refuse the lid action and the machine would stay awake
    if [[ ${src} == etc/systemd/logind.conf.d/lid.conf && "$(uname -n)" != x13 ]]; then
      continue
    fi
    audit_nonsymlinks "${src}" "/${src}"
  done < <(find etc -type f)

  # Make xfce4-power-manager let logind handle the lid (for
  # suspend-then-hibernate), and lock via xss-lock since xfpm's default lockers
  # (e.g. `xflock4`) aren't installed
  while read -r channel prop type value; do
    if ! command -v xfconf-query > /dev/null; then
      logI "Skipping ${channel}${prop} since xfconf isn't installed"
    elif [[ "$(xfconf-query -c "${channel}" -p "${prop}" 2> /dev/null)" == "${value}" ]]; then
      logI "Found existing ${channel}${prop}"
    else
      logI "Setting ${channel}${prop}..."
      if [[ -z ${DRY_RUN:-} ]]; then
        xfconf-query -c "${channel}" -p "${prop}" -n -t "${type}" -s "${value}" || logE "Failed to set ${channel}${prop}"
      fi
    fi
  done << 'EOF'
xfce4-power-manager /xfce4-power-manager/logind-handle-lid-switch bool true
xfce4-session /general/LockCommand string loginctl lock-session
EOF
fi
audit_nonsymlinks code/extensions.vscode.txt \
  ~/.vscode/extensions/extensions.json \
  <(jq -r '.[].identifier.id' ~/.vscode/extensions/extensions.json | sort)
ensure_symlink claude/CLAUDE.md ~/.claude/CLAUDE.md
ensure_symlink claude/settings.json ~/.claude/settings.json
ensure_symlink claude/skills ~/.claude/skills
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
ensure_symlink opencode/opencode.json ~/.config/opencode/opencode.json
if [[ "$(uname -n)" == 'art-macbook-pro' ]]; then
  ensure_symlink opencode/opencode-work.jsonc ~/.config/opencode/opencode.jsonc
else
  ensure_symlink opencode/opencode-personal.jsonc ~/.config/opencode/opencode.jsonc
fi
ensure_symlink opencode/plugins ~/.config/opencode/plugins
merge_json opencode/cli.json ~/.config/opencode/cli.json
ensure_symlink pi/extensions ~/.pi/agent/extensions
ensure_symlink pi/keybindings.json ~/.pi/agent/keybindings.json
ensure_symlink pi/mcp.json ~/.pi/agent/mcp.json
ensure_symlink pi/session-summary.json ~/.pi/agent/session-summary.json
if [[ -f pi/models.json ]]; then
  ensure_symlink pi/models.json ~/.pi/agent/models.json
else
  logE "Didn't find pi/models.json! Please copy it from another machine"
fi
ensure_symlink pi/settings.json ~/.pi/agent/settings.json
ensure_symlink pi/web-search.json ~/.pi/web-search.json
ensure_symlink ripgrep/.rgignore ~/.rgignore
ensure_symlink tmux/.tmux.conf ~/.tmux.conf
ensure_symlink yazi ~/.config/yazi
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

# micro, vscode, and yazi don't auto-install plugins/extensions
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
if command -v ya > /dev/null; then
  while read -r dep; do
    flavor_name="${dep##*[:/]}"
    if [[ -d ~/.config/yazi/flavors/${flavor_name}.yazi ]]; then
      logI "Found existing yazi ${flavor_name} flavor"
    else
      logI "Installing yazi ${flavor_name} flavor..."
      if [[ -z ${DRY_RUN:-} ]]; then
        ya pkg install || logE "Failed to install yazi ${flavor_name} flavor"
      fi
    fi
  done < <(yq -oy '.flavor.deps[].use' yazi/package.toml)
fi
