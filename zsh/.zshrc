if [[ "${OSTYPE}" == darwin* ]]; then
  IS_MAC=true
  alias date='gdate'  # GNU `date` provides nanosecond precision
else
  IS_MAC=false
fi
zmodload zsh/datetime # Provides EPOCHREALTIME, avoiding `date` forks
start=${EPOCHREALTIME}

##################################################################### Functions

# Mainly intended for use inside this .zshrc
function _command_exists {
  command -v "$1" > /dev/null
}
function _source_if_exists {
  [[ -f "$1" ]] && . "$1"
}
# Source the cached output of a slow `eval "$(cmd)"`-style init command (e.g.
# `brew shellenv`), regenerating the cache whenever the command's binary is
# newer than it. Run `rm -r ~/.cache/zsh` to force regeneration
function _evalcache {
  local -r cache="${XDG_CACHE_HOME:-${HOME}/.cache}/zsh/${1:t}.zsh"
  if [[ ! -s "${cache}" || "${commands[${1:t}]:-${1}}" -nt "${cache}" ]]; then
    mkdir -p "${cache:h}"
    "$@" > "${cache}"
  fi
  . "${cache}"
}

# Run the given command and then play a sound to signal completion
# TODO: Implement for Linux too?
function beep {
  afplay '/System/Library/Sounds/Tink.aiff'
  caffeinate "$@" || true
  afplay '/System/Library/Sounds/Glass.aiff'
}

# Headless Claude Code review and autofixer
function cr() (
  claude -p --dangerously-skip-permissions "/code-review xhigh --fix $*"
)

# Restart Claude Code sessions in tmux panes that run an outdated version,
# resuming each conversation in the same pane
function claude-restart {
  local pid id pane state name
  # Pass /dev/null so that jq doesn't read stdin when no session files exist
  jq -r --arg v "${$(claude --version)%% *}" 'select(.kind == "interactive" and .version != $v and .tmux != null) | "\(.pid) \(.sessionId) \(.tmux | split(".")[-1]) \(.status) \(.name)"' ~/.claude/sessions/*.json(N) /dev/null |
    while read -r pid id pane state name; do
      # Skip stale session files whose PID is gone or reused
      [[ $(ps -o args= -p "${pid}") == *claude* ]] || continue

      # Skip sessions that are mid-task so that we don't interrupt them
      if [[ ${state} != idle ]]; then
        echo "Skipping ${state} Claude session ${name}"
        continue
      fi

      # Exit Claude and wait for the pane's shell prompt to return
      echo "Restarting Claude session ${name} in pane ${pane}..."
      kill "${pid}"
      while kill -0 "${pid}" 2> /dev/null; do sleep 0.1; done

      # Resume the same conversation
      tmux send-keys -t "${pane}" "claude --dangerously-skip-permissions --resume ${id}" Enter
    done
}

# Mount/unmount LUKS-encrypted HDD
function hdd {
  local -r mount_name='seagate'
  local -r mount_point="/mnt/${mount_name}"
  local -r mapper_path="/dev/mapper/${mount_name}"
  if mount | grep -qF "${mount_point}"; then
    # Unmount. Stop Immich first since its bind mount keeps the fs busy, which
    # makes `luksClose` fail with "device in use"
    docker compose --project-directory ~/immich-app stop immich-server
    sudo umount "${mapper_path}"
    sleep 1
    sudo cryptsetup luksClose "${mount_name}"
  else
    # Mount. Address the LUKS container by UUID: the drive re-enumerated from
    # sda1 to sdb1 on 2026-10-04, so the hardcoded sda1 opened nothing and ext4
    # aborted its journal with "ext4_journal_check_start" once I/O started failing
    sudo cryptsetup luksOpen /dev/disk/by-uuid/4a49b7bb-8bda-440b-8c60-a073b79d9c60 "${mount_name}" || return 1
    sleep 1
    # Replay the journal and repair before mounting, in case the last unmount was
    # unclean. Preen mode (-p) fixes only unambiguously-safe problems. Exit codes
    # are a bitmask: 1 = errors corrected, 2 = corrected and reboot advised, but
    # >=4 means errors remain, so refuse to mount rather than touch a broken fs
    sudo fsck -p "${mapper_path}"
    if (( $? >= 4 )); then
      echo "hdd: fsck left errors uncorrected. Mapper is still open; run: sudo fsck -f ${mapper_path}" >&2
      return 1
    fi
    sudo mkdir -p "${mount_point}"
    sudo mount "${mapper_path}" "${mount_point}" || return 1
    # Start Immich, which refuses to start at boot while the drive is unmounted
    docker compose --project-directory ~/immich-app up -d
  fi
}

# "p" as in "print". Delegates to `ls` for folders and `less` for files
function p {
  local path="${1:-.}"
  if [[ -L "$path" ]]; then
    path="$(/usr/bin/readlink -f "$path")"
  fi
  if [[ -f "$path" ]]; then
    /usr/bin/less -M "$path"
  elif [[ $IS_MAC = true ]]; then
    /bin/ls -AGlo "$path"
  else
    /usr/bin/ls --almost-all --color=auto --no-group -l "$path"
  fi
}

# Stage all files and commit with message
function gc {
  if (( ${#1} > 69 )); then # GitHub wraps first line after 69 chars
    echo "Commit message was ${#1} characters long."
    return
  fi
  [[ -n "${NO_ADD}" ]] || git add --all
  if git config --get remote.origin.url | grep -qF '/duolingo/'; then
    GIT_CONFIG_VALUE_1="$(printf %s "moc.ogniloud@tra" | rev)" git commit -m "$@"
  else
    git commit -m "$@"
  fi
}
function gcna {
  NO_ADD=1 gc "$@"
}

# This function converts the HEAD commit into a new GitHub branch. Workflow:
#   1. Write code while on any branch, e.g. master
#   2. Commit change directly onto branch
#   3. Run `gpr` ("git push to review") to fork a new branch, push it to
#      GitHub, and reset the original branch to its previous commit
function gpr() (
  set -eu
  git log -n 1 | grep -q Chaidarun # Sanity check that I'm on my own commit
  local -r NEW_BRANCH_NAME=$(git log --format=%B -n 1 HEAD \
    | head -1 \
    | xargs -0 echo -n \
    | tr '[:space:]' '-' \
    | tr -cd '[:alnum:]-' \
    | sed -e 's/^-*//g' -e 's/-*$//g' -e 's/---*/-/g' \
    | tr '[:upper:]' '[:lower:]' \
  )
  git checkout -b "${NEW_BRANCH_NAME}"
  git push --set-upstream origin "${NEW_BRANCH_NAME}"
  git checkout -
  git reset --hard HEAD~1
)

