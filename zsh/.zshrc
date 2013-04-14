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

# $PATH

export PATH=$PATH:/usr/lib64/openmpi/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64/openmpi/lib

###############################################################################

# Command history settings

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=$HOME/.zsh_history

# Show how long a command took if it exceeded this (in seconds)

REPORTTIME=10

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

# Color prompt based on git status

# function gitcolor {
#   # Check if we're inside a git repository
#   git rev-parse >& /dev/null
#   if [ $? -eq 0 ]; then
#     git remote update >& /dev/null
#     gitstatus=`git status -uno`
#     # Return a color based on git status (this acts like a switch statement)
#       echo $gitstatus | grep -q "ahead"
#       if [[ $? -eq 0 ]]; then
#         # Local branch ahead
#         echo 'green'
#         return
#       fi
#       echo $gitstatus | grep -q "behind"
#       if [[ $? -eq 0 ]]; then
#         # Local branch behind
#         echo 'red'
#         return
#       fi
#       echo $gitstatus | grep -q "Changes not staged"
#       if [[ $? -eq 0 ]]; then
#         # Repository dirty
#         echo 'yellow'
#         return
#       fi
#       echo $gitstatus | grep -q "nothing to commit"
#       if [[ $? -eq 0 ]]; then
#         # Repository clean
#         echo 'blue'
#         return
#       fi
#     # Default
#     echo 'magenta'
#   else
#     # Not inside a repository root
#     echo 'cyan'
#   fi
# }

# Prompt formatting

autoload -U colors && colors
# PROMPT="%{$fg[green]%}%B[%*] %n@%m:%~ %#%{$reset_color%b%} " # Verbose
PROMPT='%{$fg[green]%}%B%* %1~%b%{$reset_color%} '     # Minimalist

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
alias stampede='ssh artnc@stampede.tacc.utexas.edu'
alias blacklight='ssh artnc@blacklight.psc.teragrid.org'

# Folder bookmarks

alias p='cd $HOME/Documents/Projects'
alias u='cd $HOME/Documents/UVa'

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

# Move swap back into main memory (usually done after skype crashes...)
# http://askubuntu.com/a/90399

swap() {
  free_data="$(free)"
  mem_data="$(echo "$free_data" | grep 'Mem:')"
  free_mem="$(echo "$mem_data" | awk '{print $4}')"
  buffers="$(echo "$mem_data" | awk '{print $6}')"
  cache="$(echo "$mem_data" | awk '{print $7}')"
  total_free=$((free_mem + buffers + cache))
  used_swap="$(echo "$free_data" | grep 'Swap:' | awk '{print $3}')"

  echo -e "Free memory:\t$total_free kB ($((total_free / 1024)) MB)\nUsed swap:\t$used_swap kB ($((used_swap / 1024)) MB)"
  if [[ $used_swap -eq 0 ]]; then
      echo "Congratulations! No swap is in use."
  elif [[ $used_swap -lt $total_free ]]; then
      echo "Freeing swap..."
      sudo swapoff -a
      sudo swapon -a
  else
      echo "Not enough free memory. Exiting."
      exit 1
  fi
}

# git commands (easier than oh-my-zsh plugin?)

gc() {
  git add -A
  git commit -v -m $1
}

gp() {
  remote=`git remote `
  git push $remote master
}

gl() {
  remote=`git remote `
  git pull $remote master
}

gt() {
  git add -A
  git remote update >& /dev/null
  git status -uno
}

# http://stackoverflow.com/a/904023/1436320

mandelbrot() {
  local lines columns color a b p q i pnew
  ((columns=COLUMNS-1, lines=LINES-1, color=0))
  for ((b=-1.5; b<=1.5; b+=3.0/lines)) do
    for ((a=-2.0; a<=1; a+=3.0/columns)) do
      for ((p=0.0, q=0.0, i=0; p*p+q*q < 4 && i < 32; i++)) do
        ((pnew=p*p-q*q+a, q=2*p*q+b, p=pnew))
      done
      ((color=(i/4)%8))
      echo -n "\\e[4${color}m "
    done
    echo
  done
}
