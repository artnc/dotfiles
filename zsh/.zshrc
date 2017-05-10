######################################################## Sniff machine identity

[[ $(hostname) = "abra" ]]
ARCH_THINKPAD=$?
[[ $(hostname) = "arbok" ]]
ARCH_FLEX=$?
[[ $(hostname) = "artpi" ]]
ARCH_RPI=$?

######################################################### Environment variables

# Stuff that shouldn't be pushed to public GitHub
[[ -s $HOME/Documents/openai.sh ]] && . $HOME/Documents/openai.sh

if [ "$ARCH_FLEX" = 0 ]; then
  export EDITOR=/usr/bin/nvim
  export GOPATH=$HOME/go
  export PATH=$PATH:/home/art/.gem/ruby/2.3.0/bin:$GOPATH/bin
fi

export TERM=xterm-256color

# Google Cloud SDK
[ -f '/home/art/google-cloud-sdk/path.zsh.inc' ] && . '/home/art/google-cloud-sdk/path.zsh.inc'
[ -f '/home/art/google-cloud-sdk/completion.zsh.inc' ] && . '/home/art/google-cloud-sdk/completion.zsh.inc'

################################################################# Configure zsh

# Theme
ZSH_THEME=""

# Show red dots while waiting for completion
COMPLETION_WAITING_DOTS="true"

# oh-my-zsh
if [ "$ARCH_RPI" = 0 ]; then
  ZSH=~/.oh-my-zsh
  plugins=(zsh-syntax-highlighting)
  . $ZSH/oh-my-zsh.sh
else
  ZSH=/usr/share/oh-my-zsh
  . $ZSH/oh-my-zsh.sh
  . /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# nvm
[[ -s /usr/share/nvm/init-nvm.sh ]] && . /usr/share/nvm/init-nvm.sh

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

# Switch between QWERTY and Dvorak
alias aoeu='setxkbmap us'
alias asdf='setxkbmap dvorak'

# Pipe stdout to clipboard via echo "foo" | xc
alias xc='xclip -selection clipboard'

# Pacaur
alias pi='pacaur -S'
alias pu='pacaur -Syu'

# Default programs
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
alias -s py='subl3'
alias -s sass='subl3'
alias -s scss='subl3'
alias -s tex='subl3'
alias -s txt='subl3'
alias -s xml='subl3'

# Python
alias ipy='ipython'
alias pyprof='python -m cProfile -s "time"'

# Folder bookmarks
alias g='cd $HOME/git'

# Append always-used options to common commands
alias ag='ag --case-sensitive --color-line-number "0;32" --color-path "0;35" --hidden --nobreak --noheading'
alias df='df -hT'
alias diff='diff --color=always'

# Git
alias ga='git add -A'
alias gb='git branch'
alias gbb='git bisect bad'
alias gbg='git bisect good'
alias gca='git commit --amend'
alias gcane='git commit --amend --no-edit'
alias gcm='git commit -m'
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

# Kubernetes
alias k='kubectl'
alias kccc='kubectl config current-context'
alias kcuc='kubectl config use-context'
alias kd='kubectl describe'
alias kdj='kubectl describe job'
alias kdp='kubectl describe pod'
alias kg='kubectl get'
alias kgj='kubectl get job'
alias kgp='kubectl get pod'

##################################################################### Functions

# "p" as in "print". Delegates to `ls` for folders and `less` for files
p() {
  if [[ -f $1 ]]; then
    less $1
  else
    ls -AGl $1
  fi
}

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

# https://transfer.sh/
transfer() {
  if [ $# -eq 0 ]; then
    echo "No arguments specified. Usage:\necho transfer /tmp/test.md\ncat /tmp/test.md | transfer test.md"
    return 1
  fi
  tmpfile=$( mktemp -t transferXXX )
  if tty -s; then
    basefile=$(basename "$1" | sed -e 's/[^a-zA-Z0-9._-]/-/g')
    curl --progress-bar --upload-file "$1" "https://transfer.sh/$basefile" >> $tmpfile
  else
    curl --progress-bar --upload-file "-" "https://transfer.sh/$1" >> $tmpfile
  fi
  cat $tmpfile
  rm -f $tmpfile
}
