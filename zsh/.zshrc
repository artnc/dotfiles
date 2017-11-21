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
#   1. Write code while on master
#   2. Commit change directly onto master
#   3. Run `gpr` to fork branch, push to GitHub, and reset local master
gpr() (
  set -eu
  git log -n 1 | grep -q Chaidarun
  local -r BRANCH_NAME=$(git log --format=%B -n 1 HEAD \
    | head -1 \
    | xargs -0 echo -n \
    | tr '[:space:]' '-' \
    | tr -cd '[:alnum:]-' \
    | sed -e 's/^-*//g' -e 's/-*$//g' -e 's/---*/-/g' \
    | tr '[:upper:]' '[:lower:]' \
  )
  git checkout -b "${BRANCH_NAME}"
  git push --set-upstream origin "${BRANCH_NAME}"
  git checkout master
  git reset --hard HEAD~1
)

################################################################# Configure zsh

# Theme
export ZSH_THEME=""

# Show red dots while waiting for completion
export COMPLETION_WAITING_DOTS="true"

# oh-my-zsh
if [[ -d "${HOME}/.oh-my-zsh" ]]; then
  ZSH="${HOME}/.oh-my-zsh"
  plugins=(zsh-syntax-highlighting) . "${ZSH}/oh-my-zsh.sh"
else
  ZSH=/usr/share/oh-my-zsh
  . "${ZSH}/oh-my-zsh.sh"
  . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Command history settings
export HISTSIZE=10000
export SAVEHIST=10000
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
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "${branch}" = "(detached from FETCH_HEAD)" ]; then
      message="$(git --no-pager log -1 --pretty=%s)"
      branch="(${message:0:24})"
    fi
    stashmarker="$([[ $(git stash list 2> /dev/null | tail -n1) != '' ]] && echo '*')"
    cleanliness="$([[ $(git status --porcelain 2> /dev/null | tail -n1) != '' ]] && echo 'red' || echo 'blue')"
    echo "%B%{$fg[$cleanliness]%} $branch$stashmarker%{$reset_color%}%b"
  fi
}

export PROMPT='%{$fg[green]%}%B%1~%{$reset_color%}%b$(gitprompt) '

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

# Pacaur
if command_exists pacaur; then
  alias pi='pacaur -S'
  alias pu='pacaur -Syu'
fi

# Ripgrep
if command_exists rg; then
  alias g='rg --color always --hidden --line-number --max-columns 250 --no-heading --sort-files'
fi

# Default programs
if command_exists subl3; then
  alias -s c='subl3'
  alias -s conf='subl3'
  alias -s cpp='subl3'
  alias -s css='subl3'
  alias -s h='subl3'
  alias -s hpp='subl3'
  alias -s hs='subl3'
  alias -s html='subl3'
  alias -s js='subl3'
  alias -s md='subl3'
  alias -s pdf='evince'
  alias -s php='subl3'
  alias -s sass='subl3'
  alias -s scss='subl3'
  alias -s tex='subl3'
  alias -s txt='subl3'
  alias -s xml='subl3'
fi

# Python
alias ipy='ipython'
alias pyprof='python -m cProfile -s "time"'

# Append always-used options to common commands
alias df='df -hT'
alias diff='diff --color=always'

# Git
alias ga='git add --all'
alias gb='git branch'
alias gbd='git branch | grep -v " master$" | xargs git branch -D'
alias gca='git commit --amend'
alias gcane='git commit --amend --no-edit'
alias gcm='git commit -m'
alias gd='git diff'
alias gf='git fetch'
alias gg='git log'
alias gk='git checkout'
alias gkm='git checkout master'
alias gl='git pull'
alias gm='git merge'
alias gmm='git merge master'
alias gp='git push'
alias gr='git rebase'
alias gra='git rebase --abort'
alias grc='git rebase --continue'
alias grm='git rebase master'
alias gsa='git stash apply'
alias gsd='git stash drop'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gss='git stash save --include-untracked'
alias gt='git status --untracked-files=all'
alias gx='git reset'
alias gxh='git reset --hard'

############################################ Environment variables and sourcing

export PATH

# Android Studio
if [[ -d "${HOME}/Android/Sdk" ]]; then
  export ANDROID_HOME="${HOME}/Android/Sdk"
  export ANDROID_NDK_HOME="${HOME}/Android/Sdk/ndk-bundle"
  PATH="${ANDROID_NDK_HOME}:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${PATH}"
fi

# Duolingo
source_if_exists "${HOME}/Documents/Work/Duolingo/duolingo.sh"

# fzf
source_if_exists /usr/share/fzf/key-bindings.zsh
source_if_exists /usr/share/fzf/completion.zsh

# nodenvs
if [[ -d "${HOME}/.nodenv" ]]; then
  PATH="${HOME}/.nodenv/bin:${PATH}"
  eval "$(nodenv init -)"
fi

# nvim
command_exists nvim && export EDITOR=/usr/bin/nvim

# nvm
# Adding `--no-use` can speed this up
# (https://github.com/creationix/nvm/issues/782) but results in a bug where `nvm
# use` deletes the current directory's node_modules. An alternative possibly
# worth investigating is zsh-nvm
source_if_exists /usr/share/nvm/init-nvm.sh
# source_if_exists /usr/share/nvm/init-nvm.sh --no-use

# Ruby
command_exists ruby && PATH="$(ruby -rubygems -e 'puts Gem.user_dir')/bin:${PATH}"

# virtualenvwrapper
if [[ -d "${HOME}/.virtualenvs" ]]; then
  export WORKON_HOME="${HOME}/.virtualenvs"
  export PROJECT_HOME="${HOME}/git"
  source_if_exists /usr/bin/virtualenvwrapper_lazy.sh
  alias wo='workon'
fi

# xfce4-terminal
export TERM=xterm-256color

###############################################################################

end=$(date +%s.%N)
elapsed=$(printf "%.2f" $(echo "${end} - ${start}" | bc))
echo "\e[2m.zshrc took ${elapsed}s"