# Convert all .mov files in /tmp to .mp4
function mp4 {
  local mov_file
  while read -r mov_file; do
    local base_name="${mov_file%.mov}"
    local mp4_file="${base_name}.mp4"
    if [[ ! -f "${mp4_file}" ]]; then
      echo "Creating ${mp4_file}..."
      ffmpeg -nostdin -i "${mov_file}" -loglevel error -vcodec h264 "${mp4_file}" || return 1
    fi
  done < <(find -H /tmp -maxdepth 1 -type f -name '*.mov' | sort)
  echo 'Done!'
}

# Print the adb transport of the one connected device whose
# ro.build.characteristics matches $1: "watch", or "phone" for anything that is
# not a watch. Empty output and nonzero exit unless exactly one device matches
function _adb_device_of_type {
  local -r want="$1"
  local serial hw characteristics match='' match_hw=''
  # adb's mDNS auto-connect already surfaces paired devices in `adb devices`
  # under their service name, so we just classify whatever is connected
  while read -r serial; do
    # </dev/null so adb doesn't drain the loop's stdin (the device list)
    read -r hw characteristics < <(adb -s "${serial}" shell 'echo $(getprop ro.serialno) $(getprop ro.build.characteristics)' </dev/null 2>/dev/null | tr -d '\r')
    if [[ "${want}" == watch ]]; then
      [[ "${characteristics}" == *watch* ]] || continue
    else
      [[ "${characteristics}" == *watch* ]] && continue
    fi
    # One device can have two connections (mDNS auto-connect plus `adb connect`
    # by ip:port), so skip any whose hardware serial we already matched
    [[ -n "${match}" && "${hw}" == "${match_hw}" ]] && continue
    # A second distinct match means we can't tell them apart, so refuse to guess
    [[ -n "${match}" ]] && return 1
    match="${serial}" match_hw="${hw}"
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [[ -n "${match}" ]] && print -r -- "${match}"
}

