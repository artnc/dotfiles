start=$(date +%s.%N)

##################################################################### Functions

# Mainly intended for use inside this .zshrc
command_exists() {
  command -v "$1" > /dev/null
}
source_if_exists() {
  [[ -f "$1" ]] && . "$1"
}

# "p" as in "print". Delegates to `ls` for folders and `less` for files
p() {
  local path="${1:-.}"
  if [[ -f "$path" ]]; then
    /usr/bin/less "$path"
  else
    /usr/bin/ls --almost-all --color=auto --no-group -l "$path"
  fi
}

# Stage all files and commit with message
gc() {
  if (( ${#1} < 70 )); then # GitHub wraps first line after 69 chars
    git add --all
    git commit --message="$1"
  else
    echo "Commit message was ${#1} characters long."
  fi
}

# This function converts HEAD into a GitHub branch. Workflow:
#   1. Write code while on any branch
#   2. Commit change directly onto master
#   3. Run `gpr` to fork branch, push to GitHub, and reset previous branch
gpr() {
  (
    set -eu
    git log -n 1 | grep -q Chaidarun
    local -r PARENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
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
    git checkout "${PARENT_BRANCH_NAME}"
    git reset --hard HEAD~1
  )
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
    num_stashes="$(git stash list | wc -l)"
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
if command_exists setxkbmap; then
  alias aoeu='setxkbmap us && xmodmap ${HOME}/.Xmodmap'
  alias asdf='setxkbmap dvorak && xmodmap ${HOME}/.Xmodmap'
  alias thai='setxkbmap -layout th -variant pat && xmodmap ${HOME}/.Xmodmap'
  alias  ้ทงก='setxkbmap dvorak && xmodmap ${HOME}/.Xmodmap'
fi

# Pipe stdout to clipboard via echo "foo" | xc
if command_exists xclip; then
  alias xc='xclip -selection clipboard'
fi

# Linux equivalent of Mac `open`
alias open='xdg-open'

# adb install
alias adbd='adb -d install -d -r'
alias adbe='adb -e install -d -r'

# make
alias m='make'

# pacman / pacaur
if command_exists pacaur; then
  alias pi='pacaur -S'
  # If a dropbox.desktop file is left over from a previously failed upgrade,
  # the next upgrade will fail. The package maintainer refuses to fix this :|
  # https://aur.archlinux.org/packages/dropbox/#comment-717660
  alias pu='sudo rm -f /usr/share/applications/dropbox.desktop ~/.cache/pacaur/dropbox/src/dropbox.desktop && pacaur --noconfirm --noedit -Syu && paccache -rk1 && paccache -ruk0'
  alias px='pacaur -Rs'
else
  alias pi='sudo pacman -S'
  alias pu='sudo pacman -Syu && paccache -rk1 && paccache -ruk0'
  alias px='sudo pacman -Rs'
fi

# Ripgrep
if command_exists rg; then
  alias g='rg --hidden --line-number --max-columns 250 --no-heading --sort-files'
fi

# Default programs
if command_exists subl; then
  alias -s c='subl'
  alias -s conf='subl'
  alias -s cpp='subl'
  alias -s css='subl'
  alias -s h='subl'
  alias -s hpp='subl'
  alias -s hs='subl'
  alias -s html='subl'
  alias -s js='subl'
  alias -s md='subl'
  alias -s pdf='evince'
  alias -s php='subl'
  alias -s sass='subl'
  alias -s scss='subl'
  alias -s tex='subl'
  alias -s txt='subl'
  alias -s xml='subl'
fi

# Python
alias ipy='ipython'
alias pyprof='python -m cProfile -s "time"'

# Append always-used options to common commands
alias df='df -hT'

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
alias gcm='git commit -m'
alias gd='git diff'
alias gds='git diff --stat'
alias gdw='git diff -w'
alias gf='git fetch'
alias gg='git log'
alias gh='git cherry-pick'
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

# Sublime Text
alias s='subl'

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
if command_exists direnv; then
  eval "$(direnv hook zsh)"
fi

# Duolingo
source_if_exists "${HOME}/Documents/Work/Duolingo/duolingo.sh"
source_if_exists "${HOME}/.duolingo/init.sh"

# fzf
source_if_exists /usr/share/fzf/key-bindings.zsh
source_if_exists /usr/share/fzf/completion.zsh
if command_exists fzf; then
  if command_exists fd; then
    export FZF_DEFAULT_COMMAND='fd --type f'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
fi

# nodenv
if [[ -d "${HOME}/.nodenv" ]]; then
  PATH="${HOME}/.nodenv/bin:${PATH}"
  eval "$(nodenv init -)"
fi

# Rclone
# https://rclone.org/docs/#environment-variables
if command_exists rclone; then
  # https://rclone.org/b2/#fast-list
  export RCLONE_FAST_LIST=true
  # https://rclone.org/docs/#p-progress
  export RCLONE_PROGRESS=true
  # https://rclone.org/b2/#transfers
  export RCLONE_TRANSFERS=32
fi

# Ruby
command_exists ruby && PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:${PATH}"
command_exists rbenv && eval "$(rbenv init -)"

# virtualenvwrapper
if [[ -d "${HOME}/.virtualenvs" ]]; then
  export WORKON_HOME="${HOME}/.virtualenvs"
  export PROJECT_HOME="${HOME}/git"
  source_if_exists /usr/bin/virtualenvwrapper_lazy.sh
  alias wo='workon'
fi

# xfce4-terminal
export TERM=xterm-256color

# zsh-syntax-highlighting (should appear at end of .zshrc)
# https://github.com/zsh-users/zsh-syntax-highlighting
source_if_exists /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

###############################################################################

end=$(date +%s.%N)
elapsed=$(printf "%.2f" $(echo "${end} - ${start}" | bc))
echo "\e[2m.zshrc took ${elapsed}s"
