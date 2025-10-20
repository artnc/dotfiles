if [[ "$(uname)" = Darwin ]]; then
  IS_MAC=true
  alias date='gdate'  # GNU `date` provides nanosecond precision
else
  IS_MAC=false
fi
start=$(date +%s.%N)

##################################################################### Functions

# Mainly intended for use inside this .zshrc
_command_exists() {
  command -v "$1" > /dev/null
}
_source_if_exists() {
  [[ -f "$1" ]] && . "$1"
}

# Run the given command and then play a sound to signal completion
# TODO: Implement for Linux too?
beep() {
  afplay '/System/Library/Sounds/Tink.aiff'
  caffeinate "$@" || true
  afplay '/System/Library/Sounds/Glass.aiff'
}

# Claude
c() {
  # Use real Docker executable instead of any shims
  image_id="$(/usr/local/bin/docker build -q - << EOF | head -1
FROM alpine:3.22.2
RUN apk add --no-cache bash npm && npm install -g @anthropic-ai/claude-code
EOF
)"
  # Run dangerously inside Docker sandbox
  docker_cmd=(
    /usr/local/bin/docker
    run --rm -it
    -e IS_SANDBOX=1 # Disables `--dangerously-skip-permissions cannot be used with root/sudo privileges`
    -v "${HOME}:/root:ro" # Give readonly access to global CLAUDE.md
    -v "${HOME}:${HOME}:ro" # Make symlinks that reference host paths still work
    -v "/tmp:/tmp" # Give write access to /tmp
    -v "/private/tmp:/private/tmp"
    -v "${HOME}/.claude:/root/.claude" # Let Claude write to its own files
    -v "${HOME}/.claude.json:/root/.claude.json"
    -v "${HOME}/.claude.json.backup:/root/.claude.json.backup"
    -v "${PWD}:/code" # Mount current directory
    -w /code
    "${image_id}"
  )
  "${docker_cmd[@]}" claude --dangerously-skip-permissions "$@"
}

