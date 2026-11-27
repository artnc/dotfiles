#!/usr/bin/env bash
# https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-codespaces-for-your-account#dotfiles

set -eu

# Resolve repo-relative paths (e.g. `etc/common`) against this repo instead of
# the caller's cwd
cd "$(dirname "${BASH_SOURCE[0]}")"

# Colored stderr loggers
logE() {
  printf '%s%s%s\n' "$(tput setaf 1 2> /dev/null)" "${1//"${HOME}"/\~}" "$(tput sgr0 2> /dev/null)" >&2
}
logI() {
  printf '%s%s%s\n' "$(tput setaf 2 2> /dev/null)" "${1//"${HOME}"/\~}" "$(tput sgr0 2> /dev/null)" >&2
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
      ln -fns "${PWD}/${src}" "${dst}"
    fi
  # Check `-L` before `-e` since `-e` is false for a dangling symlink, which
  # would make `ln` fail and trip `set -e`
  elif [[ -L ${dst} ]]; then
    if [[ "$(readlink "${dst}")" == "${PWD}/${src}" ]]; then
      logI "Found existing ${dst}"
    else
      logE "Found ${dst} symlinked to $(readlink "${dst}") instead of ${PWD}/${src}"
    fi
  elif [[ -e ${dst} ]]; then
    logE "Found unsymlinked ${dst}"
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

# Audit files that we can't easily symlink
audit_nonsymlinks() {
  local -r src="${1}"
  local -r dst="${2}"
  if [[ -f ${dst} ]]; then
    local -r differences="$(diff "${src}" "${dst}" || true)"
    if [[ -n ${differences} ]]; then
      logE "Found mismatched ${dst}. Please resolve conflicts by hand"
      echo "${differences}"
    else
      logI "Found matching ${dst}"
    fi
  else
    logE "Didn't find ${dst}. Please copy from this repo"
  fi
}

# Merge tracked keys into a JSON file that we can't symlink because its owner
# rewrites it via temp file + rename(), which replaces a symlink with a regular
# file on the first write. Values in src win, and untracked keys in dst are kept
merge_json() {
  local -r src="${1}"
  local -r dst="${2}"
  if [[ ! -f ${dst} ]]; then
    logE "Didn't find ${dst}. Please run its app once and rerun this script"
    return
  fi
  # Arch installs jq only after this runs, so a fresh machine may lack it
  if ! command -v jq > /dev/null; then
    logE "Skipping ${dst} since jq isn't installed"
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

# Merge tracked keys into a Qt INI file that we can't symlink because its owner
# writes secrets into it, e.g. KeePassXC's KeeShare private key. Values in src
# win, and untracked keys in dst are kept
merge_ini() {
  local -r src="${1}"
  local -r dst="${2}"
  if [[ ! -f ${dst} ]]; then
    logE "Didn't find ${dst}. Please run its app once and rerun this script"
    return
  fi
  # Arch's package list doesn't include Python, so a fresh machine may lack it
  if ! command -v python3 > /dev/null; then
    logE "Skipping ${dst} since python3 isn't installed"
    return
  fi
  # Print the merged INI only if a tracked key differs. Declare separately so
  # that a Python error trips `set -e`
  local merged
  merged="$(
    python3 - "${src}" "${dst}" << 'EOF'
import configparser
import sys


def parse(path):
    # Keep `%` literal and keys case-sensitive like Qt's QSettings does
    p = configparser.ConfigParser(delimiters=("=",), interpolation=None)
    p.optionxform = str
    p.read(path)
    return p


src, dst = parse(sys.argv[1]), parse(sys.argv[2])
if any(dst.get(s, k, fallback=None) != v for s in src.sections() for k, v in src.items(s)):
    dst.read_dict(src)
    dst.write(sys.stdout, space_around_delimiters=False)
EOF
  )"
  if [[ -z ${merged} ]]; then
    logI "Found matching ${dst}"
    return
  fi
  logI "Updating ${dst}..."
  if [[ -z ${DRY_RUN:-} ]]; then
    printf '%s\n' "${merged}" > "${dst}"
  fi
}

# Process all dotfiles. Symlinks for programs that I'm not currently using but
# might try again in the future are commented out for posterity
if [[ ${os_name} == Darwin ]]; then
  ensure_symlink aerospace ~/.config/aerospace
  ensure_symlink ghostty/config-macos ~/.config/ghostty/config
  audit_nonsymlinks granted/config ~/.granted/config
  ensure_symlink hammerspoon ~/.hammerspoon
  merge_ini keepassxc/keepassxc.ini ~/Library/Application\ Support/keepassxc/keepassxc.ini
  ensure_symlink unity/Dvorak.shortcut ~/Library/Preferences/Unity/Editor-5.x/shortcuts/default/Dvorak.shortcut
  logI 'Applying macOS settings...'
  if [[ -z ${DRY_RUN:-} ]]; then
    macos/settings.sh
  fi
else
  ensure_symlink dunst ~/.config/dunst
  ensure_symlink fontconfig ~/.config/fontconfig
  ensure_symlink ghostty/config-linux ~/.config/ghostty/config
  ensure_symlink gtk-3.0 ~/.config/gtk-3.0
  ensure_symlink gtk-4.0 ~/.config/gtk-4.0
  ensure_symlink iftop/.iftoprc ~/.iftoprc
  merge_ini keepassxc/keepassxc.ini ~/.config/keepassxc/keepassxc.ini
  ensure_symlink sway ~/.config/sway
  ensure_symlink swaylock ~/.config/swaylock
  ensure_symlink waybar ~/.config/waybar
  ensure_symlink xdg-autostart ~/.config/autostart
  ensure_symlink yay/config.json ~/.config/yay/config.json
  ensure_symlink zsh/.zprofile ~/.zprofile
fi
ensure_symlink claude/CLAUDE.md ~/.claude/CLAUDE.md
ensure_symlink claude/settings.json ~/.claude/settings.json
ensure_symlink claude/skills ~/.claude/skills
ensure_symlink claude/themes ~/.claude/themes
ensure_symlink ghostty/config-base ~/.config/ghostty/config-base
ensure_symlink git/.git-template ~/.git-template
ensure_symlink_if_artnc git/.gitconfig ~/.gitconfig
ensure_symlink git/.gitignore ~/.gitignore
ensure_symlink micro/bindings.json ~/.config/micro/bindings.json
ensure_symlink micro/colorschemes ~/.config/micro/colorschemes
ensure_symlink micro/plug ~/.config/micro/plug
ensure_symlink micro/settings.json ~/.config/micro/settings.json
ensure_symlink mise/global.toml ~/.config/mise/config.toml
ensure_symlink mpv/mpv.conf ~/.config/mpv/mpv.conf
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

# Install Arch packages and enable their services. Run this after symlinking
# dotfiles so that yay uses my config. Commented-out packages are ones that
# I've used before but don't currently need
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
    cronie
    curl
    # direnv
    fzf
    fzf-tab
    git
    go-yq
    htop
    # iftop
    jq
    man-db
    micro
    mosh
    ncdu
    openssh
    pacman-contrib
    prek
    rclone
    ripgrep
    rsync
    syncthing
    tailscale
    tmux
    unzip
    wget
    yazi
    zip
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
  )
  # Arch Linux ARM lacks these. Its mirrorlist uses a GeoIP redirector instead
  # of reflector, and claude-code has no `armv7h` build
  if [[ "$(uname -m)" == x86_64 ]]; then
    pkgs+=(claude-code reflector)
  fi
  # pi isn't packaged: `npm install -g @mariozechner/pi-coding-agent`

  # List packages for graphical machines. Detect them by `sway` (or by
  # `xorg-server` on machines that I haven't moved to Sway yet) rather than
  # `WAYLAND_DISPLAY`, which is unset whenever Sway isn't running. Set
  # `GRAPHICAL=1` to install these on a new machine
  if [[ -n ${GRAPHICAL:-} ]] || pacman -Qq sway &> /dev/null || pacman -Qq xorg-server &> /dev/null; then
    pkgs+=(
      adw-gtk-theme # GTK 3 port of libadwaita that reads Iceberg colors from `gtk-3.0/gtk.css`
      alsa-utils
      brightnessctl
      cliphist
      dex
      docker
      docker-buildx
      docker-compose
      dunst
      ffmpeg
      firefox
      ghostty
      gimp
      gvfs
      imagemagick
      keepassxc
      libnotify # Provides `notify-send` for Waybar's low-battery warnings
      mpv
      network-manager-applet
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      pacgraph
      pipewire
      pipewire-alsa
      pipewire-pulse
      qownnotes
      qt6-wayland # Lets Qt apps (e.g. KeePassXC) run natively instead of via XWayland
      ristretto
      sway
      sway-contrib # Provides grimshot
      swaybg
      swayidle
      swaylock
      thunar
      thunar-archive-plugin
      ttf-dejavu
      ttf-liberation
      ttf-ms-fonts # Real Verdana, Georgia, etc. instead of Noto fallbacks
      ttf-roboto
      upower # Hibernates or powers off at 2% battery. See `CriticalPowerAction` in `/etc/UPower/UPower.conf`
      vocalinux
      waybar
      wireplumber
      wl-clipboard
      wmenu
      wtype
      xarchiver
      xdg-desktop-portal-wlr # Lets apps (e.g. Firefox) share and screenshot the screen
      xfce-polkit            # Shows password prompts when GUI apps need root (e.g. nm-applet)
      xorg-xwayland
      xpra
    )
  fi

  # Find and install missing packages
  # https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
  mapfile -t missing_pkgs < <(pacman -T "${pkgs[@]}")
  # `pacman -T` exits 127 if some are missing but 1 if it can't check at all
  wait "${!}" || [[ ${?} == 127 ]] || {
    logE 'Failed to check for missing Arch packages'
    exit 1
  }
  logI "Found $((${#pkgs[@]} - ${#missing_pkgs[@]})) existing Arch packages"
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
--system cronie.service
--system docker.service
--system tailscaled.service
--system upower.service
--user ssh-agent.socket
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
  # `GTK_THEME`, and setting it strips the background from Ghostty's toasts.
  # Also set the GTK 3 theme here, since GTK 3 on Wayland reads it from
  # gsettings and ignores `gtk-theme-name` in `gtk-3.0/settings.ini`
  while read -r key value; do
    if ! command -v gsettings > /dev/null; then
      logI "Skipping ${key} since gsettings isn't installed"
    elif [[ $(gsettings get org.gnome.desktop.interface "${key}") == "'${value}'" ]]; then
      logI "Found existing ${key}"
    else
      logI "Setting ${key}..."
      if [[ -z ${DRY_RUN:-} ]]; then
        gsettings set org.gnome.desktop.interface "${key}" "${value}" || logE "Failed to set ${key}"
      fi
    fi
  done << 'EOF'
