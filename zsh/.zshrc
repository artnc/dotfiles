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

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Show how long a command took if it exceeded this (in seconds)

REPORTTIME=10

# Options

setopt auto_cd            # Don't need to type cd to cd
setopt correct            # Spelling correction
setopt dvorak             # Use Dvorak for spelling correction
setopt hist_reduce_blanks # Strip unnecessary whitespace from history
setopt inc_append_history # Immediately append commands to history
setopt prompt_subst       # Prompt expansion

# Prompt formatting

autoload -U colors && colors
function gitcolor {
  if [ -d .git ]; then
    # gitcolor=`git status -s`
    # if [[ ${#gitcolor} -gt 1 ]]; then
    #   echo 'red'
    # else
    #   echo 'green'
    # fi
    if [[]]; then
      # Local branch same
      gitcolor=`git status -s`
      if [[ ${#gitcolor} -gt 1 ]]; then
        # Repository dirty
        echo 'yellow'
      else
        # Repository clean
        echo 'blue'
      fi
    elif [[]]
      # Local branch ahead
      echo 'green'
    else
      # Local branch behind
      echo 'red'
  else
    # Not inside a repository root
    echo 'cyan'
  fi
}
# PS1="%{$fg[green]%}%B[%*] %n@%m:%~ %#%{$reset_color%b%} " # Verbose
PROMPT='%{$fg[$(gitcolor)]%}%B%* %1~%b%{$reset_color%} '            # Minimalist

###############################################################################

# Switch between QWERTY and Dvorak

alias aoeu='setxkbmap us'
alias asdf='setxkbmap dvorak'

# yum commands

alias yu='sudo yum upgrade --skip-broken -y'
alias yi='sudo yum install'
alias yr='sudo yum remove'

# SSH aliases

alias power='ssh nc5rk@power5.cs.virginia.edu'

# Folder bookmarks

alias p='cd ~/Documents/Projects'
alias u='cd ~/Documents/UVa'

# Default programs

alias -s c='sublime'
alias -s conf='sublime'
alias -s cpp='sublime'
alias -s css='sublime'
alias -s h='sublime'
alias -s hpp='sublime'
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

###############################################################################

# Combine multiple PDFs into a single output.pdf
# Example usage: combinepdf input1.pdf input2.pdf input3.pdf

combinepdf() {
  gs -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=./output-unfinished.pdf -dBATCH $*
  mv ./output-unfinished.pdf ./output.pdf
}

# Set current directory as Apache document root

docroot() {
  sudo rm -f /var/www/html
  sudo ln -s $PWD /var/www/html
}

# Mount/unmount UVa's home directory service

hds() {
  # If /mnt/hds exists
  if [ -d "/mnt/hds" ]; then
    # If /mnt/hds already contains files
    if [ "$(ls -A /mnt/hds)" ]; then
      echo "HDS is already mounted. Unmounting..."
      sudo umount /mnt/hds \
        && echo "Successfully unmounted."
    else
      echo "Mounting HDS..."
      sudo mount -t cifs //home1.Virginia.EDU/nc5rk /mnt/hds -o username=nc5rk \
        && echo "Successfully mounted."
      sudo thunar /mnt/hds
    fi
  else
    echo "Creating /mnt/hds and mounting HDS..."
    sudo mkdir -p /mnt/hds
    sudo mount -t cifs //home1.Virginia.EDU/nc5rk /mnt/hds -o username=nc5rk \
      && echo "Successfully mounted." \
      && sudo thunar /mnt/hds
  fi
}

# git commands (easier than oh-my-zsh plugin?)

gc() {
  git add -A
  git commit -v
}

gp() {
  remote=`git remote `
  git push $remote master
}

gl() {
  remote=`git remote `
  git pull $remote master
}