# "p" as in "print". Delegates to `ls` for folders and `less` for files
p() {
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
gc() {
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
gcna() {
  NO_ADD=1 gc "$@"
}

# This function converts the HEAD commit into a new GitHub branch. Workflow:
#   1. Write code while on any branch, e.g. master
#   2. Commit change directly onto branch
#   3. Run `gpr` ("git push to review") to fork a new branch, push it to
#      GitHub, and reset the original branch to its previous commit
gpr() {
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

# Open the current directory's Sublime Text project, creating it if needed
sp() {
  project_file="${HOME}/.virtualenvs/$(basename "${PWD}").sublime-project"
  mkdir -p "$(dirname "${project_file}")"
  if [[ ! -f "${project_file}" ]]; then
    cat > "${project_file}" << EOM
{
  "folders": [
    {
      "folder_exclude_patterns": [
        "__pycache__",
        "node_modules"
      ],
      "path": "${PWD}"
    }
  ]
}
EOM
  fi
  subl "${project_file}"
}

################################################################# Configure zsh

# Make Ctrl+Left and Ctrl+Right jump between words. This used to work out of the
# box but broke around January 2018 for some reason...
# https://unix.stackexchange.com/a/167045
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

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
setopt hist_ignore_all_dups # Remove old duplicate commands
setopt hist_reduce_blanks   # Strip unnecessary whitespace from history
setopt inc_append_history   # Immediately append commands to history
setopt no_hup               # Run all background processes with nohup
setopt no_check_jobs        # Since no_hup is enabled, don't ask when exiting
setopt prompt_subst         # Enable prompt variable expansion

# Prompt formatting
autoload -U colors && colors

function gitprompt {
  if git rev-parse HEAD > /dev/null 2>&1; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "${branch}" = "(detached from FETCH_HEAD)" ]; then
      message="$(git --no-pager log -1 --pretty=%s)"
      branch="(${message:0:24})"
    fi
    num_stashes="$(git stash list | wc -l | awk '{print $1}')"
    stashmarker="$([[ "$num_stashes" != '0' ]] && printf '*%.0s' {1..$num_stashes})"
    cleanliness="$([[ $(git status --porcelain 2> /dev/null | tail -n1) != '' ]] && echo 'red' || echo 'blue')"
    echo "%B%{$fg[$cleanliness]%} $branch$stashmarker%{$reset_color%}%b"
  fi
}

export PROMPT='%{$fg[green]%}%B%1~%{$reset_color%}%b$(gitprompt) '
export RPROMPT=''

# Command completions
autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit

####################################################################### Aliases

# Switch between QWERTY and Dvorak
if _command_exists setxkbmap; then
  alias aoeu='setxkbmap us qwerty && xmodmap ${HOME}/.Xmodmap'
  alias asdf='setxkbmap us dvorak && xmodmap ${HOME}/.Xmodmap'
  alias thai='setxkbmap -layout th -variant pat && xmodmap ${HOME}/.Xmodmap'
  alias  ้ทงก='setxkbmap us dvorak && xmodmap ${HOME}/.Xmodmap'
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
  _pacman_remove_orphans() (
    set -e
    # https://www.reddit.com/r/archlinux/comments/kc4zq3/removing_orphans/
    _pacman_orphans="$(pacman -Qtdq || true)"
    [[ -z ${_pacman_orphans} ]] || printf %s "${_pacman_orphans}" | sudo pacman -Rns -
    # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Detecting_more_unneeded_packages
    pacman -Qqd | sudo pacman -Rsu -
  )
  if _command_exists yay; then
    _pacman_helper='yay'
  elif _command_exists pacaur; then
    _pacman_helper='pacaur'
  else
    _pacman_helper='pacman'
  fi
  alias pi="${_pacman_helper} -S"
  pu() (
    set -e
    _pacman_remove_orphans
    # https://unix.stackexchange.com/a/574496
    sudo pacman -Sy --noconfirm archlinux-keyring
    "${_pacman_helper}" --noconfirm -Syu
    paccache -rk1
    paccache -ruk0
    "${_pacman_helper}" -Sac --noconfirm
  )
  px() (
    set -e
    "${_pacman_helper}" -Rncs "${1}"
    _pacman_remove_orphans
  )
fi

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

# Sublime Text / VS Code / Zed
if [[ -n "${CODESPACES}" ]]; then
  alias s='code'
elif _command_exists code; then
  # Preferring VSCode over Cursor for now because Cursor lacks Unity extension
  # and I'm using Claude Code instead for AI anyway
  alias s='code'
elif _command_exists cursor; then
  alias s='cursor'
elif _command_exists subl; then
  alias s='subl'
elif _command_exists zed; then
  alias s='zed'
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

# SSH
# https://superuser.com/a/215506
if [[ -n "$(find "${HOME}/.ssh" -name '*.pem')" ]]; then
  alias ssh='chmod 700 ~/.ssh && chmod 600 ~/.ssh/*.pem ~/.ssh/config && ssh'
else
  alias ssh='chmod 700 ~/.ssh && chmod 600 ~/.ssh/config && ssh'
fi

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

############################################ Environment variables and sourcing

export EDITOR=/usr/bin/nano
export PATH

PATH="${HOME}/bin:${PATH}"

# Android Studio
if [[ -d "${HOME}/Android/Sdk" ]]; then
  export ANDROID_HOME="${HOME}/Android/Sdk"
  PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${PATH}"
fi

# awslogs
PATH="${HOME}/.local/bin:${PATH}"

# direnv
if _command_exists direnv; then
  eval "$(direnv hook zsh)"
fi

# Docker
export DOCKER_BUILDKIT=1
if [[ $IS_MAC = true ]]; then
  # https://stackoverflow.com/a/74148162
  export DOCKER_HOST="unix://${HOME}/Library/Containers/com.docker.docker/Data/docker.raw.sock"
fi

# Duolingo
_source_if_exists "${HOME}/Documents/Work/Duolingo/duolingo.sh"
_source_if_exists "${HOME}/.duolingo/init.sh"

# fzf
if _command_exists fzf; then
  if [[ $IS_MAC = true ]]; then
    _source_if_exists "${HOME}/.fzf.zsh"
  else
    _source_if_exists /usr/share/fzf/key-bindings.zsh
    _source_if_exists /usr/share/fzf/completion.zsh
  fi
  if _command_exists rg; then
    # https://github.com/junegunn/fzf.vim/issues/121#issuecomment-546360911
    export FZF_DEFAULT_COMMAND='rg --files --hidden'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# Git
if [[ ${GITHUB_USER:-} == artnc ]] || [[ "$(whoami)" == art ]]; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0="user.name"
  export GIT_CONFIG_VALUE_0="Art Chaidarun"
  export GIT_CONFIG_KEY_1="user.email"
  export GIT_CONFIG_VALUE_1="$(printf %s "moc.nuradiahc@tra" | rev)"
fi

# Java
if [[ -d '/opt/homebrew/opt/openjdk@17' ]]; then
  export PATH="/opt/homebrew/opt/openjdk@17/bin:${PATH}"
  export CPPFLAGS='-I/opt/homebrew/opt/openjdk@17/include'
fi

# .NET
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# nodenv
if [[ -d "${HOME}/.nodenv" ]]; then
  PATH="${HOME}/.nodenv/bin:${PATH}"
  nodenv() {
    eval "$(command nodenv init - --no-rehash zsh)"
    nodenv "$@"
  }
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
  # https://rclone.org/b2/#transfers
  export RCLONE_TRANSFERS=32
fi

# Ruby
if _command_exists ruby; then
  ruby() {
    PATH="$(command ruby -r rubygems -e 'puts Gem.user_dir')/bin:${PATH}"
    unfunction ruby
    ruby "$@"
  }
fi
if _command_exists rbenv; then
  rbenv() {
    eval "$(command rbenv init - --no-rehash zsh)"
    rbenv "$@"
  }
fi

# virtualenvwrapper
if [[ -d "${HOME}/.virtualenvs" ]]; then
  export WORKON_HOME="${HOME}/.virtualenvs"
  export PROJECT_HOME="${HOME}/git"
  _source_if_exists /usr/bin/virtualenvwrapper_lazy.sh
  alias wo='workon'
fi

# VSCode
if [[ $IS_MAC = true ]]; then
  PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:${PATH}"
fi

# zsh-syntax-highlighting (should appear at end of .zshrc)
# https://github.com/zsh-users/zsh-syntax-highlighting
if [[ $IS_MAC = true ]]; then
  _source_if_exists /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
else
  _source_if_exists /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

###############################################################################

end=$(date +%s.%N)
elapsed=$(printf "%.2f" $(echo "${end} - ${start}" | bc))
echo "\e[2m.zshrc took ${elapsed}s"
