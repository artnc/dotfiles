# Path to oh-my-zsh config

ZSH=$HOME/.oh-my-zsh

# Theme

ZSH_THEME=""

# Show red dots while waiting for completion

COMPLETION_WAITING_DOTS="true"

# oh-my-zsh plugins

plugins=(zsh-syntax-highlighting)

# oh-my-zsh

source $ZSH/oh-my-zsh.sh

###############################################################################

# Command history settings

HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Show how long a command took if it exceeded this (in seconds)

REPORTTIME=10

# Options

setopt auto_cd            # Don't need to type cd to cd
setopt correct            # Spelling correction
setopt dvorak             # Use Dvorak for spelling correction
setopt hist_reduce_blanks # Strip unnecessary whitespace from history
setopt inc_append_history # Immediately append commands to history

# Prompt formatting

autoload -U colors && colors
# PS1="%{$fg[green]%}%B[%*] %n@%m:%~ %#%{$reset_color%b%} " # Verbose
PS1="%{$fg[green]%}%B%* %~%b%{$reset_color%} "            # Minimalist

# Switch between QWERTY and Dvorak

alias aoeu='setxkbmap us'
alias asdf='setxkbmap dvorak'

# Common yum commands

alias yu='sudo yum upgrade --skip-broken -y'
alias yi='sudo yum install'
alias yr='sudo yum remove'

# Run Python from command line without IDLE

alias py='python -c'

# SSH aliases

alias power='ssh nc5rk@power5.cs.virginia.edu'

# Set current directory as Apache document root

docroot() {
  sudo rm -f /var/www/html
  sudo ln -s $PWD /var/www/html
}

# Combine multiple PDFs into a single output.pdf

combinepdf() {
  gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=./output-unfinished.pdf -dBATCH $*
  mv ./output-unfinished.pdf ./output.pdf
}

# Default programs

alias -s c='sublime'
alias -s conf='sublime'
alias -s cpp='sublime'
alias -s css='sublime'
alias -s hs='sublime'
alias -s html='sublime'
alias -s js='sublime'
alias -s md='sublime'
alias -s pdf='evince'
alias -s php='sublime'
alias -s py='sublime'
alias -s sass='sublime'
alias -s scss='sublime'
alias -s tex='sublime'
alias -s txt='sublime'
alias -s xml='sublime'