# Best-effort explicit connect for the rare case where adb's mDNS auto-connect
# is off. If auto-connect is on, this adds a second connection to the same device
# under its ip:port, which `_adb_device_of_type` dedupes. Tries every ip:port adb
# advertises for the `_adb-tls-connect._tcp` service, so it doesn't depend on the
# exact column layout of `adb mdns services`
function _adb_mdns_connect {
  local line tok
  adb mdns services 2>/dev/null | while read -r line; do
    [[ "${line}" == *_adb-tls-connect._tcp* ]] || continue
    for tok in ${(z)line}; do
      [[ "${tok}" == *:* ]] && adb connect "${tok}" >/dev/null 2>&1
    done
  done
}

# Ensure a wireless-debugging device of type $1 ("watch" or "phone") is connected
# over the LAN and print its adb transport on stdout. adb discovers paired
# devices over mDNS on its own (ADB_MDNS_AUTO_CONNECT, on by default), so the
# rotating ip:port never has to be entered - only a one-time pairing does
function _adb_ensure {
  local -r type="$1"
  local found i

  # Wait briefly for mDNS to surface the device (nudging a connect in case
  # auto-connect is off), then classify it by type
  for i in {1..10}; do
    found="$(_adb_device_of_type "${type}")" && { print -r -- "${found}"; return 0; }
    _adb_mdns_connect
    sleep 0.5
  done

  # Nothing appeared: this machine has probably never paired with the device.
  # Pairing is one-time
  echo "No ${type} found over mDNS. On the device: Settings > Developer options > Wireless debugging." >&2
  local target code
  if [[ "${type}" == phone ]]; then
    # Pair by QR code like Android Studio does. The QR code holds a made-up
    # service name and password, and scanning it makes the phone advertise a
    # pairing service under that name over mDNS, which reveals its ip:port
    local -r name="studio-${RANDOM}${RANDOM}"
    code="${RANDOM}${RANDOM}${RANDOM}"
    echo 'If this machine has never paired with it, open "Pair device with QR code" and scan:' >&2
    qrencode -t ANSIUTF8 "WIFI:T:ADB;S:${name};P:${code};;" >&2
    local line tok
    for i in {1..120}; do
      line="$(adb mdns services 2>/dev/null | grep -F "${name}" | grep -F _adb-tls-pairing._tcp)"
      for tok in ${(z)line}; do
        [[ "${tok}" == *:* ]] && target="${tok}"
      done
      [[ -n "${target}" ]] && break
      sleep 0.5
    done
    if [[ -z "${target}" ]]; then
      echo 'Timed out waiting for the scan. Is the phone on the same Wi-Fi as this machine?' >&2
      return 1
    fi
  else
    # Watches have no camera, so pair with the code shown on the watch instead
    echo 'If this machine has never paired with it, open "Pair device with pairing code" and enter:' >&2
    local host pair_port
    read "host?Device IP address (top of the Wireless debugging screen): "
    read "pair_port?Pairing port: "
    read "code?Pairing code: "
    target="${host}:${pair_port}"
  fi
  # Send adb's output to stderr since callers capture stdout as the transport
  adb pair "${target}" "${code}" >&2 || return 1

  # After pairing, mDNS auto-connect should bring it online within a few seconds
  for i in {1..20}; do
    found="$(_adb_device_of_type "${type}")" && { print -r -- "${found}"; return 0; }
    _adb_mdns_connect
    sleep 0.5
  done
  echo "Paired but no ${type} came online; is Wireless debugging still enabled?" >&2
  return 1
}