color-scheme prefer-dark
gtk-theme adw-gtk3-dark
EOF

  # Set Thunar's xfconf properties, which can't be symlinked since xfconfd saves
  # each channel via temp file + rename()
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
thunar /default-view string ThunarDetailsView
thunar /last-menubar-visible bool true
thunar /last-restore-tabs bool true
thunar /misc-date-style string THUNAR_DATE_STYLE_YYYYMMDD
thunar /misc-full-path-in-tab-title bool true
thunar /misc-middle-click-in-tab bool true
thunar /misc-open-new-window-as-tab bool true
thunar /misc-single-click bool false
thunar /misc-symbolic-icons-in-sidepane bool false
thunar /shortcuts-icon-emblems bool true
thunar /shortcuts-icon-size string THUNAR_ICON_SIZE_24
EOF

  # Install my /etc files from etc/common, then from this machine's overlay (e.g.
  # etc/x13). Drop-ins are named 90-dotfiles.* in etc/common and 91-dotfiles.*
  # in overlays, so that overlays win and stale ones are findable
  etc_changed=()
  etc_wanted=' '
  while read -r src; do
    dst="/etc/${src#etc/*/}"
    etc_wanted+="${dst} "
    if cmp -s "${src}" "${dst}"; then
      logI "Found matching ${dst}"
    else
      logI "Installing ${dst}..."
      etc_changed+=("${dst}")
      if [[ -z ${DRY_RUN:-} ]]; then
        sudo install -Dm644 "${src}" "${dst}" || logE "Failed to install ${dst}"
      fi
    fi
    # The repo version is authoritative for whole files (e.g. reflector.conf),
    # so upstream changes to them are noise
    if [[ -f ${dst}.pacnew ]]; then
      logI "Deleting ${dst}.pacnew..."
      if [[ -z ${DRY_RUN:-} ]]; then
        sudo rm "${dst}.pacnew" || logE "Failed to delete ${dst}.pacnew"
      fi
    fi
  done < <(find etc/common "etc/$(uname -n)" -type f 2> /dev/null)

  # Delete drop-ins that I've since removed from this repo
  while read -r dst; do
    if [[ ${etc_wanted} == *" ${dst} "* ]]; then
      continue
    fi
    logI "Deleting ${dst}..."
    etc_changed+=("${dst}")
    if [[ -z ${DRY_RUN:-} ]]; then
      sudo rm "${dst}" || logE "Failed to delete ${dst}"
    fi
  done < <(find /etc -name '9[01]-dotfiles.*' 2> /dev/null)

  # Apply changed /etc files. Dedupe the commands since several files can share
  # one. logind reloads on SIGHUP without dropping sessions since systemd 254.
  # udevd rereads changed rules by itself before it handles new events, so a
  # trigger is enough
  declare -A etc_cmds=()
  for dst in "${etc_changed[@]}"; do
    case ${dst} in
      /etc/NetworkManager/*) etc_cmds['sudo nmcli general reload']=1 ;;
      /etc/mkinitcpio.conf.d/*) etc_cmds['sudo mkinitcpio -P']=1 ;;
      /etc/systemd/journald.conf.d/*) etc_cmds['sudo systemctl restart systemd-journald']=1 ;;
      /etc/systemd/logind.conf.d/*) etc_cmds['sudo systemctl reload systemd-logind']=1 ;;
      /etc/udev/rules.d/*) etc_cmds['sudo udevadm trigger --subsystem-match=serio']=1 ;;
    esac
  done
  for cmd in "${!etc_cmds[@]}"; do
    logI "Running ${cmd}..."
    if [[ -z ${DRY_RUN:-} ]]; then
      ${cmd} || logE "Failed to run ${cmd}"
    fi
  done

  # Report stock files that my drop-ins replaced but that are still modified,
  # e.g. full copies from before I switched to drop-ins
  for path in /etc/makepkg.conf /etc/mkinitcpio.conf /etc/pacman.conf /etc/security/faillock.conf /etc/systemd/journald.conf; do
    if pkg="$(pacman -Qqo "${path}" 2> /dev/null)" && pacman -Qii "${pkg}" | grep -qF "${path} [modified]"; then
      logE "Found modified ${path}. Please restore it from the ${pkg} package"
    fi
  done

  # https://wiki.archlinux.org/title/Pacman/Pacnew_and_Pacsave
  while read -r path; do
    logE "Found ${path}. Please merge it into ${path%.*} and delete it"
  done < <(find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2> /dev/null)
fi

# Install RTK
if command -v rtk > /dev/null; then
  logI 'Found existing rtk'
else
  logI 'Installing rtk...'
  if [[ -z ${DRY_RUN:-} ]]; then
    if [[ ${os_name} == Darwin ]] && command -v brew > /dev/null; then
      brew install rtk || logE 'Failed to install rtk'
    else
      # Install to ~/.local/bin. Use `pipefail` so that `sh` exiting 0 on empty
      # input doesn't hide a failed download
      (set -o pipefail && curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh) || logE 'Failed to install rtk'
    fi
  fi
fi

# micro and yazi don't auto-install plugins/extensions
if command -v micro > /dev/null; then
  while read -r repo_url; do
    # repo.json is an array for hosted plugins but an object for vendored ones.
    # Tolerate non-JSON responses so that `set -e` doesn't abort the script
    plugin_name="$(curl -fsSL "${repo_url}" | jq -r 'if type == "array" then .[].Name else .Name end' || true)"
    if [[ -z ${plugin_name} ]]; then
      logE "Couldn't resolve micro plugin name from ${repo_url}"
      continue
    elif [[ -d ~/.config/micro/plug/${plugin_name} ]]; then
      logI "Found existing micro ${plugin_name} plugin"
    else
      logI "Installing micro ${plugin_name} plugin..."
      if [[ -z ${DRY_RUN:-} ]]; then
        micro -plugin install "${plugin_name}" || logE "Failed to install micro ${plugin_name} plugin"
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
