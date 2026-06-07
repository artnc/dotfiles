if [[ "$(uname)" = Darwin ]]; then
  IS_MAC=true
  alias date='gdate'  # GNU `date` provides nanosecond precision
else
  IS_MAC=false
fi
start=$(date +%s.%N)

##################################################################### Functions

# Mainly intended for use inside this .zshrc
function _command_exists {
  command -v "$1" > /dev/null
}
function _source_if_exists {
  [[ -f "$1" ]] && . "$1"
}

# Run the given command and then play a sound to signal completion
# TODO: Implement for Linux too?
function beep {
  afplay '/System/Library/Sounds/Tink.aiff'
  caffeinate "$@" || true
  afplay '/System/Library/Sounds/Glass.aiff'
}

# Mount/unmount LUKS-encrypted HDD
function hdd {
  local -r mount_name='seagate'
  local -r mount_point="/mnt/${mount_name}"
  local -r mapper_path="/dev/mapper/${mount_name}"
  if mount | grep -qF "${mount_point}"; then
    # Unmount
    sudo umount "${mapper_path}"
    sleep 1
    sudo cryptsetup luksClose "${mount_name}"
  else
    # Mount
    sudo cryptsetup luksOpen /dev/sda1 "${mount_name}"
    sleep 1
    sudo mkdir -p "${mount_point}"
    sudo mount "${mapper_path}" "${mount_point}"
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
function gpr {
  (
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
}

# Convert all .mov files in /tmp to .mp4
function mp4 {
  local mov_file
  while read -r mov_file; do
    local base_name="${mov_file%.mov}"
    local mp4_file="${base_name}.mp4"
    if [[ ! -f "${mp4_file}" ]]; then
      echo "Creating ${mp4_file}..."
      ffmpeg -i "${mov_file}" -loglevel error -vcodec h264 "${mp4_file}"
    fi
  done < <(find -H /tmp -maxdepth 1 -type f -name '*.mov' | sort)
  echo 'Done!'
}

# Reconnect to a wireless debugging device
function _phone_connect {
  # Disconnect first since `adb connect` returns success even for a stale or
  # offline session
  adb disconnect "${1}" >/dev/null 2>&1
  local i
  for i in {1..20}; do
    adb connect "${1}" >/dev/null 2>&1
    adb devices | grep -q "^${1}[[:space:]]\+device$" && return 0
    sleep 0.5
  done
  return 1
}

# Deploy current Android project to phone over Tailscale wireless debugging
function phone {
  if [[ -z "${1}" ]]; then
    echo 'Usage: phone <wireless-debugging-port>' >&2
    return 1
  fi
  local -r ip="$(tailscale ip -4 pixel-10-pro)"
  local -r addr="${ip}:${1}"
  echo "Connecting to ${addr}..."
  if ! _phone_connect "${addr}"; then
    # A failed connect almost always means that this machine is no longer paired
    # with the phone, so prompt for a one-time pairing and then retry
    echo "Could not connect to ${addr} (the connect port may have rotated). If this machine is not paired, open \"Pair device with pairing code\" on the phone and enter:" >&2
    local pair_port pair_code
    read "pair_port?Pairing port: "
    read "pair_code?Pairing code: "
    adb pair "${ip}:${pair_port}" "${pair_code}" || return 1
    if ! _phone_connect "${addr}"; then
      echo "Device ${addr} never came online; check the connect port on the phone's Wireless debugging screen" >&2
      return 1
    fi
  fi
  echo 'Building APK...'
  JAVA_HOME="${JAVA_HOME:-/opt/android-studio/jbr}" ./gradlew assembleRelease || return 1
  local -r apk="$(find app -path '*release*' -name '*.apk' -print -quit)"
  if [[ -z "${apk}" ]]; then
    echo 'No release APK found' >&2
    return 1
  fi
  echo "Installing ${apk}..."
  adb -s "${addr}" install -r --user 0 "${apk}" || return 1
  local -r pkg="$(sed -nE 's/.*applicationId = "([^"]+)".*/\1/p' app/build.gradle.kts | head -1)"
  local -r activity="$(awk '
    /<activity/ && !/<\/activity/ { in_activity=1; name="" }
    in_activity && !name && match($0, /android:name="[^"]+"/) {
      name = substr($0, RSTART+14, RLENGTH-15)
    }
    /android.intent.category.LAUNCHER/ && in_activity { print name; exit }
    /<\/activity>|<activity[^>]*\/>/ { in_activity=0 }
  ' app/src/main/AndroidManifest.xml)"
  if [[ -n "${pkg}" && -n "${activity}" ]]; then
    echo 'Launching app...'
    adb -s "${addr}" shell am start --user 0 -n "${pkg}/${activity}"
  fi
}

# Send files/folders to another tailnet host's /tmp/inbox/
function send {
  setopt local_options
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
  rsync -ahR --mkpath "${sources[@]}" "${host}:/tmp/inbox/"
  printf 'Sent %d file(s) in %d ms\n' ${#items[@]} $(( $(date +%s%3N) - t_start ))
}

# SSH / mosh
function ssh {
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

# Command completions
autoload -Uz compinit && compinit
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

# Homebrew / pacman / pacaur / yay
if _command_exists brew; then
  alias pi='brew install'
  alias pu='brew upgrade && brew upgrade --cask'
  alias px='brew uninstall'
else
  function _pacman_remove_orphans {
  (
    set -e
    # https://www.reddit.com/r/archlinux/comments/kc4zq3/removing_orphans/
    local -r _pacman_orphans="$(pacman -Qtdq || true)"
    [[ -z ${_pacman_orphans} ]] || printf %s "${_pacman_orphans}" | sudo pacman -Rns -
    # Hide the "removing X from target list" warning message that pacman spams
    # for each still-needed package
    # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Detecting_more_unneeded_packages
    pacman -Qqd | sudo pacman -Rsu - 2> >(grep -v ' from target list$' >&2)
  )
  }
  if _command_exists yay; then
    _pacman_helper='yay'
  elif _command_exists pacaur; then
    _pacman_helper='pacaur'
  else
    _pacman_helper='pacman'
  fi
  # https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported
  alias pi="pu && ${_pacman_helper} -S"
  function pu {
  (
    set -e
    _pacman_remove_orphans
    # https://unix.stackexchange.com/a/574496
    sudo pacman -Sy --noconfirm archlinux-keyring
    "${_pacman_helper}" --noconfirm -Syu
    paccache -rk1
    paccache -ruk0
    "${_pacman_helper}" -Sac --noconfirm
    if _command_exists xmodmap; then
      xmodmap ~/.Xmodmap
    fi
    if _command_exists synclient; then
      synclient TapButton1=1
      synclient TapButton2=3
      synclient TapButton3=2
    fi
  )
  }
  function px {
  (
    set -e
    "${_pacman_helper}" -Rncs "${1}"
    _pacman_remove_orphans
  )
  }
fi

# Claude
if _command_exists claude; then
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

export EDITOR=/usr/bin/micro

# Android Studio
if [[ -d "${HOME}/Android/Sdk" ]]; then
  export ANDROID_HOME="${HOME}/Android/Sdk"
  PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${PATH}"
fi

# direnv
if _command_exists direnv; then
  eval "$(direnv hook zsh)"
fi

# Docker
export DOCKER_BUILDKIT=1

# fzf
if _command_exists fzf; then
  source <(fzf --zsh)
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
if [[ ${GITHUB_USER:-} == artnc ]] || [[ "$(whoami)" == art ]]; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0="user.name"
  export GIT_CONFIG_VALUE_0="Art Chaidarun"
  export GIT_CONFIG_KEY_1="user.email"
  export GIT_CONFIG_VALUE_1="$(printf %s "moc.nuradiahc@tra" | rev)"
fi

# Homebrew
PATH="/opt/homebrew/sbin:${PATH}" # iftop uses sbin for some reason
PATH="/opt/homebrew/bin:${PATH}" # literally everything else

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"


# Java
if [[ -d '/opt/homebrew/opt/openjdk@17' ]]; then
  PATH="/opt/homebrew/opt/openjdk@17/bin:${PATH}"
  export CPPFLAGS='-I/opt/homebrew/opt/openjdk@17/include'
fi

# less
export LESS=-FRXq

# .NET
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# nodenv
if [[ -d "${HOME}/.nodenv" ]]; then
  PATH="${HOME}/.nodenv/bin:${PATH}"
  eval "$(command nodenv init - --no-rehash zsh)"
fi

# pre-commit
if [[ $IS_MAC = true ]]; then
  export SKIP=no-commit-to-branch
else
  export SKIP=no-commit-to-branch,swiftlint
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

# Ruby
if _command_exists ruby; then
  PATH="$(command ruby -r rubygems -e 'puts Gem.user_dir')/bin:${PATH}"
fi
if _command_exists rbenv; then
  eval "$(command rbenv init - --no-rehash zsh)"
fi

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

end=$(date +%s.%N)
elapsed=$(printf "%.2f" $(echo "${end} - ${start}" | bc))
echo "\e[2m.zshrc took ${elapsed}s"