# Build a Gradle module's release APK and install+launch it on a connected
# device. $1 = device addr (ip:port). $2 = Gradle task. $3 = module dir, which is
# also where the release APK and the module's applicationId live
function _adb_deploy {
  local -r addr="$1" task="$2" module="$3"
  echo 'Building APK...'
  JAVA_HOME="${JAVA_HOME:-/opt/android-studio/jbr}" ./gradlew "${task}" || return 1
  # Scope to the AGP output dir so the search skips the huge build/intermediates tree
  local -r apk="$(find "${module}/build/outputs/apk" -path '*release*' -name '*.apk' -print -quit)"
  if [[ -z "${apk}" ]]; then
    echo "No release APK found in ${module}" >&2
    return 1
  fi
  echo "Installing ${apk}..."
  adb -s "${addr}" install -r --user 0 "${apk}" || return 1
  # Quit at the first applicationId line so sed needn't read the rest of the file
  local -r pkg="$(sed -nE '/applicationId =/{s/.*applicationId = "([^"]+)".*/\1/p;q;}' "${module}/build.gradle.kts")"
  if [[ -n "${pkg}" ]]; then
    echo 'Launching app...'
    # Launch via monkey's LAUNCHER intent rather than `am start -n pkg/activity`:
    # the wear activity lives in a `.wear` namespace, not under the applicationId,
    # so a relative component would resolve to the wrong class
    adb -s "${addr}" shell monkey -p "${pkg}" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  fi
}

# Deploy this Android project's phone app over LAN wireless debugging. Connect to
# the device's LAN IP directly; set a DHCP reservation to keep that IP stable
function phone {
  local addr
  addr="$(_adb_ensure phone)" || return 1
  _adb_deploy "${addr}" :app:assembleRelease app
}

# Deploy this Android project's Wear OS app over LAN wireless debugging
function wear {
  local addr
  addr="$(_adb_ensure watch)" || return 1
  _adb_deploy "${addr}" :wear:assembleRelease wear
}

# Deploy the watch-face repo's WFF watch face over LAN wireless debugging and
# make it the active watch face
function watchface {
  local addr
  addr="$(_adb_ensure watch)" || return 1
  _adb_deploy "${addr}" :watchface:assembleRelease watchface || return 1
  echo 'Activating watch face...'
  adb -s "${addr}" shell am broadcast -a com.google.android.wearable.app.DEBUG_SURFACE --es operation set-watchface --es watchFaceId com.chaidarun.watchface >/dev/null
}

# Send files/folders to another tailnet host's /tmp/inbox/
function send() (
  set -eu

  # Get target host
  if (( $# < 1 )); then
    echo 'Usage: send <host> [path...]' >&2
    return 1
  fi
  local -r host="${1}"
  shift

  # Determine list of items to send
  local -a items
  local tmp=''
  trap '[[ -n "${tmp}" ]] && rm -f "${tmp}"' EXIT
  if (( $# > 0 )); then
    items=("$@")
  elif [[ $IS_MAC == true ]]; then
    local mac_files=''
    mac_files=$(osascript -e 'POSIX path of (the clipboard as «class furl»)' 2>/dev/null || true)
    if [[ -n "${mac_files}" ]]; then
      local path
      while IFS= read -r path; do
        [[ -n "${path}" ]] && items+=("${path}")
      done <<< "${mac_files}"
    else
      tmp="${TMPDIR:-/tmp}/clipboard"
      if command -v pngpaste &>/dev/null && pngpaste "${tmp}" 2>/dev/null; then
        true
      else
        pbpaste > "${tmp}"
      fi
      items=("${tmp}")
    fi
  else
    local -r targets=$(xclip -selection clipboard -t TARGETS -o 2>/dev/null || true)
    if grep -q '^text/uri-list$' <<< "${targets}"; then
      local uri
      while IFS= read -r uri; do
        [[ "${uri}" == file://* ]] || continue
        # Strip file:// prefix, URL-decode percent-encoded chars
        items+=("$(printf '%b' "${${uri#file://}//%/\\x}")")
      done < <(xclip -selection clipboard -t text/uri-list -o | tr -d '\r')
    else
      tmp="${TMPDIR:-/tmp}/clipboard"
      local target=''
      target=$(grep -m1 '^image/png$' <<< "${targets}") \
        || target=$(grep -v '^text/' <<< "${targets}" | grep -m1 '/') \
        || true
      if [[ -n "${target}" ]]; then
        xclip -selection clipboard -t "${target}" -o > "${tmp}"
      else
        xclip -selection clipboard -o > "${tmp}"
      fi
      items=("${tmp}")
    fi
  fi

  # Preserve each item's path below the lowest common ancestor of all items
  # so a lone file keeps just its basename while siblings keep their shared tree
  # Use absolute normalized paths without resolving symlinks (:a, not :A)
  local -ar abs=("${items[@]:a}")
  # root = longest directory prefix shared by every item's parent dir
  local root="${abs[1]:h}"
  local p
  for p in "${abs[@]}"; do
    # Shrink root until it is an ancestor of (or equal to) this item's parent
    while [[ "${root}" != "/" && "${p:h}" != "${root}" && "${p:h}" != "${root}/"* ]]; do
      root="${root:h}"
    done
  done
  # Mark the root boundary with /./ so rsync -R recreates only the part below it
  local -r base="${root%/}"
  local -a sources=()
  for p in "${abs[@]}"; do
    sources+=("${base}/./${p#${base}/}")
  done

  # Send items
  local -r t_start=$(date +%s%3N)
  rsync -ahR --rsync-path="mkdir -p /tmp/inbox && rsync" "${sources[@]}" "${host}:/tmp/inbox/"
  printf 'Sent %d file(s) in %d ms\n' ${#items[@]} $(( $(date +%s%3N) - t_start ))
)

# SSH / mosh
function ssh() (
  set -eu

  # Syncthing sometimes messes with perms. https://superuser.com/a/215506
  if [[ -d "${HOME}/.ssh" ]]; then
    chmod 700 ~/.ssh && chmod 600 ~/.ssh/*.pem ~/.ssh/config
  fi

  # Translate -p flag, which mosh treats differently from ssh
  local ssh_port=() mosh_args=()
  while (( $# > 0 )); do
    case "${1}" in
      -p)
        ssh_port=(-p "${2}")
        shift 2
        ;;
      *)
        mosh_args+=("${1}")
        shift
        ;;
    esac
  done

  # Use mosh only if present on both local and remote. ControlMaster reuses the
  # probe's auth session and typed password for the real connection
  local -r socket="${HOME}/.ssh/mosh-probe-$$"
  if _command_exists mosh && command ssh \
      -o ControlMaster=auto \
      -o ControlPath="${socket}" \
      -o ControlPersist=15 \
      "${ssh_port[@]}" "${mosh_args[@]}" 'command -v mosh-server' > /dev/null 2>&1; then
    mosh --predict=experimental --ssh="ssh ${ssh_port[*]} -o ControlPath=${socket}" "${mosh_args[@]}"
  else
    command ssh -o ControlPath="${socket}" "${ssh_port[@]}" "${mosh_args[@]}"
  fi
)

# Detach every other attached tmux client, keeping only the one that called this
function tx {
  if [[ -z "${TMUX}" ]]; then
    echo 'Not inside tmux' >&2
    return 1
  fi
  local -r current="$(tmux display-message -p '#{client_tty}')"
  local tty
  while read -r tty; do
    [[ "${tty}" == "${current}" ]] || tmux detach-client -t "${tty}"
  done < <(tmux list-clients -F '#{client_tty}')
}

################################################################# Configure zsh

# Make Ctrl+Left and Ctrl+Right jump between words (this used to work out of the
# box but broke around January 2018 for some reason). Also handle Alt for
# consistency with macOS GUI apps
# https://unix.stackexchange.com/a/167045
bindkey "^[[1;3C" forward-word    # Alt+Right
bindkey "^[[1;3D" backward-word   # Alt+Left
bindkey "^[[1;5C" forward-word    # Ctrl+Right (fallback)
bindkey "^[[1;5D" backward-word   # Ctrl+Left (fallback)
bindkey "^[^?" backward-kill-word # Alt+Backspace (Ghostty sends ESC+DEL)

# Theme
export ZSH_THEME=""

# Show red dots while waiting for completion
export COMPLETION_WAITING_DOTS="true"

# oh-my-zsh
if [[ -d "/usr/share/oh-my-zsh" ]]; then
  ZSH=/usr/share/oh-my-zsh
  . "${ZSH}/oh-my-zsh.sh"
fi

# Command history settings
export HISTSIZE=1000000
export SAVEHIST=1000000
export HISTFILE="${HOME}/.zsh_history"

# Show how long a command took if it exceeded this (in seconds)
export REPORTTIME=10

# Options
setopt auto_cd              # Don't need to type cd to cd
setopt correct              # Spelling correction
setopt dvorak               # Use Dvorak for spelling correction
setopt hist_find_no_dups    # Skip duplicates when searching history
setopt hist_reduce_blanks   # Strip unnecessary whitespace from history
setopt share_history        # Sync immediately across concurrent shells
setopt no_beep              # Don't ring the terminal bell on ZLE errors
setopt no_check_jobs        # Since no_hup is enabled, don't ask when exiting
setopt no_hist_beep         # Don't ring the bell on missing history entries
setopt no_hup               # Run all background processes with nohup
setopt no_list_beep         # Don't ring the bell on ambiguous tab completion
setopt prompt_subst         # Enable prompt variable expansion

# Prompt formatting
autoload -U colors && colors

function gitprompt {
  if git rev-parse HEAD > /dev/null 2>&1; then
    local branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "${branch}" = "(detached from FETCH_HEAD)" ]; then
      local -r message="$(git --no-pager log -1 --pretty=%s)"
      branch="(${message:0:24})"
    fi
    local -r num_stashes="$(git stash list | wc -l | awk '{print $1}')"
    local -r stashmarker="$([[ "$num_stashes" != '0' ]] && printf '*%.0s' {1..$num_stashes})"
    local -r cleanliness="$([[ $(git status --porcelain 2> /dev/null | tail -n1) != '' ]] && echo 'red' || echo 'blue')"
    echo "%B%{$fg[$cleanliness]%} $branch$stashmarker%{$reset_color%}%b"
  fi
}

export PROMPT='%{$fg[green]%}%B%1~%{$reset_color%}%b$(gitprompt) '
export RPROMPT=''

# Command completions. compinit's security audit of completion dirs takes
# ~100ms, so skip it (-C) unless the dump is missing or older than a day
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qN.mh-24) ]]; then
  compinit -C
else
  compinit
fi
autoload bashcompinit && bashcompinit

####################################################################### Aliases

export PATH
PATH="${HOME}/.local/bin:${HOME}/bin:${PATH}"

# Switch between QWERTY and Dvorak
if _command_exists setxkbmap; then
  alias aoeu='setxkbmap us && xmodmap ${HOME}/.Xmodmap'
  alias asdf='setxkbmap us dvorak && xmodmap ${HOME}/.Xmodmap'
  # alias thai='setxkbmap -layout th -variant pat && xmodmap ${HOME}/.Xmodmap'
  # alias  ้ทงก='setxkbmap us dvorak && xmodmap ${HOME}/.Xmodmap'
fi

# Pipe stdout to clipboard via echo "foo" | xc
if _command_exists xclip; then
  alias xc='xclip -selection clipboard'
  alias xp='xclip -selection clipboard -o'
  if _command_exists jq; then
    alias xj='xclip -selection clipboard -o | jq -S . | xclip -selection clipboard'
  fi
elif _command_exists pbcopy; then
  alias xc='pbcopy'
  alias xp='pbpaste'
  if _command_exists jq; then
    alias xj='pbpaste | jq -S . | pbcopy'
  fi
fi

# Linux equivalent of Mac `open`
if ! _command_exists open; then
  alias open='xdg-open'
fi

# adb install
alias adbd='adb -d install -d -r'
alias adbe='adb -e install -d -r'

# make
alias m='make'

# Homebrew / yay
if _command_exists brew; then
  alias pn='brew install'
  alias pu='pi update --all && claude update && brew upgrade && brew upgrade --cask && claude-restart'
  alias px='brew uninstall'
else
  alias yay='yay --color=auto'
  function _pacman_remove_orphans() (
    set -e
    # https://www.reddit.com/r/archlinux/comments/kc4zq3/removing_orphans/
    local -r _pacman_orphans="$(yay -Qtdq || true)"
    [[ -z ${_pacman_orphans} ]] || printf %s "${_pacman_orphans}" | yay -Rns -
    # Hide the "removing X from target list" warning message that yay spams
    # for each still-needed package
    # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Detecting_more_unneeded_packages
    yay -Qqd | yay -Rsu - 2> >(grep -v ' from target list$' >&2)
  )
  # https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
  alias pn="pu && yay -S"
  function pu() (
    set -e
    _pacman_remove_orphans
    # https://unix.stackexchange.com/a/574496
    yay -Sy --noconfirm archlinux-keyring
    yay --noconfirm -Syu
    paccache -rk1
    paccache -ruk0
    yay -Sac --noconfirm
    if _command_exists xmodmap; then
      xmodmap ~/.Xmodmap
    fi
    if _command_exists synclient; then
      synclient TapButton1=1
      synclient TapButton2=3
      synclient TapButton3=2
    fi
    if _command_exists claude; then
      claude-restart
    fi
  )
  function px() (
    set -e
    yay -Rncs "${@}"
    _pacman_remove_orphans
  )
fi

# Coding agents
if _command_exists pi; then
  # Pi has no setting to hide only its "Package updates are available" startup
  # notice (`checkForPackageUpdates()` in `interactive-mode.js` bails out only on
  # `PI_OFFLINE`). Disable startup network checks since `pu` updates Pi and its
  # packages. Package commands must stay
  # online: `PI_OFFLINE=1 pi update` prints "Updated packages" but does nothing
  function pi() (
    if [[ ${1} == (install|update) ]]; then
      command pi "${@}"
    else
      PI_OFFLINE=1 command pi "${@}"
    fi
  )
fi
if _command_exists opencode; then
  alias c='opencode'
elif _command_exists pi; then
  alias c='pi update --extensions &> /dev/null; pi'
elif _command_exists claude; then
  alias c='claude --dangerously-skip-permissions'
fi

# fastmod
alias fm='fastmod --accept-all --hidden'

# Ripgrep
if _command_exists rg; then
  alias g='rg --crlf --engine=auto --hidden --line-number --max-columns=250 --multiline --no-heading --sort-files'
fi

# Append always-used options to common commands
if [[ $IS_MAC = true ]]; then
  alias df='df -h'
else
  alias df='df -hT'
fi

# Git
alias g2='git bisect'
alias g2b='git bisect bad'
alias g2g='git bisect good'
alias g2r='git bisect reset'
alias g2s='git bisect start'
alias ga='git add --all'
alias gb='git branch'
alias gbd='git branch | grep -v " master$" | xargs git branch -D'
alias gca='git commit --amend'
alias gcane='git commit --amend --no-edit'
alias gd='git diff'
alias gds='git diff --stat'
alias gdw='git diff -w'
alias gf='git fetch'
alias gg='git log'
alias gy='git cherry-pick'
alias gk='git checkout'
alias gkm='git checkout master'
alias gl='git pull'
alias gm='git merge'
alias gmm='git merge master'
alias gp='git push'
alias gr='git rebase'
alias gra='git rebase --abort'
alias grc='git rebase --continue'
alias gri='git rebase --interactive'
alias grm='git rebase master'
alias gsa='git stash apply'
alias gsd='git stash drop'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gss='git stash save --include-untracked'
alias gt='git status --untracked-files=all'
alias gv='git revert'
alias gw='git show'
alias gws='git show --stat'
alias gww='git show -w'
alias gx='git reset'
alias gxh='git reset --hard'

# micro
if [[ -n "${CODESPACES}" ]]; then
  alias e='code'
elif [[ -n "${SSH_CONNECTION}" ]]; then
  if _command_exists micro; then
    alias e='micro'
  elif _command_exists nano; then
    alias e='nano'
  fi
elif _command_exists micro; then
  alias e='micro'
elif _command_exists code; then
  alias e='code'
fi
alias -s c='s'
alias -s conf='s'
alias -s cpp='s'
alias -s css='s'
alias -s h='s'
alias -s hpp='s'
alias -s hs='s'
alias -s html='s'
alias -s js='s'
alias -s md='s'
alias -s pdf='evince'
alias -s php='s'
alias -s sass='s'
alias -s scss='s'
alias -s tex='s'
alias -s txt='s'
alias -s xml='s'

# systemctl
if _command_exists systemctl; then
  alias sc='sudo systemctl'
  alias scs='sudo systemctl start'
  alias scx='sudo systemctl stop'
  alias scr='sudo systemctl restart'
  alias sce='sudo systemctl enable'
  alias scd='sudo systemctl disable'
  alias sct='sudo systemctl status'
fi

# Tailscale
# https://tailscale.com/kb/1080/cli/?tab=macos#using-the-cli
tailscale_mac='/Applications/Tailscale.app/Contents/MacOS/Tailscale'
if [[ ${IS_MAC} == true ]] && [[ -f ${tailscale_mac} ]]; then
  alias tailscale="${tailscale_mac}"
fi

# tee
alias tt='tee "$(tty)"'

# tmux
alias ta='tmux new -A'

# ts
alias ts="ts -i %.s | awk '{sub(/^[0-9]+\.[0-9]+/, sprintf(\"%4d\", \$1 * 1000)); print}'"

# Zsh
alias z='. ~/.zshrc'

############################################ Environment variables and sourcing

if [[ $IS_MAC = true ]]; then
  export EDITOR=/opt/homebrew/bin/micro
else
  export EDITOR=/usr/bin/micro
fi

# Android Studio
if [[ -d "${HOME}/Android/Sdk" ]]; then
  export ANDROID_HOME="${HOME}/Android/Sdk"
  PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${PATH}"
fi

# direnv
if _command_exists direnv; then
  _evalcache direnv hook zsh
fi

# Docker
export DOCKER_BUILDKIT=1

# fzf
if _command_exists fzf; then
  _evalcache fzf --zsh
  if _command_exists rg; then
    # https://github.com/junegunn/fzf.vim/issues/121#issuecomment-546360911
    export FZF_DEFAULT_COMMAND='rg --files --hidden'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi

  # Make `gk **<TAB>` show a menu of most recent branches
  function _fzf_complete_gk {
    _fzf_complete --preview='git log --oneline -50 {}' -- "$@" < <(
      git reflog --format='%gs' |
      sed -n 's/checkout: moving from .* to \(.*\)/\1/p' |
      awk '!seen[$0]++' |
      head -50
    )
  }
fi

# Git
if [[ ${GITHUB_USER:-} == artnc ]] || [[ "${USER}" == art ]]; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0="user.name"
  export GIT_CONFIG_VALUE_0="Art Chaidarun"
  export GIT_CONFIG_KEY_1="user.email"
  # Reverse the string in pure zsh (split to chars, reverse order, join)
  export GIT_CONFIG_VALUE_1="${(j::)${(Oas::):-moc.nuradiahc@tra}}"
fi

# Homebrew
if _command_exists brew; then
  _evalcache /opt/homebrew/bin/brew shellenv
fi

# Java
if [[ -d '/opt/homebrew/opt/openjdk@17' ]]; then
  PATH="/opt/homebrew/opt/openjdk@17/bin:${PATH}"
  export CPPFLAGS='-I/opt/homebrew/opt/openjdk@17/include'
fi

# less
export LESS=-FRXQ

# mise
if _command_exists mise; then
  _evalcache mise activate zsh
fi

# .NET
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# pre-commit
if [[ $IS_MAC = true ]]; then
  export SKIP=no-commit-to-branch,validate-email-domain
else
  export SKIP=no-commit-to-branch,swiftlint,validate-email-domain
fi

# Rclone
# https://rclone.org/docs/#environment-variables
if _command_exists rclone; then
  # https://rclone.org/b2/#fast-list
  export RCLONE_FAST_LIST=true
  # https://rclone.org/docs/#p-progress
  export RCLONE_PROGRESS=true
  # https://rclone.org/docs/#track-renames
  export RCLONE_TRACK_RENAMES=true
  # https://rclone.org/b2/#transfers
  export RCLONE_TRANSFERS=32
fi

# Ruby. Computing Gem.user_dir takes ~60ms, so cache it
if _command_exists ruby; then
  _evalcache ruby -r rubygems -e 'puts "PATH=\"#{Gem.user_dir}/bin:${PATH}\""'
fi

# Unity CLI
_source_if_exists "${HOME}/.unity/env"
# Unity crudely greps .zshrc for its own snippet and will silently add it if absent :|
: '
# Unity CLI
. "/Users/art/.unity/env"
'

# VSCode
if [[ $IS_MAC = true ]]; then
  PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:${PATH}"
fi

# X
# https://stackoverflow.com/a/79028896
export DISPLAY=:0

# zsh-syntax-highlighting (should appear at end of .zshrc)
# https://github.com/zsh-users/zsh-syntax-highlighting
if [[ $IS_MAC = true ]]; then
  _source_if_exists /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
  _source_if_exists /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Duolingo (must be declared last)
_source_if_exists "${HOME}/Documents/Work/Duolingo/duolingo.sh"
_source_if_exists "${HOME}/.duolingo/init.sh"

###############################################################################

printf '\e[2m.zshrc took %.2fs\n' $((EPOCHREALTIME - start))
