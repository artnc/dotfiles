######################################################## Sniff machine identity

[[ $(uname -r) =~ "fc" ]]
FEDORA_MBP=$?
[[ $(hostname) = "arbok" ]]
ARCH_LENOVO=$?
[[ $(hostname) = "artpi" ]]
ARCH_RPI=$?

######################################################### Environment variables

if [ "$FEDORA_MBP" = 0 ]; then
  # Stuff that shouldn't be pushed to public GitHub
  source $HOME/Documents/zshrc.sh

  # Environment variables
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib64:/lib64
  export LDFLAGS="$LDFLAGS -lm"
  export JAVA_HOME=/usr/lib/jvm/java-1.7.0
  export PATH=$PATH:$JAVA_HOME/bin
fi

################################################################# Configure zsh

# Path to oh-my-zsh config
if [ "$ARCH_LENOVO" = 0 ]; then
  ZSH=/usr/share/oh-my-zsh
else
  ZSH=$HOME/.oh-my-zsh
fi

# Theme
ZSH_THEME=""

# Show red dots while waiting for completion
COMPLETION_WAITING_DOTS="true"

# oh-my-zsh plugins
if [ "$ARCH_LENOVO" = 1 ]; then
  plugins=(zsh-syntax-highlighting)
fi

# oh-my-zsh
source $ZSH/oh-my-zsh.sh
if [ "$ARCH_LENOVO" = 0 ]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

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

######################################################################## Prompt

# Prompt formatting
autoload -U colors && colors

function gitprompt {
  if [ -d .git ]; then
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$branch" = "(detached from FETCH_HEAD)" ]; then
      message="$(git --no-pager log -1 --pretty=%s)"
      branch="(${message:0:24})"
    fi
    stashmarker="$([[ $(git stash list 2> /dev/null | tail -n1) != '' ]] && echo '*')"
    cleanliness="$([[ $(git status --porcelain 2> /dev/null | tail -n1) != '' ]] && echo 'red' || echo 'blue')"
    echo "%B%{$fg[$cleanliness]%} $branch$stashmarker%{$reset_color%}%b"
  fi
}

PROMPT='%{$fg[green]%}%B%1~%{$reset_color%}%b$(gitprompt) '

####################################################################### Aliases

if [ "$ARCH_RPI" = 1 ]; then
  # Switch between QWERTY and Dvorak
  alias aoeu='setxkbmap us'
  alias asdf='setxkbmap dvorak'

  # Pipe stdout to clipboard via echo "foo" | xc
  alias xc='xclip -selection clipboard'
  alias sublime='subl3'
fi
if [ "$FEDORA_MBP" = 0 ]; then
  # DNF
  alias yu='sudo dnf upgrade -y'
  alias yi='sudo dnf install'
  alias yr='sudo dnf remove'

  # VisualVM profiler
  alias jvisualvm='/usr/java/jdk1.7.0_04/bin/jvisualvm'
fi
if [ "$ARCH_LENOVO" = 0 ]; then
  # Packer
  alias pi='packer -S'
  alias pu='packer -Syu'
fi

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

# Detailed, colored ls
alias l='ls -AGl --color=auto'

# Python profiler
alias pyprof='python -m cProfile -s "time"'

# Folder bookmarks
alias g='cd $HOME/git'

# ag with always-used options
alias ag='ag -s --color-line-number "0;32" --color-path "0;35" --nobreak --noheading'

# Git
alias ga='git add -A'
alias gb='git branch'
alias gbb='git bisect bad'
alias gbg='git bisect good'
alias gca='git commit --amend'
alias gd='git diff'
alias gg='git log'
alias gk='git checkout'
alias gkm='git checkout master'
alias gkt='git checkout testcenter'
alias gl='git pull'
alias gp='git push'
alias gx='git reset'
alias gxh='git reset --hard'
alias gls='git review -d'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gss='git stash save -u'
alias gt='git status -uall'

##################################################################### Functions

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

# Wait 5 seconds and then begin screencast (press 'q' to stop)
screencast() {
  sleep 5
  ffmpeg -f x11grab -s 1920x1200 -i :0.0 -qscale 0 /home/art/Desktop/screencast.mp4
}

# git commands (easier than oh-my-zsh plugin?)
gc() {
  if (( ${#1} < 70 )); then # GitHub wraps first line after 69 chars
    git add -A
    git commit -v -m $1
  else
    echo "Commit message was ${#1} characters long."
  fi
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
